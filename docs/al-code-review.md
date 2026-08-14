# al-code-review

## What it is for

The review gate. One pass over a settled diff across a single list of review dimensions, one disposition per surviving finding, one re-review. Code still in flight belongs to [`/al-implement`](al-implement.md); this reviews what has landed.

## When you reach for it

- **Slice-done** — every technical task in the slice has settled and the slice's verify walk still waits on the review stamp.
- **Feature-done** — every task but the breaking-change task has settled and the branch is waiting to merge.
- Any time you want an in-depth review of AL code.

It requires a green gate on a clean tree. An uncertain baseline makes every finding a guess.

## What it produces

Findings surviving both passes are ranked by the consequence of shipping the diff as it stands, each presented as a glyphed headline — `⛔` defect, `⚖️` change request, `⚠️` recommendation — over three one-line slots: `⚡ Breaks:`, `📍 Proof:`, `🔧 Fix:`. Each is disposed one of two ways:

- **Defect** — a bug or implementation-quality problem whose correction needs no user decision. It lands in this run: a behavioural defect goes red first through `/al-implement` and commits under the originating `AB#<id>`; a provably non-semantic one lands directly.
- **Change request** — resolving it would override a recorded user decision, or establish business or architecture intent nobody has decided. You settle it, in conversation, worst first: do it now, write a task, or keep the code.

A finding whose baseline cannot be named is asking for a new baseline, so it is a change request. The diff cannot authorize itself.

A clean gate hands its verdict to `/al-routing`, which stamps the review evidence and opens what the gate was holding — the slice's verify task, or on a clean feature the breaking-change task.

## The passes

Two passes over the scoped diff. The first is BCQuality's knowledge pass, run through `/al-knowledge-pass`. The second fans out across the dimensions: correctness, assertion rigor, proof coverage, red-verdict rigor, precedent, public surface, structure, naming and compliance, comments and history, simplification.
