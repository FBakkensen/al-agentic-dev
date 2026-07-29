# al-code-review

## What it is for

The review gate. One pass over a settled diff across a single list of review dimensions, one disposition per surviving finding, one re-review. Code still in flight belongs to [`/al-implement`](al-implement.md); this reviews what has landed.

## When you reach for it

- **Slice-done** — every technical task sharing one slice is `done` and the slice's verify task is still `blocked`.
- **Feature-done** — every task in the feature is `done` and the branch is waiting to merge.
- Any time you want an in-depth review of AL code.

It requires a green gate on a clean tree. An uncertain baseline makes every finding a guess.

## What it produces

Findings reported as `Finding:` / `Where:` / `Action:`, each disposed one of two ways:

- **Rework** — resolving it restores conformance to an existing baseline and changes no baseline. It lands in this run: behaviour-changing rework goes red first and commits under the originating `T-NNN`; non-semantic rework lands directly.
- **Change request** — resolving it would contradict a baseline, or write one that does not exist yet. You settle it, in conversation, worst first: do it now, write a task, or keep the code.

A finding whose baseline cannot be named is asking for a new baseline, so it is a change request. The diff cannot authorize itself.

A clean gate hands its verdict to `/al-routing`, which stamps the review evidence and opens what the gate was holding — the slice's verify task, or on a clean feature the breaking-change task.

## The dimensions

Correctness, assertion rigor, proof coverage, red-verdict rigor, BC anti-patterns, AppSource contract, performance, structure, naming and compliance, comments and history, simplification. One list, applied to the scoped diff.
