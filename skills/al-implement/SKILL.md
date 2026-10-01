---
name: al-implement
description: Use whenever /mattpocock-skills:implement runs against AL work in a Consumer repository.
---

# al-implement - AL workers, reviews, and receipt for the slice

In: `/mattpocock-skills:implement` on the executable Original work item or its child PBI. Read its reviewed `Test specification`, including the `Current-to-final proof map`, and the Original work item's process and Building Block Level 1. The entry skill owns the process; this addition supplies the workers, the reviews, the change map, and the receipt. An unresolved AAA seam, existing-proof disposition, or expected value returns to `/mattpocock-skills:tdd` before code changes.

Trace the narrow path through the workspace first: existing module, event, interface, test, fixture, pattern. Confirm every BC object, table, field, procedure, event, enum value, and dialog text through lookup in this session, never recalled. Write BC vocabulary (Insert, Post, Validate, codeunit) and reach for the platform before new code.

Gherkin defines observable business behavior; AAA defines the reviewed proof seam and expected values; Building Block Level 1 defines caller-visible module ownership; private object layout stays an implementation decision.

## Workers

Before an existing test changes, require its current scope green:

▶ haiku · /al-build gate on the affected test scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

One worker per Gherkin scenario, and scenarios that name the same production site go to one worker; the workers dispatch as background `Agent` calls in one message:

▶ sonnet · one Gherkin scenario: run /mattpocock-skills:tdd with al-tdd on its AAA cases, production site, seam, proof-map rows, and the grounding rule → red evidence per case, the green gate line, files touched

Each AAA case is implemented through its named module interface. One scenario may need several tests, and a `keep` test supplies evidence without a duplicate. The production change is the smallest that turns the proof green: business writes on validated or posting paths, Base App seams reused, quality properties preserved. A pre-existing bug or behavior the work item does not name is a follow-up line in the receipt, not a change, unless the proof cannot go green without it.

A walkthrough-only case takes no automated red; keep it in the receipt for /al-walkthrough. A worker that ends its turn with a fault site and scope gets its fault turn from the lead through `SendMessage`, one worker at a time, the next only after that worker's green returns. Judge every return against its contract before the next step.

## Map what landed

After green, trace the landed production path from its caller through every changed AL object to the records, events, and module interfaces it uses. Build the connected-object change map from the code, never from the changed-file list: every changed production object, only the unchanged neighbours that explain a connection, and a separate Proof group for changed test objects. Mark each object `Added`, `Changed`, `Existing`, or `Removed`; label every edge with the exact procedure, event, interface implementation, or Read/Insert/Modify relation. A changed object with no explained connection is unresolved.

One affected Level 1 module takes a Building Block Level 2 white box. Several take a Level 1 impact overview plus a Level 2 white box for each module whose object relations need explanation. Add a Runtime View only when call order, a transaction boundary, or an error path matters.

▶ haiku · /al-arc42 the chosen views from the connected-object change map → HTML path, SVG and PNG paths, alt text, publishable fragments

Show the HTML through `show_widget`, falling back to an Artifact, then the local file. Add or update the Original work item's Level 2 only when the map reveals stable internal building blocks or interfaces worth preserving, published without change markers; a simple module may need the implementation map but no Original work item Level 2.

▶ haiku · /al-azure-devops-attachments the PNG and SVG to the executable item → verified attachment URLs

Write `.output/receipts/<work-item-id>.md`: work-item ID, map paths and alt text, tests, objects changed, Level 2 decision, gate result, evidence, and `verified:` / `assumed:` / `unresolved:` ledger entries. Put the PNG and the same evidence in the executable item's comment.

## Review

`/mattpocock-skills:code-review` reads committed work, so /al-commit the green slice first. Then both reviews run in parallel, background `Agent` calls in one message, over the slice range from the commit the slice started from:

▶ sonnet · /mattpocock-skills:code-review with al-review, fixed point <start commit>, spec <work item id> → findings as ⛔ and ⚖️, unmerged
▶ sonnet · the built-in /code-review at effort high over <start commit>..HEAD → findings as ⛔ and ⚖️

Fix every ⛔ and /al-commit the fixes, so the slice's final commit carries none; then run both once more over the same range. A ⛔ still red stops the run for the user. ⚖️ findings go to the user, never fixed silently.

## Close

At every exit, including a stop for the user and an unresolved red:

▶ haiku · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree

When the slice gives a shape its first example in this repository, add its row to `docs/patterns.md` from the proposed row and the objects that now realize it; the commit below carries it. Finish outcome first: what changed, what proves it, where the map is attached, which module interface stayed stable, and whether the Original work item's Level 2 changed. Name `/simplify` and `/mattpocock-skills:improve-codebase-architecture` as the next move. A stop names the exact red reason.
