#!/usr/bin/env bash
# Self-test for release-gate-check.sh: a fake gh on PATH records every call and answers from fixture files
# (a fixture with several lines answers one line per call, the last line repeating), so each case asserts what
# the gate does on GitHub: status written on the release PR, full suite dispatched or not, PR merged or refused.
# Usage: scripts/project/release-gate-check.test.sh   (no network). Exits non-zero when any case fails.

HERE=$(cd "$(dirname "$0")" && pwd)
RG="$HERE/release-gate-check.sh"
T=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/release-gate-test.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'GH'
#!/usr/bin/env bash
# Fake gh: log the call, answer from $FX/<key>.
echo "gh $*" >> "$FX/calls"
next() { # print the first line of $FX/$1; drop it unless it is the last
  local f="$FX/$1"
  [ -f "$f" ] || return 0
  head -n1 "$f"
  if [ "$(wc -l < "$f")" -gt 1 ]; then tail -n +2 "$f" > "$f.tmp" && mv "$f.tmp" "$f"; fi
}
args="$*"
case "$args" in
  "api -X POST "*) ;;
  "api repos/"*"/statuses?"*) next status ;;
  "api repos/"*"/commits/"*) next head ;;
  "api repos/"*) echo main ;;
  "pr list"*) cat "$FX/prs" 2>/dev/null ;;
  "pr view"*) next pr ;;
  "run list"*) next live ;;
  "issue list"*"--label nightly-red"*) cat "$FX/red" 2>/dev/null ;;
  "workflow run"*) exit "$(cat "$FX/dispatch_rc" 2>/dev/null || echo 0)" ;;
  "pr merge"*) exit "$(cat "$FX/merge_rc" 2>/dev/null || echo 0)" ;;
esac
exit 0
GH
chmod +x "$T/bin/gh"
unset BRANCH WORKFLOW DISPATCH_REF NO_MERGE MERGE_METHOD WAIT_MIN POLL_SEC GRACE_SEC
export PATH="$T/bin:$PATH" FX="$T/fx" GH_REPO=o/r POLL_SEC=0 GRACE_SEC=0

pass=0; fail=0; OUT="$T/out"; CODE=0
fresh() {
  rm -rf "$T/fx"; mkdir -p "$T/fx"; : > "$T/fx/calls"
  echo abc1234def > "$T/fx/head"; echo "7 rel9999" > "$T/fx/prs"; echo "OPEN main rel9999" > "$T/fx/pr"
  echo 0 > "$T/fx/live"
}
rg() { "$RG" "$@" > "$OUT" 2>&1; CODE=$?; cat "$T/fx/calls" >> "$OUT"; }

# check <desc> <expected exit> [pattern that must appear] [!pattern that must not appear]
check() {
  local desc=$1 want=$2 ok=1; shift 2
  [ "$CODE" = "$want" ] || ok=0
  for p in "$@"; do
    case "$p" in
      !*) grep -qF -- "${p#!}" "$OUT" && ok=0 ;;
      *) grep -qF -- "$p" "$OUT" || ok=0 ;;
    esac
  done
  if [ $ok = 1 ]; then pass=$((pass + 1)); echo "ok   $desc"
  else fail=$((fail + 1)); echo "FAIL $desc (exit $CODE, want $want)"; sed 's/^/     | /' "$OUT"; fi
}

# sync: copy, never dispatch, never fail on a red gate
fresh; echo "success https://run/9" > "$FX/status"; rg sync
check "sync green: release-gate success on the release PR head" 0 'statuses/rel9999' 'state=success' \
  'context=release-gate' 'main abc1234 全量通过' 'target_url=https://run/9' '!workflow run'
