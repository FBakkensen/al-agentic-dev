---
name: al-refactor
description: Use after a green AL implementation when it needs a bounded tidy pass, or when the user names a deeper module reshape whose behavior must stay fixed.
---

# al-refactor - improve the shape

In: the green implementation, reviewed AAA specification, receipt, and the Feature that is executable itself or parents the child User Story. Choose one mode:

- **Tidy:** local duplication, names, extraction, data access, readability, or dead structure in the changed slice.
- **Deepening:** only on an explicit user request that names the module boundary to reshape.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Freeze behavior

Gherkin, reviewed AAA expected values, and the Level 1 module interface are fixed. Read the diff and receipt, then trace consumers before moving a seam. Confirm every BC object, field, event, enum value, or test library used through lookup in this session.

## Tidy

Stay inside changed files and immediate seams. Prefer canonical BC patterns and Base App helpers. An interface with one implementation is a finding; collapse it unless a second implementation or stable external contract proves the seam.

## Deepening

Reduce hidden complexity behind the existing caller-visible interface. Keep ownership singular, test through that interface, and make internals replaceable. A proposed Level 1 interface change returns to /al-design and the user before refactoring.

## Prove

Run /al-build in `UnitTestOnly` mode after a unit-only edit or `AllTests` mode after an integration edit, then finish in `AllTests` mode. Restore the last green shape when an edit weakens behavior or the module contract.

Regenerate the receipt's connected-object change map from the final diff so it shows the landed shape rather than the pre-refactor shape. If stable internal building blocks changed, update or remove the Feature's arc42 Level 2 so it matches the landed code. Ask /al-arc42 for refreshed local HTML, SVG, PNG, alt text, and publishable fragments. When attachment upload is unavailable, show the artifact paths and exact manual attach steps, then resume after the user supplies the attachment URLs. Routine tidy can change the receipt map without changing Feature Level 2.

## Close

Update the receipt with the final implementation map, `Tidy: none` or the exact reshapes, test evidence, gate result, Feature Level 2 delta, and any new `verified:` / `assumed:` entries. Commit changes with a plain descriptive message at every exit. Finish outcome first; stop with the exact red reason when the gate does not pass.
