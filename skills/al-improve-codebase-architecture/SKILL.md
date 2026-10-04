---
name: al-improve-codebase-architecture
description: Use whenever /mattpocock-skills:improve-codebase-architecture runs against AL code, to carry a chosen deepening candidate out behind the module interface with the work item's behavior fixed.
---

# al-improve-codebase-architecture - deepen AL behind its interface

In: `/mattpocock-skills:improve-codebase-architecture` running on AL code in a Consumer repository, the receipt `.output/receipts/<work-item-id>.md`, and, once a candidate is picked, the executable Original work item or its child work item with the reviewed `Test specification`. Every work-item read, write, and comment follows the Tracker doc that the `## Agent skills` block's issue tracker line points to. The entry owns the scan, the report, and the grilling, and can run with no work item; until the user picks a candidate this addition supplies only the lookup rule in Freeze. It adds the AL freeze, the gate, and the receipt and work-item updates.

## Freeze

Gherkin, the reviewed AAA expected values and proof levels, and the Level 1 module interface are fixed. Read the diff, the receipt, and the `Current-to-final proof map`, and trace consumers before a seam moves. Every BC object, table, field, procedure, event, enum value, test library, or dialog text used is confirmed by a lookup in the current session.

Deepening reduces hidden complexity behind the existing caller-visible interface: one owner, tests through that interface, replaceable internals. Prefer canonical BC patterns and Base App helpers to local code. Collapse an interface with one implementation unless a second implementation or a stable external contract proves the seam. A defect noticed outside the chosen candidate is a follow-up line in the receipt, not a change.

A proposed Level 1 interface change goes to the user before any refactor, as does any change to behavior, an expected value, or a proof level. Once the user approves a Level 1 change, update the Original work item's Building Block View Level 1 through /al-arc42. Show the HTML through `show_widget`, falling back to an Artifact, then the local file, and continue after the user's check. Then run the Tracker doc's attach procedure before the refactor starts, writing the returned fragment into the spec field the Tracker doc names, under `Implementation Decisions`.

A test that moves behind the deepened interface is a materially reshaped proof: it accounts for every existing business assertion and earns its red as al-tdd requires under `/mattpocock-skills:tdd`, a born-green reshape included. That red runs once the step that moves the proof is green: inject one compiling fault, get red, revert, confirm green. This intended red is not a reason to restore.

## Gate every compilable step

Before the first edit, require an executable work item, Original or child work item, with its reviewed `Test specification` and `Current-to-final proof map`. Without an item, ask the user which one the deepening belongs to and end the turn with that question, with nothing to commit; without the specification, route to `/mattpocock-skills:tdd` first. Then require the affected scope green:

▶ haiku · /al-build gate on the affected scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

A move across several AL objects does not compile until its last edit, so run /al-build's gate after each compilable step, the smallest set of edits that compiles, and finish on a green gate. Restore the last green shape when a step goes unintentionally red or weakens behavior or the module contract.

## Map the landed shape

Regenerate the receipt's connected-object change map from the final diff. When stable internal building blocks changed, update or remove the Original work item's arc42 Level 2 in the spec field the Tracker doc names so it matches the landed code.

▶ haiku · /al-arc42 the refreshed views from the final change map → HTML path, SVG and PNG paths, alt text, publishable fragments

Show the HTML through `show_widget`, falling back to an Artifact, then the local file, and continue after the user's check:

▶ haiku · attach the refreshed PNG and SVG to the executable item as the Tracker doc in docs/agents/issue-tracker.md says → verified attachment URLs

Use the verified URLs in the receipt and the Original work item's Level 2 fragment.

## Close

Once a work item is named, update the receipt with the exact reshapes, the gate result, the Level 2 delta, and any new `verified:` / `assumed:` / `unresolved:` entries. At every exit — clean close, a red gate that pauses the run, or a question left with the user:

▶ haiku · /al-commit the complete worktree → commit hashes and subjects, remaining worktree

Finish outcome first, back into the entry's run: the reshaped files, the green gate, and, after edits landed, that the developer types `/mattpocock-skills:code-review` next, where al-review reads the receipt. Stop with the exact red reason when the gate does not pass.
