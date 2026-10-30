---
name: cr-apply
description: Validate and apply the findings from a /cr-deep report file. Groups findings by code area, runs the groups in sequence with 1 to 5 isolated agents per group (parallel agents only for findings in disjoint files, no nested agents), amends fixes into the branch commit that introduced the defect, and marks each finding fixed or skipped in the report. Pass the report path; defaults to the newest code-review-*.md at the repo root.
disable-model-invocation: true
argument-hint: [report-path] [--group <name>]
---

Apply the findings from a `/cr-deep` report. You are the **orchestrator**. You run in the main
session. You plan the groups and dispatch 1 to 5 agents per group. You do not read source files or
diffs yourself. The agents do the work, and only their final messages enter your context.

Arguments: `$ARGUMENTS`

### Input

- The first argument is the report path. If there is none, use the newest `code-review-*.md`
  at the repo root.
- `--group <name>` runs one named group and then stops.
- Refuse to run on the default branch (`main` or `master`).
- Refuse if `git status --porcelain` shows staged or unstaged changes to tracked files.
  Untracked files are fine.
- Record `MERGE_BASE=$(git merge-base main HEAD)` (fall back to `master`). Every amend target
  must be inside `$MERGE_BASE..HEAD`. A commit in main is never rewritten.

### Phase 0a: backup branch (once per report)

Before any fix, create a backup of the current branch at the current HEAD:

```
git branch <branch>-backup-<YYYYMMDD-HHMM>
```

Work continues on the current branch. The backup branch is the untouched copy. Write the backup
branch name into the `## Fix plan` section (Phase 0b). If the report already names a backup
branch, create no second one.

### Phase 0b: group plan (once per report)

If the report already has a `## Fix plan` section, skip this phase and resume at the first
group whose status is `open`.

Otherwise, read the report once and build the plan:

1. Collect every finding. A finding starts with `### <ID>. <title>` and carries a
   `- **Location:**` line.
2. Read the "Cross-agent convergences" table (if present). Each row is one defect reported
   under several IDs. Treat each row as one work item that closes all of its IDs.
3. Group the findings by code area: app, directory, or component. Never group by severity.
   The goal is that several fixes land in the same files together, so one agent amends them
   in one pass. Aim for groups of 5 to 25 findings.
4. Order the groups by their highest severity, High first.
5. Split each group into slices. One agent applies one slice, and the agents of a group run at
   the same time. Use the `- **Location:**` lines to apply these rules:
   - Use 1 to 5 slices for a group.
   - No file appears in two slices. Put two findings that cite the same file in one slice.
   - A convergence row stays in one slice.
   - Put two findings in one slice if the fix for one of them can change a file of the other:
     a shared type, a shared helper, a changed function signature and its callers, a lockfile,
     a migration, or a generated file.
   - Each slice has 3 findings or more. Thus a group of fewer than 6 findings has one slice.
   - Balance the slices by the number of findings.
   - If you cannot tell that two findings are independent, put them in one slice. If the group
     does not split cleanly, use one slice. One slice is always correct; it is only slower.
6. Insert a `## Fix plan` section directly after the metadata header of the report:

```
## Fix plan

Backup branch: `<name>`
Merge base: `<sha>`

| # | Group | Findings | Slices | Status |
|---|---|---|---|---|
| 1 | <area> | <ID, ID, ...> | [<ID, ID, ...>] [<ID, ...>] | open |
| 2 | <area> | <ID, ID, ...> | 1 | open |
```

The `Slices` column holds `1` for a group with one slice. Otherwise it holds one bracketed list
of finding IDs for each slice.

Status values for a group: `open`, `done`, `failed(<reason>)`.

If a `## Fix plan` section from an earlier run has no `Slices` column, treat each group as one
slice.

### Phase 1: groups in sequence, 1 to 5 agents per group

Run the `open` groups in table order. Finish one group, with Phase 2, before you start the next
group. Never run two groups at the same time.

