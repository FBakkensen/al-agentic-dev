# al-refactor

## What it is for

Reshapes AL production and test code while the tests stay green, leaving observable behaviour identical. The build is green before the first change and after every one that follows.

Reshaping against a red build is debugging, and that belongs to [`/al-implement`](al-implement.md).

## When you reach for it

- A technical task is implemented and the build is green.
- Standalone, on legacy AL that needs shape work before anything else lands in it.

Legacy code with no covering tests has no regression signal, so the skill writes baseline tests that pass against the code as it stands before touching anything.

## What it produces

A reshaped diff, gated after every single change; the reshape is reported to `/al-routing`, whose write settles the task — a reshaped green replaces the task's gate receipt.

It reads the whole task diff through five dimensions: simplification, BC platform reuse, structure, terminology against `CONTEXT.md` and the ADRs, and performance shape. Anything that would move observable behaviour, or that contradicts the Design story, an ADR, or verified behaviour, is not a reshape — it gets recorded and routed as new work.

## Worth knowing

Renames and seam introduction land first, because they touch many call sites and conflict with anything queued behind them. A rename crossing the shipped surface goes through `ObsoleteState = Pending` then `Removed` rather than changing in place; internal-only symbols rename freely.

`[HandlerFunctions('...')]` names a test procedure inside a string literal that symbol tools cannot see, so renaming a handler starts with a text search.
