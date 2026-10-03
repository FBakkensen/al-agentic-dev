## Work item structure

The `## Agent skills` block's issue tracker line names the project that takes new Original work items, and that line is the one to read.

### Tools

Every read and write goes through the bundled `ado` MCP server's tools, `mcp__plugin_al-agentic-dev_ado__*`. When those tools are unavailable, show the exact work-item change and stop; write no substitute record anywhere else.

### Reading an item

An existing item is read by its id alone, which is unique across the org: `mcp__plugin_al-agentic-dev_ado__wit_work_item`, action `get`, with `expand` set to `Relations`.

### Updating an item

An update to a field read earlier starts with a `test` on `/rev` carrying the revision that read returned. On a revision conflict, read the item again before retrying.

### Triage

Triage roles are Azure DevOps tags: each role string in `docs/agents/triage-labels.md` is a tag name. Tags live in one field, Tags, as one semicolon-separated string. Read it, add or remove the one role, and write the whole string back, so the team's other tags stay.

**PRs as a request surface: no.** Pull requests stay out of triage.

## When a skill says "publish to the issue tracker"

Write the spec into the Original work item, as "write the spec" gives.

## When a skill says "fetch the relevant ticket"

Read the item by id as Reading an item gives. Its relations carry the parent, the children, and the predecessors.

## When a skill says "create the Original work item"

`mcp__plugin_al-agentic-dev_ado__wit_work_item_write`, action `create`, in the project the issue tracker line names, with `workItemType` `<new Original work item type>`, or `<defect type>` when the request reports a defect.

## When a skill says "write the spec"

Put the spec in the field `<spec field for each type>` names for the item's type, with `wit_work_item_write`, action `update`, as Updating an item gives.

## When a skill says "write the acceptance criteria"

Put the Gherkin `Behavior` and the `Test specification` in `<acceptance criteria location>`, with `wit_work_item_write`, action `update`, as Updating an item gives.

## When a skill says "create a slice"

`wit_work_item_write`, action `add_child`, in the Original's project, with `workItemType` `<slice type>`, under the Original work item; `add_child` creates the parent link. It sets only the title and the item's description, so the spec and the acceptance criteria follow through "write the spec" and "write the acceptance criteria". An existing item takes a parent with `mcp__plugin_al-agentic-dev_ado__wit_work_item_link_write`, action `link`, type `parent`.

## When a skill says "link a blocker"

On the blocked item, `wit_work_item_link_write`, action `link`, type `predecessor`, with `linkToId` set to the blocker.

## When a skill says "comment"

`mcp__plugin_al-agentic-dev_ado__wit_work_item_comment_write`, action `add`.

## When a skill says "attach a file"

Local files reach a work item through `/al-azure-devops-attachments`, which returns verified attachment URLs, each with its name. Missing MCP attachment support is not a blocker; Azure CLI authentication trouble stays with that skill until the sign-in works. An embedded image is a verified PNG URL placed as a Markdown image carrying its alt text, in the field `<spec field for each type>` names, under the section the skill names. A refreshed file keeps its filename, and its new URL replaces the old reference. A comment names an attached file by its verified URL.

## When a skill says "name the work item in a pull request"

An Azure Repos pull request links natively: for each work-item id not yet linked, call `mcp__plugin_al-agentic-dev_ado__wit_work_item_link_write`, action `link_to_pull_request`, with the pull request's `projectId` GUID, `repositoryId`, `pullRequestId`, and `workItemId`. Its body carries no work-item id line.

A GitHub pull request carries `AB#<id>` for each work item, which links once the Azure Boards app is connected to the GitHub organization.
