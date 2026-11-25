---
name: pr-comments
description: Address the open review comments on a pull request. Check each comment against the code, fix the valid ones, push, reply to each comment with what changed or why nothing changed, and resolve each thread. Use when the user asks to handle, address, answer, or go through the PR comments or review comments. Optional argument - a PR number or URL; defaults to the PR of the current branch.
disable-model-invocation: false
---

Address every open comment on one pull request. Fix the valid comments, answer every comment,
and resolve every thread. The user asked for this skill, so it pushes to the PR branch and posts
on the PR without a separate approval. This replaces the "never push" rule and the rule to ask
before a push in the user's workflow instructions, for this PR only.

## 1. Find the PR and the worktree

1. Find the PR. Use the argument if there is one. Otherwise run
   `gh pr view --json number,url,headRefName,baseRefName,author`.
2. Find the worktree that has the PR branch checked out: `git worktree list`. Run every git
   command in that worktree, with `git -C <path>` or `cd <path>`. If no worktree has the branch,
   stop and tell the user.
3. If `git status --porcelain` shows changes in that worktree, stop and tell the user. The
   changes can belong to other work.
4. Run `git fetch origin`. If the local branch and `origin/<branch>` differ, stop and tell the
   user. Do not merge, rebase, or reset to make them match.
5. Record `git rev-parse origin/<branch>` as `<before>`. Step 4 uses it to scope the review and
   the push.

## 2. Collect the comments

Read all 3 kinds of comment with one GraphQL query. Get `<owner>` and `<repo>` from the PR URL.
If `hasNextPage` is true for a list, query that list again with `after:"<endCursor>"`.

```
gh api graphql -f owner=<owner> -f name=<repo> -F number=<n> -f query='
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      reviewThreads(first:100){pageInfo{hasNextPage endCursor} nodes{
        id isResolved isOutdated path line originalLine
        comments(first:100){pageInfo{hasNextPage endCursor} nodes{databaseId author{login} body url}}}}
      reviews(first:100){pageInfo{hasNextPage endCursor}
        nodes{databaseId author{login} state body url}}
      comments(first:100){pageInfo{hasNextPage endCursor}
        nodes{databaseId author{login} body url}}}}}'
```

Keep these items:

- **Review threads** that are not resolved. Read every comment in the thread, not only the
  first one.
- **Review bodies and top-level comments** that ask for a change, ask a question, or flag a
  point for a decision. A review body often lists points that have no inline comment.

Skip these items, and list them in the report as skipped:

- Status comments from bots that ask for nothing: deploy previews, CI summaries, translation
  checks, coverage tables.
- Comments that a reply on the PR already answered.

If nothing is left, tell the user and stop.

## 3. Check each comment

For each comment, read the code that the comment is about at the PR head. Do not trust the line
number: an outdated thread points at old code. Then choose one verdict:

- **Valid**: the problem is real at the PR head. Fix it.
- **Partly valid**: fix the part that is real. Explain the other part.
- **Already fixed**: a later commit fixed it. Name the commit.
- **Not valid**: the comment is wrong about the code, or the change would break something. Make
  no change. Give the concrete reason, with the file and line or the behavior that proves it.
- **Decision**: the comment asks for a choice and does not report a bug. Apply the rule for
  open decisions from the user's instructions: choose the recommended option, or the smaller,
  safe option. Do not ask the user.

Do not fix something only because a reviewer asked for it. Check each claim yourself. A
suggested patch can be wrong even when the problem is real. Also fix the same defect in other
places of the PR when the comment exposes it.

## 4. Fix, commit, review, push

Skip this step if no comment needs a change.

1. Make the fixes.
2. Commit. `<base>` is the `baseRefName` from step 1. Compare
   `git log --format=%ae origin/<base>..HEAD` with `git config user.email`.
   - **The user's own branch** (the user wrote every commit): fold each fix into the commit
     that introduced the code. This replaces the `/commit` step of the user's workflow.
     1. Create a backup branch: `git branch backup/<branch>-pr-comments-<date>`.
     2. Run `git commit --fixup <sha>` for each fix.
     3. Run `git rebase --autosquash $(git merge-base origin/<base> HEAD)`. Git 2.44 and later
        apply `--autosquash` without `-i`.
     4. If a fix makes a commit message wrong, update that message.
   - **A branch with commits from someone else, or with a merge commit**
     (`git rev-list --merges origin/<base>..HEAD` prints a SHA): add new commits with the
     `/commit` skill. Do not rewrite their commits. A rebase drops a merge commit and its
     conflict resolutions.
3. Run `/cr --fix` and scope it to the fixes: "review only the changes in
   `git diff <before> HEAD`, which address these PR comments: <list>". Carry its decisions
   into the report.
4. Push. After a rebase, use `git push --force-with-lease=<branch>:<before>`. Otherwise use a
   plain `git push`. If the push fails, stop and tell the user. Do not use `--force`.
5. If the PR description now says something false, update it with `gh pr edit --body-file`.

## 5. Reply to each comment and resolve it

Reply after the push, so each reply can name the final commit SHA.

- **Review thread**: reply in the thread, then resolve it. Write the reply to a file in the
  scratchpad first. `-F body=@<file>` then sends backticks and quotes without shell expansion.

  ```
  gh api graphql -f query='mutation($id:ID!,$body:String!){
    addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}){comment{url}}}' \
    -f id=<thread id> -F body=@<reply file>
  gh api graphql -f query='mutation($id:ID!){
    resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id=<thread id>
  ```

  Resolve every thread you answered, also when the verdict is "not valid".

- **Review body or top-level comment**: GitHub cannot resolve these. Post one top-level PR
  comment that answers each point in order: `gh pr comment <n> --body-file <file>`. Quote the
  first words of each point so the reader can match them.

Write each reply in 1 to 4 short sentences:

- Start with the verdict: "Valid.", "Partly valid.", "Already fixed in `<sha>`.",
  "Not changed.", or "Decision:".
- For a fix: say what changed and where, and give the short SHA.
- For no change: give the reason in concrete terms.
- Do not thank the reviewer and do not apologize.
- Put identifiers, paths, and code in backticks. Do not write a bare `@name`.

## 6. Report

Tell the user:

1. A table with one row for each comment: the author, the file or "review body", the verdict,
   and the link to the reply.
2. The commits after the fixes, and whether the push rewrote history.
3. The short `/cr` summary.
4. The skipped comments, in one line each.
5. The `## Decisions I made for you` section from the user's instructions, with each
   "Decision" verdict and each "Not valid" verdict that rests on a judgment call.
