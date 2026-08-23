---
name: al-walkthrough
description: Use when an implemented Feature or Vertical slice needs its Gherkin scenarios walked in a running Business Central Web Client with the user's business-central-mcp server.
---

# al-walkthrough - walk the slice

In: the implemented executable Feature itself, or a child User Story and its parent Feature. The user-installed `business-central-mcp` server drives the Web Client. This pass observes Gherkin behavior; AAA unit and integration cases remain build evidence.

## Confirm the walk

Read the Gherkin scenarios and BPMN outcomes. Present the exact scenario order, company or tenant, required records, and expected visible result. Ask the user to confirm before opening the client.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Walk through Business Central

Run /al-build in `AllTests` mode with forced republish into the same container used by `business-central-mcp`. Record the commit and deployed app version before the first scenario.

Use `business-central-mcp` to open the Web Client and exercise each confirmed scenario as a user would. Before relying on any page, action, field, enum value, dialog, or resulting record, confirm it through the current client or a lookup in this session.

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
