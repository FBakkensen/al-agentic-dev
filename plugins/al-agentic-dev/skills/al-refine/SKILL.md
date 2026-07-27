---
name: al-refine
description: "One `status: ready` task to a fresh Test Specification or Verification Plan for AL/Business Central. Technical task -> ready-for-implementation. Verify task -> ready-for-verification."
---

# /al-refine, task to Test Specification / Verification Plan

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

One named `status: ready` task in `tasks/` gets its `Test Specification` or `Verification Plan` regenerated from the current app and tests, in the grammar of [task-grammar.md](../../references/task-grammar.md). One task per run.

Branch by `kind:` in the task file's frontmatter:

- `technical` → fresh `Test Specification`, flip `ready` → `ready-for-implementation`, stamp `phase: refined`.
- `verify` → fresh `Verification Plan`, flip `ready` → `ready-for-verification`, stamp `phase: planned`.
- `provision` / `breaking-change` → decline: *"ops task → run `/al-provision`"* or *"ops task → run `/al-validate-breaking-changes`"*.

## The interview

Run the interview contract in [user-involvement.md](../../references/user-involvement.md).

Strategic here — what `/al-implement`, `/al-page-script`, and `/al-user-verification` work against and can only reopen through a replan: which behaviours this task's proof has to pin, the proof layer where a behaviour lands when the choice leaves manual verification behind, any public surface the task commits to, and what the user signs off by hand. Tactical: AL test procedure names, case ordering, which coverage table carries the cases, assertion phrasing, and the `New:` / `Modified:` seeds.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, run `/al-event-model` (or `/al-design` for backend-only).
- Spec folder holds `architecture.md`. Missing → **Stop**, run `/al-design`.
- User/API-facing features carry `event-model.md` alongside. A `kind: verify` task without it is a contract violation: **Stop**, route `/al-steer`.
- The target task is named and has `status: ready`.
- A `ready` verify task carries `review: clean` — `/al-code-review` stamped it when it opened the task. Absent → torn state: **Stop**, `Next: /al-steer`.
- Read [task-grammar.md](../../references/task-grammar.md), [test-strategy.md](../../references/testing/test-strategy.md), [test-layout.md](../../references/testing/test-layout.md) (the Unit-vs-Integration placement rule lives there — a codepath needing real BaseApp behaviour cannot be scoped `Unit`), and [task-lifecycle.md](../../references/task-lifecycle.md) before writing.
- Scan `.not-yet-specified/*.md` at repo root when present. A question the task's behaviour touches → **Stop**, name the question file, route `/al-steer` (or `/al-grill-adr` for a domain rule).

### A `blocked` or `done` task routes by why

Opening a task whose gate has already been earned is applying a decision; crossing an unearned review gate is making one — only the former happens here ([task-lifecycle.md](../../references/task-lifecycle.md), Apply a decision vs. make a decision).

- `kind: technical`, `blocked`, all `depends_on:` `done`, no replan flag, and its slice already open (a same-`slice:` sibling is not `blocked`) → the upstream close missed the flip; open it `ready` and proceed.
- Every task in the slice still `blocked` → the slice's opening gate (the prior slice's clean `/al-code-review` or verify pass) is unearned: **Stop**, `Next: /al-steer`.
- A `kind: verify` task reaches `ready` only when `/al-code-review` opens it carrying `review: clean`. Blocked with all technical deps `done` and no `review: clean` → the slice owes its review: **Stop**, `Next: /al-code-review T-NNN`.
- `blocked` on an unsatisfied edge or a replan flag → `/al-steer`.
- `done` → reopen only through `/al-steer`.

## Question repertoire

- **Which business edge does this task have to survive?** Mine the description, `architecture.md`, `event-model.md`, `CONTEXT.md`, the codebase, and `al-researcher` first, and name what you found. Ask only where the business behaviour is genuinely unsettled — partial posting, reversal, dimension inheritance, a bound nobody wrote down.
- **Is this push-up worth taking?** Which layer can reach a behaviour is a fact. What the user decides is whether the manual verification the push-up leaves behind is a price worth paying on this task.
- **Which name here becomes a commitment?** A private procedure name is tactical. A name landing on public surface — a shipped object, an API, a published event — is a commitment AppSource holds for the life of the app, so it is asked.
- **Verify task: what would you check by hand, and where would you look hardest?** The expected outcomes come from `event-model.md`, and a new one is upstream replan. What the user adds is the emphasis at sign-off and the risk worth an `Exploration Charter`.

