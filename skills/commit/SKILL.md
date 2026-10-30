---
name: commit
description: Commit the current branch's outstanding work split into logical, self-contained commits
disable-model-invocation: false
---

Commit all outstanding work on the current branch, split into logical commits.

### Process
- Inspect `git status` and the full diff — staged, unstaged, and untracked files — before deciding anything.
- Group changes into logical, self-contained units by feature/concern, not by file. Each commit should build and make sense in isolation.
- Order: prerequisites/refactors first, then features, then docs/tests only if genuinely separable — otherwise keep tests/docs in the commit for the change they cover.
- Stage precisely per unit: `git add <paths>`, and `git add -p` when one file contains changes for multiple units.
- Write imperative, concise commit messages; add a body only when the why isn't obvious from the subject.
- If everything is truly one logical unit, one commit is correct — don't split artificially.

### Rules
- Never push or open a PR from this skill.
- Never commit to the default branch — create a branch first.
- Treat any arguments as hints (e.g. a suggested split or message prefix).
