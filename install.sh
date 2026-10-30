#!/usr/bin/env bash
# Link the skills, agents, and rules of this repo into the Claude Code config folder.
# The script is idempotent. update.sh runs it after each update.
#
# Usage: install.sh [--force] [--uninstall]
#   --force      Back up each conflicting item, then replace it with a link.
#   --uninstall  Remove each link that points into this repo.

# Stop at once if the shell is not bash. The script needs BASH_SOURCE and bash glob rules.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "error: run the script with bash: ./install.sh" >&2
  # shellcheck disable=SC2317 # exit runs when the script is not sourced.
  return 1 2>/dev/null || exit 1
fi
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  echo "error: do not source the script. Run it: ./install.sh" >&2
  return 1
fi

set -Eeuo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  sed -n '5,7s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
}

force=0
uninstall=0
for arg in "$@"; do
  case $arg in
    --force) force=1 ;;
    --uninstall) uninstall=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "error: unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# Find the repo. If the script was started through a symlink, follow the link first.
self="${BASH_SOURCE[0]}"
while [ -L "$self" ]; do
  dir="$(cd -P "$(dirname "$self")" && pwd)"
  self="$(readlink "$self")"
  case $self in /*) ;; *) self="$dir/$self" ;; esac
done
REPO="$(cd -P "$(dirname "$self")" && pwd)"

[ -f "$REPO/install.sh" ] && [ -d "$REPO/skills" ] && [ -d "$REPO/rules" ] ||
  die "$REPO is not the dotfiles-claude repo."

# A link into a worktree dangles after the worktree is removed. Install from the main checkout only.
if git_dir="$(git -C "$REPO" rev-parse --absolute-git-dir 2>/dev/null)" &&
  common_dir="$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" &&
  [ "$git_dir" != "$common_dir" ]; then
  die "$REPO is a git worktree. Run install.sh from the main checkout: ${common_dir%/.git}"
fi

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
# shellcheck disable=SC2088 # Match a literal tilde from a quoted value.
case $CLAUDE_DIR in
  "~" | "~/"*) CLAUDE_DIR="$HOME${CLAUDE_DIR#"~"}" ;;
  /*) ;;
  *) die "CLAUDE_CONFIG_DIR must be an absolute path: $CLAUDE_DIR" ;;
esac
while [ "${CLAUDE_DIR%/}" != "$CLAUDE_DIR" ]; do
  CLAUDE_DIR="${CLAUDE_DIR%/}"
done
if [ -z "$CLAUDE_DIR" ] || [ "$CLAUDE_DIR" = "${HOME%/}" ]; then
  die "CLAUDE_CONFIG_DIR must not be / or your home folder: ${CLAUDE_CONFIG_DIR:-}"
fi
if [ -d "$CLAUDE_DIR" ]; then
  case "$(cd -P "$CLAUDE_DIR" && pwd)/" in
    "$REPO"/*) die "$CLAUDE_DIR resolves into the repo $REPO. Point it to a separate folder." ;;
  esac
fi

BACKUP_DIR="$CLAUDE_DIR/backups/dotfiles-claude/$(date +%Y%m%d-%H%M%S)-$$"
trap 'echo "error: install.sh failed at line $LINENO. Backups, if any, are in $BACKUP_DIR" >&2' ERR

linked=0
relinked=0
removed=0
backed_up=0
skipped=0

# Return 0 if <path> is an item of type <sub> (skills, agents, or rules).
is_item() {
  local sub="$1" path="$2"
  case $sub in
    skills) [ -f "$path/SKILL.md" ] ;;
    *)
      case ${path##*/} in
        README.md) return 1 ;;
        *.md) [ -f "$path" ] ;;
        *) return 1 ;;
      esac
      ;;
  esac
}

# Move <destination> to the backup folder. Never overwrite an earlier backup.
backup_item() {
  local dest="$1" rel="$2"

  if [ -e "$BACKUP_DIR/$rel" ] || [ -L "$BACKUP_DIR/$rel" ]; then
    die "the backup $BACKUP_DIR/$rel exists already."
  fi
  (umask 077 && mkdir -p "$BACKUP_DIR/$(dirname "$rel")")
  mv "$dest" "$BACKUP_DIR/$rel"
  echo "backed up  $rel -> $BACKUP_DIR/$rel"
  backed_up=$((backed_up + 1))
}

skip_item() {
  local rel="$1" reason="$2"
  echo "skipped    $rel ($reason)" >&2
  skipped=$((skipped + 1))
}

