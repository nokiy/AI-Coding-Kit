#!/usr/bin/env bash
# Release gate: the 「发版」 rule — a release PR merges only when the base branch HEAD has a green full-suite.
# Usage (needs gh; GH_REPO=<owner/repo> in the environment):
#   release-gate-check.sh sync        copy the full-suite status of the base branch HEAD onto every open release PR
#                                     (label "autorelease: pending") as the commit status release-gate. Never dispatches
#                                     a full suite. Run by .github/workflows/release-gate.yml (release-please runs) and by
#                                     full-suite.yml when it tested the base branch HEAD. BRANCH = base (default: the
#                                     repo's default branch). Exit 0 whatever the gate says; 1 only when a gh call fails.
#   release-gate-check.sh check <pr>  the 「发版」 merge step, run by the session. Reads full-suite on the PR base HEAD:
#                                     success → merge the PR · failure → refuse, naming the open nightly-red issue (or
#                                     the run) · missing or pending → dispatch the project's full-suite stub once (unless
#                                     a run of it is already queued or running), wait for the status, then decide again.
#     WORKFLOW      the project's full-suite stub file (default full-suite.yml); it takes a `ref` input
#     DISPATCH_REF  ref the stub is dispatched on (default: the PR base branch)
#     NO_MERGE=1    decide only, never merge · MERGE_METHOD squash | merge | rebase (default squash)
#     WAIT_MIN      longest wait for the dispatched run (default 180) · POLL_SEC (default 30)
#     GRACE_SEC     after dispatching, how long a missing live run still counts as starting (default 120)
#   Exit: 0 merged (or green with NO_MERGE) · 1 refused: full suite red · 3 refused: no result (dispatch failed,
#         run ended without a status, timed out, or the base branch moved while waiting) · 2 usage
# Status read: the latest commit status with context full-suite (written by full-suite.yml); pending is not a result.

set -u
CONTEXT=full-suite
GATE=release-gate
LABEL="autorelease: pending"
RED=nightly-red

die() { echo "release-gate: $*" >&2; exit 2; }
[ -n "${GH_REPO:-}" ] || die "GH_REPO is not set"

head_of() { gh api "repos/$GH_REPO/commits/$1" --jq .sha; }

fs_status() { # <sha> → "<success|failure|pending|none> <target url or ->"
  local out
  out=$(gh api "repos/$GH_REPO/commits/$1/statuses?per_page=100" --jq \
    "[.[] | select(.context == \"$CONTEXT\")][0] // empty | \"\(.state) \(.target_url // \"-\")\"") || return 1
  echo "${out:-none -}"
}

gate_line() { # <state> <sha> → "<status state>|<description>"
  local s=${2:0:7}
  case "$1" in
    success) echo "success|$BASE $s 全量通过" ;;
    failure) echo "failure|$BASE $s 全量失败：说「发版」会被拒绝" ;;
    *)       echo "pending|$BASE $s 还没跑全量：说「发版」时补跑" ;;
  esac
}

