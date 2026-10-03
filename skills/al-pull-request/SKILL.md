---
name: al-pull-request
description: Use only when the user asks to create or update a pull request from the current branch.
---

# al-pull-request - open the change

In: a current branch whose changes are committed, plus every applicable work-item ID and available proof. Out: one ready pull request for that branch. This skill never creates or keeps a draft.

Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Read the branch

Read the current branch, base branch, commits, and diff with git. A dirty worktree returns /al-commit as the next move.

Read `git remote get-url origin`: the procedure is the sibling file whose `Hosts` line lists that host. A `*.` entry matches any subdomain of that domain. A host no procedure lists stops the skill, naming the host.

Procedures: [AZURE-REPOS.md](AZURE-REPOS.md), [GITHUB.md](GITHUB.md).

Read the branch's existing pull request and its linked work items as the procedure says.

Work-item ids come from the request, the branch name, the receipts under `.output/receipts/`, and the existing pull request's linked work items. Never guess an id.

## Write the pull request

Use `<area>: <imperative change>` for the title. Choose the narrowest area that covers the branch.

Write the body in this order:

```markdown
## Changed

- <landed behavior or repository change>

## Proof

- `<command or check>`: <exact result>
```

`Changed` describes the combined landed delta without copying the work item's spec or acceptance criteria. Include `Proof` only for evidence already produced; this skill runs no tests. Add `Review notes` only for a real risk, migration concern, assumption, or design drift. The body ends with the link lines the Tracker doc's "How a pull request names a work item" section gives for this Code host. The procedure's description cap binds: merge `Changed` bullets, then shorten `Proof` lines, and never cut mid-line; a body that still exceeds the cap stops for the user.

## Publish

Push unpublished commits and set the upstream when needed. Create or update the pull request as ready for review, as the procedure says. Then link every work-item id on the branch as that section says. Never merge.

## Close

Show the PR title, URL, linked work items, and recorded proof. Name /al-pr-shepherd as the next move.
