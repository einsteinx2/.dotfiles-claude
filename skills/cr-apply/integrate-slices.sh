#!/usr/bin/env bash
# Integrate the commits of the slice branches of one cr-apply group into the current branch.
#
# Usage: integrate-slices.sh <merge-base> <group-base> <slice-branch>...
#
# The script cherry-picks each slice commit in order. It folds each `fixup!` commit at once,
# so a fold conflict always involves the top commit. If a fold conflicts, the script keeps the
# fix as a normal commit on top of the branch.
#
# Output: one line per slice commit: `folded`, `on-top`, or `on-top(<reason>)`.
# Exit 1: a cherry-pick failed. The commits before the failed commit stay integrated.
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <merge-base> <group-base> <slice-branch>..." >&2
  exit 2
fi

merge_base=$1
group_base=$2
shift 2

# Turn the `fixup!` commit at HEAD into a normal commit. The body of the fixup is the message.
keep_on_top() {
  local subject=$1 body
  body=$(git log -1 --format=%b)
  git commit --amend --quiet -m "${body:-${subject#fixup! }}"
}

for branch in "$@"; do
  while read -r commit; do
    subject=$(git log -1 --format=%s "$commit")

    if ! git cherry-pick "$commit" >/dev/null 2>&1; then
      git cherry-pick --abort >/dev/null 2>&1 || true
      echo "FAILED cherry-pick: $branch $commit $subject"
      exit 1
    fi

    if [[ $subject != fixup!* ]]; then
      echo "on-top: $subject"
      continue
    fi

    if GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$merge_base" >/dev/null 2>&1 </dev/null; then
      # The fixup stays at HEAD if its target is not in the range.
      if [[ $(git log -1 --format=%s) == fixup!* ]]; then
        keep_on_top "$subject"
        echo "on-top(no fold target): ${subject#fixup! }"
      else
        echo "folded: ${subject#fixup! }"
      fi
    else
      git rebase --abort
      keep_on_top "$subject"
      echo "on-top(fold conflict): ${subject#fixup! }"
    fi
  done < <(git rev-list --reverse "$group_base..$branch")
done
