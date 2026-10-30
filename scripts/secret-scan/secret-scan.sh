#!/usr/bin/env bash
# secret-scan — gitleaks over a commit range of the repo in cwd, logs redacted.
# CI twin of the local commit-secrets hook: same gitleaks version, run by the secrets job
# of .github/workflows/quality.yml and asserted by test.sh. Portable: macOS /bin/bash 3.2
# and Linux bash; needs git, curl, tar and sha256sum or shasum.
#
# Usage: secret-scan.sh <base-sha> <head-sha>    scans exactly <base>..<head>
# Exit: 0 no leaks · 1 leaks or gitleaks error · 2 internal error (one line on stderr)
#
# gitleaks comes from the official GitHub release, checked against that release's
# checksums file, into a fresh temp dir per run. Rules: ./.gitleaks.toml when present,
# gitleaks defaults otherwise. Findings print rule + file:line; the secret is REDACTED.
set -uo pipefail
VERSION=8.30.1

die() { echo "secret-scan: $1" >&2; exit 2; }
[ $# -eq 2 ] || die "usage: secret-scan.sh <base-sha> <head-sha>"
base=$1; head=$2

# Fail closed: gitleaks exits 0 when its own git call fails, so the range is resolved first.
count=$(git rev-list --count "${base}..${head}" 2>/dev/null) || die "cannot resolve ${base}..${head}"
echo "scanning ${count} commit(s): ${base}..${head}"
[ "$count" -gt 0 ] || exit 0

case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) os="" ;; esac
case "$(uname -m)" in x86_64|amd64) arch=x64 ;; arm64|aarch64) arch=arm64 ;; *) arch="" ;; esac
[ -n "$os" ] && [ -n "$arch" ] || die "no gitleaks build for $(uname -s)/$(uname -m)"

tarball="gitleaks_${VERSION}_${os}_${arch}.tar.gz"
sums="gitleaks_${VERSION}_checksums.txt"
url="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}"
dir=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/gitleaks.XXXXXX") || die "mktemp failed"
trap 'rm -rf "$dir"' EXIT
curl -fsSL -o "$dir/$tarball" "$url/$tarball" || die "download failed: $tarball"
curl -fsSL -o "$dir/$sums" "$url/$sums" || die "download failed: $sums"
sum=$(grep " ${tarball}\$" "$dir/$sums") || die "$tarball missing from $sums"
if command -v sha256sum >/dev/null; then sha=(sha256sum); else sha=(shasum -a 256); fi
(cd "$dir" && printf '%s\n' "$sum" | "${sha[@]}" -c -) || die "checksum mismatch: $tarball"
tar -xzf "$dir/$tarball" -C "$dir" gitleaks || die "extract failed: $tarball"

cfg=()
[ -f .gitleaks.toml ] && cfg=(--config .gitleaks.toml)
# ${cfg[@]+…}: bash 3.2 under set -u treats an empty array as unbound.
"$dir/gitleaks" git -v --redact --no-banner --no-color ${cfg[@]+"${cfg[@]}"} \
  --log-opts="${base}..${head}" .
