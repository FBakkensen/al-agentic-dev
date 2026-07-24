---
name: al-design
description: Settle the AL/Business Central feature architecture from idea or `event-model.md`. Use after `/al-event-model` for user/API-facing features, after `/al-grill-adr` for backend-only features, or when the user asks to design an AL feature.
---

# /al-design, Idea → feature architecture

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Turn the sharpened idea into feature-level architecture and write `architecture.md`. `/al-scope` reads it next and decomposes it into tasks.

## Artifact boundary

Writes only `architecture.md`, plus new question files under `.not-yet-specified/` — never task-level proof. Module boundaries, AL object responsibilities, seams, events, decision-logic placement, and testability constraints settle here. `/al-scope` owns the `tasks/` folder; `/al-refine` owns task-level proof shape.

## Preconditions

- `/al-grill-adr` ran for this idea. Without sharpened intent in `CONTEXT.md` / domain ADRs you cannot tell domain confusion from genuine architectural choice. **Stop**, run it first.
- User/API-facing: `/al-event-model` ran and `event-model.md` sits in the spec folder. Without it this skill re-litigates user-side picks inline. When it is missing, ask whether the feature is backend-only (no human, no API consumer) or whether `/al-event-model` was forgotten. **Stop** unless the user confirms backend-only.
- Branch and spec folder setup follows [worktree-feature-branching.md](../../references/worktree-feature-branching.md) — read it in full before touching the branch; it owns the checkout classification, the Stop conditions, and `specs/<NNN>-<slug>/` creation. On an in-flight feature branch, the branch and spec folder already exist and this skill writes into them.
- An existing `architecture.md` means this run is reshaping; re-run with the user's awareness.

## What goes into architecture.md

Every element that `/al-scope` decomposes into tasks settles here — a gap in the artifact resurfaces as a guess inside a task.

- **Slices**: when `event-model.md` is present, its user-facing slots are settled; read, do not re-decide. Qualify each slice by AL pattern from its trigger source; backend-only slices name trigger source only. The *Slice* entry in [LANGUAGE.md](../../references/LANGUAGE.md) homes the pattern table, both slot sets, and the two-artifact settlement.
- **Module map**: modules under `src/<module>/`, named in the project's ubiquitous language, applying the project-specific delta recorded in `CONTEXT.md` ("the Settlement intake module", never "the FooBarHandler").
- **BC patterns**: match from [bc-patterns.md](../../references/bc-patterns.md) where one fits a module. Verify adopted patterns through `al-researcher` with `Use: durable artifact architecture.md` before committing.
- **Decision logic and test surfaces**: per module, where decisions live and what unit tests reach. Name the pure decisions apart from the reads that feed them and the writes that follow. The split is homed in [LANGUAGE.md](../../references/LANGUAGE.md) *Functional core, imperative shell*.
- **Brownfield touchpoints**: objects, procedures, events, table fields the feature touches. Verify every name + signature against workspace evidence (`al-symbols-mcp` / `grep`); behaviour and contracts the workspace cannot answer route through `al-researcher`.
- **Testability constraints**: name where the architecture exposes isolated decision logic and where behaviour necessarily crosses BC runtime, database, page/TestPage, event wiring, table triggers, telemetry shape, install / upgrade, permissions, or public surface. Seams and their earning bar live in [testability.md](../../references/testing/testability.md). No task-level proof, AAA cases, or assertions.
- **Evidence before write**: every BC-specific name is grounded per [GROUND-RULES.md](../../references/GROUND-RULES.md). `architecture.md` is a durable design artifact: facts beyond names already in the dependency graph — pattern fitness, BaseApp behaviour, event contracts — route through `al-researcher` with `Use: durable artifact architecture.md`. `SINGLE-SOURCE` does not satisfy this artifact. Names from `/al-event-model` count only when `grep` against `event-model.md` returns them this session.

An unanswerable question means the architecture is not ready for `/al-scope`. Invoke `al-researcher` for BC behaviour; route a domain rule through `/al-grill-adr` and a replan through `/al-steer`. Some in-scope questions are not sharp enough to block on: named, they matter, and there is no way to phrase them as a decision yet. Write each as `.not-yet-specified/<question>.md` at repo root — the deferred-question ledger `/al-steer` grooms. There it graduates into a decision later instead of resurfacing as an implementation guess.

## AL realisation per slice

Each slice names an AL realisation for every slot — an unnamed slot leaves `/al-implement` to invent one or stall. The slot list is the *Slice* entry in [LANGUAGE.md](../../references/LANGUAGE.md). User-facing gaps are caught at `/al-event-model`; this check covers AL realisation.

