---
name: al-design
description: Settle the AL/Business Central feature architecture from idea or `event-model.md`. Use after `/al-event-model` for user/API-facing features, after `/al-grill-adr` for backend-only features, or when the user asks to design an AL feature.
---

# /al-design, Idea → feature architecture

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Turn the sharpened idea into feature-level architecture and write `architecture.md`. `/al-scope` reads it next and decomposes it into tasks.

## The interview

Run the interview contract in [user-involvement.md](../../references/user-involvement.md).

Strategic here — what `/al-scope` decomposes into every task of the feature and cannot reopen without a replan: module ownership and dependency direction, where persisted data lives, seam placement, which existing behaviour the feature is allowed to change, the public surface it commits to, the boundary between pure decisions and BC runtime, and the constraint the candidates diverge on. Tactical: object and file names, which of two equivalent BC patterns carries a module, and the order the artifact's sections land in.

The module map — pure core, seams, dependency direction — is the case a panel pays for at this altitude. A candidate comparison is not; keep that in chat.

## Artifact boundary

Writes only `architecture.md`, plus new question files under `.not-yet-specified/` — never task-level proof. Module boundaries, AL object responsibilities, seams, events, decision-logic placement, and testability constraints settle here. `/al-scope` owns the `tasks/` folder; `/al-refine` owns task-level proof shape.

## Preconditions

- `/al-grill-adr` ran for this idea. Without sharpened intent in `CONTEXT.md` / domain ADRs you cannot tell domain confusion from genuine architectural choice. **Stop**, run it first.
- User/API-facing: `/al-event-model` ran and `event-model.md` sits in the spec folder. Without it this skill re-litigates user-side picks inline. When it is missing, ask whether the feature is backend-only (no human, no API consumer) or whether `/al-event-model` was forgotten. **Stop** unless the user confirms backend-only.
- Branch and spec folder setup follows [worktree-feature-branching.md](../../references/worktree-feature-branching.md) — read it in full before touching the branch; it owns the checkout classification, the Stop conditions, and `specs/<NNN>-<slug>/` creation. On an in-flight feature branch, the branch and spec folder already exist and this skill writes into them.
- An existing `architecture.md` means this run is reshaping; re-run with the user's awareness.

## Question repertoire

- **Which module owns this decision, and what breaks when it moves?** The deletion test runs against every candidate module row — it is homed in [LANGUAGE.md](../../references/LANGUAGE.md) Principles. Name the ubiquitous-language module, never a class-shaped one.
- **What has to stay decidable without the BC runtime?** The pure decisions apart from the reads that feed them and the writes that follow, per *Functional core, imperative shell* in [LANGUAGE.md](../../references/LANGUAGE.md). What the user answers is which behaviour is worth that isolation, not how to build the seam.
- **Which existing behaviour is this feature allowed to change?** The touchpoints themselves are facts — name the objects, procedures, events, and fields against workspace evidence. AppSource already forces interception over base modification, so the open call is which behaviour existing callers may see move.
- **Which future change must this architecture keep cheap?** A planned rewrite, a partner integration, a module about to be replaced. The code cannot say it and the user can.
- **Which constraint is actually binding?** The one a wrong answer makes expensive. It is also the fork the candidates below diverge on.

## What goes into architecture.md

Every element that `/al-scope` decomposes into tasks settles here — a gap in the artifact resurfaces as a guess inside a task.

