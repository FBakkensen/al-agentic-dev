---
name: al-pull-request
description: Use only when the user asks to create or update a pull request from the current branch.
---

# al-pull-request - open the change

In: a current branch whose changes are committed, plus every applicable Azure DevOps work-item ID and available proof. Out: one ready pull request for that branch. This skill never creates or keeps a draft.

Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Read the branch

Read the current branch, base branch, commits, and diff with git. A dirty worktree returns /al-commit as the next move. Read the branch's existing pull request and its linked work items with `mcp__plugin_al-agentic-dev_ado__repo_pull_request`: `list` filtered by `sourceRefName`, then `get` with `includeWorkItemRefs`.

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

`Changed` describes the combined landed delta without copying the work-item Description or Acceptance Criteria. Include `Proof` only for evidence already produced; this skill runs no tests. Add `Review notes` only for a real risk, migration concern, assumption, or design drift. The body carries no work-item id line; the links below carry it. Azure Repos caps the description at 4000 characters: merge `Changed` bullets, then shorten `Proof` lines, and never cut mid-line; a body that still passes the cap stops for the user.

## Publish

Push unpublished commits and set the upstream when needed. With no pull request, create a ready one with `mcp__plugin_al-agentic-dev_ado__repo_pull_request_write`, action `create`, passing `workItems` with every work-item id on the branch, space-separated, and `isDraft` false. With one, call `update` with the title, description, and `isDraft` false, passed explicitly on every `update` because the tool's default would otherwise publish a draft silently. The MCP's `update` cannot link work items: for each id not yet linked, run `az repos pr work-item add --id <pr> --work-items <id>`, the one step `az` covers. Never merge.

## Close

Show the PR title, URL, linked work items, and recorded proof. Name /al-pr-shepherd as the next move.
