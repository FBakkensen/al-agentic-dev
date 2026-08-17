# al-design

## What it is for

Settles the feature-level architecture through an interview and writes it onto the same Design User Story. Module ownership, dependency direction, where persisted data lives, seam placement, which existing behaviour may move, the public surface the feature commits to, and where decision logic stays reachable by unit tests without a database.

[`/al-scope`](al-scope.md) decomposes this page into every task of the feature, so a gap left here resurfaces as a guess inside a task.

## When you reach for it

- The Design story has a happy path but no Modules section.
- The feature is backend-only and skipped the event model.
- An existing Design page needs reshaping before the task list is cut from it.

It stops and sends you back if `CONTEXT.md` and the domain ADRs are not settled — domain confusion and architectural choice are indistinguishable without them.

## What it produces

The same Design User Story, rewritten whole: Goal, Happy path, When it stops, Modules, Brownfield. Each section uses a different HTML shape so the Azure DevOps dark theme does not flatten them into one slab. Modules are short paragraphs with a `Precedent` suffix. Brownfield is labelled paragraphs (Read / Insert / Profile / Reshape / Remove).

Where the design turns on a genuine fork, it builds competing candidates — each self-contained under Constraint, Shape, Flow, Seams, and Trade-offs — compares them, recommends one, and puts the pick to you.

One sibling format file ships inside the skill: `ARCHITECTURE-FORMAT.md`. The ADR and `CONTEXT.md` shapes ship with `/al-grill-adr`, their writer.
