---
name: al-walkthrough
description: Use when an implemented User Story needs its Gherkin scenarios walked in a running Business Central Web Client and the consumer repository supplies a Business Central workspace MCP for the current worktree.
---

# al-walkthrough - walk the slice

In: the implemented executable Original User Story, or a child User Story and its Original User Story. The consumer repository must supply a workspace MCP that exposes the `bc_*` Web Client tools for the current worktree. This pass observes Gherkin behavior; AAA unit and integration cases remain build evidence.

## Confirm the walk

Read the Gherkin scenarios and BPMN outcomes. Present the exact scenario order, company or tenant, required records, and expected visible result. Ask the user to confirm before opening the client.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding or a changed direction. Finish with the outcome first, then the detail, so the last message stands on its own.

## Walk through Business Central

The repository workspace MCP owns the branch and container binding. After changing branches or its configuration, restart the MCP or Copilot session before the walk. Then:

▶ mechanical · task · /al-build clean republish into the bound container → deployed commit and app version

Record both before the first scenario.

Use the repository's Business Central workspace MCP to open the Web Client and exercise each confirmed scenario as a user would. Before relying on any page, action, field, enum value, dialog, or resulting record, confirm it through the current client or a lookup in this session.

For each step report:

`▶ <business action>`

`📍 Observed: <exact visible result>`

`✅ Expected: <matching Gherkin result>`

On a mismatch report:

`⛔ <scenario and step>`

`📍 Observed: <exact visible result>`

`⚡ Expected: <Gherkin result>`

`🔧 Reproduce: <shortest path back to the mismatch>`

Continue independent scenarios after one fails when the failed state does not invalidate them.

## Close

Post walkthrough evidence as a work-item comment when Azure DevOps tools are available. Finish with passed scenarios, mismatches, resulting record identifiers, and a hand-reproduction recipe. Create no report file and change no AL code.
