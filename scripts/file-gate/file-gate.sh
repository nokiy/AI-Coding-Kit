#!/usr/bin/env bash
# file-gate — whole-file size / line-length / file-name gate for commits and PRs.
# Spec: protocols/file-gate.md. Portable: macOS /bin/bash 3.2 and Linux bash; needs git + perl.
#
# Usage:
#   file-gate.sh --staged        pre-commit: files in the index, judged by their staged blob
#   file-gate.sh --base <ref>    CI: files changed between merge-base(<ref>, HEAD) and HEAD, judged at HEAD
# Exit: 0 pass · 1 violations (all printed) · 2 internal error (one line on stderr)
#
# Rules, on the whole file:
#   1. generic file name (stem in GENERIC below) → block
#   2. more than 400 lines → block (largest functions listed when lizard is available)
#   3. any line longer than 200 characters (Unicode characters) → block
#
# A file is skipped when any of these holds:
#   - its extension is not a code extension (CODE_EXT below): lockfiles, md, json, yaml … pass untouched
#   - a directory segment of its path is one of SKIP_DIRS below
#   - it is generated: first 5 lines carry "Code generated … DO NOT EDIT" or "@generated",
#     or git check-attr linguist-generated is set/true
#   - it is vendored: git check-attr linguist-vendored is set/true ("-linguist-vendored" lines re-include)
#   - it is listed in the repo-root .lint-exempt (one path per line, # comments, a directory covers
#     everything under it); --staged reads the staged .lint-exempt, --base the one at HEAD
#   - it is a submodule entry (not a blob)
# --staged also passes while a merge, rebase, cherry-pick or revert is in progress: CI judges those.
# Lizard: $LIZARD, else lizard on PATH, else $HOME/.local/bin/lizard; absent or failing → no function list.

MAX_LINES=400
MAX_CHARS=200
LINE_LIST_CAP=10
CODE_EXT=" swift go ts tsx js jsx mjs cjs py rs kt java rb dart c h cpp hpp m mm vue svelte html css scss sh bash zsh "
GENERIC=" util utils helper helpers type types model models common config configs constant constants extension"
GENERIC="$GENERIC extensions misc shared base manager service services data "
SKIP_DIRS=" node_modules vendor third_party dist build .build docs .claude prototype prototypes "

die() { echo "file-gate: $*" >&2; exit 2; }

mode=""; base=""
case "${1:-}" in
  --staged) mode=staged; [ $# -eq 1 ] || die "usage: file-gate.sh --staged | --base <ref>" ;;
  --base) mode=base; base="${2:-}"; [ $# -eq 2 ] && [ -n "$base" ] || die "usage: file-gate.sh --base <ref>" ;;
  *) die "usage: file-gate.sh --staged | --base <ref>" ;;
esac

command -v perl >/dev/null 2>&1 || die "perl not found"
top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
cd "$top" || die "cannot enter $top"

tmp=$(mktemp -d 2>/dev/null) || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

if [ "$mode" = staged ]; then
  for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
    if [ -e "$(git rev-parse --git-path "$marker")" ]; then
      echo "file-gate: $marker present — merge/rebase/cherry-pick/revert commits are judged by CI"
      exit 0
    fi
  done
  rev=":0:"
  attr_flag="--cached"
  git diff --cached --name-only --diff-filter=ACMR -z > "$tmp/files" || die "git diff --cached failed"
  title="✗ 提交被拦（file-gate）"
else
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "base ref '$base' does not resolve to a commit"
  git rev-parse --verify --quiet "HEAD^{commit}" >/dev/null || die "HEAD does not resolve to a commit"
  mb=$(git merge-base "$base" HEAD 2>/dev/null) || die "no merge-base between '$base' and HEAD (history too shallow?)"
  rev="HEAD:"
  attr_flag=""
  git diff --name-only --diff-filter=ACMR -z "$mb" HEAD > "$tmp/files" || die "git diff $mb HEAD failed"
  title="✗ CI 文件检查未通过（file-gate）"
fi

# .lint-exempt from the judged tree (index or HEAD), normalised: no comments, no ./, no trailing /.
: > "$tmp/exempt"
if [ "$(git cat-file -t "${rev}.lint-exempt" 2>/dev/null)" = blob ]; then
  git cat-file blob "${rev}.lint-exempt" | perl -ne '
    s/\r?\n$//; s/^\s+|\s+$//g; next if $_ eq "" || /^#/;
    s{^(\./)+}{}; s{/+$}{}; print "$_\n" if $_ ne "";' > "$tmp/exempt" || die "cannot read .lint-exempt"
fi

is_exempt() { # $1 path
  perl -e 'my $p = shift; open my $f, "<", shift or exit 1;
    while (<$f>) { chomp; exit 0 if $p eq $_ || index($p, "$_/") == 0 } exit 1' "$1" "$tmp/exempt"
}

attr_on() { # $1 path, $2 attribute → true when set/true
  local v
  v=$(git check-attr $attr_flag -z "$2" -- "$1" 2>/dev/null | tr '\0' '\n' | sed -n 3p)
  [ "$v" = set ] || [ "$v" = true ]
}

