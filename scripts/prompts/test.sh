#!/usr/bin/env bash
# Self-test for render.sh and the prompt templates in prompts/: both projects render, keep the report and issue formats,
# and stay inside their permissions.
# Usage: scripts/prompts/test.sh   (macOS /bin/bash 3.2 or Linux bash; needs awk, grep, sed)
# Prints one line per case and a summary; exits non-zero when any case fails.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
RENDER="$HERE/render.sh"
P="$ROOT/prompts"
SH=${BASH:-bash}
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT

pass=0; fail=0; failed=""
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); failed="$failed\n  $1"; echo "FAIL $1${2:+ — $2}"; }

keys_of_config() { sed -n 's/^## \([a-z0-9_]*\)[[:space:]]*$/\1/p' "$1" | sort -u; }
keys_of_template() { grep -o '{{[a-z0-9_]*}}' "$1" | sed 's/[{}]//g' | sort -u; }
section() { # <file> <heading line> → lines after it up to the next "## " / "### " heading
  # index/length, not ==: macOS awk compares strings with strcoll, which can call two CJK headings equal
  awk -v h="$2" 'index($0, h) == 1 && length($0) == length(h) { on = 1; next } on && /^##/ { exit } on' "$1"
}

# --- render.sh mechanics ---
"$SH" "$RENDER" > "$T/o" 2>&1; c=$?
if [ "$c" = 2 ]; then ok "usage: no arguments → exit 2"; else no "usage: no arguments → exit 2" "got $c"; fi

printf 'note before keys\n## one\n\nfirst\nsecond\n\n## two\nB\n' > "$T/cfg.md"
printf 'x {{one}} y {{two}}{{two}}\nplain\n' > "$T/tpl.md"
"$SH" "$RENDER" "$T/cfg.md" "$T/tpl.md" > "$T/o" 2>&1; c=$?
printf 'x first\nsecond y BB\nplain\n' > "$T/want"
if [ "$c" = 0 ] && cmp -s "$T/o" "$T/want"; then ok "multi-line value, trimmed, two keys on one line"
else no "multi-line value, trimmed, two keys on one line" "exit $c: $(tr '\n' '|' < "$T/o")"; fi

printf 'a {{three}} {{one}}\n' > "$T/tpl2.md"
"$SH" "$RENDER" "$T/cfg.md" "$T/tpl2.md" > "$T/o" 2> "$T/e"; c=$?
if [ "$c" = 1 ] && grep -q 'no key three' "$T/e"; then ok "missing key → exit 1, named"
else no "missing key → exit 1, named" "exit $c"; fi

printf '## two\nC\n## three\nD\n' > "$T/var.md"
printf '{{one}} {{two}} {{three}}\n' > "$T/tpl3.md"
"$SH" "$RENDER" "$T/cfg.md" "$T/var.md" "$T/tpl3.md" > "$T/o" 2>&1; c=$?
printf 'first\nsecond C D\n' > "$T/want"
if [ "$c" = 0 ] && cmp -s "$T/o" "$T/want"; then ok "variant config: later key replaces, others kept"
else no "variant config: later key replaces, others kept" "exit $c: $(tr '\n' '|' < "$T/o")"; fi

# --- row 1: both projects render both templates, differing only by config ---
projects="quota-bar infinite-canvas"
for proj in $projects; do
  for tpl in nightly morning; do
    out="$T/$proj-$tpl.md"
    "$SH" "$RENDER" "$P/projects/$proj.md" "$P/$tpl.md" > "$out" 2> "$T/e"; c=$?
    if [ "$c" = 0 ] && ! grep -q '{{' "$out" && [ -s "$out" ]; then ok "row 1: $proj × $tpl renders, no key left"
    else no "row 1: $proj × $tpl renders, no key left" "exit $c $(cat "$T/e")"; fi
  done
done

cat "$P/nightly.md" "$P/morning.md" > "$T/both.md"
keys_of_template "$T/both.md" > "$T/used"
for proj in $projects; do
  keys_of_config "$P/projects/$proj.md" > "$T/k-$proj"
  if cmp -s "$T/used" "$T/k-$proj"; then ok "row 1: $proj config keys = template keys"
  else no "row 1: $proj config keys = template keys" "$(diff "$T/used" "$T/k-$proj" | tr '\n' ' ')"; fi
done

