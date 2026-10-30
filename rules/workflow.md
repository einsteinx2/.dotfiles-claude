## Standard implementation workflow

Finish each approved plan with the two steps below. When you write a plan in plan mode, end the
plan with these two steps. Do them as part of the execution of the approved plan.

1. **Commit** — invoke the `/commit` skill to split the work into logical, self-contained
   commits. Do not write the commits yourself; use the skill.
2. **Review** — invoke the `/cr` skill with `--fix`:
   - Before step 1, record `git rev-parse HEAD`. After step 1, count the new commits with
     `git rev-list --count <that-sha>..HEAD`.
   - If that count equals the number of commits that the branch is ahead of the remote default
     branch (for example `origin/main`), plain `/cr --fix` is correct.
   - If it does not, the branch carries earlier work. Scope the review explicitly:
     `/cr --fix — review only the last N commits, not the whole branch against main`.
     Without this, `/cr` reviews everything already landed on the branch again.

Then stop and report what landed. Never push and never open a PR. The user validates the change
and pushes it.

Skip both steps only when the work touches no file under version control (pure investigation,
or edits outside a git repo).
