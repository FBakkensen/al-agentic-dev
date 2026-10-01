---
name: al-next
description: Use when an Original work item or one of its child PBIs has landed and its Azure DevOps design, evidence, or next executable slice needs reconciling.
---

# al-next - reconcile the request

In: the Original work item (a Feature, Bug, or PBI), its direct child PBIs when present, the work-item comments, the receipts, and the landed diff. Azure DevOps is the design record; `.output/receipts/` mirrors execution evidence. If Azure DevOps work-item tools are unavailable, show the exact reconciliation update and stop without creating a substitute record.

Ask one substantive question per message. Connect it to the Original work item, the landed behavior, and verified code facts.

## Show what landed

Name the executable item and its receipts. Launch both together:

▶ haiku · receipts and work-item comments for the executable items → one summary per item

▶ haiku · BC-anatomy delta table from the diff base: objects touched, schema, events, permissions, translations, tests, caller-visible behavior now present → the table

Show the connected-object change map before the delta table. The map explains how changed production objects connect and keeps tests in a separate Proof group.

## Reconcile the Original work item

Read the spec from Description, or from Repro Steps on a Bug, under `/mattpocock-skills:to-spec`'s headings. Compare the landed code with the process contract and Business process under `Solution`, and with the Building Block View Level 1, the Runtime View, black boxes, and Level 2 when present under `Implementation Decisions`. Compare the executable-item change map with the landed diff. Report drift and send the correction to the entry skill the developer types: `/mattpocock-skills:implement` for behavior drift, `/simplify` or `/mattpocock-skills:improve-codebase-architecture` for shape drift. Update the Original work item when implementation proved a better stable internal shape. A Level 2 change records current structure; the executable-item map records what changed.

## Reconcile the slices

Exactly one total slice stays on the Original work item. With two or more, the Original work item is their container and every slice is one direct child PBI. Add a newly proven slice only after the user approves its independent outcome and Gherkin. Remove or merge a slice whose separate value disappeared. Never create grandchildren or work items for modules, tests, diagrams, or implementation tasks.

## Choose the next move

- An executable item without reviewed AAA goes to `/mattpocock-skills:tdd`.
- An executable item with a reviewed `Test specification`, including its `Current-to-final proof map`, goes to `/mattpocock-skills:implement`.
- A hard-to-reverse business decision goes to `/mattpocock-skills:grill-with-docs`.
- An unclear outcome goes to `/mattpocock-skills:prototype` before the hierarchy changes.

## Close

Post reconciliation evidence as comments on the work item. Name the Original work item, the executable item, and the chosen entry skill. The pass ends when the spec field, Acceptance Criteria, child PBIs, comments, and landed code tell one story.
