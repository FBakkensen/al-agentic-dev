# Issue tracker: Azure DevOps

Work items for this repository live in the Azure DevOps org `naveksaas`. The `## Agent skills` block's issue tracker line names the backlog project, which is `NAVEKSA NEXT` for ShopFloor.

## Tools

Every read and write goes through the bundled `ado` MCP server's tools, `mcp__plugin_al-agentic-dev_ado__*`. When those tools are unavailable, show the exact work-item change and stop; write no substitute record anywhere else.

## Work items

- **Read**: an existing item is read by its id alone, which is unique across the org: `mcp__plugin_al-agentic-dev_ado__wit_work_item`, action `get`, with `expand` set to `Relations`.
- **The Original work item** is the Feature, Bug, or PBI the request arrives on. `Original` names its role in this workflow, not the top of the Azure DevOps hierarchy; its structural parents stay as they are.
- **A new Original work item** is created only when the request arrives on none. It is a PBI, or a Bug when the request reports a defect, created in the backlog project with `mcp__plugin_al-agentic-dev_ado__wit_work_item_write`, action `create`.
- **Slices**: one slice creates no child, and the Original work item is executable. Several slices each get one direct child PBI in the Original's project, created with `wit_work_item_write`, action `add_child`, `workItemType` `Product Backlog Item`, under the Original. `add_child` sets only title and Description, so Acceptance Criteria follows in an `update`.
- **Never**: create a Feature, Epic, Task, or a grandchild below the Original work item, and never move an item to another parent, project, area, iteration, or state.
- **Comment**: `mcp__plugin_al-agentic-dev_ado__wit_work_item_comment_write`, action `add`.

## Fields

- The spec goes in Description on a Feature or PBI, and in Repro Steps on a Bug.
- Gherkin `Behavior` and the `Test specification` go in Acceptance Criteria.
- `Product`, `Expected Release Version`, `Implementation notes`, and `Release notes` are never read or written.
- An update to a field read earlier starts with a `test` on `/rev` carrying the revision that read returned. On a revision conflict, read the item again before retrying.

## Links

Parent and blocking edges are native links, never text lines in a body.

- **Parent**: `add_child` creates the parent link. An existing item takes one with `mcp__plugin_al-agentic-dev_ado__wit_work_item_link_write`, action `link`, type `parent`.
- **Blocking**: on the blocked item, `wit_work_item_link_write`, action `link`, type `predecessor`, with `linkToId` set to the blocker.

## Triage

Triage roles are Azure DevOps tags: each role string in `docs/agents/triage-labels.md` is a tag name. Tags live in one field, Tags, as one semicolon-separated string. Read it, add or remove the one role, and write the whole string back, so the team's other tags stay. A role never changes an item's state.

**PRs as a request surface: no.** Pull requests stay out of triage.

## When a skill says "publish to the issue tracker"

Write into the Original work item's fields as Fields places them. Create an item only as Work items allows.

## When a skill says "fetch the relevant ticket"

Read the item by id with `wit_work_item`, action `get`, `expand` set to `Relations`. Its relations carry the parent, the child PBIs, and the predecessors.