# --- variants only replace keys the project has; prompts/rendered/ is a fresh render ---
for v in "$P"/projects/variants/*.md; do
  base="$P/projects/$(basename "$v" .md | sed 's/-[a-z]*$//').md"
  keys_of_config "$base" > "$T/base-keys"
  extra=$(keys_of_config "$v" | grep -vxF -f "$T/base-keys")
  if [ -f "$base" ] && [ -z "$extra" ]; then ok "variant $(basename "$v"): keys all in $(basename "$base")"
  else no "variant $(basename "$v"): keys all in $(basename "$base")" "base $base, extra: $extra"; fi
done
"$SH" "$HERE/render-all.sh" "$T/rendered" 2> "$T/e"; c=$?
if [ "$c" = 0 ] && diff -r "$T/rendered" "$P/rendered" > "$T/d"; then ok "prompts/rendered/ = fresh render-all.sh output"
else no "prompts/rendered/ = fresh render-all.sh output" "exit $c; run scripts/prompts/render-all.sh: $(head -n3 "$T/d" | tr '\n' ' ')"; fi
m="$P/rendered/infinite-canvas-morning-local.md"
if [ -s "$m" ] && ! grep -Eq 'gh pr merge|/merge|-X PUT|push --force|push -f|--force-with-lease|/reviews' "$m"; then
  ok "row 3: infinite-canvas local morning never merges or force-pushes"
else no "row 3: infinite-canvas local morning never merges or force-pushes"; fi

# --- row 3: permissions ---
forbid_night='gh pr merge|gh pr close|gh pr review|gh run rerun|gh issue close|gh issue delete'
forbid_night="$forbid_night|gh repo|gh secret|gh variable|gh release"
forbid_night="$forbid_night|git push|git commit|git checkout|git switch|git branch|git worktree"
forbid_night="$forbid_night|-X (POST|PATCH|PUT|DELETE)|--method"
for proj in $projects; do
  allow="$T/allow-$proj"
  section "$T/$proj-nightly.md" "### 允许的命令" > "$allow"
  if [ -s "$allow" ] && ! grep -Eq "$forbid_night" "$allow"; then ok "row 3: $proj nightly allow-list has no code / merge / settings write"
  else no "row 3: $proj nightly allow-list has no code / merge / settings write" "$(grep -E "$forbid_night" "$allow" | head -n3)"; fi
  if grep -q 'gh workflow run' "$allow" && grep -q 'gh issue create' "$allow"; then ok "row 3: $proj nightly allow-list can trigger and file"
  else no "row 3: $proj nightly allow-list can trigger and file"; fi
  m="$T/$proj-morning.md"
  if ! grep -Eq 'gh pr merge|/merge|-X PUT|push --force|push -f|--force-with-lease|/reviews' "$m"; then ok "row 3: $proj morning never merges or force-pushes"
  else no "row 3: $proj morning never merges or force-pushes" "$(grep -E 'gh pr merge|/merge|-X PUT|push --force|push -f|/reviews' "$m" | head -n3)"; fi
done

# --- row 2: report and issue formats (template block = sample) ---
R="$P/examples/ci-health-report.md"; N="$P/nightly.md"
for line in \
  '**结论**：' \
  '## 账单' \
  '| 流水线 | 运行 | 成功率 | 正常耗时 | 最慢 | 趋势 | 偶发 | 白跑 |' \
  '## 问题清单' \
  '| # | 类别 | 问题 | 证据 | Agent 定位 |' \
  '## 修复进度' \
  '<!-- watermark: '; do
  if grep -qF -- "$line" "$N" && grep -qF -- "$line" "$R"; then ok "row 2: template and sample report both carry: $line"
  else no "row 2: template and sample report both carry: $line"; fi
done
section "$R" "## 问题清单" | grep -E '^\| [0-9]+ \|' > "$T/rows"
total=$(wc -l < "$T/rows" | tr -d ' ')
filled=$(awk -F'|' '$(NF-1) ~ /[^ ]/' "$T/rows" | wc -l | tr -d ' ')
if [ "$total" -ge 1 ] && [ "$total" = "$filled" ]; then ok "row 2: every sample problem row has an Agent 定位 ($total)"
else no "row 2: every sample problem row has an Agent 定位" "$filled of $total"; fi
I="$P/examples/nightly-red-issue.md"
for h in '## 结论' '## 证据' '## 嫌疑 PR' '## 建议修法'; do
  if grep -qxF "$h" "$N" && grep -qxF "$h" "$I"; then ok "row 2: template and sample issue both carry $h"
  else no "row 2: template and sample issue both carry $h"; fi
done

echo "$pass passed, $fail failed"
[ "$fail" = 0 ] || { printf 'failed:%b\n' "$failed"; exit 1; }