sync() {
  BASE=${BRANCH:-$(gh api "repos/$GH_REPO" --jq .default_branch)} || return 1
  local sha st url line state desc prs pr oid rc=0
  sha=$(head_of "$BASE") || return 1
  read -r st url <<<"$(fs_status "$sha")" || return 1
  [ -n "$st" ] || return 1
  line=$(gate_line "$st" "$sha"); state=${line%%|*}; desc=${line#*|}
  [ "$url" = - ] && url=""
  prs=$(gh pr list -R "$GH_REPO" --state open --base "$BASE" --label "$LABEL" \
    --json number,headRefOid --jq '.[] | "\(.number) \(.headRefOid)"') || return 1
  [ -n "$prs" ] || { echo "no open release PR into $BASE"; return 0; }
  while read -r pr oid; do
    gh api -X POST "repos/$GH_REPO/statuses/$oid" -f state="$state" -f context="$GATE" \
      -f description="$desc" -f target_url="$url" --silent || { rc=1; continue; }
    echo "release PR #$pr: $GATE=$state ($desc)"
  done <<<"$prs"
  return $rc
}

live_runs() { # queued or running runs of the stub → count
  gh run list -R "$GH_REPO" --workflow "$WORKFLOW" --limit 20 --json status \
    --jq '[.[] | select(.status != "completed")] | length'
}

refuse() { # <exit> <reason>
  echo "拒绝发版：$2"
  BRANCH=$BASE sync >/dev/null 2>&1 || true
  exit "$1"
}

check() {
  local pr=$1 info pstate oid sha cur st url issue dispatched=0 t0 deadline
  WORKFLOW=${WORKFLOW:-full-suite.yml}
  info=$(gh pr view "$pr" -R "$GH_REPO" --json state,baseRefName,headRefOid \
    --jq '"\(.state) \(.baseRefName) \(.headRefOid)"') || refuse 3 "读不到 PR #$pr"
  read -r pstate BASE oid <<<"$info"
  [ "$pstate" = OPEN ] || refuse 3 "PR #$pr 不是打开状态（$pstate）"
  sha=$(head_of "$BASE") || refuse 3 "读不到 $BASE 的最新提交"
  t0=$(date +%s); deadline=$((t0 + ${WAIT_MIN:-180} * 60))
  echo "发版门：PR #$pr → $BASE ${sha:0:7}"
  while :; do
    cur=$(head_of "$BASE") || refuse 3 "读不到 $BASE 的最新提交"
    [ "$cur" = "$sha" ] || refuse 3 "$BASE 在等待期间从 ${sha:0:7} 变成 ${cur:0:7}：发版 PR 还没跟上，等 release-please 跑完再说「发版」"
    st=$(fs_status "$sha") || refuse 3 "读不到 $BASE ${sha:0:7} 的 $CONTEXT 状态"
    read -r st url <<<"$st"
    case "$st" in
      success)
        echo "全量通过：$BASE ${sha:0:7}（$url）"
        BRANCH=$BASE sync || true
        if [ "${NO_MERGE:-}" = 1 ]; then echo "NO_MERGE=1：不合并"; exit 0; fi
        gh pr merge "$pr" -R "$GH_REPO" "--${MERGE_METHOD:-squash}" --match-head-commit "$oid" \
          || refuse 3 "合并 PR #$pr 失败（头提交变了或合并被拒）"
        echo "已合并发版 PR #$pr"; exit 0 ;;
      failure)
        issue=$(gh issue list -R "$GH_REPO" --label "$RED" --state open --limit 1 --json number,url \
          --jq '.[0] | "#\(.number) \(.url)"' 2>/dev/null)
        refuse 1 "$BASE ${sha:0:7} 全量失败，${issue:+见 issue $issue}${issue:-没有打开的 $RED issue，看运行 $url}" ;;
    esac
    # Missing or pending: a pending status from a dead run is not progress, so look for a live run.
    if [ "$(live_runs 2>/dev/null || echo 0)" = 0 ]; then
      if [ "$dispatched" = 0 ]; then
        gh workflow run "$WORKFLOW" -R "$GH_REPO" --ref "${DISPATCH_REF:-$BASE}" -f ref="$sha" \
          || refuse 3 "补跑全量没能触发（$WORKFLOW）"
        dispatched=$(date +%s)
        echo "$BASE ${sha:0:7} 还没有全量结果：已补跑一次（$WORKFLOW），等结果"
      elif [ $(( $(date +%s) - dispatched )) -ge "${GRACE_SEC:-120}" ]; then
        refuse 3 "补跑的全量已结束，$BASE ${sha:0:7} 上仍没有 $CONTEXT 结果"
      fi
    fi
    [ "$(date +%s)" -lt "$deadline" ] || refuse 3 "等了 ${WAIT_MIN:-180} 分钟仍没有全量结果"
    sleep "${POLL_SEC:-30}"
  done
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  sync) sync ;;
  check) [ $# = 1 ] || die "usage: check <pr>"; check "$1" ;;
  *) die "usage: release-gate-check.sh sync | check <pr>" ;;
esac
