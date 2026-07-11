---
name: al-implement
description: Pick a `ready-for-implementation` technical task from the `tasks/` folder and drive it red→green through TDD for AL/Business Central. Use after `/al-refine`, one task per session, Unit AAA cases first, then Integration AAA cases. Stops at green and hands off to `/al-refactor` then `/al-mutate`.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-implement, Pick a task, drive it red→green

Pick the next `ready-for-implementation` technical task from the `tasks/` folder. Consume its fresh `Test Specification`. Drive AAA cases red → green: `Unit` first, `Integration` second. Reconcile final procedure names and scopes in the task file. Stamp `phase: implemented` when the full suite is green and the spec reconciled — `status:` stays `ready-for-implementation`; `/al-mutate` flips it `done` on a clean verdict. **Stop at green** — reshape (`/al-refactor`) and rigor (`/al-mutate`) are the next steps the user invokes, not work this skill runs. One task per session.

This skill calls only `/al-research` (evidence-bar escalation) and `/al-build` (compile/test), and consults the rubber-duck agent for an independent cross-family read on non-trivial work ([rubber-duck-review.md](../../references/rubber-duck-review.md)). It invokes the `al-red-green` custom agent per AAA case but invokes no other skill — it hands off by naming the next step, never by chaining.

**Layer.** Red-first at the Unit + Integration layers (see [`test-strategy.md`](../../references/test-strategy.md)). A production bug a higher layer surfaces is pushed down to this layer so the proof lives where an oracle sees it.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, `Next: /al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/` holds the `tasks/` folder + `architecture.md`. Missing → **Stop**, `Next: /al-design`.
- Target task `kind: technical`. `kind: verify` → **Stop**; `Next: /al-steer` or `/al-code-review` based on verification state. `kind: provision` → `Next: /al-provision`; `kind: breaking-change` → `Next: /al-validate-breaking-changes` (ops tasks, run-and-flip, never reach `ready-for-implementation`).
- Target task `status: ready-for-implementation` with populated `Test Specification`. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. `ready-for-implementation` with empty or missing `Test Specification` → **Stop**, `Next: /al-steer`; status and proof disagree. `blocked` → **Stop**, `Next: /al-steer`. `phase: implemented` or later → already green and reconciled; do not re-drive the cases **unless** re-entered for a named follow-up on that same task: an `/al-mutate` reached-real-gap survivor (write the killer test) or an `/al-code-review` finding routed here as `T-NNN`. Work either red-first under the originating task, reconciling `Contract notes` on green; a survivor killer-test round that closes the last gap may flip `status: done` (clean verdict now proved). `status: done` → finished, nothing further intended; the same two named follow-ups (a survivor killer test, an `/al-code-review` finding routed as `T-NNN`) still re-enter — the fix lands red-first under the originating task and commits under its `T-NNN` prefix, `status:` stays `done` (the finding is repair, not reopened scope). Any other reason to touch a `done` task → **Stop**, `Next: /al-steer`.
- Before code, read [`test-specification.md`](../../references/test-specification.md) and [`voice-contract.md`](../../references/voice-contract.md). Production names and signatures arrive minted in the task's `New and Modified Objects`; the `al-red-green` agent reads its own implementation references on each invocation.

## What this session answers

- **Seam.** Read `architecture.md` R → P → W boundary, module map, brownfield touchpoints. Name seam in BC vocab: procedure to extract, event to subscribe, interface to implement, or page/action to wire.
- **AL surface.** Build against the task's `New and Modified Objects` signatures — production surface only; test codeunits and procedures are minted by the per-case subagent. In-object drift (procedure rename, parameter change, visibility flip, helper procedure, field addition on a named object): absorb, reconcile the section to actuals before the phase stamp, note in `Contract notes`.
- **AAA order.** `Unit` cases first, then `Integration`, in coverage-ID order. One case red → green before the next.
- **End.** `phase:` → `implemented` at full green + reconcile; `status:` stays `ready-for-implementation`. Then hand off: `/al-refactor` (reshape) for non-trivial work, `/al-mutate` (rigor) — its clean verdict flips the task `done`; then the slice gate.

Unanswerable → task not ready. Resolve via `/al-research`, `/al-refine`, or `/al-steer`.

## Workflow

### One AAA case at a time

RED → GREEN → gate, one case, then next. Bulk-RED locks test surface before the seam is understood and verifies imagined behaviour. No `in-progress` status; the task stays `ready-for-implementation` through the whole hardening window (implement → refactor → mutate) — `phase:` tracks progress, and `/al-mutate` stamps `status: done` on a clean verdict.

Default order:

1. `Unit` cases red/green, one per spawned subagent.
2. `Integration` cases red/green, one per invocation.
3. Full gate.

