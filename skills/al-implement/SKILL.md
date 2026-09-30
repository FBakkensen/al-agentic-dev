---
name: al-implement
description: Use when an executable User Story has reviewed Gherkin, AAA test specification, and module contracts ready to implement in AL.
---

# al-implement - prove the slice

In: the executable Original User Story, or a child User Story and its Original User Story. Read the executable item's reviewed `Test specification`, including its `Current-to-final proof map`, and the Original User Story's process and Building Block Level 1. If the AAA seam, existing-proof disposition, or expected value is unresolved, return that question to /al-test-design before editing code.

Before editing, trace the narrow path through the workspace. Search for an existing module, event, interface, test, fixture, and pattern first. Confirm every BC object, table, field, procedure, event, enum value, and dialog text through lookup in this session.

Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Contract

Gherkin defines observable business behavior; AAA defines the reviewed proof seam and expected values; Building Block Level 1 defines caller-visible module ownership; private object layout remains an implementation decision.

## Shape the proof

Before changing an existing test, require its current scope green:

▶ haiku · /al-build gate on the affected test scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

## Prove and green, one worker per scenario

For each Gherkin scenario, pick its AAA cases, production site, and seam, then dispatch; the scenarios launch together, and each worker's brief carries the three paragraphs below:

▶ sonnet · one Gherkin scenario: its AAA cases, production site, seam, proof-map rows, and the grounding rule → red evidence per case, the green gate line, files touched

Apply the proof map's proof-preserving reshapes before new expectations or production changes. Account for every existing business assertion in the final cases unless the current requirement explicitly replaces it, rerun the gate green, and add no transitional test that the accepted map does not retain.

Implement each unit or integration AAA case through the named module interface. One Gherkin scenario may need several tests. An unchanged existing test marked `keep` supplies evidence without a duplicate. Every new or materially reshaped automated proof earns a red. If born red, require failure for the intended reason. If born green because the behavior exists, inject one compiling fault into the production site the proof targets, run its scope to red, revert the fault, and confirm green. A compile error or a failure before the assertion is not red; if no fault forces red, strengthen the assertion until it does.

Write the smallest production change that makes the proof green. Keep business writes on validated or posting paths, reuse Base App seams, preserve quality properties, and avoid an AL interface with one implementation. A pre-existing bug or a behavior the User Story does not name is a follow-up line in the receipt, not a change, unless the proof cannot go green without it. Run /al-build's gate until green; a red result remains red until the output names its exact cause.

A walkthrough-only case does not enter the automated red step. Keep it in the receipt for /al-walkthrough. Judge every return against its contract before the next step.

## Map what landed

After green, trace the landed production path from its caller through every changed AL object to the records, events, and module interfaces it uses. Create a connected-object change map from the code, never from the changed-file list. Include every changed production object, only the unchanged neighbours needed to explain its connections, and a separate Proof group for changed test objects. Mark each object `Added`, `Changed`, `Existing`, or `Removed`. Label every edge with the exact procedure, event, interface implementation, or Read/Insert/Modify relation. A changed object with no explained connection remains unresolved.

For one affected Level 1 module, use a Building Block Level 2 white box. For several affected Level 1 modules, use a Level 1 impact overview plus a Level 2 white box for each module whose object relations need explanation. Add a Runtime View only when call order, a transaction boundary, or an error path matters.

▶ haiku · /al-arc42 the chosen views from the connected-object change map → HTML path, SVG and PNG paths, alt text, publishable fragments

Show the HTML through `show_widget`, falling back to an Artifact, then to the local file. Keep the change markers in the receipt and executable-item comment. Add or update the Original User Story's Level 2 only when the implementation map reveals stable internal building blocks or interfaces worth preserving; publish that current-state view without change markers. A simple module may need the implementation map but no Original User Story Level 2.

▶ haiku · /al-azure-devops-attachments the PNG and SVG to the executable item → verified attachment URLs

Use the verified URLs in the comment and Original User Story fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Receipt

Write `.output/receipts/<work-item-id>.md` with the work-item ID, implementation-map paths and alt text, tests, objects changed, Level 2 decision, gate result, evidence, and `verified:` / `assumed:` / `unresolved:` ledger entries. Add the PNG and the same evidence to the executable-item comment when Azure DevOps tools are available.

## Close

At every exit:

▶ haiku · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree

Finish outcome first: what changed, what proves it, where the implementation map is attached, which module interface stayed stable, and whether Original User Story Level 2 changed. Name /al-refactor as the next move. Stop with the exact red reason when any proof is unresolved.
