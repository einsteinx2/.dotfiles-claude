---
name: dotfiles-update
description: Update the dotfiles-claude repo to its newest version and relink its skills, agents, and rules. Shows the incoming changes and asks the user before it applies them.
disable-model-invocation: true
---

Update the dotfiles-claude clone with its `update.sh` script. The script is at the repo root,
two folders above this skill: `${CLAUDE_SKILL_DIR}/../../update.sh`.

1. Run `bash "${CLAUDE_SKILL_DIR}/../../update.sh" --check`.
   - If the script prints an error, show the error to the user and stop. Do not try to fix the
     clone yourself. Do not run `git stash`, `git reset`, `git checkout`, or `git pull`.
   - If the script prints `Already up to date.`, tell the user and stop.
2. Show the user the commits and the changed items from the output. Keep the item list exact.
3. Ask the user with `AskUserQuestion` whether to apply the changes. If the user declines, stop.
4. Run `bash "${CLAUDE_SKILL_DIR}/../../update.sh" --yes --to <commit>`. Copy `<commit>` from
   the last line of the `--check` output. Thus the update applies only the commits that the
   user saw.
5. Report the result:
   - The new commit, and each line that starts with `linked`, `relinked`, `removed`, or
     `backed up`.
   - Each `skipped` line, with its reason. A skipped item is another item with the same name.
     Tell the user to remove or rename that item, or to run `install.sh --force` to back it up
     and replace it. Do not run `--force` yourself.
   - Tell the user to start a new Claude Code session. The current session keeps the old rules.
