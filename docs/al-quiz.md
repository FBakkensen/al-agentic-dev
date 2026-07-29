# al-quiz

## What it is for

Tests your model of code that has already landed. The subject under test is you, not the diff — the code is on disk either way; what nobody has checked is whether the person who now owns it could have written it.

It runs no gate, flips no task, and writes no file. The whole result lives in your head when it closes.

## When you reach for it

- A long agentic run just finished and you watched it loosely.
- A slice is `done` and the feature is heading for merge.
- You are coming back to a repo after time away.
- Any diff, slice, or object area you want to be sure of.

## What it produces

A conversation, one question per message, and a closing account of where your model was sound and where it was not.

Questions come from what shipped, not from the plan — reciting the Test Specification proves nothing about the code. They land where a wrong answer would cost something: which seam the logic sits on and what breaks when it moves, the edge case a named AAA case pins, the existing path the change reroutes, the contract a dependent app leans on.

No lettered options. You are a witness here, and options would hand over the answer before you gave it.

A miss is corrected on the spot, in one line, against the object or procedure that carries it. Where misses cluster on shipped behaviour rather than on how it was built, [`/al-code-review`](al-code-review.md) over the same scope is the follow-up worth taking.

The repo is left untouched.
