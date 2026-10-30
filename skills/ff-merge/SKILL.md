---
name: ff-merge
description: Rebase the current topic worktree's branch onto the feature branch it was cut from, then fast-forward the feature branch (checked out in its own worktree) to the topic branch. Optional argument - the feature branch name.
disable-model-invocation: false
---

Land the current topic branch on its feature branch. The topic branch lives in this worktree.
The feature branch lives in another worktree, and the user works there at the same time.

### Find the feature branch
- If an argument names a branch, use it.
- Otherwise read the branch's creation entry:
  `git reflog show --format='%gs' <topic branch> | tail -1`. If it reads
  `branch: Created from <name>` and `<name>` is checked out in another worktree, use it.
- Otherwise run `git worktree list` and take every other worktree's branch as a candidate. Drop
  `main`, `master`, and any branch with `backup` in its name.
- For each candidate, compute `git merge-base HEAD <candidate>`. Pick the candidate whose
  merge-base is newest (`git log -1 --format=%ct <sha>`). Landed topic branches share the
  feature tip, so ties are common. If two candidates tie, or no candidate remains, stop and ask
  the user which branch to use.
- Run each git command plainly, one per call. Do not put git inside pipelines, loops, or
  subshells. Some permission hooks reject that form.
- Record the feature worktree path from `git worktree list`. Never check the feature branch out
  here. Commands on the feature branch run in the feature worktree. A worktree-isolated session
  rejects `git -C <other path>` and `cd`, so first finish every step in this worktree, then call
  ExitWorktree with `action: "keep"` to return to the launch directory, and confirm with `pwd`
  that it is the feature worktree. Run the feature-branch commands from there. If the launch
  directory is not the feature worktree, stop and report the commands for the user to run.

### Preflight (stop and report on any failure)
- This worktree must be clean: `git status --porcelain` prints nothing. Untracked files are fine.
- The feature worktree must not have uncommitted changes to any file the topic commits touch.
  Compare `git -C <feature path> status --porcelain` against
  `git diff --name-only <merge-base>..HEAD`. If they overlap, stop: the user must commit or move
  that work first. Never stash in either worktree; the stash stack is shared.
- The topic branch must be ahead of the feature branch by at least one commit
  (`git rev-list --count <feature>..HEAD` > 0). If not, report that there is nothing to land.

### Rebase
- Run `git rebase <feature>` in this worktree.
- If the rebase stops on a conflict, do not resolve it on your own. Run `git rebase --abort`,
  then report the conflicting files and stop.
- After the rebase, print `git log --oneline <feature>..HEAD` so the user sees what will land.

### Fast-forward
- Run `git -C <feature path> merge --ff-only <topic branch>`.
- If it fails, report the error and stop. Do not fall back to a merge commit or a force move.
- Confirm with `git -C <feature path> log --oneline -1` that the feature branch tip equals the
  topic branch tip.

### Report
- State the feature branch, the number of commits landed, and the new tip.
- Do not delete the topic branch or this worktree. Print the two commands the user can run to
  remove them:
  `git worktree remove <this path>` and `git branch -d <topic branch>`.
- Never push and never open a PR.
