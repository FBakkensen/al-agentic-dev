---
name: al-refine
description: "One `status: ready` task to a fresh Test Specification or Verification Plan for AL/Business Central. Technical task -> ready-for-implementation. Verify task -> ready-for-verification."
---

# /al-refine, task to Test Specification / Verification Plan

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

One named `status: ready` task in `tasks/` gets its `Test Specification` or `Verification Plan` regenerated from the current app and tests, in the grammar of [test-specification.md](../../references/testing/test-specification.md). One task per run.

Branch by `kind:` in the task file's frontmatter:

- `technical` → fresh `Test Specification`, flip `ready` → `ready-for-implementation`, stamp `phase: refined`.
- `verify` → fresh `Verification Plan`, flip `ready` → `ready-for-verification`, stamp `phase: planned`.
- `provision` / `breaking-change` → decline: *"ops task → run `/al-provision`"* or *"ops task → run `/al-validate-breaking-changes`"*.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, run `/al-event-model` (or `/al-design` for backend-only).
- Spec folder holds `architecture.md`. Missing → **Stop**, run `/al-design`.
- User/API-facing features carry `event-model.md` alongside. A `kind: verify` task without it is a contract violation: **Stop**, route `/al-steer`.
- The target task is named and has `status: ready`.
- A `ready` verify task carries `review: clean` — `/al-code-review` stamped it when it opened the task. Absent → torn state: **Stop**, `Next: /al-steer`.
- Read [test-specification.md](../../references/testing/test-specification.md), [test-strategy.md](../../references/testing/test-strategy.md), [test-layout.md](../../references/testing/test-layout.md) (the Unit-vs-Integration placement rule lives there — a codepath needing real BaseApp behaviour cannot be scoped `Unit`), and [task-lifecycle.md](../../references/task-lifecycle.md) before writing.
- Scan `.not-yet-specified/*.md` at repo root when present. A question the task's behaviour touches → **Stop**, name the question file, route `/al-steer` (or `/al-grill-adr` for a domain rule).

### A `blocked` or `done` task routes by why

Opening a task whose gate has already been earned is applying a decision; crossing an unearned review gate is making one — only the former happens here ([task-lifecycle.md](../../references/task-lifecycle.md), Apply a decision vs. make a decision).

- `kind: technical`, `blocked`, all `depends_on:` `done`, no replan flag, and its slice already open (a same-`slice:` sibling is not `blocked`) → the upstream close missed the flip; open it `ready` and proceed.
- Every task in the slice still `blocked` → the slice's opening gate (the prior slice's clean `/al-code-review` or verify pass) is unearned: **Stop**, `Next: /al-steer`.
- A `kind: verify` task reaches `ready` only when `/al-code-review` opens it carrying `review: clean`. Blocked with all technical deps `done` and no `review: clean` → the slice owes its review: **Stop**, `Next: /al-code-review T-NNN`.
- `blocked` on an unsatisfied edge or a replan flag → `/al-steer`.
- `done` → reopen only through `/al-steer`.

## Regenerate the section whole

Preserve scope-time context: title, description, the `depends_on:` / `refactors:` / `fixes:` edges, `slice:`, constraints, risks, source context, acceptance intent. Regenerate the `Test Specification` / `Verification Plan` section whole — never keep stale cases, tables, examples, or charters because they existed.

## Technical task: Test Specification

Answer before writing:

- **What does the task deliver?** Resolve from the description, the `architecture.md` slice, `event-model.md` when present, `CONTEXT.md`, and the codebase.
- **Which coverage table?** Choose per the table criteria in [test-specification.md](../../references/testing/test-specification.md); multiple unrelated groups → split or route `/al-steer`.
- **What is each AAA case's scope?** Unit vs Integration per [test-layout.md](../../references/testing/test-layout.md). Refine proposes scope; `/al-implement` may change it and must reconcile the task file.
- **What procedure names should exist?** Propose short PascalCase AL test procedure names; they populate `Covered By`, AAA headers, and `Procedure:` per the grammar.
- **What does the codebase actually expose?** Real codeunits, tables, fields, pages, procedures, events, and APIs on the boundary.
- **Which objects and signatures does the task land?** Write `New and Modified Objects` per the grammar. Seed `New:` vs `Modified:` from `architecture.md`'s `new` / `extends` markers. Override the seed by workspace state at refine time. Architecture silent on a needed object → mint it when it serves a listed slice slot. A missing slot is a replan trigger ([task-lifecycle.md](../../references/task-lifecycle.md)), route `/al-steer`.

