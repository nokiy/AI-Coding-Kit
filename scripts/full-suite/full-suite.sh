#!/usr/bin/env bash
# Every GitHub call of the central full suite (.github/workflows/full-suite.yml). Needs gh and GH_REPO; seen, mark,
# status, report and suspects also SHA (or the commit as argument).
# Commands: seen · status <sha> · mark <state> <desc> · run · report <green|flaky|red> · backstop · suspects
# One open nightly-red issue per repo, at most: a later red comments on it, so the morning repair reads one place.
# Only a pass on the default branch HEAD closes it: a test-branch or older-commit green says nothing about main.
# A failed build is not rerun (a build is not flaky); a failed test command is rerun once, whole.
# backstop runs on every trigger (FILER=external): a reviewer that never came must not leave a red unfiled, and the
# red commit is rarely retriggered once the default branch moves on.
# Exit: 0 done · 1 a required gh call failed · 2 usage

set -u
# shellcheck source=SCRIPTDIR/status.sh
. "$(cd "$(dirname "$0")" && pwd)/status.sh"
HEALTH=ci-health
FLAKY_TITLE="全量偶发记录"
LOG_DIR=${LOG_DIR:-${RUNNER_TEMP:-/tmp}/full-suite}
TAIL_LINES=${TAIL_LINES:-80}
SUSPECT_DEPTH=${SUSPECT_DEPTH:-30}
BACKSTOP_DAYS=${BACKSTOP_DAYS:-14}

die() { echo "full-suite: $*" >&2; exit 2; }
need() { [ -n "${!1:-}" ] || die "$1 is not set"; }
api() { gh api "$@"; }

seen() {
  need GH_REPO; need SHA
  local s st age
  s=$(fs_status "$SHA") || return 1
  read -r st age _ <<<"$s"
  echo "state=$st age=$age"
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

suspects() { # [sha] (default SHA)
  local sha=${1:-${SHA:-}} commits c state seen_prs="" n=0 pr
  need GH_REPO; [ -n "$sha" ] || die "SHA is not set"
  commits=$(api "repos/$GH_REPO/commits?sha=$sha&per_page=$SUSPECT_DEPTH" --jq '.[].sha' 2>/dev/null) || {
    echo "- （查询失败，嫌疑范围未知）"; return 0; }
  for c in $commits; do
    state=$(fs_status "$c" 2>/dev/null); state=${state%% *}
    [ "$c" != "$sha" ] && [ "$state" = success ] && { echo "- 上次全量绿灯：$c"; break; }
    while IFS= read -r pr; do
      [ -n "$pr" ] || continue
      case " $seen_prs " in *" ${pr%% *} "*) continue ;; esac
      seen_prs="$seen_prs ${pr%% *}"; echo "- PR $pr"; n=$((n + 1))
    done < <(api "repos/$GH_REPO/commits/$c/pulls" --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null)
  done
  [ "$n" -gt 0 ] || echo "- （区间内没有找到 PR）"
}

failure_body() { # <heading> <sha> <run url> [log dir: the run's logs, only when it is this run]
  local log="" f
  for f in ${4:+"$4/test-2.log" "$4/build.log"}; do [ -f "$f" ] && { log=$f; break; }; done
  printf '%s\n\n- 提交：%s\n- 运行：%s\n\n### 嫌疑 PR（自上次全量绿灯以来）\n%s\n' \
    "$1" "$2" "$3" "$(suspects "$2")"
  if [ -n "$log" ]; then
    printf '\n### 日志末尾（%s，%s 行）\n\n~~~\n%s\n~~~\n' \
      "$(basename "$log")" "$TAIL_LINES" "$(tail -n "$TAIL_LINES" "$log")"
  fi
}

file_red() { # <title> <heading> <sha> <run url> [log dir]
  ensure_label "$RED" b60205 "全量确认红：早上由本机 Claude Code 或用户修"
  local n; n=$(open_issues "$RED" | head -n1)
  if [ -n "$n" ]; then
    failure_body "$2" "$3" "$4" "${5:-}" | gh issue comment "$n" -R "$GH_REPO" --body-file - >/dev/null && echo "commented on #$n"
  else
    failure_body "$2" "$3" "$4" "${5:-}" | gh issue create -R "$GH_REPO" --title "$1" --label "$RED" --body-file -
  fi
}

