---
name: al-improve-codebase-architecture
description: Use whenever /mattpocock-skills:improve-codebase-architecture runs against AL code, to carry a chosen deepening candidate out behind the module interface with the Azure DevOps work item's behavior fixed.
---

# al-improve-codebase-architecture - deepen AL behind its interface

In: `/mattpocock-skills:improve-codebase-architecture` running on AL code in a Consumer repository, the receipt `.output/receipts/<work-item-id>.md`, and the executable Original work item or its child PBI with the reviewed `Test specification`. The entry owns the scan, the report, and the grilling. This addition applies when the user picks a candidate and it is carried out in this session; it adds the AL freeze, the gate, and the receipt and work-item updates.

## Freeze

Gherkin, the reviewed AAA expected values and proof levels, and the Level 1 module interface are fixed. Read the diff, the receipt, and the `Current-to-final proof map`, and trace consumers before a seam moves. Every BC object, table, field, procedure, event, enum value, test library, or dialog text used is confirmed by a lookup in the current session.

Deepening reduces hidden complexity behind the existing caller-visible interface: one owner, tests through that interface, replaceable internals. Prefer canonical BC patterns and Base App helpers to local code; an interface with one implementation is a finding.

A proposed Level 1 interface change goes to the user before any refactor, as does any change to behavior, an expected value, or a proof level.

## Gate every edit

Before the first edit, require the affected scope green:

▶ haiku · /al-build gate on the affected scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

Run /al-build's gate after each edit and finish on a green gate. Restore the last green shape when an edit weakens behavior or the module contract.

## Map the landed shape

Regenerate the receipt's connected-object change map from the final diff. When stable internal building blocks changed, update or remove the Original work item's arc42 Level 2 so it matches the landed code.

▶ haiku · /al-arc42 the refreshed views from the final change map → HTML path, SVG and PNG paths, alt text, publishable fragments

▶ haiku · /al-azure-devops-attachments the refreshed PNG and SVG to the executable item → verified attachment URLs

Use the verified URLs in the receipt and the Original work item's Level 2 fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Close

Update the receipt with the exact reshapes, the gate result, the Level 2 delta, and any new `verified:` / `assumed:` / `unresolved:` entries. At every exit — clean close, a red gate that pauses the run, or a question left with the user:

▶ haiku · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree

Finish outcome first, back into the entry's run: the reshaped files, the green gate, and that /al-review takes the receipt next. Stop with the exact red reason when the gate does not pass.