The `Slices` column of the group sets the mode:

- One slice: run the group in **single mode**.
- Two or more slices: run the group in **slice mode**.

Each agent prompt must carry:

- the report path, as an absolute path,
- the group number, the group name, and the finding IDs of the agent,
- the merge-base SHA,
- the rule block below, verbatim, with the commit rules of the mode in place of
  `<COMMIT RULES>`.

#### Single mode

Call the Agent tool **once** with `subagent_type: general-purpose`. The agent works in the main
checkout and rebases the branch itself. Wait for it to finish.

#### Slice mode

Agents in one checkout collide: each rebase rewrites the branch, and the checkout has one index.
Thus each slice agent works in its own git worktree, and no slice agent rebases.

1. Record `GROUP_BASE=$(git rev-parse HEAD)`.
2. Create one worktree for each slice, from the repo root:
   `git worktree add -b cr-apply/g<N>-s<K> .claude/worktrees/cr-apply-g<N>-s<K> HEAD`
3. Call the Agent tool once for each slice, with `subagent_type: general-purpose`. Send all
   calls of the group in one message, so the agents run at the same time. Add the absolute path
   of the worktree of the slice to each prompt.
4. Wait until all agents of the group finish. Do not integrate a slice before that.
5. Integrate the slices into the branch. Run from the repo root:
   `${CLAUDE_SKILL_DIR}/integrate-slices.sh <MERGE_BASE> <GROUP_BASE> cr-apply/g<N>-s1 cr-apply/g<N>-s2 ...`
   The script is `integrate-slices.sh` in the directory of this skill (`${CLAUDE_SKILL_DIR}`).
   It cherry-picks each slice commit in order and folds each `fixup!` commit at once. If a fold conflicts, it keeps the fix as a normal commit on top of
   the branch. It prints one line for each slice commit.
6. If the script exits with a non-zero status, a cherry-pick failed. Keep the worktrees and the
   slice branches. Set the group's row to `failed(<reason>)`, stop, and report the script output.
7. If the script succeeds, remove each worktree and each slice branch:
   `git worktree remove --force <path>` and `git branch -D cr-apply/g<N>-s<K>`.

#### Rule block for the agent prompt

```
You apply a set of code-review findings. Do the whole set yourself in this one context.

CRITICAL: do NOT call the Agent tool. Do not spawn any sub-agent, parallel agent, background
agent, or finder. Do not use any multi-agent orchestration. One agent does this set: you.

1. Validate first. For each finding ID, read the finding in the report, then read the cited
   code at the current HEAD. Confirm the defect is real and still present. Decide one status:
   `fixed`, `skipped(<reason>)`, or `n/a(<note>)`. Apply no fix for a finding that does not
   hold. A convergence row is one fix that closes all of its IDs; give each ID the same status.
2. Apply the fixes for the whole set. Fix sibling defects of the same shape inside the files of
   the set. Run the narrowest check that covers each change: the compile or type check of the
   package, or the affected test file. Use the commands that the project documents, for example
   in its `CLAUDE.md`, `package.json`, or `Makefile`. Report the result of every check.
<COMMIT RULES>
5. Record status in the report. Under each finding's `- **Severity:**` line add one line:
   `- **Status:** fixed(<one line: where and how>)`, `- **Status:** skipped(<reason>)`, or
   `- **Status:** n/a(<note>)`. Change only the findings of your set. Change nothing else in
   the report. Do not commit the report file. Other agents can edit the report at the same
   time: if an edit fails because the file changed, read the file again and repeat the edit.
6. Never push. Never open a pull request.
7. Final message. This is the only thing the orchestrator sees. Include, in this order:
   - one line per finding ID: the status and a short detail,
   - the subjects of the commits you amended or targeted with a fixup, and the subjects of the
     new normal commits,
   - the checks you ran and their results, verbatim where short,
   - anything the user should decide: a finding you were unsure about, an adjacent defect
     outside the set, a check you could not run.
```

Commit rules for single mode:

```
3. Commit placement. Find the commit that introduced the defective lines with `git blame` or
   `git log -L`, limited to `<MERGE_BASE>..HEAD`.
   - If the lines come from a commit in that range, stage only that fix, run
     `git commit --fixup=<sha>`, and fold it at once with
     `GIT_SEQUENCE_EDITOR=: git rebase --autosquash <MERGE_BASE>`.
   - If the lines are already in main, or the fix is new code with no single introducing
     commit, create a normal commit on top of the branch.
   - One fixup or one commit per independent fix. Never stage an unrelated change into a fixup.
4. Conflicts. Fold each fixup before you start the next fix, so a conflict always involves the
   top commit. If the rebase stops on a conflict: run `git rebase --abort`, then turn the fixup
   into a normal commit with `git commit --amend -m "<message>"`. Continue with the next fix.
   Never rewrite a commit that is in main. Never use `git stash` (the stash stack is shared).
```

Commit rules for slice mode:

```
3. Worktree. Other agents apply other findings of this group at the same time, each in its own
   git worktree. Your worktree is `<WORKTREE>`. Do every read of code, every edit, every check,
   and every git command in `<WORKTREE>` (`cd` into it, or use `git -C`). The report file is
   the one exception: edit it at the absolute path you were given. Never edit a source file in
   the main checkout. Fix only the files that your findings need: a different agent owns each
   other file. If a fix needs a file outside your findings, do not apply it; mark the finding
   `skipped(needs <file>, outside the slice)`. The worktree has no installed dependencies. If
   a check needs them, install them in the worktree first with the lockfile-only command of
   the project, for example `pnpm install --frozen-lockfile --prefer-offline` or `npm ci`.
4. Commit placement. Find the commit that introduced the defective lines with `git blame` or
   `git log -L`, limited to `<MERGE_BASE>..HEAD`.
   - If the lines come from a commit in that range, stage only that fix and run
     `git commit --fixup=<sha> -m "<message>"`. Write `<message>` as a complete, normal commit
     message for the fix. The orchestrator uses it if the fixup does not fold.
   - If the lines are already in main, or the fix is new code with no single introducing
     commit, create a normal commit.
   - One fixup or one commit per independent fix. Never stage an unrelated change into a fixup.
   - Do NOT run `git rebase`. Leave each `fixup!` commit in place. The orchestrator folds the
     fixups after all agents finish. Never use `git stash` (the stash stack is shared). Do not
     remove the worktree and do not change its branch.
```

Replace `<WORKTREE>` with the absolute path of the worktree of the slice.

### Phase 2: after each group

1. Print the final message of each agent verbatim for the user. Do not condense it. In slice
   mode, print the output of `integrate-slices.sh` too.
2. Verify the branch state:
   - `git status --porcelain` shows only untracked files.
   - `git log --format=%s <MERGE_BASE>..HEAD | grep -c '^fixup!'` prints `0`.
   - `git worktree list` shows no `cr-apply-g<N>-s<K>` worktree.
   - Each finding ID of the group has a `- **Status:**` line in the report. If a line is
     missing, add it from the final message of the agent.
3. If a check fails, set the group's row to `failed(<reason>)`, stop, and report. Do not start
   the next group.
4. Otherwise set the group's row in `## Fix plan` to `done` and start the next `open` group.

### Final summary

When no `open` group remains, report:

- counts per status: fixed, skipped, n/a, failed,
- the amended commits and the new top-of-branch commits,
- `git rev-list --count <MERGE_BASE>..HEAD` at the start and at the end,
- the backup branch name, and the command to restore it:
  `git reset --hard <backup-branch>`.

### Rules

- Never push. Never open a pull request. The user validates and pushes.
- Never rewrite a commit that is in main.
- Never use bare `git stash`.
- Never run two agents in the same checkout at the same time. Parallel agents use one worktree
  each.
- The report file stays untracked. Do not commit it, stage it, or add it to `.gitignore`.
