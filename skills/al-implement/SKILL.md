---
name: al-implement
description: Use when an executable Feature or Vertical slice has reviewed Gherkin, AAA test specification, and module contracts ready to implement in AL.
---

# al-implement - prove the slice

In: the executable Feature itself, or a child User Story and its parent Feature. Read the executable item's reviewed `Test specification` and the Feature's process and Building Block Level 1. If the AAA seam or expected value is unresolved, return that question to /al-test-design before editing code.

Before editing, trace the narrow path through the workspace. Search for an existing module, event, interface, fixture, and pattern first. Confirm every BC object, table, field, procedure, event, enum value, and dialog text through lookup in this session.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update only on an important finding or a changed direction.

## Contract

- Gherkin defines observable business behavior.
- AAA defines the reviewed proof seam and expected values.
- Building Block Level 1 defines caller-visible module ownership.
- Private object layout remains an implementation decision.

## Red

Implement each unit or integration AAA case through the named module interface. One Gherkin scenario may need several tests. Run /al-build in `UnitTestOnly` mode for unit proof or `AllTests` mode for integration proof; a new automated proof goes red for the intended reason. If existing behavior and an existing test already prove the case, record that evidence instead of adding a duplicate test.

A walkthrough-only case does not enter the automated red step. Keep it in the receipt for /al-walkthrough.

## Green

Write the smallest production change that makes the proof green. Keep business writes on validated or posting paths, reuse Base App seams, preserve quality properties, and avoid an AL interface with one implementation.

Run the same /al-build mode until green, then run /al-build in `AllTests` mode. A red result remains red until the output names its exact cause.

## Document proven internals

After green, inspect each changed Level 1 module. Add arc42 Building Block Level 2 to the Feature only when implementation revealed stable internal building blocks and interfaces worth preserving. Ask /al-arc42 to apply the official template and create the local architecture review HTML, editable SVG, and PNG. When attachment upload is unavailable, show both artifact paths and exact manual attach steps, then resume after the user supplies the attachment URLs. A simple module needs no Level 2.

## Receipt

Write `.output/receipts/<work-item-id>.md` with the work-item ID, tests, objects changed, `Tidy: none` or exact tidy candidates, Level 2 decision, gate result, evidence, and `verified:` / `assumed:` ledger entries. Add the same evidence as a work-item comment when Azure DevOps tools are available.

## Close

Commit code and tracked documentation with a plain descriptive message at every exit. Finish outcome first: what changed, what proves it, which module interface stayed stable, and whether Level 2 was added. Stop with the exact red reason when any proof is unresolved.