Where the interview names a fork — a proof layer, a coverage boundary — building out at this altitude is a complete AAA case set per candidate for the behaviour in question, per the alternatives beat in [user-involvement.md](../../references/user-involvement.md).

## Regenerate the section whole

Preserve scope-time context: title, description, the `depends_on:` / `refactors:` / `fixes:` edges, `slice:`, constraints, risks, source context, acceptance intent. Regenerate the `Test Specification` / `Verification Plan` section whole — never keep stale cases, tables, examples, or charters because they existed. Cases land in the task file as they settle, per [user-involvement.md](../../references/user-involvement.md).

## Technical task: Test Specification

Answer before writing:

- **What does the task deliver?** Resolve from the description, the `architecture.md` slice, `event-model.md` when present, `CONTEXT.md`, and the codebase.
- **Which coverage table?** Choose per the table criteria in [task-grammar.md](../../references/task-grammar.md); multiple unrelated groups → split or route `/al-steer`.
- **What is each AAA case's scope?** Unit vs Integration per [test-layout.md](../../references/testing/test-layout.md). Refine proposes scope; `/al-implement` may change it and must reconcile the task file.
- **What procedure names should exist?** Propose short PascalCase AL test procedure names; they populate `Covered By` and the AAA case headers per the grammar.
- **What does the codebase actually expose?** Real codeunits, tables, fields, pages, procedures, events, and APIs on the boundary.
- **Which objects and signatures does the task land?** Write `New and Modified Objects` per the grammar. Seed `New:` vs `Modified:` from `architecture.md`'s `new` / `extends` markers. Override the seed by workspace state at refine time. Architecture silent on a needed object → mint it when it serves a listed slice slot. A missing slot is a replan trigger ([task-lifecycle.md](../../references/task-lifecycle.md)), route `/al-steer`.

Unanswerable routes by what is missing: a BC behaviour invokes `al-researcher`, a domain rule goes to `/al-grill-adr`, a strategic call goes to the user, an answer only running code can give routes per the fidelity ladder in [user-involvement.md](../../references/user-involvement.md), and a replan goes to `/al-steer`. Keep or flip `status: blocked` when none of them lands this run.

## Verify task: Verification Plan

Every check derives from the slice's observable user/API surface, never internal state. Write only subsections that apply — `Journey Examples`, `Contract Examples`, `Exploration Charters` — per the grammar and at-least-one-example rules in [task-grammar.md](../../references/task-grammar.md). Answer before writing:

- **Which slice does this verify?** Resolve `slice:` to the `event-model.md` timeline step; title and description quote its Role, Action, Business Event, View, Status vocabulary.
- **Which surface is exercised?** Name it inline — downstream skills must not guess.
- **Which E2E journeys are `Record: yes`?** Per the `Record:` flag semantics in the grammar: only when no AL test layer can automate the behaviour. Behaviour a lower test should pin is pushed down via `/al-steer`, never recorded.
- **Which `event-model.md` slots are cited?** Every Role / Action / Business Event / View / Status name is backed by `grep` against `event-model.md` or a workspace lookup on the underlying BC surface.

Unanswerable routes the same way: `al-researcher` for a BC surface fact, the user for a strategic call, `/al-steer` for a wrong slice boundary or missing prerequisite.

## Surface push-ups, commit nothing

Push-up definition, justification content, and the report shape are homed in [test-strategy.md](../../references/testing/test-strategy.md). Refine proposes scope. It emits the Push-up report as its own chat section. It records each push-up's justification as a `Contract notes` line. It commits nothing — the handoff stop is the user's review point.

## Ground exact names

Every exact BC name written into the `Test Specification` or `Verification Plan` meets the grounding bar in [GROUND-RULES.md](../../references/GROUND-RULES.md), including the minted-name clause for `New and Modified Objects`.

