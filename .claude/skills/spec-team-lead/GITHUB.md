# GitHub recipes

`R` is `owner/name`, `O` is the owner, `NAME` is the repo name. Every command here was used on a live run.

## Sub-issues

List the spec's children:
```bash
gh api graphql -f query='query{repository(owner:"O",name:"NAME"){issue(number:SPEC){subIssues(first:100){nodes{number title state}}}}}' \
  --jq '.data.repository.issue.subIssues.nodes[] | "#\(.number) \(.state) \(.title)"'
```

File a follow-up and attach it to the spec:
```bash
url=$(gh issue create --repo R --title "…" --label ready-for-agent --body-file body.md); n=${url##*/}
p=$(gh api graphql -f query='query{repository(owner:"O",name:"NAME"){issue(number:SPEC){id}}}' --jq .data.repository.issue.id)
c=$(gh api graphql -f query="query{repository(owner:\"O\",name:\"NAME\"){issue(number:$n){id}}}" --jq .data.repository.issue.id)
gh api graphql -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){subIssue{number}}}' -f p="$p" -f c="$c"
```

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
