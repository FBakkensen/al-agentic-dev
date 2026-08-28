---
name: al-refactor
description: Use after a green AL implementation when it needs a bounded tidy pass, or when the user names a deeper module reshape whose behavior must stay fixed.
---

# al-refactor - improve the shape

In: the green implementation, reviewed AAA specification, receipt, and the Original User Story that is executable itself or parents the executable child User Story. Choose one mode:

- **Tidy:** local duplication, names, extraction, data access, readability, or dead structure in the changed slice.
- **Deepening:** only on an explicit user request that names the module boundary to reshape.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Freeze behavior

Gherkin, reviewed AAA expected values and proof levels, and the Level 1 module interface are fixed. Read the accepted `Current-to-final proof map`, diff, and receipt, then trace consumers before moving a seam. Confirm every BC object, field, event, enum value, or test library used through lookup in this session.

## Reshape the proof

Inspect the affected proof set as if all current requirements had existed when its tests were first written. Compare the landed tests with the accepted proof map. Correct avoidable layers, overlaps, and chronology-shaped tests inside the affected tests and shared helpers; leave unrelated proof alone.

Before changing an existing test, run /al-build in `UnitTestOnly` mode for unit proof or `AllTests` mode for integration proof and require its current scope green. Keep production unchanged while applying proof-preserving reshapes, account for every existing business assertion unless the current requirement explicitly replaces it, then rerun the same mode green. A behavior, expected-value, or proof-level change returns to /al-test-design and the user.

Every new or materially reshaped proof born green takes mutation as its red. Inject one compiling fault into the production site the proof targets, require red, revert the fault, and confirm green. If no fault forces red, strengthen the assertion until it does.

## Tidy

Stay inside changed files and immediate seams. Prefer canonical BC patterns and Base App helpers. An interface with one implementation is a finding; collapse it unless a second implementation or stable external contract proves the seam.

## Deepening

Reduce hidden complexity behind the existing caller-visible interface. Keep ownership singular, test through that interface, and make internals replaceable. A proposed Level 1 interface change returns to /al-design and the user before refactoring.

## Prove

Run /al-build in `UnitTestOnly` mode after a unit-only edit or `AllTests` mode after an integration edit, then finish in `AllTests` mode. Restore the last green shape when an edit weakens behavior or the module contract.

Regenerate the receipt's connected-object change map from the final diff so it shows the landed shape rather than the pre-refactor shape. If stable internal building blocks changed, update or remove the Original User Story's arc42 Level 2 so it matches the landed code. Ask /al-arc42 for refreshed local HTML, SVG, PNG, alt text, and publishable fragments. Ask /al-azure-devops-attachments to attach the refreshed PNG and SVG, and use its verified URLs in the receipt and Original User Story fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works. Routine tidy can change the receipt map without changing Original User Story Level 2.

## Close

Update the receipt with the final implementation map, `Tidy: none` or the exact reshapes, test evidence, gate result, Original User Story Level 2 delta, and any new `verified:` / `assumed:` entries. Ask /al-commit to commit the complete worktree at every exit. Finish outcome first; stop with the exact red reason when the gate does not pass.
