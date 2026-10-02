---
name: al-simplify
description: Use whenever /simplify runs against AL code, or when working AL code is tidied or reshaped with its behavior, tests, and Level 1 interface kept unchanged.
---

# al-simplify - tidy AL with its proof frozen

In: `/simplify` running on AL code in a Consumer repository, the receipt `.output/receipts/<work-item-id>.md`, and the executable Original work item or its child PBI with the reviewed `Test specification`. `/simplify` owns the review and applies its own cleanups. This addition adds the AL freeze, the gate around every edit, and the receipt and work-item updates.

When this addition loads and `/simplify` has not run, run `/simplify` with the Skill tool on the same scope, then follow this addition.

## Freeze

Gherkin, the reviewed AAA expected values and proof levels, and the Level 1 module interface are fixed. Read the diff, the receipt, and the `Current-to-final proof map`, and trace consumers before a seam moves. Every BC object, table, field, procedure, event, enum value, test library, or dialog text used is confirmed by a lookup in the current session.

A cleanup that would change behavior, an expected value, a proof level, or the Level 1 interface goes to the user before it is applied.

## BC thrift

Prefer canonical BC patterns and Base App helpers to local code. An interface with one implementation is a finding; collapse it unless a second implementation or a stable external contract proves the seam. A defect noticed outside the slice is a follow-up line in the receipt, not a change.

## Gate every edit

Before `/simplify` changes an existing test, require its current scope green:

▶ haiku · /al-build gate on the affected scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

Run /al-build's gate after each edit and finish on a green gate. Every existing business assertion survives unless the current requirement explicitly replaces it. Restore the last green shape when an edit weakens behavior or the module contract.

Every new or materially reshaped proof born green takes mutation as its red. Inject one compiling fault into the production site the proof targets, require red, revert the fault, and confirm green. If no fault forces red, strengthen the assertion until it does.

## Map the landed shape

Regenerate the receipt's connected-object change map from the final diff. When stable internal building blocks changed, update or remove the Original work item's arc42 Level 2 so it matches the landed code; routine tidy changes the receipt map only.

▶ haiku · /al-arc42 the refreshed views from the final change map → HTML path, SVG and PNG paths, alt text, publishable fragments

▶ haiku · /al-azure-devops-attachments the refreshed PNG and SVG to the executable item → verified attachment URLs

Use the verified URLs in the receipt and the Original work item's Level 2 fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Close

Update the receipt with `Tidy: none` or the exact cleanups, the gate result, the Level 2 delta, and any new `verified:` / `assumed:` / `unresolved:` entries. At every exit — clean close, a red gate that pauses the run, or a question left with the user:

▶ haiku · /al-commit the complete worktree → commit hashes and subjects, remaining worktree

Finish outcome first, back into `/simplify`'s run: the tidied files, the `Tidy:` line, and the green gate. Stop with the exact red reason when the gate does not pass.
