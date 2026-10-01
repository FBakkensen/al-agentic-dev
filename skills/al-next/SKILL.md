---
name: al-next
description: Use when an Original work item or one of its child PBIs has landed and its Azure DevOps design, evidence, or next executable slice needs reconciling.
---

# al-next - reconcile the request

In: the Original work item (a Feature, Bug, or PBI), its direct child PBIs when present, the work-item comments, the receipts, and the landed diff. Azure DevOps is the design record, and every work-item read and write follows the tracker text the `## Agent skills` block's issue tracker line points to, Acceptance Criteria updates included; `.output/receipts/` mirrors execution evidence. If Azure DevOps work-item tools are unavailable, show the exact reconciliation update and stop without creating a substitute record.

Ask one substantive question per message. Connect it to the Original work item, the landed behavior, and verified code facts.

## Show what landed

Name the executable item and its receipts. Launch both together:

▶ haiku · receipts and work-item comments for the executable items → one summary per item

▶ haiku · BC-anatomy delta table from the diff base: objects touched, schema, events, permissions, translations, tests, caller-visible behavior now present → the table

Show the connected-object change map before the delta table. The map explains how changed production objects connect and keeps tests in a separate Proof group.

## Reconcile the Original work item

Read the spec from Description, or from Repro Steps on a Bug, under `/mattpocock-skills:to-spec`'s headings. Compare the landed code with the process contract and Business process under `Solution`, and with the Building Block View Level 1, the Runtime View, black boxes, and Level 2 when present under `Implementation Decisions`. Compare the landed code with the executable item's `Behavior` Gherkin and `Test specification` in Acceptance Criteria, and the executable-item change map with the landed diff. Report drift and send the correction to the entry skill the developer types: `/mattpocock-skills:implement` for behavior drift, `/simplify` or `/mattpocock-skills:improve-codebase-architecture` for shape drift. When implementation proved a better stable internal shape, dispatch the Level 2 update to the Original work item:

▶ haiku · the settled Level 2 content and the landed diff → the formatted view through `/al-arc42`

▶ haiku · the `/al-arc42` artifacts and the Original work item → attachments published through `/al-azure-devops-attachments`

A Level 2 change records current structure; the executable-item map records what changed.

## Reconcile the slices

Exactly one total slice stays on the Original work item. With two or more, the Original work item is their container and every slice is one direct child PBI. Add a newly proven slice only after the user approves its independent outcome and Gherkin. When a second slice is approved, move the first slice's `Behavior` from the Original work item's Acceptance Criteria into its own direct child PBI; the Original work item becomes the container. When a slice's separate value disappeared, fold its Gherkin into the surviving slice with the user's approval, comment on the retired slice, and leave its state and parent to the user. Never create grandchildren or work items for modules, tests, diagrams, or implementation tasks.

## Choose the next move

- An executable item without reviewed AAA goes to `/mattpocock-skills:tdd`.
- An executable item with a reviewed `Test specification`, including its `Current-to-final proof map`, goes to `/mattpocock-skills:implement`.
- A hard-to-reverse business decision goes to `/mattpocock-skills:grill-with-docs`.
- An unclear outcome goes to `/mattpocock-skills:prototype` before the hierarchy changes.

## Close

Post reconciliation evidence as comments on the executable item, and on the Original work item when it changed. Name the Original work item, the executable item, and the chosen entry skill. The pass ends when the spec field, the executable item's Acceptance Criteria, child PBIs, comments, and landed code tell one story.
