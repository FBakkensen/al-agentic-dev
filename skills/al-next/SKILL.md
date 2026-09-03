---
name: al-next
description: Use when a root or child User Story has landed and its Azure DevOps design, evidence, or next executable slice needs reconciling.
---

# al-next - reconcile the request

In: the Original Azure DevOps User Story, its child User Stories when present, work-item comments, receipts, and the landed diff. Azure DevOps is the design record; `.output/receipts/` mirrors execution evidence. If Azure DevOps work-item tools are unavailable, show the exact reconciliation update and stop without creating a substitute record.

Ask one substantive question per message. Connect it to the Original User Story, the landed behavior, and verified code facts. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Show what landed

Name the executable item and its receipts. Launch both together:

▶ mechanical · task · receipts and work-item comments for the executable items → one summary per item

▶ mechanical · task · BC-anatomy delta table from the diff base: objects touched, schema, events, permissions, translations, tests, caller-visible behavior now present → the table

Show the connected-object change map before the delta table. The map explains how changed production objects connect and keeps tests in a separate Proof group.

## Reconcile the Original User Story

Compare the code with the Original User Story's BPMN, Runtime View, Building Block Level 1, black boxes, and Level 2 when present. Compare the executable-item change map with the landed diff. Report drift and send the correction to /al-implement or /al-refactor. Update the Original User Story when implementation proved a better stable internal shape. A Level 2 change records current structure; the executable-item map records what changed.

## Reconcile the slices

Exactly one total slice stays on the Original User Story. With two or more, the Original User Story is their container and every slice is a direct child User Story. Add a newly proven slice only after the user approves its independent outcome and Gherkin. Remove or merge a slice whose separate value disappeared. Never create grandchildren or work items for modules, tests, diagrams, or implementation tasks.

## Choose the next move

- An executable item without reviewed AAA goes to /al-test-design.
- An executable item with reviewed AAA goes to /al-orchestrate or /al-implement.
- A hard-to-reverse business decision goes to /al-grill-adr.
- An unclear outcome gets a prototype before the hierarchy changes.

## Close

Post reconciliation evidence as User Story comments. Name the Original User Story, the executable item, and the chosen next skill. The pass ends when the Description, Acceptance Criteria, child hierarchy, comments, and landed code tell one story.
