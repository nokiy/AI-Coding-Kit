#!/usr/bin/env bash
# Full-suite helper for .github/workflows/full-suite.yml: every GitHub call the central nightly flow makes.
# Usage: full-suite.sh <command> [args]   (needs gh; GH_REPO=<owner/repo> and SHA=<commit> in the environment)
#   seen                 print "state=<success|failure|pending|none> age=<minutes>" of the latest full-suite status
#   mark <state> <desc>  write the full-suite commit status (pending | success | failure), target = RUN_URL
#   run                  run BUILD_CMD (empty = none), then TEST_CMD; a failed test run is rerun once, a failed
#                        build is not; prints verdict=<green|flaky|red>; logs in LOG_DIR (build, test-1, test-2)
#   report <verdict>     status first, then issues per FILER (central | external), see below
#   backstop             FILER=external: failure older than WINDOW_MIN and no open nightly-red issue → open one 未经评审
#   suspects             PRs merged since the last commit with a green full-suite (best effort, bounded)
# Issues (one open nightly-red per repo, at most):
#   green | flaky → close open nightly-red issues with 「已恢复」 (both filers)
#   flaky, central → comment on the open ci-health issue titled 全量偶发记录, or open it
#   red, central   → comment on the open nightly-red issue, or open one; external → status only (backstop later)
# Exit: 0 done · 1 a required gh call failed · 2 usage

set -u
CONTEXT=full-suite
RED=nightly-red
HEALTH=ci-health
FLAKY_TITLE="全量偶发记录"
LOG_DIR=${LOG_DIR:-${RUNNER_TEMP:-/tmp}/full-suite}
TAIL_LINES=${TAIL_LINES:-80}
SUSPECT_DEPTH=${SUSPECT_DEPTH:-30}

die() { echo "full-suite: $*" >&2; exit 2; }
need() { [ -n "${!1:-}" ] || die "$1 is not set"; }
api() { gh api "$@"; }

seen() {
  need GH_REPO; need SHA
  local out
  out=$(api "repos/$GH_REPO/commits/$SHA/statuses?per_page=100" --jq \
    "[.[] | select(.context == \"$CONTEXT\")][0] // empty
     | \"\(.state) \(((now - (.created_at | fromdateiso8601)) / 60) | floor)\"") || return 1
  [ -n "$out" ] || { echo "state=none age=0"; return 0; }
  echo "state=${out% *} age=${out#* }"
}

mark() {
  need GH_REPO; need SHA
  api -X POST "repos/$GH_REPO/statuses/$SHA" -f state="$1" -f context="$CONTEXT" \
    -f description="$2" -f target_url="${RUN_URL:-}" --silent
}

