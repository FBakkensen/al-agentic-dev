---
name: al-implement
description: Pick a `ready-for-implementation` technical task from the `tasks/` folder and drive it red→green through TDD for AL/Business Central. Use after `/al-refine`, one task per session, Unit AAA cases first, then Integration AAA cases. Stops at green and hands off to `/al-refactor` then `/al-mutate`.
---

# /al-implement — pick a task, drive it red→green

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

One `ready-for-implementation` technical task from the `tasks/` folder goes red→green. Consume its fresh `Test Specification`, drive AAA cases one at a time — `Unit` first, then `Integration`, in coverage-ID order — reconcile the task file to actuals, and stamp `phase: implemented` at full green. `status:` stays `ready-for-implementation` through the hardening window; `/al-mutate`'s clean verdict flips it `done` ([task-lifecycle.md](../../references/task-lifecycle.md)). Stop at green: `/al-refactor` (reshape) and `/al-mutate` (rigor) are the user's next invocations, never chained from here. One task per session.

The Composition table at the end carries this skill's full call boundary: `/al-build` is the only skill it calls directly; BC facts go through the `al-researcher` custom agent. Everything else hands off by naming the next step.

Red-first lives at the Unit and Integration layers ([test-strategy.md](../../references/testing/test-strategy.md)); a production bug a higher layer surfaces is pushed down here so the proof lands where an oracle sees it.

## Preconditions

Any disagreement between the branch, feature artifacts, task kind, status, and `Test Specification` stops work before code.

- Branch matches `^\d{3}-`. If not: **Stop**, `Next: /al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/` holds the `tasks/` folder and `architecture.md`. Missing → **Stop**, `Next: /al-design`.
- Target task `kind: technical`. `kind: verify` → **Stop**, `Next: /al-steer` or `/al-code-review` by verification state. `kind: provision` → `Next: /al-provision`; `kind: breaking-change` → `Next: /al-validate-breaking-changes`.
- Target task `status: ready-for-implementation` with a populated `Test Specification`. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. Empty or missing `Test Specification` → **Stop**, `Next: /al-steer` — status and proof disagree. `blocked` → **Stop**, `Next: /al-steer`.
- `phase: implemented` or later is already green and reconciled — never re-drive its cases.
- Exactly two named follow-ups re-enter such a task, including at `status: done`: an `/al-mutate` survivor's killer test, and an `/al-code-review` must-fix finding routed as `T-NNN`. Either lands red-first under the originating task and commits under its `T-NNN` prefix. Stamp mechanics follow the repair exception in [task-lifecycle.md](../../references/task-lifecycle.md).
- One flip only: a survivor killer-test round that closes the last open gap on a still-`ready-for-implementation` task flips `status: done` — the clean verdict is now proved.
- Any other reason to touch a `done` task → **Stop**, `Next: /al-steer`.
- Read [task-grammar.md](../../references/task-grammar.md) before code. Production names and signatures arrive minted in the task's `New and Modified Objects`. Test codeunits and procedures are the per-case subagent's to mint. `al-red-green` reads its own implementation references on each invocation.

## Name the seam

Read `architecture.md` — the module map, decision logic and test surfaces, brownfield touchpoints — and name the seam in BC vocabulary: procedure to extract, event to subscribe, interface to implement, or page/action to wire. A BC fact beyond direct workspace reading invokes `al-researcher`; a stale specification routes through `/al-refine`, and a design gap through `/al-steer`.

## One AAA case at a time

One case runs RED → GREEN before the next begins. There is no `in-progress` status; the task holds `ready-for-implementation` while `phase:` tracks progress.

For each case, spawn the `al-red-green` custom agent. Pass it the single AAA case (Arrange/Act/Assert text from the `Test Specification`), the task's `New and Modified Objects` block, and the task file path.

Its red is graded by a fresh blind `al-review-red` before any of the case's behaviour exists, and its test surface is hash-frozen from that reviewed red to green ([tdd.md](../../references/testing/tdd.md)). Both halves report through the outcome note; neither is this skill's to run.

- No in-loop escalation and no inline or `general-purpose` fallback. A case that can't reach green after retry surfaces as `BLOCKED` and routes on the verdict below.
- `al-red-green` or `al-review-red` unavailable → report `BLOCKED`, name the missing agent, and stop.
- Read the outcome note before proceeding. A note naming no object or observation goes back to the agent. Relay it through the Gate/Stop shapes, never raw.

Route on the line-1 verdict:

