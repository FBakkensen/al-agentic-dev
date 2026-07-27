---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references intent with the codebase, and offers domain ADRs only when a hard-to-reverse business rule earns one.
---

# /al-grill-adr, Domain-aware grilling for AL/Business Central

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

**Interview the user about domain intent, one question at a time ([GROUND-RULES.md](../../references/GROUND-RULES.md) One decision per question), reading the codebase when it can answer.** Sharpen `CONTEXT.md` until BC vocabulary is unambiguous; offer a domain ADR when a constraint is hard to reverse and worth preserving.

[user-involvement.md](../../references/user-involvement.md) is the interview contract this session runs on. Strategic here: what a term means in this project, which constraint earns an ADR, and which question is deferred rather than answered. Where a `CONTEXT.md` entry sits, how an ADR's prose reads, and which of two equivalent phrasings lands are tactical — decide them and say so in one line.

## Artifact boundary

**Writes only `CONTEXT.md`, accepted domain ADRs under `docs/adr/`, and new question files under `.not-yet-specified/`** — the deferred-question ledger `/al-steer` grooms.

May read implementation, app, and test code to expose domain conflicts, never edits them. Never writes `event-model.md`, `architecture.md`, or the `tasks/` folder.

The thread is complete when the next natural move feels like writing AL or sketching objects. Finish the ADR or `CONTEXT.md` entry the question earned, then move to the next question or the handoff.

Journey pressure hands off to `/al-event-model`; architecture, object-responsibility, task, proof, or implementation pressure to `/al-design` or the downstream owning skill.

## Preconditions

**No hard precondition gates this skill.** Run before `/al-design` to crystallise intent, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.

- `CONTEXT.md` missing at repo root → materialise from `../../references/CONTEXT.template.md` (relative to this skill's base directory) on the first term that resolves.
- `docs/adr/` missing → materialise the first ADR from `../../references/adr.template.md` on first accept.

## Question repertoire

- **Which BC term here is ambiguous, overloaded, or conflicts with `CONTEXT.md`?** Resolve it into the project's ubiquitous language. Standard Microsoft terms are the baseline; architectural vocabulary comes from [LANGUAGE.md](../../references/LANGUAGE.md). Record only what this project narrows, extends, or names that Microsoft doesn't, updating `CONTEXT.md` inline as terms resolve.
- **What concrete BC scenario forces a boundary between two concepts to be precise?** Partial posting, reversal, dimension inheritance, multi-company, AppSource constraint.
- **What is the user not asking because they don't know to ask it?** Name the adjacent BC behaviour, historical constraint, or standard pattern the user shows no sign of having considered, and let the user decide whether it matters — an unclaimed one is where the implementation guesses later. One that matters but can't be decided yet is written as `.not-yet-specified/<question>.md` at repo root (the question and what it waits on) so it survives the session.
- **Where does the user's stated behaviour disagree with the code?** Read the code when it can answer; ask the user only what code cannot tell (intent, future direction, why a constraint exists). Name the conflict; resolution is the user's call.
- **What is the cheapest rung that settles this question?** Route it per the fidelity ladder in [user-involvement.md](../../references/user-involvement.md). A term the workspace or `al-researcher` settles is a fact — resolve it and name what you found instead of asking. A rule whose consequences the user cannot judge from one sentence earns the concrete BC scenario sketched in chat, not a second question.
- **Does a domain constraint earn an ADR?** Offer one inline only when all four hold:
  - hard to reverse (shipped data, partner integrations, behavioural contracts)
  - surprising without context
  - a real trade-off with genuine alternatives
  - domain — a rule about *what the business does*, not *how the code is shaped*

  Three of four does not earn one. When a question feels architectural, grill the domain constraint behind it. Where the fork behind a constraint is genuinely open, building out at this altitude is one complete ADR candidate per option — context, decision, consequences — presented together, per the alternatives beat in [user-involvement.md](../../references/user-involvement.md). Template: `../../references/adr.template.md` (relative to this skill's base directory). Resolve `NNNN` per `../../references/cross-branch-numbering.md`.

Every BC name landing in `CONTEXT.md` or a domain ADR is grounded per [GROUND-RULES.md](../../references/GROUND-RULES.md). A BC behavioural gap invokes `al-researcher` with `Use: durable artifact <path>`. `CONFLICT` or `UNRESOLVED` means grilling is not done: keep going and write neither the term nor the ADR this session.

## Document verification

**After writing `CONTEXT.md` or a domain ADR, run the document-integrity check yourself, inline (no subagent), against [doc-integrity.md](../../references/doc-integrity.md) before handing off.** A **fail** blocks handoff — fix it or route to `/al-steer`. A **warn** rides in the handoff note. The gate checks document integrity only, never whether the domain rule is right.

## Next step

**Once the idea is grilled and any earned `CONTEXT.md` or ADR writes are integrity-checked, name the handoff.** `Next: /al-event-model` (user/API-facing feature) or `/al-design` (backend-only). Term still unsettled or a behavioural conflict unresolved after research → `Next: /al-steer`.

## Composition

| | |
|---|---|
| **Runs after**     | `main` (kicks off new feature) or standalone for a fuzzy term |
| **Hands off to**   | `/al-event-model` (user/API-facing features) or `/al-design` (backend-only) |
| **Replan venue**   | `/al-steer` |
| **Calls directly** | no skills |
| **Spawns**         | `al-researcher` for BC facts beyond direct workspace reading |
| **Sidebands**      | `/grill-me` when an answer itself needs pressure ([user-involvement.md](../../references/user-involvement.md)) |
