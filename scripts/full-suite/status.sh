# shellcheck shell=bash
# Sourced by full-suite.sh and scripts/project/release-gate-check.sh: the one definition of a commit's full-suite
# result and of the label a confirmed red is filed under, so the nightly flow and the release gate never disagree.
# Needs gh and GH_REPO.
CONTEXT=full-suite
# shellcheck disable=SC2034  # read by the scripts that source this file
RED=nightly-red

# fs_status <sha> → "<success|failure|pending|none> <age in minutes> <target url or ->": the latest full-suite status.
fs_status() {
  local out
  out=$(gh api "repos/$GH_REPO/commits/$1/statuses?per_page=100" --jq \
    '[.[] | select(.context == "'"$CONTEXT"'")][0] // empty
     | "\(.state) \(((now - (.created_at | fromdateiso8601)) / 60) | floor) \(if (.target_url // "") == "" then "-" else .target_url end)"') \
    || return 1
  echo "${out:-none 0 -}"
}
