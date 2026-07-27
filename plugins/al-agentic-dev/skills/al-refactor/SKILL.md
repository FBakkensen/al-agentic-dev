---
name: al-refactor
description: Reshape AL/Business Central production and test code while tests stay green, via five parallel lens subagents then serial apply with `/al-build` between. Use after `/al-implement` takes a task to green (full task diff, once per task) or standalone on legacy code.
---

# /al-refactor — improve shape while green

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Reshape AL so modules that earn their keep deepen and the ones that don't dissolve. Observable behaviour does not change.

## Preconditions

- The build is green. Refactoring against a red build is debugging → it belongs in `/al-implement`.
- Run after `/al-implement` takes the current task to green (the user's next step at `phase: implemented`), or standalone on legacy code.
- The branch matches `^\d{3}-` with `specs/<branch>/tasks/`, or the run is a pure legacy reshape with no owning task. Owning task `blocked` → run `/al-steer`.
- Legacy-code mode (no covering tests) writes baseline tests first: [legacy-refactor-plan.md](references/legacy-refactor-plan.md).

## What you answer before reshape

**Unanswerable from the diff → the area is not ready to reshape.** Invoke `al-researcher` for a BC fact; route a domain rule through `/al-grill-adr` and an architectural gap through `/al-steer`.

- **What seam is being introduced, hardened, or dissolved?** Name the mechanism (publisher event, AL `interface`, `Implementation` enum, internal helper) and the adapters that justify it.
- **Where does decision logic split from the reads and writes around it in this area?** The full split is homed under **Functional core, imperative shell** in [LANGUAGE.md](../../references/LANGUAGE.md).
- **What crosses a published API?** That constrains rename, removal, and signature change.
- **Does the reshape surface new behaviour or a hidden requirement?** Yes → route the discovery; the run never absorbs it.

Architectural vocabulary (Module, Interface, Implementation, Seam, Adapter, Depth, Leverage, Locality) lives in [LANGUAGE.md](../../references/LANGUAGE.md). Use it exactly.

## Lenses

Invoke the 5 lens agents in parallel on the task diff — `al-review-simplify`, `al-review-bc`, `al-review-structural`, `al-review-compliance`, `al-review-perf` — declaring `Mode: refactor` and the scope per [review-lenses.md](../../references/review-lenses.md). Each agent body carries its own detection rules, read-only posture, and findings shape; the invocation carries the task diff, plus the changed `.al` files for the perf lens. A lens returning the invocation-error line is a failed lens: name it in the Gate report, never read it as clean.

| # | Lens | Focused goal |
|---|---|---|
| 1 | `al-review-simplify` | Duplication, dead code, redundant procedures, inline candidates, speculative generality |
| 2 | `al-review-bc` | BC anti-patterns and platform reinvention confirmed through `al-researcher` evidence |
| 3 | `al-review-structural` | The decision-logic/IO split, depth over indirection, seam shape |
| 4 | `al-review-compliance` | BC vocabulary and project terminology per `CONTEXT.md`, ADRs, `architecture.md`, `event-model.md`; ADR and module-boundary compliance; over-build; the reshape delta against the task's `New and Modified Objects` |
| 5 | `al-review-perf` | Structural performance reshapes via the al-performance scanner, gated at touched-procedure granularity |

When the diff touches test code, the invocation also names [test-layout.md](../../references/testing/test-layout.md): its authoring contract is exactly what tidy passes break silently. Moving a test across the unit/integration boundary is replan, never a lens call — route `/al-steer`.

## Judge

Invoke the `al-review-judge` custom agent once, passing `Mode: refactor`, the task diff, and all 5 lenses' raw findings blocks — never their `Out-of-scope:` notes. It dedupes the overlap, substantiates each survivor against the diff — defaulting to false-positive when it can't — and classifies. `MUST-FIX` and `SHOULD-FIX` survivors are real reshape opportunities, ranked by the consequence of leaving the diff as it is. `NO-ACTION` survivors are dropped.

The judge never chooses apply order, sequences edits, or touches build/workflow state. This skill owns the queue and checks each survivor before it reaches the user. A finding naming no object or observation goes back to its lens.

**`al-review-judge` unavailable** → report `BLOCKED`, name `al-review-judge` as the missing agent, and stop. No inline substitution.

## Disposition and queue

Disposition every `MUST-FIX` and `SHOULD-FIX` survivor by the baseline test under **A finding on code** in [review-lenses.md](../../references/review-lenses.md): `rework` lands in one apply queue, a `change request` is held for the grilling close, `NO-ACTION` drops.

- Renames and seam introduction land before dedup — they touch many call sites and conflict otherwise.

## Apply

**One reshape at a time; delegate the gate through `/al-build` after each.** Red → revert that step; recover before the next.

### Extraction

Rule of Three is the brake: extract a helper on the third occurrence, not the second — a one-caller wrapper is exactly what the deletion test ([LANGUAGE.md](../../references/LANGUAGE.md)) then kills. Until then, leave the duplication and note it. Logic with a rightful home — a BaseApp / System Application helper, an existing module's internal helper — routes there and the canonical one is reused; code already in the wrong module is not a licence to add more there.

### Tests move with production

Production and tests refactor together. New tests for branches the reshape uncovers must pass against *current* code first — the regression signal stays honest. Unit tests on modules the refactor merges away get deleted, not layered.

### Seams

Seam work is homed in [testability.md](../../references/testing/testability.md). **Earned seams** decides whether any seam is justified at all, naming the prop-seam and temp-record over-applications. **Three-phase decoupling** lands a justified seam: each phase compiles on its own and existing callers never change. Name one of the **Three default seams** before extracting a fresh one.

### Renames

- A test-procedure rename requires task-spec reconciliation — update the AAA case header and `Covered By` in the same change when the task is active. An intent shift routes through `/al-refine`.
- `[HandlerFunctions('...')]` strings are invisible to symbol tools; grep before any test-procedure rename per [tdd.md](../../references/testing/tdd.md).
- A rename pulling a BC name or verb from outside the codebase is grounded per [GROUND-RULES.md](../../references/GROUND-RULES.md) before it lands; conflicts invoke `al-researcher` with `Use: resolve conflict`.

### Performance findings

Every perf survivor joins the queue as a manual reshape. The scanner marks nothing auto-fixable, and its fixer rewrites a whole file with no way to aim it at one occurrence — so it would reach patterns outside this task's diff. Reshape by hand, then delegate the gate through `/al-build`, as for every other queue entry; red reverts that file.

Server absent → the perf lens returns exactly `perf scan skipped: al-performance MCP not available` and nothing else. That is degraded coverage, never a clean lens: name it in the Gate report and reshape on the other four lenses.

## Out-of-scope routing

Non-structural concerns the lenses surface as `Out-of-scope:` notes — AppSource compliance, publisher/subscriber contracts beyond structural reshape, the direct-`xRec` validation trap, and pure one-line perf fixes — belong to `/al-code-review`: record them in the calling task file, never act on them here. Correcting the `xRec` trap changes when a cascade runs, so it is never a reshape.

A `New and Modified Objects` delta the compliance lens raises is the exception that lands here: reconcile the section under the surgical-edit contract in [task-lifecycle.md](../../references/task-lifecycle.md) when the reshape genuinely moved the production surface, or route `/al-steer` when the delta means the task's scope changed.

## AppSource compatibility

**Never rename a shipped object, table field, page action, or procedure other extensions may bind to.** Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside. No BaseApp modification. Internal-only symbols rename freely.

## Replan and behaviour preservation

Reshape surfacing an architectural gap that blocks the reshape itself stops the run — code stays green; the halt is on planning → **Stop**, route `/al-steer`. Every other escalation takes the baseline test: a finding whose resolution would contradict baselined content, or establish content no baseline yet contains, is a change request held for the grilling close per **A finding on code** in [review-lenses.md](../../references/review-lenses.md).

The diff leaves observable behaviour identical. New behaviour belongs to `/al-implement` (new task) or `/al-refine` (re-plan).

## Gate report and phase stamp

Before stamping, grill the change-request residue in the live session per **A finding on code**: one conversation at a time in the judge's `Rank:` order, clustered by contested baseline decision, each converging on one of the three terminal outcomes. A do-it-now ruling joins the apply queue on the same one-reshape-at-a-time terms. A written task lands in `specs/<branch>/tasks/` and holds the stamp until it is `done`. A keep-the-code ruling clears here and routes the baseline update as `Next: /al-steer` citing trigger #6.

**Emit one Gate report at module / pattern / seam altitude (not procedure level), naming the application invariant preserved and the next step.**

On a task-scoped run (invoked on a task's diff after `/al-implement`), stamp `phase: refactored` on that task's frontmatter when the reshape lands green, overwriting `phase: implemented`. Skip the stamp on standalone legacy runs with no owning task. `status:` stays `ready-for-implementation` — `/al-mutate` flips it `done` on a clean verdict, or the developer marks it done early. `/al-refactor` does not edit `architecture.md` and writes no Notes by default. Beyond the phase stamp, a task file under `tasks/` is touched only when an operational outcome demands it, per the surgical-edit contract in [task-lifecycle.md](../../references/task-lifecycle.md).

## Next step

- **Reshape complete, inside the slice cycle:** `Next: /al-mutate` — validate the tests catch the decision logic the reshape just moved through.
- **Standalone legacy reshape, no owning task:** `Next: /al-mutate` if the area carries decision logic worth pinning; otherwise the Gate report is the final output — no further step. Surface any architectural gap as `Next: /al-design` or `/al-steer`.
- **Stopped on an architectural gap / new behaviour:** `Next: /al-steer`.

If state can't be read, fall back: `/al-mutate` after a behaviour-bearing reshape, `/al-steer` if anything bigger than tidy-up surfaced.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` took the current task to green, OR standalone on legacy code |
| **Hands off to**   | `/al-mutate` (the next rigor step); standalone with no mutation or architecture step warranted, the Gate report ends the run |
| **Calls directly** | `/al-build` (green between applies) — the only skill it invokes |
| **Spawns**         | `al-researcher` for BC facts; the `refactor` mode's five lenses per [review-lenses.md](../../references/review-lenses.md) — `al-review-simplify`, `al-review-bc`, `al-review-structural`, `al-review-compliance`, `al-review-perf`; `al-review-judge` after the lens pass |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-code-review` (non-structural concerns surface as out-of-scope notes), `/al-design` (standalone-on-legacy surfacing real architecture), `/grill-me` (non-obvious trade-off needs the user) |