naming() { # <sha> → open nightly-red issues whose title, body or a comment carry its first 7 characters
  gh issue list -R "$GH_REPO" --label "$RED" --state open --limit 50 --json number,title,body,comments \
    --jq '.[] | select([.title, .body, (.comments[]?.body)] | join(" ") | contains("'"${1:0:7}"'")) | .number'
}

file_flaky() {
  ensure_label "$HEALTH" fbca04 "CI 健康：偶发、变慢、白跑，只记录不自动修"
  local n body
  n=$(open_issues "$HEALTH" ".[] | select(.title == \"$FLAKY_TITLE\")" | head -n1)
  body=$(printf '全量第一次失败、整条重跑后通过（判为偶发）。\n\n- 提交：%s\n- 运行：%s\n' "$SHA" "${RUN_URL:-}")
  if [ -n "$n" ]; then gh issue comment "$n" -R "$GH_REPO" --body "$body" >/dev/null && echo "commented on #$n"
  else gh issue create -R "$GH_REPO" --title "$FLAKY_TITLE" --label "$HEALTH" --body "$body"; fi
}

on_default_head() { # SHA is the default branch HEAD (a failed lookup counts as no)
  local base head
  base=$(api "repos/$GH_REPO" --jq .default_branch) || return 1
  head=$(api "repos/$GH_REPO/commits/$base" --jq .sha) || return 1
  [ -n "$head" ] && [ "$head" = "$SHA" ]
}

close_red() {
  local n
  on_default_head || { echo "tested ${SHA:0:7} is not the default branch HEAD: nightly-red issues left open"; return 0; }
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
    red) if [ "$filer" = central ]; then
           file_red "全量失败：${SHA:0:7}" "凌晨全量确实红了（重跑一次仍失败）。" "$SHA" "${RUN_URL:-}" "$LOG_DIR"
         else echo "issue-filer=external: status only; backstop opens an issue after ${WINDOW_MIN:-120} min"; fi ;;
  esac
  return $rc
}

backstop() { # newest first, back to the last green: each red past the window that no open issue names gets one
  need GH_REPO
  [ "${FILER:-central}" = external ] || return 0
  local base shas c s st age url
  base=$(api "repos/$GH_REPO" --jq .default_branch) || return 1
  shas=$(api "repos/$GH_REPO/commits?sha=$base&per_page=100" --jq \
    ".[] | select((.commit.committer.date | fromdateiso8601) > now - $BACKSTOP_DAYS * 86400) | .sha") || return 1
  for c in $shas; do
    s=$(fs_status "$c") || return 1
    read -r st age url <<<"$s"
    case "$st" in
      success) echo "${c:0:7} is green: reds before it are recovered"; return 0 ;;
      failure) ;;
      *) continue ;;
    esac
    if [ "$age" -lt "${WINDOW_MIN:-120}" ]; then
      echo "${c:0:7} red for $age min, review window ${WINDOW_MIN:-120} min: waiting"; continue
    fi
    [ -z "$(naming "$c")" ] || { echo "${c:0:7}: an open nightly-red issue names it: reviewed"; continue; }
    [ "$url" != - ] || url=""
    file_red "全量失败（未经评审）：${c:0:7}" \
      "全量红了 $age 分钟仍没有评审开出的 nightly-red issue，由中央兜底开出。**未经评审**：偶发 / 回归 / 环境尚未判断。" \
      "$c" "$url" || return 1
  done
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  seen) seen ;;
  status) [ $# = 1 ] || die "usage: status <sha>"; need GH_REPO; fs_status "$1" ;;
  mark) [ $# = 2 ] || die "usage: mark <state> <desc>"; mark "$1" "$2" ;;
  run) run ;;
  report) [ $# = 1 ] || die "usage: report <green|flaky|red>"; report "$1" ;;
  backstop) backstop ;;
  suspects) suspects ;;
  *) die "usage: full-suite.sh seen|status|mark|run|report|backstop|suspects" ;;
esac
