# GitHub recipes

`R` is `owner/name`, `O` is the owner, `NAME` is the repo name. Every command here was used on a live run. The issue relationship flags need `gh` 2.99.0 or later.

## Sub-issues

List the spec's children, and read each child's native blocking edges:
```bash
gh issue view SPEC --repo R --json subIssues --jq '.subIssues.nodes[] | "#\(.number) \(.state) \(.title)"'
gh issue view <child> --repo R --json blockedBy --jq '[.blockedBy.nodes[] | "\(.number):\(.state)"]'
```

File a follow-up as a sub-issue of the spec, with its blocking edges, in one call:
```bash
gh issue create --repo R --title "…" --label ready-for-agent --parent SPEC --blocked-by <n>[,<n>] --body-file body.md
```
Leave `--blocked-by` out when the follow-up has no blocker.
Link an existing issue with `gh issue edit <n> --repo R --parent SPEC`, and add a blocking edge with `--add-blocked-by <blocker>`. An edge that already exists fails with "Target issue has already been taken".

## Closing references

`gh pr view <pr> --repo R --json closingIssuesReferences --jq '[.closingIssuesReferences[].number]'` must name the child. If it doesn't, fix the body:
```bash
gh pr view <pr> --repo R --json body --jq .body > body.md   # edit: add "Fixes #<child>"
gh pr edit <pr> --repo R --body-file body.md
```
The link appears a few seconds after the edit, so check again before you call it broken.

## Hold threads

Post a hold. A file-level review comment counts as an unresolved conversation, which branch protection blocks:
```bash
sha=$(gh pr view <pr> --repo R --json headRefOid --jq .headRefOid)
gh api -X POST repos/R/pulls/<pr>/comments -f commit_id="$sha" -f path="<a file the PR changes>" \
  -f subject_type=file -f body="HOLD (team-lead): <what must land first>. team-lead resolves this thread when the hold ends."
```

Release it, after you've verified the fixes on the PR head:
```bash
t=$(gh api graphql -f query='query{repository(owner:"O",name:"NAME"){pullRequest(number:<pr>){reviewThreads(first:100){nodes{id isResolved comments(first:1){nodes{body}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved|not) | select(.comments.nodes[0].body|startswith("HOLD (team-lead)")) | .id')
gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}' -f t="$t"
```

## The automatic review

The required check is `claude-review`; its conclusion is the review verdict. Its blocking findings are inline review threads, and its nits go in one summary comment, authored by `github-actions`.

## Failing checks

```bash
run=$(gh pr view <pr> --repo R --json statusCheckRollup --jq '.statusCheckRollup[] | select(.conclusion=="FAILURE") | .detailsUrl' | head -1 | sed -E 's#.*/runs/([0-9]+)/.*#\1#')
gh run view "$run" --repo R --log-failed | sed 's/\x1b\[[0-9;]*m//g' | grep -E -A12 'Expected|\[-\]|failed'
```

## Verifying content on main

Git Bash rewrites `origin/main:path` into a Windows path. Prefix it with `MSYS_NO_PATHCONV=1`:
```bash
git fetch origin && MSYS_NO_PATHCONV=1 git show origin/main:<path> | grep -n "<decided phrase>"
git merge-base --is-ancestor <branch-or-sha> origin/main && echo merged
```