run() {
  need TEST_CMD
  mkdir -p "$LOG_DIR"; rm -f "$LOG_DIR"/*.log
  if [ -n "${BUILD_CMD:-}" ]; then
    bash -c "$BUILD_CMD" 2>&1 | tee "$LOG_DIR/build.log"
    [ "${PIPESTATUS[0]}" = 0 ] || { echo "verdict=red"; return 0; }
  fi
  bash -c "$TEST_CMD" 2>&1 | tee "$LOG_DIR/test-1.log"
  [ "${PIPESTATUS[0]}" = 0 ] && { echo "verdict=green"; return 0; }
  echo "::warning::full suite failed once — rerunning the whole test command"
  bash -c "$TEST_CMD" 2>&1 | tee "$LOG_DIR/test-2.log"
  if [ "${PIPESTATUS[0]}" = 0 ]; then echo "verdict=flaky"; else echo "verdict=red"; fi
}

open_issues() { # <label> [jq filter] → numbers of open issues with that label
  gh issue list -R "$GH_REPO" --label "$1" --state open --limit 50 --json number,title \
    --jq "${2:-.[]} | .number"
}

ensure_label() { # create once; an existing label (maybe made by the reviewer agent) is left as it is
  gh label create "$1" -R "$GH_REPO" --color "$2" --description "$3" >/dev/null 2>&1 || true
}

suspects() {
  need GH_REPO; need SHA
  local commits c state seen_prs="" n=0 pr
  commits=$(api "repos/$GH_REPO/commits?sha=$SHA&per_page=$SUSPECT_DEPTH" --jq '.[].sha' 2>/dev/null) || {
    echo "- （查询失败，嫌疑范围未知）"; return 0; }
  for c in $commits; do
    state=$(api "repos/$GH_REPO/commits/$c/statuses?per_page=100" \
      --jq "[.[] | select(.context == \"$CONTEXT\")][0].state // \"\"" 2>/dev/null)
    [ "$c" != "$SHA" ] && [ "$state" = success ] && { echo "- 上次全量绿灯：$c"; break; }
    while IFS= read -r pr; do
      [ -n "$pr" ] || continue
      case " $seen_prs " in *" ${pr%% *} "*) continue ;; esac
      seen_prs="$seen_prs ${pr%% *}"; echo "- PR $pr"; n=$((n + 1))
    done < <(api "repos/$GH_REPO/commits/$c/pulls" --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null)
  done
  [ "$n" -gt 0 ] || echo "- （区间内没有找到 PR）"
}

failure_body() { # <heading>
  local log="" f
  for f in "$LOG_DIR/test-2.log" "$LOG_DIR/build.log"; do [ -f "$f" ] && { log=$f; break; }; done
  printf '%s\n\n- 提交：%s\n- 运行：%s\n\n### 嫌疑 PR（自上次全量绿灯以来）\n%s\n' \
    "$1" "$SHA" "${RUN_URL:-}" "$(suspects)"
  if [ -n "$log" ]; then
    printf '\n### 日志末尾（%s，%s 行）\n\n~~~\n%s\n~~~\n' \
      "$(basename "$log")" "$TAIL_LINES" "$(tail -n "$TAIL_LINES" "$log")"
  fi
}

file_red() { # <title> <heading>
  ensure_label "$RED" b60205 "全量确认红：早上由本机 Claude Code 或用户修"
  local n; n=$(open_issues "$RED" | head -n1)
  if [ -n "$n" ]; then
    failure_body "$2" | gh issue comment "$n" -R "$GH_REPO" --body-file - >/dev/null && echo "commented on #$n"
  else
    failure_body "$2" | gh issue create -R "$GH_REPO" --title "$1" --label "$RED" --body-file -
  fi
}

file_flaky() {
  ensure_label "$HEALTH" fbca04 "CI 健康：偶发、变慢、白跑，只记录不自动修"
  local n body
  n=$(open_issues "$HEALTH" ".[] | select(.title == \"$FLAKY_TITLE\")" | head -n1)
  body=$(printf '全量第一次失败、整条重跑后通过（判为偶发）。\n\n- 提交：%s\n- 运行：%s\n' "$SHA" "${RUN_URL:-}")
  if [ -n "$n" ]; then gh issue comment "$n" -R "$GH_REPO" --body "$body" >/dev/null && echo "commented on #$n"
  else gh issue create -R "$GH_REPO" --title "$FLAKY_TITLE" --label "$HEALTH" --body "$body"; fi
}

close_red() {
  local n
  for n in $(open_issues "$RED"); do
    gh issue close "$n" -R "$GH_REPO" --comment "已恢复：全量在 $SHA 上通过（${RUN_URL:-}）。" >/dev/null \
      && echo "closed #$n"
  done
}

report() {
  need GH_REPO; need SHA
  local filer=${FILER:-central} rc=0
  case "$filer" in central|external) ;; *) die "FILER must be central or external" ;; esac
  case "$1" in
    green) mark success "全量通过" || rc=1 ;;
    flaky) mark success "全量通过（偶发：重跑后通过）" || rc=1 ;;
    red)   mark failure "全量失败" || rc=1 ;;
    *) die "report: verdict must be green, flaky or red" ;;
  esac
  case "$1" in
    green) close_red ;;
    flaky) close_red; if [ "$filer" = central ]; then file_flaky; fi ;;
    red) if [ "$filer" = central ]; then file_red "全量失败：${SHA:0:7}" "凌晨全量确实红了（重跑一次仍失败）。"
         else echo "issue-filer=external: status only; backstop opens an issue after ${WINDOW_MIN:-120} min"; fi ;;
  esac
  return $rc
}

backstop() {
  need GH_REPO; need SHA
  [ "${FILER:-central}" = external ] || return 0
  local s state age
  s=$(seen) || return 1
  state=${s#state=}; state=${state%% *}; age=${s##*age=}
  [ "$state" = failure ] || return 0
  if [ "$age" -lt "${WINDOW_MIN:-120}" ]; then
    echo "red for $age min, review window ${WINDOW_MIN:-120} min: waiting"; return 0
  fi
  [ -z "$(open_issues "$RED" | head -n1)" ] || { echo "a nightly-red issue is open: reviewed"; return 0; }
  file_red "全量失败（未经评审）：${SHA:0:7}" \
    "全量红了 $age 分钟仍没有评审开出的 nightly-red issue，由中央兜底开出。**未经评审**：偶发 / 回归 / 环境尚未判断。"
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  seen) seen ;;
  mark) [ $# = 2 ] || die "usage: mark <state> <desc>"; mark "$1" "$2" ;;
  run) run ;;
  report) [ $# = 1 ] || die "usage: report <green|flaky|red>"; report "$1" ;;
  backstop) backstop ;;
  suspects) suspects ;;
  *) die "usage: full-suite.sh seen|mark|run|report|backstop|suspects" ;;
esac
