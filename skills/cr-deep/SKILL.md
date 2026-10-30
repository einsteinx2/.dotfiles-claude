---
name: cr-deep
description: Thorough multi-agent code review of the current branch + uncommitted changes. Explicitly spawns specialized parallel reviewers for different angles. By default it applies NO fixes and saves a full-detail markdown report to the repo (uncommitted); pass --fix to apply fixes. Useful when running on Opus.
disable-model-invocation: true
---

You are performing a **thorough multi-agent code review**. You are the **orchestrator**. You run in the main session and dispatch the review agents from it.

### Instructions
- Spawn multiple specialized parallel sub-agents / finder angles to cover different aspects of the review thoroughly.
- Recommended angles (adapt as needed):
  - Correctness / logic bugs
  - Security issues
  - Regressions and edge cases
  - CLAUDE.md / project convention compliance
  - Performance or resource issues (if relevant)
  - Code duplication / dead code
- After the parallel agents return, synthesize the findings, deduplicate, and rank by severity/confidence.
- Do not skip the multi-agent fan-out — the point of this skill is thorough parallel coverage.

### Scope
Review:
1. Commits on the current branch that are ahead of its upstream (fallback to main/master if no upstream)
2. All uncommitted and staged changes in the working tree

### Review Focus
Prioritize real correctness issues, bugs, security problems, broken edge cases, regressions, and clear logic errors.  
Ignore pure style nits unless they are clearly harmful.

### Default mode: report-only (when --fix is NOT present)
The findings are consumed by a **separate validation session** that verifies them and applies the fixes. Therefore, by default:
- **Do NOT apply any fixes, edits, or commits.** Do not modify any source file, no matter how trivial or certain the fix.
- Write the full report to a markdown file at the repo root named `code-review-<branch>-<YYYY-MM-DD-HHMM>.md` (sanitize `/` in branch names, e.g. `feature/foo` → `feature-foo`).
- **Do not commit, stage, or push** the report file, and do not add it to .gitignore. Leave it untracked.

### Report requirements (full detail — no summarization)
The report file must preserve every sub-agent's findings in full:
- Include **every** finding from every sub-agent, including low-priority, minor, and informational items. Do not condense, filter, or omit anything except true duplicates.
- Deduplication means collapsing identical findings only; when merging duplicates, keep the most detailed writeup.
- Each finding must retain: severity, confidence, `file:line` references, description, evidence/reasoning, and a suggested fix.
- Suggested structure: metadata header (branch, commits reviewed, date, review angles/agents spawned), a summary table of counts by severity, then all findings grouped by severity, each written out in full detail.

### Final message (report-only mode)
Your final message must be **only** a short summary and the file path: severity counts, the report file path, and this explicit statement:

> Report saved to `<path>`. Per this skill's contract, no fixes were applied and none should be applied by this session — fixes are handled in a separate validation session.

Do not echo the findings into the chat, and do not suggest or begin any fixes.

### Fix behavior (only when --fix is explicitly present)
- Write the report file first (same requirements as above), then apply the fixes yourself.
- Where possible, amend the most appropriate existing commit in this branch if the fix directly relates to that code (cleaner history).
- If the fix is unrelated or warrants its own commit, create one new commit per independent fix on top of the branch.

#### Fix bar (must obey)
Fix every finding you are confident is real. Leave a finding unfixed only for one of these three reasons:

1. **Decision** — the correct behavior is a product, design, or naming choice that only the user can make.
2. **Scope** — the fix needs work outside the diff: a refactor of untouched code, a new dependency, a schema or API change, or a change to a file this branch does not touch.
3. **Risk** — the fix could change behavior that you cannot verify here, because there is no test and the intended contract is unclear.

Rules that go with the bar:

- "Minor", "cosmetic", "low severity", "pre-existing", and "not strictly needed" are **not** reasons to skip. Fix them.
- A finding you are unsure is real is not a skip. Investigate it. Then fix it or drop it as not a finding.
- If a finding meets a skip reason but has a safe partial fix, apply the partial fix. Then report the remainder.

#### Re-triage pass (must obey)
Do this step before you write the final message. Walk your skip list one item at a time. For each item, name which of the three reasons applies. If no reason applies, fix the item now and move it to "Fixes applied". An empty skip list is a normal and good result.

### Final message (fix mode)
The report file carries the full finding detail. Your final message must hold these four sections, in this order. Write "None" under a section that has no entries.

1. **Fixes applied** — one entry per fix. Give the `file:line`, what was wrong, what you changed, and which commit carries it. State whether you amended an existing commit or created a new one.
2. **Needs your decision** — one entry per item left unfixed for reason 1 (Decision). Give the `file:line`, the problem, the options, and which option you would pick.
3. **Deliberately not fixed** — one entry per item left unfixed for reason 2 (Scope) or reason 3 (Risk). Name the reason, and say what a fix would take.
4. **Report file** — the path of the report file.

Do not condense, reorder, or omit any section.

If "Needs your decision" or "Deliberately not fixed" holds any item, then end the final message with a question: ask the user which of those items to fix. Ask once, with the items numbered. Do not fix them before the user answers.

### Effort
Default to high thoroughness. Respect any explicit effort level the user provided.

Start by inspecting git status and the relevant diff, then launch the parallel review agents.
