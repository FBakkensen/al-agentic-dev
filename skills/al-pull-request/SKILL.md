---
name: al-pull-request
description: Use only when the user asks to create or update a pull request from the current branch.
---

# al-pull-request - open the change

In: a current branch whose changes are committed, plus every applicable Azure DevOps work-item ID and available proof. Out: one ready pull request for that branch. This skill never creates or keeps a draft.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Read the branch

Use `gh` for every GitHub operation. Read the current branch, base branch, commits, diff, existing pull request, and work-item references. A dirty worktree returns /al-commit as the next move. Never guess a work-item ID.

## Write the pull request

Use `<area>: <imperative change>` for the title. Choose the narrowest area that covers the branch.

Write the body in this order:

```markdown
AB#<work-item-id>

## Changed

- <landed behavior or repository change>

## Proof

- `<command or check>`: <exact result>
```

List every work item represented by the branch, one `AB#<id>` line each. `Changed` describes the combined landed delta without copying the work-item Description or Acceptance Criteria. Include `Proof` only for evidence already produced; this skill runs no tests. Add `Review notes` only for a real risk, migration concern, assumption, or design drift.

## Publish

Push unpublished commits and set the upstream when needed. Create a ready pull request when none exists; otherwise update the current branch's pull request and mark it ready if necessary. Never merge.

## Close

Show the PR title, URL, work-item references, and recorded proof. Name /al-pr-shepherd as the next move.
