---
name: al-next
description: Use when an Original work item or one of its child work items has landed and its design, evidence, or next executable slice needs reconciling.
---

# al-next - reconcile the request

In: the Original work item, its direct child work items when present, the work-item comments, the receipts, and the landed diff. The Original work item is the design record, and every work-item read and write, acceptance criteria updates included, follows the Consumer repository's Tracker doc; `.output/receipts/` mirrors execution evidence. If the Tracker doc's tools are unavailable, show the exact reconciliation update and stop without creating a substitute record.

Ask one substantive question per message. Connect it to the Original work item, the landed behavior, and verified code facts.

## Show what landed

Name the executable item and its receipts. Launch both together:

▶ haiku · receipts and work-item comments for the executable items → one summary per item

▶ haiku · BC-anatomy delta table from the diff base: objects touched, schema, events, permissions, translations, tests, caller-visible behavior now present → the table

Show the connected-object change map before the delta table. The map explains how changed production objects connect and keeps tests in a separate Proof group.

## Reconcile the Original work item

Read the spec from the spec field the Tracker doc names, under `/mattpocock-skills:to-spec`'s headings. Compare the landed code with the process contract and Business process under `Solution`, and with the Building Block View Level 1, the Runtime View, black boxes, and Level 2 when present under `Implementation Decisions`. Compare the landed code with the executable item's `Behavior` Gherkin and `Test specification` in acceptance criteria, and the executable-item change map with the landed diff.

Build the trace page in-line, with no `▶` line, from those reads, the receipts, and the landed diff: one row per named BPMN end event, with the columns BPMN end event, executable item, `Behavior` scenario, AAA case and proof level from the `Current-to-final proof map`, test procedure, and changed production object. An empty cell is a gap. A single slice is its own executable item; with several slices the rows span every direct child work item. Write it to `.output/trace/<original-work-item-id>/trace.html` as static, self-contained HTML: no CDN, iframe, remote asset, or script. It is disposable and never attached or committed; the reconciliation comments stay the record. Show the HTML through `show_widget`, falling back to an Artifact, then the local file.

Report drift and send the correction to the entry skill the developer types: `/mattpocock-skills:implement` for behavior drift, `/simplify` or `/mattpocock-skills:improve-codebase-architecture` for shape drift. `/al-implement` publishes Level 2 after green. Update it here only when it drifts from the landed code, so the two never publish in parallel:

▶ haiku · /al-arc42 the corrected Level 2 white box from the landed diff → HTML path, SVG and PNG paths, alt text, publishable fragments

Show the HTML through `show_widget`, falling back to an Artifact, then the local file, and continue after the user's check:

▶ haiku · attach the Level 2 PNG and SVG to the Original work item as the Tracker doc in docs/agents/issue-tracker.md says → verified attachment URLs

Place the fragment and each verified PNG under `Implementation Decisions` in the spec field, as the Tracker doc says. A Level 2 change records current structure; the executable-item map records what changed.

## Reconcile the slices

Exactly one total slice stays on the Original work item. With two or more, the Original work item is their container and every slice is one direct child work item. Add a newly proven slice only after the user approves its independent outcome and Gherkin. When a second slice is approved, move the first slice's `Behavior`, `Test specification`, and `Current-to-final proof map` from the Original work item's acceptance criteria into its own direct child work item, and rename its receipt `.output/receipts/<original-id>.md` to `<child-id>.md`; the Original work item becomes the container, and its slices stay children. When a slice's separate value disappeared, fold its Gherkin into the surviving slice with the user's approval, comment on the folded slice, and leave its state and parent to the user. A folded child is listed "pending retirement" until the user retires it; it is never the executable item and is left out of the slice count. Never create grandchildren or work items for modules, tests, diagrams, or implementation tasks.

## Choose the next move

- An executable item without reviewed AAA goes to `/mattpocock-skills:tdd`.
- An executable item with a reviewed `Test specification`, including its `Current-to-final proof map`, goes to `/mattpocock-skills:implement`.
- A hard-to-reverse business decision goes to `/mattpocock-skills:grill-with-docs`.
- An unclear outcome goes to `/mattpocock-skills:prototype` before the hierarchy changes.

## Close

Post reconciliation evidence as comments on the executable item, and on the Original work item when it changed. Name the Original work item, the executable item, and the chosen entry skill. The pass ends when the spec field, the Original work item's and each executable item's acceptance criteria, child work items, comments, and landed code tell one story.
