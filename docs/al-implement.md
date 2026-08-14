# al-implement

## What it is for

Drives one technical task through TDD. It consumes the task's Test Specification, takes the AAA cases one at a time — Unit before Integration — and stops at green. A test that starts red goes red→green; a test born green (the behaviour already exists) is proved by mutation: one fault injected into the site it targets must force it red, then the fault is reverted.

It does not reshape the diff. That is [`/al-refactor`](al-refactor.md), and it is not chained from here.

## When you reach for it

- A technical task is refined — its Test Specification filled — and the router names it for implementation.
- An `/al-code-review` must-fix needs a red-first repair.

The repair re-enters a task whose behaviour is already proved, lands its commits under the owning `AB#<id>`, and moves no work-item state.

## What it produces

Production and test AL, committed at green, with the work item's Description reconciled against what actually landed — every AAA case header carrying its real AL test procedure name, `New and Modified Objects` matching the diff.

The green is handed to `/al-routing`, which records the transition and the clean-gate receipt. `/al-refactor`'s clean pass is what settles the task.

## Worth knowing

The skill decides Unit versus Integration by what the AL Runner can actually prove. Your own tables, fields, and triggers run for real in memory, so record behaviour is unit-provable; anything inside an `.app` dependency auto-stubs, so a case whose truth rides on what a stubbed BaseApp object really returns gets reclassified as Integration rather than wrapped in a one-off interface built only to stub it.

It applies small decisions and keeps going — an object ID, a caption, a permission entry, a local rename — logging each as a `Deviations:` line. It stops and blocks on a genuinely new decision: a new table, a new event publisher, a new seam, a public-surface rename.
