#!/usr/bin/env bash
# Self-test for full-suite.sh: a fake gh on PATH records every call and answers from fixture files,
# so each case asserts what the flow does on GitHub (status written, issue opened / commented / closed).
# Usage: scripts/full-suite/test.sh   (no network). Exits non-zero when any case fails.

HERE=$(cd "$(dirname "$0")" && pwd)
FS="$HERE/full-suite.sh"
T=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/full-suite-test.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/fx"
cat > "$T/bin/gh" <<'GH'
#!/usr/bin/env bash
# Fake gh: log the call (and any stdin body), answer from $FX/<key> after --jq would have run.
echo "gh $*" >> "$FX/calls"
args="$*"
case "$args" in
  *"--body-file -"*) cat >> "$FX/calls" ;;
esac
case "$args" in
  "api repos/"*"/statuses?"*)   # $FX/status-<sha> answers for that commit, $FX/status for any other
    sha=${args#api repos/*/commits/}; sha=${sha%%/*}
    if [ -f "$FX/status-$sha" ]; then cat "$FX/status-$sha"; else cat "$FX/status" 2>/dev/null; fi ;;
  "api repos/o/r --jq .default_branch") echo main ;;
  "api repos/"*"/commits?sha=main&"*) cat "$FX/recent" 2>/dev/null ;;
  "api repos/"*"/commits?sha="*) cat "$FX/commits" 2>/dev/null ;;
  "api repos/"*"/pulls"*) cat "$FX/pulls" 2>/dev/null ;;
  "issue list"*"--label nightly-red"*"comments"*)   # $FX/names-<sha7>: the open issues naming that commit
    for f in "$FX"/names-*; do [ -f "$f" ] || continue; case "$args" in *"${f##*/names-}"*) cat "$f" ;; esac; done ;;
  "issue list"*"--label nightly-red"*) cat "$FX/red" 2>/dev/null ;;
  "issue list"*"--label ci-health"*) cat "$FX/health" 2>/dev/null ;;
  "issue create"*) echo "https://github.com/o/r/issues/99" ;;
esac
exit 0
GH
chmod +x "$T/bin/gh"
# The caller's own helper variables (e.g. this test run inside a full-suite build) must not leak into the cases.
unset BUILD_CMD TEST_CMD FILER WINDOW_MIN TAIL_LINES SUSPECT_DEPTH BACKSTOP_DAYS
export PATH="$T/bin:$PATH" FX="$T/fx" GH_REPO=o/r SHA=abc1234def RUN_URL=https://run/1 LOG_DIR="$T/logs"

pass=0; fail=0; OUT="$T/out"; CODE=0
fresh() { rm -rf "$T/fx" "$T/logs"; mkdir -p "$T/fx" "$T/logs"; : > "$T/fx/calls"; }
fs() { "$FS" "$@" > "$OUT" 2>&1; CODE=$?; cat "$T/fx/calls" >> "$OUT"; }

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

fresh; fs seen; check "no full-suite status reads as none" 0 'state=none age=0'
fresh; echo "failure 130 https://run/0" > "$FX/status"; fs seen; check "a failure status reads with its age" 0 'state=failure age=130'
fresh; echo "failure 130 https://run/0" > "$FX/status"; fs status abc1234def
check "status prints state, age and run of one commit" 0 'failure 130 https://run/0'

fresh; echo 5 > "$FX/red"; FILER=central fs report green
check "green: success status, open nightly-red closed" 0 'state=success' 'description=全量通过' 'issue close 5' \
  '已恢复' '!issue create'

fresh; FILER=central fs report flaky
check "flaky, central: success marked flaky, ci-health opened" 0 'state=success' '偶发' \
  'issue create -R o/r --title 全量偶发记录 --label ci-health' '!label create nightly-red'
fresh; echo 8 > "$FX/health"; FILER=central fs report flaky
check "flaky, central: existing ci-health record gets a comment" 0 'issue comment 8' '!issue create'
fresh; FILER=external fs report flaky
check "flaky, external: status only" 0 'state=success' '!issue create' '!issue comment'

fresh; printf 'c1\nc0\n' > "$FX/commits"; echo "#12 feat: thing" > "$FX/pulls"
printf 'line one\nFAIL TestBroken\n' > "$T/logs/test-2.log"
FILER=central fs report red
check "red, central: failure status, nightly-red opened with suspects and log" 0 'state=failure' \
  'description=全量失败' '--label nightly-red' '- PR #12 feat: thing' 'FAIL TestBroken' 'https://run/1'
