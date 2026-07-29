# al-implement

## What it is for

Drives one technical task red to green with TDD. It consumes the task's Test Specification, takes the AAA cases one at a time — Unit before Integration — and stops at green.

It does not reshape the diff and it does not test the tests. Those are [`/al-refactor`](al-refactor.md) and [`/al-mutate`](al-mutate.md), and neither is chained from here.

## When you reach for it

- A technical task is refined — its Test Specification filled — and the router names it for implementation.
- A `/al-mutate` survivor needs a killer test.
- An `/al-code-review` must-fix needs a red-first repair.

The last two re-enter a task that is already `done`, land under the original `T-NNN`, and move no status.

## What it produces

Production and test AL, committed at green, with the task file reconciled against what actually landed — every AAA case header carrying its real AL test procedure name, `New and Modified Objects` matching the diff.

The green is handed to `/al-routing`, which stamps the phase. The task stays open through the hardening window; `/al-mutate`'s clean verdict is what settles it.

## Worth knowing

The skill decides Unit versus Integration by what the AL Runner can actually prove. Your own tables, fields, and triggers run for real in memory, so record behaviour is unit-provable; anything inside an `.app` dependency auto-stubs, so a case whose truth rides on what a stubbed BaseApp object really returns gets reclassified as Integration rather than wrapped in a one-off interface built only to stub it.

It applies small decisions and keeps going — an object ID, a caption, a permission entry, a local rename — logging each assumption as a `deviations:` line. It stops and blocks on a genuinely new decision: a new table, a new event publisher, a new seam, a public-surface rename.
