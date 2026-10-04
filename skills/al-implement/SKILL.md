---
name: al-implement
description: Use whenever /mattpocock-skills:implement runs against AL work in a Consumer repository.
---

# al-implement - AL workers, reviews, and receipt for the slice

In: `/mattpocock-skills:implement` on the executable Original work item or its child work item. Every work-item read, write, and comment follows the Tracker doc that the `## Agent skills` block's issue tracker line points to. Read its reviewed `Test specification`, including the `Current-to-final proof map`, and the Original work item's process and Building Block Level 1. The entry skill owns the process; this addition supplies the workers, the reviews, the change map, and the receipt. An unresolved AAA seam, existing-proof disposition, or expected value returns to `/mattpocock-skills:tdd` before code changes.

Trace the narrow path through the workspace first: existing module, event, interface, test, fixture, pattern. Confirm every BC object, table, field, procedure, event, enum value, and dialog text through lookup in this session, never recalled. Write BC vocabulary (Insert, Post, Validate, codeunit) and reach for the platform before new code.

Gherkin defines observable business behavior; AAA defines the reviewed proof seam and expected values; Building Block Level 1 defines caller-visible module ownership; private object layout stays an implementation decision.

## Workers

Before an existing test changes, require its current scope green:

▶ haiku · /al-build gate on the affected test scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

One worker per Gherkin scenario that takes an automated red. The workers run one at a time: each is dispatched after the previous worker's return meets its contract, and owns the worktree for its whole red and green cycle, injected-fault red included. When a return meets its contract, the lead runs /al-commit on that scenario's accepted work as a checkpoint, so the next worker starts from a clean, committed worktree and its files touched are its own diff against the checkpoint:

▶ sonnet · one Gherkin scenario: run /mattpocock-skills:tdd with al-tdd on its AAA cases, production site, seam, proof-map rows, and the grounding rule → red evidence per case, the green gate line, files touched

New behavior lands in a module, an existing one or a new child namespace of its feature cluster, never in open code. Each AAA case is implemented through its named module interface. The production change is the smallest that turns the proof green: business writes on validated or posting paths, Base App seams reused, quality properties preserved. A pre-existing bug or behavior the work item does not name is a follow-up line in the receipt, not a change, unless the proof cannot go green without it.

A walkthrough-only case gets no worker; keep it in the receipt for /al-walkthrough. Judge every return against its contract before the next step. A missed return is re-dispatched with the last checkpoint commit and the failed attempt's diff in the brief; the new worker first resets only the files that attempt changed, never `.`: tracked paths restored from the checkpoint in index and worktree (`git restore --source=<checkpoint> --staged --worktree`), untracked paths that attempt created removed. Then it starts. After the last worker, require every scenario's proof green together:

▶ haiku · /al-build gate on the combined test scope of every scenario, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

## Map what landed

After green, trace the landed production path from its caller through every changed AL object to the records, events, and module interfaces it uses. Build the connected-object change map from the code, never from the changed-file list: every changed production object, only the unchanged neighbours that explain a connection, and a separate Proof group for changed test objects. Mark each object `Added`, `Changed`, `Existing`, or `Removed`; label every edge with the exact procedure, event, interface implementation, or Read/Insert/Modify relation. A changed object with no explained connection is unresolved.

One affected Level 1 module takes a Building Block Level 2 white box. Several take a Level 1 impact overview plus a Level 2 white box for each module whose object relations need explanation. Add a Runtime View only when call order, a transaction boundary, or an error path matters.

▶ haiku · /al-arc42 the chosen views from the connected-object change map → HTML path, SVG and PNG paths, alt text, publishable fragments

Show the HTML through `show_widget`, falling back to an Artifact, then the local file. Add or update the Original work item's Level 2 only when the map reveals stable internal building blocks or interfaces worth preserving, published without change markers; a simple module may need the implementation map but no Original work item Level 2.

▶ haiku · attach the PNG and SVG to the executable item as the Tracker doc in docs/agents/issue-tracker.md says → verified attachment URLs

Write `.output/receipts/<work-item-id>.md`: work-item ID, map paths and alt text, tests, objects changed, Level 2 decision, gate result, evidence, and `verified:` / `assumed:` / `unresolved:` ledger entries. Put the PNG and the same evidence in the executable item's comment, as the Tracker doc says.

## Review

`/mattpocock-skills:code-review` reads committed work, so /al-commit the green slice first. Then both reviews run in parallel, background `Agent` calls in one message, over the slice range from the commit the slice started from:

▶ sonnet · /mattpocock-skills:code-review with al-review, fixed point <start commit>, spec <work item id> → findings as ⛔ and ⚖️, unmerged
▶ sonnet · the built-in /code-review at effort high over <start commit>..HEAD → findings as ⛔ and ⚖️

Fix every ⛔ and /al-commit the fixes, so the slice's final commit carries none; then run both once more over the same range. A ⛔ still red stops the run for the user. ⚖️ findings go to the user, never fixed silently.

## Close

On a green close, for each shape the slice realized that has a precedent in the Original's Level 1 and no row in `docs/patterns.md`, add the row from that precedent with the objects that now realize it, creating `docs/patterns.md` with its first row. A slice with no surveyed shape records nothing.

At every exit, including a stop for the user and an unresolved red:

▶ haiku · /al-commit the complete worktree → commit hashes and subjects, remaining worktree

Finish outcome first: what changed, what proves it, where the map is attached, which module interface stayed stable, and whether the Original work item's Level 2 changed. Name `/simplify` and `/mattpocock-skills:improve-codebase-architecture` as the next move. A stop names the exact red reason.