For each case, **invoke the `al-red-green` custom agent** (fixed Terra worker role — no in-loop escalation; a case that can't reach green after retry falls back to you doing it inline or a `general-purpose` spawn), passing: the single AAA case (Arrange/Act/Assert text from the `Test Specification`), the task's `New and Modified Objects` block, and the task file path. Read the agent's outcome note before proceeding — and before relaying anything from it, run pre-send check 3 ([voice-contract.md](../../references/voice-contract.md) Relaying subagent findings): a note naming no object or observation goes back to the agent; relay through the Gate/Stop shape, never raw. Then route on the verdict:

- `GREEN` → run the full suite gate (a red anywhere, including a sibling task's test, blocks the `phase: implemented` stamp), then proceed to the next case.
- `PUSH-UP` → handle the push-up commitment gate (see below).
- New decision flagged / `BLOCKED` → `Next: /al-steer`.

**Survive compaction.** A multi-case task outlives the context window: track per-case progress in the session todo list (one todo per AAA case, status flipped as each lands) — todos and plans survive context compaction; this skill's injected body and the per-case chatter do not. After a compaction, re-read this skill and the task file, then resume from the todo state.

Exception: when a Unit seam should exist but current code is tangled, instruct the spawn to write an Integration characterization test first, then spawn again to extract the Unit seam and add the Unit case. Reconcile scope changes in the task file.

### Gate every push-up above the blessed scope

Writing a test above the scope `/al-refine` blessed is a **push-up** that needs commitment, not a silent reclassify (see [`test-strategy.md`](../../references/test-strategy.md)). The push-up signal arrives in the subagent's outcome note: either a planned `Unit` case hit an AL-Runner wall or a *new* `Integration` case emerged mid-TDD (trigger #5). Before the non-`Unit` test is written, **stop** — emit the commitment as a Stop ([`voice-contract.md`](../../references/voice-contract.md)): the case, why `Unit` cannot hold it, and the seam from [`testability.md`](../../references/testability.md) that would push it down versus accepting `Integration`. Commitment is build-the-seam (push down) or accept-the-slower-test; on accept, record the justification in `Contract notes` and spawn the case again as `Integration`.

This is the pipeline's one hard gate, elevated above the act-inline floor because a silent slow test is a durable cost, not reversible. **Unattended**, where no human answers, the stop degrades by context so the push-up never lands silently — an unblessed push-up is replan-class when no one can commit: flip `status: blocked` and `Next: /al-steer`. A push-up already blessed by `/al-refine`'s report flows without a stop; the gate fires only on deviation above plan.

### Reconcile task spec before the phase stamp

Before stamping `phase: implemented`, update the task file so it reflects actual proof:

- `Procedure:` and AAA headers match actual AL test procedure names; `Covered By` names them only.
- `Covers:` references real `B#` / `R#`.
- `Scope:` is final; any scope change is edited back in.
- `New and Modified Objects` matches the actual diff: objects, fields, signatures, visibility, R → P → W letters.
- Implementation discoveries land in `Contract notes` as new bullets, one fact per landing line.
- `Researched:` citations and in-object drift from each subagent outcome note land as `Contract notes` bullets (the evidence-bar trace, [voice-contract.md](../../references/voice-contract.md)) — skipped research stays visible to `/al-code-review`.
- Closeout follows the [test-specification.md](../../references/test-specification.md) shape: pyramid bullets. The mutation verdict table lands later, when `/al-mutate` runs.

### AppSource compliance bites at implementation time

New objects get IDs via available allocator. Shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over a deprecation window).

### Replan halts planning, not code

Eight triggers run as a gate before the `phase: implemented` stamp. The tier test is what the unknown touches: local and reversible (naming, internal structure, test shape) → absorb; it contradicts a settled artifact (`architecture.md`, `event-model.md`, this task's `Test Specification` contract, an ADR) → the map itself is wrong, stop. Trigger invalidates plan → flip `status: blocked` and write the one-line `blocked-on:` headline in the same Edit, `Next: /al-steer`. Trigger is new info the plan absorbs → append a one-line entry to the task's `deviations:` frontmatter (what was assumed, what it touches) and continue; agent-depth goes to the body, but the assumption itself is never buried there — `/al-steer` reads `deviations:` off frontmatter, so absorbed unknowns stay visible to the developer instead of surfacing only at the gate. Record trigger ID + one-line reason; the check is silent unless a trigger fires. On a `blocked` flip especially, state the block in this reply's own chat output, not just the frontmatter — the developer must not have to invoke `/al-steer` to learn the run stopped. A trigger read off a tool diagnosis (compile-error class, runner gap) is re-confirmed once before the `blocked` flip; one read off a recorded fact (`depends_on:`, Goal text) is acted on as-is.

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | Implementation needs table, codeunit, or permission with no covering task, or a production object absent from the task's `New and Modified Objects` |
| 3 | Wrong order | Task can't land without later task's seam in place |
| 4 | Sibling now wrong | This task's code invalidates another task's context, `Test Specification`, or `Verification Plan` |
| 5 | New behaviour emerges | Code path needs its own test, not an appended assertion |
| 6 | Architecture decomposition wrong | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | What's landing no longer matches feature Goal |
| 8 | Verification failed | User-facing verify example does not match observed behaviour; surfaced from verify task |

A change that only applies a decision already made absorbs inline: missing scaffolding, permission set entry, object ID, caption, local BC-vocab rename, or reusing a seam pattern a sibling task established — apply, log it as a `deviations:` line when it rests on an assumption the user never blessed, rerun `/al-build`, continue. A new decision routes through `/al-steer`: schema changes, new event publishers, new codeunits, a genuinely new seam, test-outcome changes, or a production object the assertions require (trigger #2). A public-surface rename is not trivia — it is an AppSource decision, route it.

Before stamping the phase, do a final correctness read of the implementation against the reconciled task spec — production logic, AAA coverage, the `New and Modified Objects` surface. For non-trivial work, consult the rubber-duck agent for an independent cross-family read before the durable stamp ([rubber-duck-review.md](../../references/rubber-duck-review.md)).

Stamp surface: locate the task file by its `T-MMM` filename (e.g. `tasks/070-T-007-derive-audit-reason.md`) and edit anchored on its `phase:` frontmatter line (add the line after `status:` if absent, overwrite if present). `status:` does **not** change — it stays `ready-for-implementation` through refactor and mutate:

```markdown
old_string:
  status: ready-for-implementation
  phase: refined
new_string:
  status: ready-for-implementation
  phase: implemented
```

One Edit call — each string spans the two adjacent frontmatter lines (indentation marks string membership; the file has none).

**Re-entry on a `done` task** (a code-review must-fix or a survivor killer test, per Preconditions): no stamp at all — `status:` and `phase:` stay untouched; the repair is not a pipeline step, its record is the `T-NNN`-prefixed commit and the re-review. Exception: a survivor killer-test round that closes the last open gap on a still-`ready-for-implementation` task flips `status: done` (clean verdict now proved).

Everything else inside the task body follows the task shape. See [notes-discipline.md](../../references/notes-discipline.md), [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md), [voice-contract.md](../../references/voice-contract.md).

### Done is a separate, deliberate flip

`status: done` means finished — nothing further intended, for any task kind. The normal path: `/al-refactor` reshapes (phase → `refactored`), `/al-mutate` proves rigor and stamps `status: done` + `phase: mutated` on a clean verdict. The developer can instead end the hardening early ("mark it done", the board's *Mark done* button): whichever skill is active flips `status: done` at the current phase — the remaining steps are deliberately waived, and `phase:` stays the honest record of what ran.

Whoever stamps `done` also opens dependents: any **same-slice technical** task whose `depends_on:` is now fully `done` and carries no replan flag flips `blocked` → `ready`; name each opened `T-NNN`. A task `blocked` on an unsatisfied edge or a replan flag stays `blocked` — that needs a decision, `/al-steer`'s. The slice verify task is the exception — never opened here: at user/API-facing slice-done (all slice technical tasks `done`) the review gate runs first, and a clean `/al-code-review` is what opens the verify task.

If this skill exits at green without a done flip (the normal case), commit the work before handing off so the tree is clean for the user's `/al-refactor` / `/al-mutate`.

### Gate report at green

The `phase: implemented` stamp is a gate event: emit the four-row Gate report (Did / Was / Fits / Next) rendered box-first per [voice-contract.md](../../references/voice-contract.md), and run its pre-send checks on the draft. Mechanics — procedure names, RED/GREEN beats, build counts, commit hashes — live in commits and the task file; the user pulls detail by asking.

## Next step

End by naming the concrete next move, read off current state:

- **Mid-task non-green exits** carry their own `Next:` above (push-up unattended → `/al-steer`, missing spec → `/al-refine`, replan → `/al-steer`).
- **Green, work was non-trivial:** `Next: /al-refactor` (reshape the full task diff while green), then `/al-mutate` — the mutation verdict is what flips the task `done`. A fully red-driven task leaves a near-empty mutation plan; say that, and note the developer can mark the task done early if the remaining hardening isn't warranted.
- **Green, trivial work:** `Next: /al-mutate` (or mark done directly if even that is waived) — the task needs its `done` flip before the slice gate counts it. Slice-done (all slice technical tasks `done`) → `Next: /al-code-review` per-slice, both slice types — the review gate runs before the verify task is opened. Feature-done → `Next: /al-code-review` per-feature.

If state can't be read, fall back to the typical next step: `/al-refactor` then `/al-mutate`, then `/al-code-review`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refine` (filled `Test Specification` in the task file and flipped task to `ready-for-implementation`) |
| **Hands off to**   | `/al-refactor` on non-trivial green, then `/al-mutate` (its clean verdict flips the task `done`); next `ready-for-implementation` technical task; `/al-code-review` per-slice at slice-done (both slice types); `/al-code-review` per-feature at feature-done |
| **Calls directly** | `/al-research` (evidence-bar escalation), `/al-build` (compile/test) — the only skills it invokes; rubber-duck consult on non-trivial work per [rubber-duck-review.md](../../references/rubber-duck-review.md) |
| **Spawns**         | `al-red-green` custom agent (RED→GREEN per AAA case) |
| **Replan venue**   | `/al-steer` |
