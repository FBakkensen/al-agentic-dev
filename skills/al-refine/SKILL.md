---
name: al-refine
description: Turn one task into its proof — a Test Specification on a technical task, a Verification Plan on a verify task. Run it on the next unrefined task the router names.
disable-model-invocation: true
---

# Refine a task into its proof

One named task per run. Regenerate its Test Specification or Verification Plan whole against the current app and tests; keep everything scope-time — title, description, `depends_on:`, `slice:`, constraints, risks, acceptance intent. [TASK-FORMAT.md](TASK-FORMAT.md) is the body's exact shape — section order, heading levels, labels, and column names.

The body is your write; the frontmatter is `/al-routing`'s. An open question this run cannot settle — one only running code can answer, a slot `architecture.md` never allotted, an unsettled domain rule — stops the run instead: name it in chat and leave the body as the interview left it; the next run regenerates it whole once the question settles.

## Branch by kind

- `technical` → Test Specification, the red→green driver.
- `verify` → Verification Plan, the walk run with the user. Without `event-model.md` the slice has no user-facing source; the run stops.
- `provision` → decline, naming `/al-provision`. `breaking-change` → decline, naming `/al-validate-breaking-changes`.

## The interview

Read `architecture.md`, `event-model.md` when present, `CONTEXT.md`, and the code the task lands on before the first question.

A fact is looked up. A tactical call — AL test procedure names, case ordering, assertion phrasing — is decided and named in one chat line, which is what makes it overridable without asking. A strategic call is asked one question per message with lettered options, because downstream consumes it as settled: which behaviours this proof has to pin, which layer holds a behaviour when the cheapest one cannot reach it, any name landing on public surface — a shipped object, an API, a published event — that AppSource then holds for the life of the app, and what the user signs off by hand.

Write each answer into the task file as it settles. Where an answer itself needs pressure — a requirement that shifts each time it is restated, a bound nobody wrote down — run `/al-grilling`.

## Technical task: Test Specification

`## New and Modified Objects` names the production AL surface the task lands, at signature level, bodies omitted — TDD writes those. `New:` is an object absent from the workspace at this task's start; `Modified:` is one already there, including an object an earlier task landed. Procedures carry the full signature, visibility, and one tag: `— P` for a decision computed from parameters alone, `— S` for anything touching the database or external state, reads included. Fields carry the AL type, events the publisher signature. A test-only task writes the labeled line `New and Modified Objects: none` instead.

Exactly one coverage table: `## Expected Behaviors` with IDs `B1`, `B2` for a guard or a non-branching flow; `## Decision Matrix` with `R1`, `R2` for a branching rule, policy, calculation, or status combination. Every row's `Covered By` names at least one AL test procedure, and nothing else. Two unrelated behaviour groups mean a low-cohesion task: put the split to the user, and on their yes narrow this task to one group and write each other group yourself as a new open technical task per `/al-routing`'s schema — the original keeps its id and its inbound edges, and each new task carries the `depends_on:` edges its group needs.

`## AAA Cases` holds one `###` per case, headed by the AL test procedure name that `Covered By` cites. `Scope:` is exactly one of `Unit` (AL-Runner, isolated decision proof) or `Integration` (container and TestPage — BC runtime, database, event, page, posting, permission, or wiring proof); a behaviour needing both gets two cases. Then `Covers:` citing `B#` / `R#`, then `Arrange:` / `Act:` / `Assert:` bullet blocks with at least one bullet each — business state first, one business action, observable outcomes and expected errors. List all `Unit` cases, then all `Integration`, ascending coverage ID within each.

## Verify task: Verification Plan

Every check derives from the slice's observable user or API surface, never internal state, and title, description, and every Role / Action / Business Event / View / Status name quote `event-model.md`.

Write only the sections the slice earns: `## Journey Examples` (`V1`, `V2`) for a BC Web Client slice, `## Contract Examples` (`C1`) for an API or external-client slice, `## Exploration Charters` (`X1`) for a new or changed workflow. A journey carries `Scope: E2E`, `Record:`, `Role:`, an `Action:` bullet block, and an `Observable Checks:` bullet block — those checks are the gating values the user reads off the screen, so every journey carries them. A charter is one charter sentence and two to four prompts.

`Record: yes` belongs only to behaviour no AL test layer can automate — a control add-in, canvas, rendering, web-client-only behaviour. Behaviour a Unit or Integration case pins is `Record: no` and gets walked instead.

## Push-ups and exact names

Every `Integration` case, `Record: yes` journey, and `Contract` example sits above the cheapest layer that could hold the behaviour. Each owes a `Contract notes:` bullet naming why the layer below cannot hold it and what reaching it would cost — a named seam, or the wall that makes it impossible. Say the same in chat: the spec is written, and nothing is implemented until the user takes the next step — the handoff is their review point.

Every exact BC name written into the task — object, table, field, procedure, event, enum value — comes from a workspace or documentation lookup made this session; recall is not evidence. A minted name earns a zero-hit collision lookup first: objects against workspace declarations, fields against the target table and its extensions, procedures against the target object.

## Close

Name the task and what this run left on it — the proof written, the open question that stopped it, or the decline and the skill it names.

Then `/al-routing` on a written proof. A stop ends in chat and the user re-runs once the question settles; a decline ends naming the owning skill.
