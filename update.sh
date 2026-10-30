#!/usr/bin/env bash
# Update this repo to the newest version of its upstream branch, then run install.sh.
#
# Usage: update.sh [--check | --yes [--to <commit>]]
#   --check        Show the incoming changes, then stop.
#   --yes          Apply the incoming changes with no prompt.
#   --to <commit>  Update only to <commit>, for example the commit that --check showed.

if [ -z "${BASH_VERSION:-}" ]; then
  echo "error: run the script with bash: ./update.sh" >&2
  # shellcheck disable=SC2317 # exit runs when the script is not sourced.
  return 1 2>/dev/null || exit 1
fi

# The merge can change this file while it runs. Bash reads all of main before it runs it.
main() {
  set -euo pipefail

  local mode=prompt to="" arg
  while [ $# -gt 0 ]; do
    arg="$1"
    shift
    case $arg in
      --check) mode=check ;;
      --yes) mode=yes ;;
      --to)
        [ $# -gt 0 ] || die "--to needs a commit."
        to="$1"
        shift
        ;;
      -h | --help) sed -n '4,7s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; return 0 ;;
      *) die "unknown option: $arg" ;;
    esac
  done

  local self="${BASH_SOURCE[0]}" dir
  while [ -L "$self" ]; do
    dir="$(cd -P "$(dirname "$self")" && pwd)"
    self="$(readlink "$self")"
    case $self in /*) ;; *) self="$dir/$self" ;; esac
  done
  local repo
  repo="$(cd -P "$(dirname "$self")" && pwd)"
  [ -x "$repo/install.sh" ] || die "$repo is not the dotfiles-claude repo."

  # install.sh refuses a worktree. Stop before the merge, not after it.
  local git_dir common_dir
  if git_dir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" &&
    common_dir="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" &&
    [ "$git_dir" != "$common_dir" ]; then
    die "$repo is a git worktree. Run update.sh from the main checkout: ${common_dir%/.git}"
  fi

  local branch upstream
  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD)" ||
    die "the clone at $repo is not on a branch. Run: git -C $repo switch main"
  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" ||
    die "the branch $branch has no upstream branch. Run: git -C $repo switch main"

  local changes
  changes="$(git -C "$repo" status --porcelain --untracked-files=no)"
  if [ -n "$changes" ]; then
    echo "$changes" >&2
    die "the clone at $repo has local changes. Commit them or remove them, then run update.sh again."
  fi

  echo "Fetching $upstream ..."
  git -C "$repo" fetch --quiet

  # Update to one fixed commit, so that a later push to upstream cannot add unseen commits.
  local target
  target="$(git -C "$repo" rev-parse --verify --quiet '@{u}^{commit}')"
  if [ -n "$to" ]; then
    target="$(git -C "$repo" rev-parse --verify --quiet "$to^{commit}")" ||
      die "$to is not a commit in the clone."
    git -C "$repo" merge-base --is-ancestor "$target" '@{u}' ||
      die "$to is not on $upstream."
  fi

  local ahead behind
  ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD')"
  behind="$(git -C "$repo" rev-list --count "HEAD..$target")"
  if [ "$ahead" -gt 0 ]; then
    die "the branch $branch has $ahead local commit(s) that $upstream does not have. update.sh only fast-forwards."
  fi
  if [ "$behind" -eq 0 ]; then
    echo "Already up to date."
    [ "$mode" = check ] && return 0
    "$repo/install.sh"
    return
  fi

  echo
  echo "$behind new commit(s) on $upstream:"
  git -C "$repo" log --format='  %h %s' "HEAD..$target"
  echo
  echo "Changed items:"
  summarize_items "$repo" "$target"
  local other
  other="$(git -C "$repo" diff --name-only HEAD "$target" -- . ':!skills' ':!agents' ':!rules')"
  if [ -n "$other" ]; then
    echo
    echo "Other changed files:"
    printf '%s\n' "$other" | sed 's/^/  /'
  fi
  echo

  case $mode in
    check)
      echo "To apply exactly these changes, run: update.sh --yes --to $target"
      return 0
      ;;
    prompt)
      [ -t 0 ] || die "no terminal for the prompt. Run update.sh --yes to apply the changes."
      local answer
      read -r -p "Apply these changes? [y/N] " answer
      case $answer in
        y | Y | yes | YES) ;;
        *) echo "No changes applied."; return 0 ;;
      esac
      ;;
  esac

  git -C "$repo" merge --ff-only --quiet "$target"
  echo "Updated $branch to $(git -C "$repo" rev-parse --short HEAD)."
  echo
  local rc=0
  "$repo/install.sh" || rc=$?
  echo "Start a new Claude Code session to load the changes."
  return "$rc"
}

die() {
  echo "error: $*" >&2
  exit 1
}

# Print one line for each skill, agent, or rule that the update adds, changes, or removes.
summarize_items() {
  local repo="$1" target="$2" path item kind name state
  local seen=""

  while IFS= read -r path; do
    case $path in
      skills/*/*) kind=skill; name="${path#skills/}"; name="${name%%/*}"; item="skills/$name/SKILL.md" ;;
      agents/*.md) kind=agent; name="${path#agents/}"; item="$path" ;;
      rules/*.md) kind=rule; name="${path#rules/}"; item="$path" ;;
      *) continue ;;
    esac
    case $seen in *"|$kind:$name|"*) continue ;; esac
    seen="$seen|$kind:$name|"

    if ! git -C "$repo" cat-file -e "HEAD:$item" 2>/dev/null; then
      state=added
    elif ! git -C "$repo" cat-file -e "$target:$item" 2>/dev/null; then
      state=removed
    else
      state=changed
    fi
    printf '  %-8s %s %s\n' "$state" "$kind" "$name"
  done < <(git -C "$repo" diff --name-only HEAD "$target" -- skills agents rules)

  [ -n "$seen" ] || echo "  (none)"
}

# Keep the call and the exit on one line. Bash parses the full line before the merge can change it.
main "$@"; exit