- `GREEN` → the next case. The full gate lands once at task close, never per case ([tdd.md](../../references/testing/tdd.md), Task execution order); a red there, including a sibling task's test, blocks the `phase: implemented` stamp.
- `PUSH-UP` → the commitment gate below.
- `BLOCKED` naming a research question → invoke `al-researcher` with that exact `Question:`, `Use: routine`, and the case in `Context:`, then resume with its result. `UNRESOLVED` routes to `/al-steer`.
- `BLOCKED` on two `FALSE-RED` rounds, or on the frozen test surface → the reason picks the venue. A wrong expected value in the AAA case is a `Test Specification` contract change → `Next: /al-refine T-NNN`, then respawn the case from scaffold. Anything else — behaviour written ahead of its red, a changed production contract, a case the reviewers read differently — → `Next: /al-steer`. Never re-spawn the case against the same unreconciled contract.
- New decision flagged, or any other `BLOCKED` → `Next: /al-steer`.

A multi-case task outlives the context window. Track per-case progress in the session todo list, one todo per AAA case — todos survive compaction; this skill's injected body and per-case chatter do not. After a compaction, re-read this skill and the task file, then resume from the todo state.

**Characterization test.** When a Unit seam should exist but current code is tangled, instruct the spawn to write an Integration characterization test first, then spawn again to extract the Unit seam and add the Unit case. Say `characterization case` in that first invocation — it anchors behaviour that already exists, so it has no red beat to grade, and only this declaration unfires the blind RED gate. The spawn never classifies a case that way itself. Reconcile scope changes in the task file.

## Gate every push-up above the blessed scope

Push-up definition, justification content, the stage table, and the report shape are homed in [test-strategy.md](../../references/testing/test-strategy.md). This skill gates.

The signal arrives in the subagent's outcome note: a planned `Unit` case hit an AL-Runner wall, or a new `Integration` case emerged mid-TDD.

Before the test is written, **stop** — emit that push-up's report line as a Stop ([GROUND-RULES.md](../../references/GROUND-RULES.md)): the case, why `Unit` cannot hold it, and the seam from [testability.md](../../references/testing/testability.md) that would push it down. Commitment is build-the-seam or accept-`Integration`.

On accept, record the justification in `Contract notes` and respawn the case as `Integration`.

A push-up already blessed by `/al-refine`'s report flows without a stop. Unattended, with no one to commit, follow the stage table's row: flip `status: blocked`, `Next: /al-steer`.

## Reconcile the task file before the stamp

The `phase: implemented` stamp certifies the task file matches actual proof — before stamping, edit it to actuals:

- AAA case headers match actual AL test procedure names; `Covered By` names them only.
- `Covers:` references real `B#` / `R#`.
- `Scope:` is final; any scope change is edited back in.
- `New and Modified Objects` matches the actual diff: objects, fields, signatures, visibility, placement in the module map.
- Implementation discoveries land in `Contract notes` as new bullets, one fact per line. `Researched:` citations and the absorbed changes each subagent outcome note reports land there too ([GROUND-RULES.md](../../references/GROUND-RULES.md)) — skipped research stays visible to `/al-code-review`.
- Closeout follows the [task-grammar.md](../../references/task-grammar.md) shape; the mutation verdict table lands later, when `/al-mutate` runs.

Then verify the reconciled file against the `tasks/` profile in [doc-integrity.md](../../references/doc-integrity.md), scoped to this task. A **fail** blocks the stamp — fix it, or route `/al-steer` when the fix is a contract change.

## AppSource compliance bites at implementation time

A shipped surface is a one-way door — other extensions may already bind to it. New objects get IDs via the available allocator. Shipped fields never rename in place: `ObsoleteState: Pending` → `Removed` over a deprecation window.

## Replan halts planning, not code

