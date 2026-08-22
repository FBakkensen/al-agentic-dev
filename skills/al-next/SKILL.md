---
name: al-next
description: Use when a Feature or Vertical slice has landed and its Azure DevOps design, evidence, or next executable slice needs reconciling.
---

# al-next - reconcile the feature

In: the Azure DevOps Feature, its child User Stories when present, work-item comments, receipts, and the landed diff. Azure DevOps is the design record; `.output/receipts/` mirrors execution evidence. If Azure DevOps work-item tools are unavailable, show the exact reconciliation update and stop without creating a substitute record.

Ask one substantive question per message. Connect it to the Feature, the landed behavior, and verified code facts. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Show what landed

Name the executable item and its receipts. Show the BC-anatomy delta: objects touched, schema, events, permissions, translations, tests, and the caller-visible behavior now present. Ask /al-visualize to draw a changed shape.

## Reconcile the Feature

Compare the code with the Feature's BPMN, Runtime View, Building Block Level 1, black boxes, and Level 2 when present. Report code drift and send the correction to /al-implement or /al-refactor. Update the Feature when implementation proved a better internal shape. A Level 2 change records actual structure; it never rewrites the agreed business outcome.

## Reconcile the slices

Exactly one total slice stays on the Feature. With two or more, the Feature is their container and every slice is a direct child User Story. Add a newly proven slice only after the user approves its independent outcome and Gherkin. Remove or merge a slice whose separate value disappeared. Never create grandchildren or work items for modules, tests, diagrams, or implementation tasks.

## Choose the next move

- An executable item without reviewed AAA goes to /al-test-design.
- An executable item with reviewed AAA goes to /al-orchestrate or /al-implement.
- A hard-to-reverse business decision goes to /al-grill-adr.
- An unclear outcome gets a prototype before the hierarchy changes.

## Close

Post reconciliation evidence as Feature or User Story comments. Name the Feature, the executable item, and the chosen next skill. The pass ends when the Description, child hierarchy, comments, and landed code tell one story.