## Sharpen vague language inline

Replace vague phrasing with exact object, procedure, and status names inline. An implicit domain rule, an edge the user must adjudicate, a missing bound, a boundary contradicting another rule, or split intent (`validate` as schema check vs. business rule check) → run `/grill-me`.

## Document verification

Run the document-integrity check inline, no subagent, against [doc-integrity.md](../../references/doc-integrity.md) scoped to this `T-NNN`: the `tasks/` profile's checks that reach a single task file. It is mechanical and cheap, so it runs before the review gate below — a structurally broken artifact should not cost a lens fleet — and again on any regenerated text. A **fail** blocks the flip: fix it or route `/al-steer`. A **warn** rides in the close.

## Review gate

The session that wrote this artifact is its worst reader — its own rationale stands by to argue every finding down. A fresh fleet reads it blind before the status flip, per [review-lenses.md](../../references/review-lenses.md).

Spawn the branch's lenses in parallel, declaring the mode, the scope, and the artifact:

- Technical task → `Mode: test-spec`: `al-review-compliance`, `al-review-objects`, `al-review-coverage`, `al-review-assertions`, `al-review-structural`.
- Verify task → `Mode: verification-plan`: the three lenses that reference's membership matrix marks in that column.

Each invocation carries the task file, `architecture.md`, `event-model.md` when present, `CONTEXT.md`, and the slice the task belongs to. Then invoke `al-review-judge` once with the same declared mode, the artifact, and every lens's raw finding blocks — never their `Out-of-scope:` notes, which this skill routes itself.

A surviving `MUST-FIX` holds the flip. Report, tag, question, and re-review per **A blocking finding on a plan** in [review-lenses.md](../../references/review-lenses.md) — including its split between what the agent decided and what the user settled in the interview. A finding the design settled wrongly rather than the artifact stated wrongly is the upstream disposition, and a durable principle behind it reaches `/al-grill-adr` or `/al-design` through `/al-steer`.

## IDs and handles

Coverage IDs: `B#` (`Expected Behaviors`), `R#` (`Decision Matrix`), `V#` (`E2E`), `C#` (`Contract`), `X#` (`Exploration`). Stable handles downstream skills grep for: the AL test procedure name (technical); the example ID plus title, e.g. `V1 BlocksReleaseFromSalesOrderPage` (verify).

## Status flip

Flip `status:` and stamp `phase:` in the same Edit — mechanics per [task-lifecycle.md](../../references/task-lifecycle.md), Surgical-edit discipline:

```markdown
technical: status: ready → status: ready-for-implementation, phase: refined
verify:    status: ready → status: ready-for-verification,   phase: planned
```

A re-refine re-stamps `phase:`. A verify task's `review: clean` rides the flip untouched ([task-lifecycle.md](../../references/task-lifecycle.md)).

## Next step

Close with the task-close gate report per [GROUND-RULES.md](../../references/GROUND-RULES.md) House shapes — the `phase:` stamp is refine's closing stamp — with the Push-up report preceding it as its own section. A precondition failure closes with the one-line **Stop** shape.

- Technical → `Next: /al-implement T-NNN`.
- Verify → state-conditional: `/al-page-script T-NNN` when a `Record: yes` Journey Example's recording is missing, else `/al-user-verification T-NNN`. The slice's code review already ran — never route back through `/al-code-review`.
- Gate held by a surviving `MUST-FIX` → no flip, no gate report: close with the tagged findings and the lettered question.
- Stayed or flipped `blocked` → invoke `al-researcher`, or hand off to `/al-grill-adr` or `/al-steer`, per cause.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope`, or a gate-opened task at `status: ready` |
| **Hands off to**   | as Next step above |
| **Calls directly** | no skills |
| **Spawns**         | `al-researcher` for BC facts beyond direct workspace reading; the branch's mode lenses per [review-lenses.md](../../references/review-lenses.md), then `al-review-judge` |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-grill-adr`; `/grill-me` when an answer itself needs pressure ([user-involvement.md](../../references/user-involvement.md)) |
