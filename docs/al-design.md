# al-design

## What it is for

Settles the feature-level architecture through an interview and writes it down. Module map, dependency direction, where persisted data lives, seam placement, which existing behaviour may move, the public surface the feature commits to, and where decision logic stays reachable by unit tests without a database.

[`/al-scope`](al-scope.md) decomposes this file into every task of the feature, so a gap left here resurfaces as a guess inside a task.

## When you reach for it

- The spec folder has `event-model.md` but no `architecture.md`.
- The feature is backend-only and skipped the event model.
- An existing `architecture.md` needs reshaping before the task list is cut from it.

It stops and sends you back if `CONTEXT.md` and the domain ADRs are not settled — domain confusion and architectural choice are indistinguishable without them.

## What it produces

`architecture.md` in the feature's spec folder: the module map, every slice's AL realisation named slot by slot, the brownfield touchpoint inventory, and the seams that keep decisions unit-testable.

Every named object is marked `new` or `extends <existing object>`, which is how `/al-refine` derives each task's New and Modified Objects without re-deciding brownfield scope.

Where the design turns on a genuine fork, it builds competing candidates — each self-contained under Constraint, Shape, Flow, Seams, and Trade-offs — compares them, recommends one, and puts the pick to you.

One sibling format file ships inside the skill: `ARCHITECTURE-FORMAT.md`. The ADR and `CONTEXT.md` shapes ship with `/al-grill-adr`, their writer.