The replan triggers, their patterns, and the absorb-vs-blocked routing are homed in [task-lifecycle.md](../../references/task-lifecycle.md). The gate runs silently before the `phase: implemented` stamp and speaks only when a trigger fires, recording trigger ID plus a one-line reason. The cues in this skill's work: the task balloons past one TDD cycle (#1); the assertions require a production object `New and Modified Objects` never named, or a needed table, codeunit, or permission has no covering task (#2); the task can't land without a later task's seam (#3); this task's code invalidates a sibling's context or spec (#4); a code path needs its own test, not an appended assertion (#5); shotgun surgery across the task boundary, or `architecture.md` no longer describes the workspace (#6); what's landing no longer matches the feature Goal (#7).

The tier test is what the unknown touches.

- Local and reversible (naming, internal structure, test shape) → absorb: append the one-line `deviations:` entry per the frontmatter contract in [task-lifecycle.md](../../references/task-lifecycle.md) and continue. `/al-steer` reads absorbed unknowns off frontmatter, so they stay visible instead of surfacing only at the gate.
- Contradicting a settled artifact (`architecture.md`, `event-model.md`, this task's `Test Specification` contract, an ADR) → the map itself is wrong. Flip `status: blocked` with its `blocked-on:` headline per [task-lifecycle.md](../../references/task-lifecycle.md), `Next: /al-steer`. State the block in this reply's own chat output, so the developer never needs `/al-steer` to learn the run stopped.
- A trigger read off a tool diagnosis is re-confirmed once before the `blocked` flip; one read off a recorded fact is acted on as-is ([task-lifecycle.md](../../references/task-lifecycle.md)).

A change that only applies a decision already made absorbs inline: missing scaffolding, a permission-set entry, an object ID, a caption, a local BC-vocab rename, a field addition on an object `New and Modified Objects` already names, or reusing a seam a sibling task established — apply, log a `deviations:` line when it rests on an assumption the user never blessed, delegate the gate through `/al-build`, then continue. A new decision routes through `/al-steer`: a new table or a field on an object the task never named, new event publishers, new codeunits, a genuinely new seam, test-outcome changes, or a production object the assertions require (trigger #2). A public-surface rename is an AppSource decision, not trivia — route it.

## Stamp at green

The task-close full gate runs after the last case and before the stamp — `/al-refactor` gates its own reshape later. Diagnose a red there before repairing it: a container or publish failure routes through `/al-build`'s recovery table; a test green under AL Runner and red under the container is a placement or runner-semantics mismatch ([test-layout.md](../../references/testing/test-layout.md)), not a production defect; a production regression is an ordinary red — repair the production code and re-gate. When the honest repair is editing that test's expected value, that is a `Test Specification` contract change — **Stop**, `Next: /al-refine T-NNN`.

For non-trivial work, consult the rubber-duck agent before the durable stamp ([rubber-duck-review.md](../../references/rubber-duck-review.md)).

The stamp edits the `phase:` frontmatter line alone per the Surgical-edit discipline in [task-lifecycle.md](../../references/task-lifecycle.md) — add the line after `status:` if absent, overwrite if present. `status:` does not change. A re-entry repair on a `done` task stamps nothing, per the repair exception — its record is the `T-NNN`-prefixed commit and the re-review; the sole exception is the survivor killer-test flip named in Preconditions.

Commit the work at green before handing off, so the tree is clean for `/al-refactor` and `/al-mutate`. When a `done` flip does happen here (the developer ends the hardening early), open the dependents it unblocks per [task-lifecycle.md](../../references/task-lifecycle.md).

The stamp is a gate event: emit the four-row task-close gate report (Did / Was / Fits / Next) per [GROUND-RULES.md](../../references/GROUND-RULES.md). Mechanics — procedure names, RED/GREEN beats, build counts, commit hashes — live in commits and the task file; the user pulls detail by asking.

## Next step

Current task state chooses the handoff; a known exit outranks the fallback pipeline.

- Mid-task non-green exits carry their own `Next:` above (push-up unattended → `/al-steer`, missing spec → `/al-refine`, replan → `/al-steer`).
- Green, non-trivial work → `Next: /al-refactor` (reshape the full task diff while green), then `/al-mutate` — the mutation verdict flips the task `done`. A fully red-driven task leaves a near-empty mutation plan; say that, and note the developer can mark the task done early if the remaining hardening isn't warranted.
- Green, trivial work → `Next: /al-mutate` (or mark done directly if even that is waived) — the task needs its `done` flip before the slice gate counts it.
- Slice-done (all slice technical tasks `done`) → `Next: /al-code-review` per-slice, both slice types — the review gate runs before the verify task opens. Feature-done → `Next: /al-code-review` per-feature.
- State unreadable → the typical path: `/al-refactor`, then `/al-mutate`, then `/al-code-review`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refine` (filled `Test Specification` in the task file and flipped task to `ready-for-implementation`) |
| **Hands off to**   | `/al-refactor` on non-trivial green, then `/al-mutate` (its clean verdict flips the task `done`); next `ready-for-implementation` technical task; `/al-code-review` per-slice at slice-done (both slice types); `/al-code-review` per-feature at feature-done |
| **Calls directly** | `/al-build` (compile/test) — the only skill it invokes; rubber-duck consult on non-trivial work per [rubber-duck-review.md](../../references/rubber-duck-review.md) |
| **Spawns**         | `al-researcher` for BC facts; `al-red-green` custom agent (RED→GREEN per AAA case), which nests `al-review-red` to grade its own red |
| **Replan venue**   | `/al-steer` |
