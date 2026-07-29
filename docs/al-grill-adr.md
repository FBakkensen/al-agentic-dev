# al-grill-adr

## What it is for

The domain interview. It grills you about what the business actually does until every BC term in play means exactly one thing, and records the rules that would be expensive to change later.

Vocabulary settled here is what stops a fuzzy word from becoming a wrong Role name in the event model, or a guessed table in the architecture. It reads production and test code to expose where your stated rule and the code disagree, and it changes no code.

## When you reach for it

- A feature is still an idea — no `event-model.md`, no `architecture.md`, no `tasks/` folder.
- A term in the request means two things to two people.
- The rule you just stated disagrees with what the code does.
- A constraint needs its reason written down before it ships.

A crystallised idea can skip it. Most gain from it.

## What it produces

- `CONTEXT.md` at the repo root — the project's own vocabulary: what this codebase narrows, extends, renames, or names that Microsoft does not. Standard Microsoft names stay out of it.
- Accepted ADRs under `docs/adr/`, as `NNNN-slug.md`.

An ADR is offered only when a rule is hard to reverse, surprising without context, a real trade-off, and about the business rather than the code shape. Three of those four earns none.