fresh; echo "failure https://run/8" > "$FX/status"; rg sync
check "sync red: release-gate failure, exit 0" 0 'state=failure' '全量失败' '!workflow run'
fresh; rg sync
check "sync missing: release-gate pending, no dispatch" 0 'state=pending' '还没跑全量' '!workflow run'
fresh; echo "pending https://run/7" > "$FX/status"; rg sync
check "sync pending: still pending, no dispatch" 0 'state=pending' '!workflow run'
fresh; : > "$FX/prs"; echo "success https://run/9" > "$FX/status"; rg sync
check "sync without a release PR: nothing written" 0 'no open release PR' '!-X POST'
fresh; echo "success https://run/9" > "$FX/status"; BRANCH=dev rg sync
check "sync BRANCH: reads that branch and lists PRs into it" 0 'commits/dev' '--base dev' '!api repos/o/r --jq'

# check: green merges, red refuses, missing dispatches once
fresh; echo "success https://run/9" > "$FX/status"; rg check 7
check "check green: merges with the head pinned" 0 'pr merge 7 -R o/r --squash --match-head-commit rel9999' \
  '已合并' '!workflow run'
fresh; echo "success https://run/9" > "$FX/status"; NO_MERGE=1 rg check 7
check "check green, NO_MERGE: no merge" 0 'NO_MERGE=1' '!pr merge'
fresh; echo "failure https://run/8" > "$FX/status"; echo "#35 https://gh/i/35" > "$FX/red"; rg check 7
check "check red: refuses naming the nightly-red issue" 1 '拒绝发版' '全量失败' '#35 https://gh/i/35' \
  '!pr merge' '!workflow run' 'state=failure'
fresh; echo "failure https://run/8" > "$FX/status"; rg check 7
check "check red, no issue: refuses naming the run" 1 '没有打开的 nightly-red issue' 'https://run/8' '!pr merge'
fresh; printf 'none -\npending https://run/5\nsuccess https://run/5\n' > "$FX/status"; printf '0\n1\n' > "$FX/live"
WORKFLOW=stage-full.yml rg check 7
check "check missing: dispatches once on the base with ref=sha, waits, merges" 0 \
  'workflow run stage-full.yml -R o/r --ref main -f ref=abc1234def' '已补跑' 'pr merge 7'
[ "$(grep -c 'workflow run' "$OUT")" = 1 ] || { CODE=99; }
check "check missing: exactly one dispatch" 0
fresh; printf 'none -\nfailure https://run/5\n' > "$FX/status"; printf '0\n1\n' > "$FX/live"; rg check 7
check "check missing then red: refuses" 1 '已补跑' '拒绝发版' '!pr merge'
fresh; printf 'pending https://run/4\nsuccess https://run/4\n' > "$FX/status"; echo 1 > "$FX/live"; rg check 7
check "check pending with a live run: waits, no dispatch" 0 '!workflow run' 'pr merge 7'
fresh; echo "none -" > "$FX/status"; rg check 7
check "check: dispatched run ends without a status → refuse 3" 3 '已补跑' '仍没有 full-suite 结果' '!pr merge'
fresh; echo "none -" > "$FX/status"; echo 1 > "$FX/dispatch_rc"; rg check 7
check "check: dispatch fails → refuse 3" 3 '没能触发' '!pr merge'
fresh; echo "none -" > "$FX/status"; echo 1 > "$FX/live"; WAIT_MIN=0 rg check 7
check "check: timeout → refuse 3" 3 '仍没有全量结果' '!pr merge'
fresh; printf 'abc1234def\nabc1234def\nfff0000aaa\n' > "$FX/head"; echo "pending https://run/4" > "$FX/status"; echo 1 > "$FX/live"
rg check 7
check "check: base moves while waiting → refuse 3" 3 'fff0000' '!pr merge'
fresh; echo "MERGED main rel9999" > "$FX/pr"; rg check 7
check "check: PR not open → refuse 3" 3 '不是打开状态' '!pr merge'
fresh; echo "success https://run/9" > "$FX/status"; echo 1 > "$FX/merge_rc"; rg check 7
check "check: merge rejected → refuse 3" 3 '合并 PR #7 失败'
fresh; rg bogus; check "unknown command exits 2" 2 'usage'
unset GH_REPO; rg sync; export GH_REPO=o/r; check "GH_REPO missing exits 2" 2 'GH_REPO is not set'

echo "release-gate-check: $pass passed, $fail failed"
[ "$fail" = 0 ]
