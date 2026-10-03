# GitHub procedure for al-pr-shepherd

Hosts: `github.com`.

## Ground rules

Every `gh` call passes `--repo <owner>/<name>`, read from `origin`. `gh` is 2.99.0 or later, the floor the README sets, and signed in. When it is missing or older, show the install or upgrade it needs; when signed out, show `gh auth login`. Then stop.

## Read

- The pull request: `gh pr view <n> --repo <owner>/<name> --json state,mergeStateStatus,reviewDecision,statusCheckRollup,reviews,headRefOid,closingIssuesReferences,comments`.
- The threads: `gh api graphql` with `repository(owner:"<owner>",name:"<name>"){pullRequest(number:<n>){reviewThreads(first:100,after:<cursor>){pageInfo{hasNextPage endCursor} nodes{id isResolved path comments(first:50){pageInfo{hasNextPage endCursor} nodes{author{login} body}}}}}}`. Fetch the next page with `after:` until `hasNextPage` is false; a thread's further comments come from `node(id:"<thread id>")` on `PullRequestReviewThread` the same way. A resolved thread is handled.
- The driving user: `gh api user --jq .login`. A comment is theirs when its author's login matches.
- A blocking vote: a reviewer's latest review in `reviews` whose state is `CHANGES_REQUESTED`.
- A CI review's finding: an unresolved thread whose first comment is authored by `github-actions` or `github-actions[bot]`, while a check whose name contains `review` ran on the head. The check's summary comment is the top-level comment that author posted.
- Anyone else's comment: a top-level comment or an unresolved thread's comment by another login that is not a review-check bot. Every other bot, `dependabot[bot]` included, counts as anyone else's.
- The conflict: a `mergeStateStatus` of `DIRTY`.
- Merge rules: `mergeStateStatus` is `CLEAN` or `HAS_HOOKS` when the repository's own rules are met. `UNKNOWN` is read again. `UNSTABLE` is a failing check that is not required. `BLOCKED` is reported with what blocks it, read from `statusCheckRollup`, `reviewDecision`, and the unresolved threads. Any other value is reported as it is.

## Answer

An answer starts `Fixed in <short hash>`; a comment of the user's that starts so is an answer, never an instruction.

- A review-thread comment is answered by `gh api graphql` with `addPullRequestReviewThreadReply` (`pullRequestReviewThreadId`, `body`), then `resolveReviewThread` (`threadId`). A CI review's finding takes the same two calls: `Fixed in <short hash>` for a fixed one, the reason for one judged wrong.
- A top-level comment is answered by `gh pr comment <n> --repo <owner>/<name> --body "Fixed in <short hash> — answers <comment url>"`. A user comment is answered when a later user comment carries `answers <its url>`.

## Rerun

`gh run rerun <run-id> --failed --repo <owner>/<name>`; the run id comes from that check's `detailsUrl` in `statusCheckRollup`. A finding the rerun posts again is a new thread, read fresh.

## Complete

On the user's go: `gh pr merge <n> --repo <owner>/<name> --squash`.
