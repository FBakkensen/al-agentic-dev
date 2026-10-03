# GitHub procedure for al-pr-shepherd

Hosts: `github.com`.

## Ground rules

Every `gh` call passes `--repo <owner>/<name>`, read from `origin`. `gh` is 2.99.0 or later and signed in with `gh auth login`; when it is missing, older, or signed out, show the exact change and stop.

## Read

- The pull request: `gh pr view <n> --repo <owner>/<name> --json state,mergeStateStatus,reviewDecision,statusCheckRollup,reviews,headRefOid,closingIssuesReferences,comments,body`.
- The threads: `gh api graphql` with `reviewThreads(first:100){nodes{id isResolved path comments(first:50){nodes{author{login} body}}}}` on the pull request. A resolved thread is handled.
- The driving user: `gh api user --jq .login`. A comment is theirs when its author's login matches.
- A blocking vote: a reviewer's latest review in `reviews` whose state is `CHANGES_REQUESTED`.
- Another login's top-level comment counts as feedback when it is newer than the user's latest comment. A bot's comment, `github-actions` included, counts as anyone else's.
- Behind main: a `mergeStateStatus` of `BEHIND` or `DIRTY`.
- Merge rules: `mergeStateStatus` is `CLEAN` when the repository's own rules are met. `UNKNOWN` is read again. Any other value is reported with what blocks it, read from `statusCheckRollup`, `reviewDecision`, and the unresolved threads.
- The linked work items: `closingIssuesReferences`, and the `AB#<id>` lines in `body`.

## Answer

An answer starts `Fixed in <short hash>`; the user's comment that starts so is an answer, never an instruction.

- A review-thread comment: `gh api graphql` with `addPullRequestReviewThreadReply` (`pullRequestReviewThreadId`, `body`) naming the fixing commit, then `resolveReviewThread` (`threadId`).
- A top-level comment has no resolve: `gh pr comment <n> --repo <owner>/<name> --body "Fixed in <short hash>: …"`.

## Complete

On the user's go: `gh pr merge <n> --repo <owner>/<name> --squash`.