Mark each named object `new` or `extends <existing object>`. `extends` marks an extension object on an existing base — still a `New:` object at refine. An object another slice already creates is named with its owning slice, not re-marked. `/al-refine` derives each task's `New and Modified Objects` from these markers without re-deciding brownfield scope. Keep the architecture at object level. Fields and signatures are refine's altitude: they shift during TDD and rot in a reshape-only artifact.

## Deletion test and two-adapter rule

Both are homed in [LANGUAGE.md](../../references/LANGUAGE.md) Principles. At this design site: the deletion test runs against every candidate module row, and patterns implying a seam (Event Bridge, Template Method, Command Queue, AL `interface` Façade) name both adapters now or pick a different pattern.

## AppSource sanity

Two design-time risks bite at AppSource boundaries. Both trigger a reshape here, not at implement time. A BaseApp modification is replaced by interception — published events, table extensions, or AL `interface` implementations — because AppSource rejects modified-base-app extensions. A shipped field being renamed or removed follows the `ObsoleteState: Pending → Removed` lifecycle over the deprecation window. An in-place rename or removal is disallowed by AppSourceCop — it may break schema upgrades and dependent extensions. Per-task compliance (IDs, permission sets, `DataClassification`, captions, install / upgrade) bites at `/al-implement`.

## Architecture trade-off criteria

Call out an architecture trade-off inside `architecture.md` when all four are true — three of four earns nothing, and this skill writes no ADR files:

1. **Hard to reverse**: cost of changing later is meaningful.
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, one picked for specific reasons.
4. **Architectural**: mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

## Design it twice

Non-trivial calls fan out three parallel passes of the `al-design-option` custom agent. Non-trivial means multi-module, brownfield refactor, or novel pattern selection. Each call carries identical grounded context and one of the three divergent constraints below. The context is the idea or `event-model.md`, `CONTEXT.md` domain vocabulary plus ADRs, architectural vocabulary from [LANGUAGE.md](../../references/LANGUAGE.md) so all three passes name things consistently, the existing `architecture.md` when reshaping, and the brownfield touchpoints.

| Pass | Constraint |
|---|---|
| 1 | Minimise the interface, 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility, many use cases, easy extension. |
| 3 | Optimise the most common caller, default case trivial. |

Each pass returns one self-contained `ARCHITECTURE CANDIDATE` with the labeled sections `Constraint:`, `Shape:`, `Flow:`, `Seams:`, `Trade-offs:`, `Evidence:`, `Assumptions:`. A pass never compares, recommends, or picks — that judgment stays here. When `al-design-option` is unavailable, report `BLOCKED`, name `al-design-option` as the missing agent, and stop. No inline or ad hoc general-subagent substitution.

Present all three sequentially. Compare along **depth** / **locality** / **seam placement** and pick one, or a hybrid, opinionatedly. A rubber-duck consult ([rubber-duck-review.md](../../references/rubber-duck-review.md)) reconciles non-trivial picks before `architecture.md` is first written. When the choice is the user's call, run `/grill-me`, then ask one question with lettered options ([GROUND-RULES.md](../../references/GROUND-RULES.md) One decision per question).

## The write

[task-lifecycle.md](../../references/task-lifecycle.md) is a mandatory read before writing — it owns the artifact constraints and the examples table whose `architecture.example.md` owns the shape. Markdown only, text-only. Reshape via re-running, never surgical edits. Name relationships (module deps, flow) in prose. No mermaid fences.

## Document verification

Between writing `architecture.md` and the close, run the document-integrity check yourself, inline, no subagent. Check against [doc-integrity.md](../../references/doc-integrity.md): the `architecture.md` profile and sibling consistency in the spec folder. A **fail** blocks the close and the `/al-scope` handoff — fix it or route to `/al-steer`. A **warn** rides in the close. The check judges structure only, never whether the architecture is the best design.

## Next step

Close with the task-close gate report ([GROUND-RULES.md](../../references/GROUND-RULES.md) House shapes). It gives the user the evidence for the greenlight call on `/al-scope`, naming the chosen BC pattern and the core boundary as how the feature fits. `architecture.md` landed with no integrity fail → `Next: /al-scope`. `al-researcher` returned `CONFLICT` or `UNRESOLVED` → `Next: /al-steer`. A domain rule is unsettled → `Next: /al-grill-adr`. The decomposition needs a new decision → `Next: /al-steer`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-event-model` (user/API-facing features) or `/al-grill-adr` (backend-only) |
| **Hands off to**   | `/al-scope` (decomposes `architecture.md` into the slice-grouped `tasks/` folder) |
| **Calls directly** | no skills; rubber-duck consult on the candidate pick |
| **Spawns**         | `al-researcher` for BC facts; `al-design-option` custom agent, three parallel calls (non-trivial designs only) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/grill-me` (candidate picks that are the user's call) |