- **Slices**: when `event-model.md` is present, its user-facing slots are settled; read, do not re-decide. Qualify each slice by AL pattern from its trigger source; backend-only slices name trigger source only. The *Slice* entry in [LANGUAGE.md](../../references/LANGUAGE.md) homes the pattern table, both slot sets, and the two-artifact settlement.
- **Module map**: modules under `src/<module>/`, named in the project's ubiquitous language, applying the project-specific delta recorded in `CONTEXT.md` ("the Settlement intake module", never "the FooBarHandler").
- **BC patterns**: match from [bc-patterns.md](../../references/bc-patterns.md) where one fits a module. Verify adopted patterns through `al-researcher` with `Use: durable artifact architecture.md` before committing.
- **Decision logic and test surfaces**: per module, where decisions live and what unit tests reach. Name the pure decisions apart from the reads that feed them and the writes that follow.
- **Brownfield touchpoints**: objects, procedures, events, table fields the feature touches. Verify every name + signature against workspace evidence (`al-symbols-mcp` / `grep`); behaviour and contracts the workspace cannot answer route through `al-researcher`.
- **Testability constraints**: name where the architecture exposes isolated decision logic and where behaviour necessarily crosses BC runtime, database, page/TestPage, event wiring, table triggers, telemetry shape, install / upgrade, permissions, or public surface. Seams and their earning bar live in [testability.md](../../references/testing/testability.md). No task-level proof, AAA cases, or assertions.
- **Evidence before write**: every BC-specific name is grounded per [GROUND-RULES.md](../../references/GROUND-RULES.md). `architecture.md` is a durable design artifact: facts beyond names already in the dependency graph — pattern fitness, BaseApp behaviour, event contracts — route through `al-researcher` with `Use: durable artifact architecture.md`. `SINGLE-SOURCE` does not satisfy this artifact. Names from `/al-event-model` count only when `grep` against `event-model.md` returns them this session.

An unanswerable question means the architecture is not ready for `/al-scope`. Invoke `al-researcher` for BC behaviour; route a domain rule through `/al-grill-adr` and a replan through `/al-steer`. Some in-scope questions are not sharp enough to block on: named, they matter, and there is no way to phrase them as a decision yet. Write each as `.not-yet-specified/<question>.md` at repo root — the deferred-question ledger `/al-steer` grooms. There it graduates into a decision later instead of resurfacing as an implementation guess.

## AL realisation per slice

Each slice names an AL realisation for every slot — an unnamed slot leaves `/al-implement` to invent one or stall. The slot list is the *Slice* entry in [LANGUAGE.md](../../references/LANGUAGE.md). User-facing gaps are caught at `/al-event-model`; this check covers AL realisation.

Mark each named object `new` or `extends <existing object>`. `extends` marks an extension object on an existing base — still a `New:` object at refine. An object another slice already creates is named with its owning slice, not re-marked. `/al-refine` derives each task's `New and Modified Objects` from these markers without re-deciding brownfield scope. Keep the architecture at object level. Fields and signatures are refine's altitude: they shift during TDD and rot in a reshape-only artifact.

## Two-adapter rule

Homed in [LANGUAGE.md](../../references/LANGUAGE.md) Principles. At this design site: patterns implying a seam (Event Bridge, Template Method, Command Queue, AL `interface` Façade) name both adapters now or pick a different pattern.

## AppSource sanity

Two design-time risks bite at AppSource boundaries. Both trigger a reshape here, not at implement time. A BaseApp modification is replaced by interception — published events, table extensions, or AL `interface` implementations — because AppSource rejects modified-base-app extensions. A shipped field being renamed or removed follows the `ObsoleteState: Pending → Removed` lifecycle over the deprecation window. An in-place rename or removal is disallowed by AppSourceCop — it may break schema upgrades and dependent extensions. Per-task compliance (IDs, permission sets, `DataClassification`, captions, install / upgrade) bites at `/al-implement`.

## Architecture trade-off criteria

Call out an architecture trade-off inside `architecture.md` when all four are true — three of four earns nothing, and this skill writes no ADR files:

1. **Hard to reverse**: cost of changing later is meaningful.
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, one picked for specific reasons.
4. **Architectural**: mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

## Candidate architectures

Non-trivial designs earn candidates: multi-module, brownfield refactor, or novel pattern selection. They follow the alternatives beat in [user-involvement.md](../../references/user-involvement.md), diverging on the binding constraint the interview named. Building out at this altitude is one `al-design-option` call per constraint.

Fan out those calls in parallel, one divergent constraint each. Each call carries identical grounded context: the idea or `event-model.md`, `CONTEXT.md` domain vocabulary plus ADRs, architectural vocabulary from [LANGUAGE.md](../../references/LANGUAGE.md) so every pass names things consistently, the existing `architecture.md` when reshaping, the brownfield touchpoints, and the decisions the user already settled, marked as settled so no candidate reopens one.

Each pass returns one self-contained `ARCHITECTURE CANDIDATE` with the labeled sections `Constraint:`, `Shape:`, `Flow:`, `Seams:`, `Trade-offs:`, `Evidence:`, `Assumptions:`. A pass never compares, recommends, or picks — that judgment stays here. `al-design-option` unavailable once the user has set a count → report `BLOCKED`, name `al-design-option` as the missing agent, and stop. No inline or ad hoc general-subagent substitution.