Unanswerable → keep or flip `status: blocked`; invoke `al-researcher` for BC behaviour, `/al-grill-adr` for a domain rule, `/grill-me` for intent the user must adjudicate, or `/al-steer` for replan.

## Verify task: Verification Plan

Every check derives from the slice's observable user/API surface, never internal state. Write only subsections that apply — `Journey Examples`, `Contract Examples`, `Exploration Charters` — per the grammar and at-least-one-example rules in [test-specification.md](../../references/testing/test-specification.md). Answer before writing:

- **Which slice does this verify?** Resolve `slice:` to the `event-model.md` timeline step; title and description quote its Role, Action, Business Event, View, Status vocabulary.
- **Which surface is exercised?** Name it inline — downstream skills must not guess.
- **Which E2E journeys are `Record: yes`?** Per the `Record:` flag semantics in the grammar: only when no AL test layer can automate the behaviour. Behaviour a lower test should pin is pushed down via `/al-steer`, never recorded.
- **Which `event-model.md` slots are cited?** Every Role / Action / Business Event / View / Status name is backed by `grep` against `event-model.md` or a workspace lookup on the underlying BC surface.

Unanswerable → keep or flip `status: blocked`; invoke `al-researcher` for a BC surface fact, `/grill-me` for intent, or `/al-steer` for a wrong slice boundary or missing prerequisite.

## Surface push-ups, commit nothing

Push-up definition, justification content, and the report shape are homed in [test-strategy.md](../../references/testing/test-strategy.md). Refine proposes scope. It emits the Push-up report as its own chat section. It records each push-up's justification as a `Contract notes` line. It commits nothing — the handoff stop is the user's review point.

## Ground exact names

Every exact BC name written into the `Test Specification` or `Verification Plan` meets the grounding bar in [GROUND-RULES.md](../../references/GROUND-RULES.md), including the minted-name clause for `New and Modified Objects`.

## Sharpen vague language inline

Replace vague phrasing with exact object, procedure, and status names inline. An implicit domain rule, an edge the user must adjudicate, a missing bound, a boundary contradicting another rule, or split intent (`validate` as schema check vs. business rule check) → run `/grill-me`.

## Rubber-duck review on non-trivial specs and plans

Consult per [rubber-duck-review.md](../../references/rubber-duck-review.md), before the section is written into the task file.

- Technical artifact body: task title + description + proposed `Test Specification` + `CONTEXT.md` language excerpt if resolved + "what behaviours, decision rows, negatives, boundaries, scopes, procedure mappings, or object/signature landings are missing or wrong? AND does this surface any of the replan triggers? AND does wording use project vocabulary? Return a bulleted list."
- Verify artifact body: task title + slice context from `event-model.md` + proposed `Verification Plan` + "what journeys, contract checks, exploration prompts, boundaries, or exception paths are missing or wrong? AND do examples name real surfaces? AND does this surface any of the replan triggers? Return a bulleted list."

A rejected bullet that encodes a durable principle escalates via `/al-steer` to `/al-grill-adr` or `/al-design`.

## IDs and handles

Coverage IDs: `B#` (`Expected Behaviors`), `R#` (`Decision Matrix`), `V#` (`E2E`), `C#` (`Contract`), `X#` (`Exploration`). Stable handles downstream skills grep for: the AL test procedure name (technical); the example ID plus title, e.g. `V1 BlocksReleaseFromSalesOrderPage` (verify).

## Document verification

Before any status flip, run the document-integrity check inline, no subagent, against [doc-integrity.md](../../references/doc-integrity.md) scoped to this `T-NNN`: the `New and Modified Objects` coverage check and, for a verify task, the E2E `Record:` flag check. A **fail** blocks the flip — fix it or route `/al-steer`. A **warn** rides in the close.

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
- Verify → state-conditional: `/al-page-script T-NNN` when a `Record: yes` Journey Example's recording is missing, else `/al-user-verification T-NNN`. The review already ran — never route back through `/al-code-review`.
- Stayed or flipped `blocked` → invoke `al-researcher`, or hand off to `/al-grill-adr` or `/al-steer`, per cause.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope`, or a gate-opened task at `status: ready` |
| **Hands off to**   | as Next step above |
| **Calls directly** | no skills; rubber-duck consult per [rubber-duck-review.md](../../references/rubber-duck-review.md) |
| **Spawns**         | `al-researcher` for BC facts beyond direct workspace reading |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-grill-adr`, `/grill-me` |
