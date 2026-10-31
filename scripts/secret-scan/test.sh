#!/usr/bin/env bash
# Self-test for secret-scan.sh: builds throw-away git repos, runs the scan, asserts exit code and output.
# Usage: scripts/secret-scan/test.sh   (needs network: downloads the pinned gitleaks release)
# Prints one line per case and a summary; exits non-zero when any case fails.
# The fake AWS key is assembled at runtime, so nothing secret-shaped is ever committed to the kit.

HERE=$(cd "$(dirname "$0")" && pwd)
SCAN="$HERE/secret-scan.sh"
SH=${BASH:-bash}
T=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/secret-scan-test.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_NOSYSTEM=1 HOME="$T/home"
mkdir -p "$HOME"
git config --global user.name t; git config --global user.email t@t
git config --global init.defaultBranch master

pass=0; fail=0; failed=""
OUT="$T/out"; CODE=0; BASE=""

repo() { # fresh repo with one base commit; cwd = repo; BASE = that commit
  cd "$(mktemp -d "$T/r.XXXXXX")" || exit 2
  git init -q; echo seed > README.md; git add README.md; git commit -qm seed
  BASE=$(git rev-parse HEAD)
}
commit() { git add -A; git commit -qm "$1"; }
scan() { "$SH" "$SCAN" "$@" > "$OUT" 2>&1; CODE=$?; }

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
  else
    fail=$((fail + 1)); failed="$failed
  - $desc"; echo "FAIL $desc (exit $CODE, want $want)"; sed 's/^/     | /' "$OUT"
  fi
}

KEY="AKIA$(printf '%s' K7Q2 MZ4X W3PJ T6RB)"   # matches gitleaks rule aws-access-token

repo; echo ok > a.txt; commit clean; scan "$BASE" HEAD
check "clean range passes" 0 'scanning 1 commit(s)' 'no leaks found'

repo; printf 'aws_key = "%s"\n' "$KEY" > cfg.py; commit leak; scan "$BASE" HEAD
check "leak in range fails, redacted" 1 'RuleID:      aws-access-token' 'File:        cfg.py' 'REDACTED' "!$KEY"

repo; printf 'aws_key = "%s"\n' "$KEY" > cfg.py; commit leak; LEAK=$(git rev-parse HEAD)
echo ok > a.txt; commit clean; scan "$LEAK" HEAD
check "leak before base is out of range" 0 'scanning 1 commit(s)' 'no leaks found'

repo; scan deadbeef HEAD; check "unresolvable range exits 2" 2 'cannot resolve deadbeef..HEAD'
repo; scan "$BASE"; check "bad arguments exit 2" 2 'usage'

echo
echo "secret-scan test: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then echo "failed:$failed"; exit 1; fi
exit 0