# Make <destination> a link to <source>. The script owns <destination> only if it is absent or
# is a link into this repo. If another item is there, skip it, or back it up with --force.
link_item() {
  local src="$1" dest="$2"
  local rel="${dest#"$CLAUDE_DIR"/}"
  local cur

  if [ -L "$dest" ]; then
    cur="$(readlink "$dest")"
    if [ "$cur" = "$src" ]; then
      return
    fi
    case $cur in
      "$REPO"/*)
        ln -sfn "$src" "$dest"
        echo "relinked   $rel (was $cur)"
        relinked=$((relinked + 1))
        return
        ;;
    esac
    if [ "$force" -eq 0 ]; then
      skip_item "$rel" "a link to $cur, not from this repo"
      return
    fi
    backup_item "$dest" "$rel"
  elif [ -e "$dest" ]; then
    # If the destination is the repo item itself, stop. A backup would move the item out of the repo.
    if [ "$dest" -ef "$src" ]; then
      die "$dest is the same file as the repo item $src. Remove it, then run the script again."
    fi
    if [ "$force" -eq 0 ]; then
      skip_item "$rel" "a real file or folder, not from this repo"
      return
    fi
    backup_item "$dest" "$rel"
  fi
  ln -s "$src" "$dest"
  echo "linked     $rel"
  linked=$((linked + 1))
}

# Remove each link in <folder> that points into this repo. Without --uninstall, remove a link
# only if its target is no longer an item of the repo.
prune_links() {
  local sub="$1"
  local dir="$CLAUDE_DIR/$sub"
  local link target

  [ -d "$dir" ] || return 0
  for link in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
    [ -L "$link" ] || continue
    target="$(readlink "$link")"
    case $target in
      "$REPO"/*)
        if [ "$uninstall" -eq 1 ] || ! is_item "$sub" "$target"; then
          rm "$link"
          echo "removed    ${link#"$CLAUDE_DIR"/}"
          removed=$((removed + 1))
        fi
        ;;
    esac
  done
}

# An earlier version of the script linked ~/.claude/CLAUDE.md to this repo. The rules/ files
# replace it. Remove that link, but never a CLAUDE.md from another source.
unlink_old_claude_md() {
  local dest="$CLAUDE_DIR/CLAUDE.md"

  if [ -L "$dest" ]; then
    case "$(readlink "$dest")" in
      "$REPO"/*)
        rm "$dest"
        echo "removed    CLAUDE.md (an old link to this repo; rules/ replaces it)"
        removed=$((removed + 1))
        ;;
    esac
  fi
}

if [ "$uninstall" -eq 1 ]; then
  for sub in skills agents rules; do
    # An earlier version of this script linked the whole <sub> folder to this repo.
    if [ -L "$CLAUDE_DIR/$sub" ] && [ "$CLAUDE_DIR/$sub" -ef "$REPO/$sub" ]; then
      rm "$CLAUDE_DIR/$sub"
      echo "removed    $sub (folder link to this repo)"
      removed=$((removed + 1))
      continue
    fi
    prune_links "$sub"
  done
  unlink_old_claude_md
  echo "Done: $removed removed."
  exit 0
fi

(umask 077 && mkdir -p "$CLAUDE_DIR")

for sub in skills agents rules; do
  # If <sub> is a link to the same folder in this repo, remove the link. An earlier version of
  # this script made those links.
  if [ -L "$CLAUDE_DIR/$sub" ] && [ "$CLAUDE_DIR/$sub" -ef "$REPO/$sub" ]; then
    rm "$CLAUDE_DIR/$sub"
    echo "unlinked   $sub (folder link to this repo)"
  fi
  # A link to another folder would make the script write into that folder.
  if [ -L "$CLAUDE_DIR/$sub" ]; then
    die "$CLAUDE_DIR/$sub is a link to $(readlink "$CLAUDE_DIR/$sub"). Remove the link, then run the script again."
  fi
  mkdir -p "$CLAUDE_DIR/$sub"
done

unlink_old_claude_md

for src in "$REPO"/skills/*/; do
  src="${src%/}"
  is_item skills "$src" || continue
  link_item "$src" "$CLAUDE_DIR/skills/${src##*/}"
done

for sub in agents rules; do
  for src in "$REPO/$sub"/*.md; do
    is_item "$sub" "$src" || continue
    link_item "$src" "$CLAUDE_DIR/$sub/${src##*/}"
  done
done

for sub in skills agents rules; do
  prune_links "$sub"
done

echo "Done: $linked linked, $relinked relinked, $removed removed, $backed_up backed up, $skipped skipped."
if [ "$skipped" -gt 0 ]; then
  echo "The script skipped $skipped item(s) that belong to another source. Remove or rename each one, or run install.sh --force to back them up and replace them." >&2
  exit 1
fi
echo "To update later, run $REPO/update.sh, or type /dotfiles-update in Claude Code."
