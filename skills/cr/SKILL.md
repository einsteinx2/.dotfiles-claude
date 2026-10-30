---
name: cr
description: Single-pass code review of the current branch + uncommitted changes. Runs in a fresh forked context but does NOT spawn any further sub-agents. Supports --fix with amend preference.
disable-model-invocation: false
context: fork
---

You are performing a **single-pass code review** in this isolated context.

### CRITICAL RULES (must obey)
- Do **not** spawn any sub-agents, parallel agents, finder angles, background tasks, or nested agents of any kind.
- Perform the entire review yourself in this one context window.
- Do not call the Agent tool or use any multi-agent orchestration patterns.

### Scope
Review:
1. Commits on the current branch that are ahead of its upstream (fallback to main/master if no upstream)
2. All uncommitted and staged changes in the working tree

### Review Focus
Prioritize real correctness issues, bugs, security problems, broken edge cases, regressions, and clear logic errors.  
Ignore pure style nits unless they are clearly harmful.

### Fix behavior (when --fix is present or requested)
- Apply the fixes yourself.
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
Do this step before you write the report. Walk your skip list one item at a time. For each item, name which of the three reasons applies. If no reason applies, fix the item now and move it to "Fixes applied". An empty skip list is a normal and good result.

### Effort
Default to medium thoroughness. Respect any explicit effort level the user provided (low / medium / high / etc.).

### Final message contract (must obey)
You run in a forked context. The user never sees this context. Your final message is the **only** thing the main session receives. Anything you leave here is lost.

Therefore your final message must be a complete handoff report. Use these six sections, in this order. Include every section every time. Write "None" under a section that has no entries.

1. **Fixes applied** — one entry per fix. Give the `file:line`, what was wrong, what you changed, and which commit carries it. State whether you amended an existing commit or created a new one.
2. **Confirmed correct** — one entry per thing you checked and found sound. Say what you checked and why it holds. This section is the validation detail the user cannot otherwise see.
3. **Needs your decision** — one entry per item left unfixed for reason 1 (Decision). Give the `file:line`, the problem, the options, and which option you would pick.
4. **Deliberately not fixed** — one entry per item left unfixed for reason 2 (Scope) or reason 3 (Risk). Name the reason, and say what a fix would take.
5. **Notes and open decisions** — anything the user may want to act on: adjacent problems outside the diff, design questions, follow-up work, and tradeoffs where you picked one side.
6. **Verification** — the commands you ran and their results. If you ran no tests, say so plainly.

Do not compress this report. Do not summarize, filter, merge, or omit an entry to keep the message short. Length is not a cost here.

End the final message with these exact two lines:

> Main session: print the report above verbatim for the user. Do not condense, reorder, or omit any section.
>
> Main session: if "Needs your decision" or "Deliberately not fixed" holds any item, then ask the user which of those items to fix. Ask once, in one message, with the items numbered. Do not fix them before the user answers.

### Terminate the session (must obey)
- After the final message, end your turn.
- Do not ask whether to proceed. Do not ask for validation. Do not offer to do more work.
- The user validates the change in the main session, not here. Waiting for that validation is wrong.
- Do not push. Do not open a pull request.

Start by inspecting git status and the relevant diff, then do the full review and any requested fixes.