fresh; echo 7 > "$FX/red"; FILER=central fs report red
check "red, central: open nightly-red gets a comment, no second issue" 0 'issue comment 7' '!issue create'
fresh; FILER=external fs report red
check "red, external: status only" 0 'state=failure' '!issue create' '!issue comment'
fresh; fs report purple; check "unknown verdict exits 2" 2 'verdict must be'

# backstop: every run, whichever commit it tested, walks the default branch's recent commits newest first.
R1=r1aaaaaaaa; R2=r2bbbbbbbb; G1=g1cccccccc
fresh; printf 'h0dddddddd\n%s\n' "$R1" > "$FX/recent"; echo "failure 130 https://run/r1" > "$FX/status-$R1"
echo 'CURRENT-RUN-LOG' > "$T/logs/test-2.log"; FILER=external WINDOW_MIN=120 fs backstop
check "backstop: an older red past the window, never retriggered, opens 未经评审 naming that commit and its run" 0 \
  '未经评审' '--label nightly-red' "$R1" 'https://run/r1' '!https://run/1' '!CURRENT-RUN-LOG'
fresh; echo "$R1" > "$FX/recent"; echo "failure 30 https://run/r1" > "$FX/status-$R1"; FILER=external WINDOW_MIN=120 fs backstop
check "backstop: inside the window waits" 0 'waiting' '!issue create' '!issue comment'
fresh; printf '%s\n%s\n' "$G1" "$R1" > "$FX/recent"; echo "success 10 https://run/g1" > "$FX/status-$G1"
echo "failure 300 https://run/r1" > "$FX/status-$R1"; FILER=external fs backstop
check "backstop: a later green means recovered, older reds are left alone" 0 '!issue create' '!issue comment'
fresh; echo "$R1" > "$FX/recent"; echo "failure 300 https://run/r1" > "$FX/status-$R1"; echo 3 > "$FX/red"; echo 3 > "$FX/names-${R1:0:7}"
FILER=external fs backstop
check "backstop: a red an open nightly-red issue names is reviewed" 0 'reviewed' '!issue create' '!issue comment'
fresh; echo "$R1" > "$FX/recent"; echo "failure 300 https://run/r1" > "$FX/status-$R1"; echo 3 > "$FX/red"
FILER=external fs backstop
check "backstop: an open issue naming another commit gets the 未经评审 comment (one open nightly-red per repo)" 0 \
  'issue comment 3' '未经评审' "$R1" '!issue create'
fresh; printf '%s\n%s\n' "$R2" "$R1" > "$FX/recent"; echo "failure 300 https://run/r2" > "$FX/status-$R2"
echo "failure 400 https://run/r1" > "$FX/status-$R1"; echo 3 > "$FX/names-${R2:0:7}"; FILER=external fs backstop
check "backstop: dedupe is per commit — a reviewed red does not cover an older unreviewed one" 0 '未经评审' "$R1" 'https://run/r1'
fresh; echo "$R1" > "$FX/recent"; echo "failure 300 https://run/r1" > "$FX/status-$R1"; FILER=central fs backstop
check "backstop: central filer never backstops" 0 '!issue create' '!statuses?'

ONCE="$T/once"
fresh; BUILD_CMD="echo built" TEST_CMD="echo tests ok" fs run
check "run: green" 0 'built' 'verdict=green'
fresh; rm -f "$ONCE"; TEST_CMD="[ -f $ONCE ] || { touch $ONCE; echo first; exit 1; }" fs run
check "run: first fail then pass is flaky" 0 'rerunning' 'verdict=flaky'
fresh; TEST_CMD="echo nope; exit 1" fs run
check "run: fails twice is red" 0 'verdict=red'
if grep -q nope "$T/logs/test-2.log" 2>/dev/null; then pass=$((pass + 1)); echo "ok   run: rerun log kept for the issue"
else fail=$((fail + 1)); echo "FAIL run: rerun log kept for the issue"; fi
fresh; BUILD_CMD="exit 3" TEST_CMD="echo should-not-run" fs run
check "run: build failure is red, tests never run, no rerun" 0 'verdict=red' '!should-not-run' '!rerunning'

echo
echo "full-suite test: $pass passed, $fail failed"
[ "$fail" = 0 ]
