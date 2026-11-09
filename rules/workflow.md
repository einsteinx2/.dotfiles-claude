## Standard implementation workflow

Finish each change that the user asks for with the two steps below.

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

## Open decisions: apply the recommendation, then list it

Do not stop to ask the user about an open decision or an open question. This applies to a plan,
a work item, a phase of a plan, a code review (`/cr`, `/cr-deep`), and a `/cr-apply` run, with
the reviews that its fixes trigger. Choose the recommended option, apply it, and continue. The
user follows the recommendation in most cases and changes the few they disagree with.

- The `/cr`, `/cr-deep`, and `/cr-apply` skills already apply this rule and report their
  decisions. Carry their decisions into the list below. Still print a `/cr` report verbatim.
- If a decision has no clear recommendation, or the options differ in large scope (days of work,
  a different design), choose the smaller, safe option. Put that decision first in the list and
  mark it.
- Still ask before an action that is hard to undo or that reaches outside the repository: a
  push, a PR, a deletion of data, an issue that the user did not ask for.
- If the work writes a plan document, record each decision in the plan too, with the option
  that it rejects.

At the end of the task, after any `/cr` report, give a section with the heading
`## Decisions I made for you`. Format it as follows:

- Start with one or two sentences: where the decisions are recorded (if a file holds them), and
  that each decision changes only its own part of the work.
- Give one numbered list item for each decision. Start the item with a bold sentence that states
  the choice, with its identifier when the plan has one: `**C1: no long-lived streams.**`
- Follow with one to three plain sentences on what the choice does and why.
- End the item with `Rejected:` and the option or options not taken, with the reason for each
  in a few words. Omit `Rejected:` only when no real alternative existed.
- Keep the items in a fixed order: the flagged item of a large-scope decision first, then the
  order of the work.
- After the list, give a short bulleted list of the notes that you left as they are (for
  example, review notes that are not decisions), and say that the user can ask for a change.

Example item:

```markdown
3. **C4: support `private_key_jwt` now, because ChatGPT's document declares it.** Rejected:
   support `none` only and depend on ChatGPT falling back to it.
```
