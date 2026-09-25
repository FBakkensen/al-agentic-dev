---
name: al-refactor
description: Use after a green AL implementation when it needs a bounded tidy pass, or when the user names a deeper module reshape whose behavior must stay fixed.
---

# al-refactor - improve the shape

In: the green implementation, reviewed AAA specification, receipt, and the Original User Story that is executable itself or parents the executable child User Story. Choose one mode:

- **Tidy:** local duplication, names, extraction, data access, readability, or dead structure in the changed slice.
- **Deepening:** only on an explicit user request that names the module boundary to reshape.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Freeze behavior

Gherkin, reviewed AAA expected values and proof levels, and the Level 1 module interface are fixed. Read the accepted `Current-to-final proof map`, diff, and receipt, then trace consumers before moving a seam. Confirm every BC object, table, field, procedure, event, enum value, test library, or dialog text used through lookup in this session.

## Decide the list

Inspect the affected proof set as if all current requirements had existed when its tests were first written. Compare the landed tests with the accepted proof map. List the avoidable layers, overlaps, and chronology-shaped tests to correct inside the affected tests and shared helpers; leave unrelated proof alone. A behavior, expected-value, or proof-level change returns to /al-test-design and the user.

Tidy stays inside changed files and immediate seams. Prefer canonical BC patterns and Base App helpers. An interface with one implementation is a finding; collapse it unless a second implementation or stable external contract proves the seam. A defect noticed outside the slice is a follow-up line in the receipt, not a change.

Deepening reduces hidden complexity behind the existing caller-visible interface. Keep ownership singular, test through that interface, and make internals replaceable. A proposed Level 1 interface change returns to /al-design and the user before refactoring.

## Reshape through a worker

Before changing an existing test, require its current scope green:

▶ mechanical · task · /al-build gate on the affected scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

Then dispatch the list; the worker's brief carries the paragraph below:

▶ execution · task · the proof reshapes and tidy/deepening list for the named files with the frozen AAA expected values, the Speak BC paragraph, and the grounding rule → the diff, the green gate line, mutation evidence per reshaped proof, the receipt's Tidy: reshapes

Apply proof-preserving reshapes with production unchanged, account for every existing business assertion unless the current requirement explicitly replaces it, then rerun the gate green. Apply the tidy/deepening list to production next; run /al-build's gate after each edit and finish on a green gate. Every new or materially reshaped proof born green takes mutation as its red. Inject one compiling fault into the production site the proof targets, require red, revert the fault, and confirm green. If no fault forces red, strengthen the assertion until it does. Restore the last green shape when an edit weakens behavior or the module contract.

Judge the return against the frozen values and the list before the next step.

## Map the landed shape

Regenerate the receipt's connected-object change map from the final diff so it shows the landed shape rather than the pre-refactor shape. If stable internal building blocks changed, update or remove the Original User Story's arc42 Level 2 so it matches the landed code. Routine tidy can change the receipt map without changing Original User Story Level 2.

▶ mechanical · task · /al-arc42 the refreshed views from the final change map → HTML path, SVG and PNG paths, alt text, publishable fragments

▶ mechanical · task · /al-azure-devops-attachments the refreshed PNG and SVG to the executable item → verified attachment URLs

Use the verified URLs in the receipt and Original User Story fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Close

Update the receipt with the final implementation map, `Tidy: none` or the exact reshapes, test evidence, gate result, Original User Story Level 2 delta, and any new `verified:` / `assumed:` / `unresolved:` entries. At every exit:

▶ mechanical · task · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree

Finish outcome first: name the reshaped files, the `Tidy: none` or exact reshapes line, the green gate, and that /al-review takes the receipt next. Stop with the exact red reason when the gate does not pass.