Present the candidates sequentially. Compare along **depth** / **locality** / **seam placement** and recommend one, or a hybrid, opinionatedly. A rubber-duck consult ([rubber-duck-review.md](../../references/rubber-duck-review.md)) challenges that recommendation before it reaches the user. The user picks, in one question with lettered options ([GROUND-RULES.md](../../references/GROUND-RULES.md) One decision per question).

## The write

Decisions land in `architecture.md` as they settle, per [user-involvement.md](../../references/user-involvement.md). [task-lifecycle.md](../../references/task-lifecycle.md) is a mandatory read before the first write — it owns the artifact constraints and the examples table whose `architecture.example.md` owns the shape. Markdown only, text-only. Reshape via re-running, never surgical edits. Name relationships (module deps, flow) in prose. No mermaid fences.

## Document verification

Between the settled artifact and the close, run the document-integrity check yourself, inline, no subagent. Check against [doc-integrity.md](../../references/doc-integrity.md): the `architecture.md` profile and sibling consistency in the spec folder. It is mechanical and cheap, so it runs before the review gate below — a structurally broken artifact should not cost a lens fleet — and again on any regenerated text. A **fail** blocks the close and the `/al-scope` handoff — fix it or route to `/al-steer`. A **warn** rides in the close. The check judges structure only, never whether the architecture is the best design; that is the review gate's job.

## Review gate

The session that wrote this artifact is its worst reader — it recommended the candidate and wrote the file, and its own rationale stands by to argue every finding down. `/al-scope` decomposes `architecture.md` into every task of the feature, so a wrong module boundary or an unearned seam reaches a dozen task files before anything catches it. A fresh fleet reads the written artifact blind before the `/al-scope` handoff, per [review-lenses.md](../../references/review-lenses.md).

Spawn the five lenses in parallel, declaring `Mode: architecture`, the scope, and the artifact: `al-review-compliance`, `al-review-coverage`, `al-review-structural`, `al-review-bc`, `al-review-appsource`. Each invocation carries `architecture.md`, `event-model.md` when present, `CONTEXT.md`, the domain and design ADRs, and the brownfield touchpoints. Then invoke `al-review-judge` once with the same declared mode, the artifact, and every lens's raw finding blocks — never their `Out-of-scope:` notes, which this skill routes itself.

A surviving `MUST-FIX` holds the `/al-scope` handoff. Report, tag, question, and re-review per **A blocking finding on a plan** in [review-lenses.md](../../references/review-lenses.md) — including its split between what the agent decided and what the user settled in the interview. Upstream at this gate means the wrong artifact is under repair: a slice `event-model.md` settled badly, a term `CONTEXT.md` already owns, a decision an ADR already made the other way. Everything else is a design this session can rewrite.

## Next step

Close with the task-close gate report ([GROUND-RULES.md](../../references/GROUND-RULES.md) House shapes), naming the chosen BC pattern and the core boundary as how the feature fits. The picks were made in the room, so the report records what settled rather than asking for a greenlight. `architecture.md` landed with no integrity fail and a clear review gate → `Next: /al-scope`. A `MUST-FIX` surviving the review gate → no handoff and no gate report: close with the tagged findings and the lettered question. `al-researcher` returned `CONFLICT` or `UNRESOLVED` → `Next: /al-steer`. A domain rule is unsettled → `Next: /al-grill-adr`. The decomposition needs a new decision → `Next: /al-steer`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-event-model` (user/API-facing features) or `/al-grill-adr` (backend-only) |
| **Hands off to**   | `/al-scope` (decomposes `architecture.md` into the slice-grouped `tasks/` folder) |
| **Calls directly** | no skills; rubber-duck consult on the candidate recommendation |
| **Spawns**         | `al-researcher` for BC facts; `al-design-option`, one parallel call per constraint at the count the user set (non-trivial designs only); the five `architecture` lenses per [review-lenses.md](../../references/review-lenses.md), then `al-review-judge` |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/grill-me` when an answer itself needs pressure ([user-involvement.md](../../references/user-involvement.md)) |
