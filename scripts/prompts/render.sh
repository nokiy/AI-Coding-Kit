#!/usr/bin/env bash
# Render one prompt template with one project's config (prompts/README.md).
# Usage: scripts/prompts/render.sh <project config.md> <template.md>   → the prompt on stdout
# Config: each line "## <key>" (key = a-z, 0-9, _) opens a value that runs to the next "## " line or the end;
#   text before the first key is a note and ignored; blank lines around a value are trimmed.
# Template: every {{key}} is replaced by that key's value, as many lines as the value has.
# Exit: 0 rendered · 1 the template names a key the config lacks (each one named on stderr) · 2 usage

[ $# = 2 ] || { echo "usage: render.sh <project config.md> <template.md>" >&2; exit 2; }
for f in "$1" "$2"; do [ -f "$f" ] || { echo "render: no such file: $f" >&2; exit 2; }; done

awk -v CFG="$1" '
function trim(v) {
  while (substr(v, 1, 1) == "\n") v = substr(v, 2)
  while (length(v) && substr(v, length(v), 1) == "\n") v = substr(v, 1, length(v) - 1)
  return v
}
BEGIN {
  key = ""
  while ((getline line < CFG) > 0) {
    if (line ~ /^## [a-z0-9_]+[ \t]*$/) {
      key = line; sub(/^## /, "", key); sub(/[ \t]+$/, "", key); have[key] = 1; val[key] = ""
      continue
    }
    if (line ~ /^## /) { key = ""; continue }
    if (key != "") val[key] = val[key] "\n" line
  }
  close(CFG)
  for (k in have) val[k] = trim(val[k])
}
{
  out = ""; s = $0
  while (match(s, /[{][{][a-z0-9_]+[}][}]/)) {
    k = substr(s, RSTART + 2, RLENGTH - 4)
    if (!(k in have)) { missing[k] = 1; bad = 1 }
    out = out substr(s, 1, RSTART - 1) val[k]
    s = substr(s, RSTART + RLENGTH)
  }
  print out s
}
END {
  for (k in missing) print "render: config has no key " k > "/dev/stderr"
  exit bad ? 1 : 0
}' "$2"
