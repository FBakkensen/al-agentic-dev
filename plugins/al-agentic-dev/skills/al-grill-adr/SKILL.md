---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references intent with the codebase, and offers domain ADRs only when a hard-to-reverse business rule earns one.
---

# /al-grill-adr, Domain-aware grilling for AL/Business Central

**Interview the user about domain intent, one question at a time ([GROUND-RULES.md](../../references/GROUND-RULES.md) One decision per question), reading the codebase when it can answer.** Sharpen `CONTEXT.md` until BC vocabulary is unambiguous; offer a domain ADR when a constraint is hard to reverse and worth preserving.

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
- **Does a domain constraint earn an ADR?** Offer one inline only when all four hold:
  - hard to reverse (shipped data, partner integrations, behavioural contracts)
  - surprising without context
  - a real trade-off with genuine alternatives
  - domain — a rule about *what the business does*, not *how the code is shaped*

  Three of four does not earn one. When a question feels architectural, grill the domain constraint behind it. Template: `../../references/adr.template.md` (relative to this skill's base directory). Resolve `NNNN` per `../../references/cross-branch-numbering.md`.

Every BC name landing in `CONTEXT.md` or a domain ADR is grounded per [GROUND-RULES.md](../../references/GROUND-RULES.md). A question stays unanswerable → grilling is not done: keep going, or run `/al-research` when the gap is a BC behavioural fact rather than user intent. Research fails → keep grilling; write neither the term nor the ADR this session.

## Document verification

**After writing `CONTEXT.md` or a domain ADR, run the document-integrity check yourself, inline (no subagent), against [doc-integrity.md](../../references/doc-integrity.md) before handing off.** A **fail** blocks handoff — fix it or route to `/al-steer`. A **warn** rides in the handoff note. The gate checks document integrity only, never whether the domain rule is right.

## Next step

**Once the idea is grilled and any earned `CONTEXT.md` or ADR writes are integrity-checked, name the handoff.** `Next: /al-event-model` (user/API-facing feature) or `/al-design` (backend-only). Term still unsettled or a behavioural conflict unresolved → `Next: /al-research` (BC fact) or `/al-steer` (decision).

## Composition

| | |
|---|---|
| **Runs after**     | `main` (kicks off new feature) or standalone for a fuzzy term |
| **Hands off to**   | `/al-event-model` (user/API-facing features) or `/al-design` (backend-only) |
| **Replan venue**   | `/al-steer` |
| **Calls directly** | `/al-research` (BC facts) — the only skill it invokes; rubber-duck consult for ADR reconciliation per [rubber-duck-review.md](../../references/rubber-duck-review.md) |
| **Sidebands**      | `/grill-me` (interview the user) |
