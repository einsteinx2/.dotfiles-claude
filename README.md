# .dotfiles-claude

This repo holds user-level Claude Code files: skills, rules, and agents. `install.sh` links each
item into `~/.claude`. Your own `CLAUDE.md`, skills, rules, and agents stay in place.

## What you get

**Rules.** Claude Code loads each file in `~/.claude/rules/` in every session and every project.
The rules apply in addition to your own `~/.claude/CLAUDE.md`.

- `workflow.md`: after each approved plan, Claude commits the work with `/commit` and reviews it
  with `/cr --fix`. Claude never pushes and never opens a PR.
- `writing-style.md`: Claude writes all prose in Simplified Technical English (ASD-STE100).
- `zsh.md`: shell rules for the Bash tool. They apply only if your login shell is zsh.

**Skills.** Type each skill as a slash command in Claude Code, for example `/commit`.

| Skill | What it does |
|-------|--------------|
| `/commit` | Splits the uncommitted work into logical, self-contained commits. |
| `/cr` | Reviews the current branch in one pass. `--fix` applies the fixes. |
| `/cr-deep` | Reviews the current branch with several parallel agents and writes a report file. |
| `/cr-apply` | Applies the findings of a `/cr-deep` report. |
| `/ff-merge` | Rebases a topic worktree branch onto its feature branch, then fast-forwards the feature branch. |
| `/memory-cleanup` | Reviews and cleans the auto-memory folder of the current project. |
| `/dotfiles-update` | Updates this repo and runs `install.sh`. |

The items depend on each other:

- `workflow.md` uses `/commit` and `/cr`.
- `/cr-apply` reads the report of `/cr-deep`.

## Requirements

- macOS or Linux.
- `git` and `bash`. The bash 3.2 of macOS works.

## Install

```sh
git clone https://github.com/einsteinx2/.dotfiles-claude.git ~/.dotfiles-claude
~/.dotfiles-claude/install.sh
```

Then start a new Claude Code session.

Run the scripts as `./install.sh` or with their full path. Do not run them with `sh`, `zsh`, or
`source`.

Keep the clone in place. The links are absolute paths into the clone. To move the clone, run
`install.sh --uninstall` in the old location, move the clone, and then run `install.sh` again.

## Update

In Claude Code, type `/dotfiles-update`.

In a terminal, run:

```sh
~/.dotfiles-claude/update.sh
```

Both ways show the new commits and the skills and rules that change. Then they ask you to
confirm. After you confirm, the update fast-forwards the clone and runs `install.sh`. Start a new
Claude Code session to load the changes.

`update.sh --check` shows the changes and stops. `update.sh --yes` applies them with no prompt.

## What install.sh does

The script is idempotent. Each run does these steps:

1. It links each skill, rule, and agent of the repo into `~/.claude/skills/`, `~/.claude/rules/`,
   and `~/.claude/agents/`.
2. If another item with the same name is already there, the script skips it and prints a
   warning. At the end, it exits with status 1.
3. It removes each link that points into the repo to an item that the repo no longer has.

Without `--force`, the script changes a location only if the location is empty or holds a link
into this repo. It never changes your `~/.claude/CLAUDE.md`. The one exception is a link from an earlier version of
this repo: the script removes that link, because the rules replace it.

### Name conflicts

If you already have a skill or rule with the same name, for example your own `/commit`, the
script keeps your item and skips the item of this repo. You can then do one of these things:

- Rename or delete your item, and run `install.sh` again.
- Run `install.sh --force`. The script moves your item to a backup folder and links the item of
  this repo.
- Keep your item. In that case, `workflow.md` uses your `/commit` or `/cr`.

### Backups and restore

`--force` moves each conflicting item to
`~/.claude/backups/dotfiles-claude/<timestamp>-<pid>/`. Each run uses a new folder.

To restore an item, delete its link. Then move the item back from the backup folder. Example:

```sh
rm ~/.claude/skills/commit
mv ~/.claude/backups/dotfiles-claude/<timestamp>-<pid>/skills/commit ~/.claude/skills/
```

## Uninstall

```sh
~/.dotfiles-claude/install.sh --uninstall
```

The script removes each link that points into this repo. It does not touch other items or the
backups.

## Add or delete an item

- To add a skill, make the folder `skills/<name>/` with a `SKILL.md` file. Then run
  `./install.sh`.
- To add a rule or an agent, add `rules/<name>.md` or `agents/<name>.md`. Then run
  `./install.sh`.
- To delete an item, delete it from the repo. Then run `./install.sh`.

## Other config folder

If `CLAUDE_CONFIG_DIR` is set, the scripts use that folder instead of `~/.claude`. The value must
be an absolute path.

## License

This repo is in the public domain. See `LICENSE`.