find_lizard() {
  local c
  for c in "${LIZARD:-}" "$(command -v lizard 2>/dev/null)" "$HOME/.local/bin/lizard"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

biggest_functions() { # $1 temp file with the right extension → "name La-b（n 行）；…" or nothing
  local lz
  lz=$(find_lizard) || return 0
  perl -e 'alarm 3; exec @ARGV' "$lz" --csv "$1" 2>/dev/null > "$tmp/lizard.csv" || return 0
  perl -ne 'print "$1\t$2\t$3\t$4\n" if /^(\d+),[^"]*"(.+)@(\d+)-(\d+)@[^"]*"/' "$tmp/lizard.csv" \
    | sort -t "$(printf '\t')" -k1,1nr | head -3 \
    | perl -CSD -ne 'chomp; my ($n,$f,$a,$b) = split /\t/; push @o, "$f L$a-$b（$n 行）";
        END { print join("；", @o) if @o }'
}

out="$tmp/report"; : > "$out"
checked=0
while IFS= read -r -d '' path; do
  name=${path##*/}
  case "$name" in *.*) ;; *) continue ;; esac
  ext=$(printf '%s' "${name##*.}" | tr 'A-Z' 'a-z')
  case "$CODE_EXT" in *" $ext "*) ;; *) continue ;; esac

  skip=""
  dir=${path%/*}; [ "$dir" = "$path" ] && dir=""
  rest="$dir"
  while [ -n "$rest" ]; do
    seg=${rest%%/*}
    case "$SKIP_DIRS" in *" $seg "*) skip=1; break ;; esac
    [ "$seg" = "$rest" ] && break
    rest=${rest#*/}
  done
  [ -n "$skip" ] && continue
  is_exempt "$path" && continue
  attr_on "$path" linguist-vendored && continue
  attr_on "$path" linguist-generated && continue

  type=$(git cat-file -t "${rev}${path}" 2>/dev/null) || die "cannot read ${rev}${path}"
  [ "$type" = blob ] || continue
  blob="$tmp/blob.$ext"
  git cat-file blob "${rev}${path}" > "$blob" || die "cannot read ${rev}${path}"
  head -n 5 "$blob" | grep -Eq 'Code generated .* DO NOT EDIT|@generated' && continue
  checked=$((checked + 1))

  stem=$(printf '%s' "${name%.*}" | tr 'A-Z' 'a-z')
  case "$GENERIC" in
    *" $stem "*)
      base_name=${name%.*}
      cap=$(printf '%s' "${base_name:0:1}" | tr 'a-z' 'A-Z')${base_name:1}
      echo "✗ ${path}：文件名 \"${base_name}\" 是万金油名字，搜索时分不清" >> "$out"
      echo "改法：前面加上领域，比如 Usage${cap}.${name##*.}；文件头和引用它的地方一起改" >> "$out"
      ;;
  esac

  # One pass: "N <lines>" then "L <lineno> <chars>" for each over-long line.
  perl -CSD -ne 'BEGIN { $SIG{__WARN__} = sub {} } s/\r?\n\z//;
    my $l = length; print "L $. $l\n" if $l > '"$MAX_CHARS"'; END { print "N ", ($. || 0), "\n" }' \
    "$blob" > "$tmp/measure" || die "perl failed on $path"
  lines=$(sed -n 's/^N //p' "$tmp/measure")
  if [ "$lines" -gt "$MAX_LINES" ]; then
    echo "✗ ${path}：${lines} 行，超过 ${MAX_LINES} 行硬线" >> "$out"
    funcs=$(biggest_functions "$blob")
    [ -n "$funcs" ] && echo "最大的函数：$funcs" >> "$out"
    {
      echo "拆分步骤："
      echo " 1. 按职责找切口：顶层类型、extension、// MARK: 段落"
      echo " 2. Swift 拆成 类型+主题.swift；Go 在同一个包里新建文件；JS/TS 拆成独立模块"
      echo " 3. 只搬代码、不改行为，拆分单独提交，测试通过后再做原来的修改"
      echo " 4. 更新新旧文件的 [POS] 文件头和目录 README"
    } >> "$out"
  fi
  long=$(grep -c '^L ' "$tmp/measure")
  if [ "$long" -gt 0 ]; then
    grep '^L ' "$tmp/measure" | head -n "$LINE_LIST_CAP" | while read -r _ ln len; do
      echo "✗ ${path}:${ln}：${len} 字符，超过 ${MAX_CHARS}" >> "$out"
    done
    [ "$long" -gt "$LINE_LIST_CAP" ] && echo "…另有 $((long - LINE_LIST_CAP)) 行" >> "$out"
    echo "断行方法：把长表达式拆成中间变量 / 参数一个一行 / 长字符串拆开或移到常量" >> "$out"
  fi
done < "$tmp/files"

if [ -s "$out" ]; then
  { echo "$title"; cat "$out"; echo "规则：AI-Coding-Kit protocols/file-gate.md"; } >&2
  exit 1
fi
echo "✓ file-gate：检查了 ${checked} 个文件，全部通过"
exit 0
