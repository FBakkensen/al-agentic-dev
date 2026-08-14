---
name: al-grill-adr
description: Interview to settle a feature's domain vocabulary in CONTEXT.md and record hard-to-reverse business rules as ADRs. The pipeline entry — run it on a fresh AL/Business Central feature idea.
disable-model-invocation: true
---

# Grill the domain

Interview the user about what the business does until the vocabulary is unambiguous, and record the rules that would be expensive to change later. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch — then proceed.

Writes `CONTEXT.md` at the repo root and accepted ADRs under `docs/adr/`. Reads production, test, and app code to expose conflicts and leaves it unchanged. `event-model.md`, `architecture.md`, and the `tasks/` folder belong to later skills.

## The interview

Ask one question per message: one line naming what the answer locks in, then the question, then lettered options of one line each, the recommendation first and marked. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

- **A fact is answered, not asked.** Grep the workspace, read the official BC documentation through the microsoft-learn tools (microsoft_docs_search, microsoft_docs_fetch), say what you found, move on.
- **A strategic decision is asked.** Strategic means `CONTEXT.md` or an ADR locks it in and the next skill consumes it.
- **A tactical decision is made and named in one line** — where an entry sits, which of two equivalent phrasings lands. Naming it is what makes it overridable.
- **Write each answer down the moment it resolves.** Mid-session `CONTEXT.md` is working state: reorder it, leave it half-built. Batching an hour of settled answers into one write at the close loses the hour to compaction.
- **Escalate to /al-grilling when the answer itself needs pressure** — a requirement that shifts each time it is restated, a preference with no reason under it, a scope claim that would commit the feature. Carry what it surfaces back into the interview.

## What to ask

- **Which term here means two things?** Record what this project narrows, extends, renames, or names that Microsoft doesn't: one sentence on what it *is*, plus the aliases it displaces.
- **Which concrete BC scenario forces a boundary to be precise?** Partial posting, reversal, correction, dimension inheritance, multi-company, an AppSource constraint.
- **What is the user not asking because they don't know to ask it?** Name the adjacent BC behaviour or standard pattern they show no sign of having considered, and let them decide whether it matters. An unclaimed one is where the implementation guesses later.
- **Where does the stated behaviour disagree with the code?** Read the code where it can answer; ask the user what code cannot tell — intent, direction, why a constraint exists. Name the conflict and leave the resolution to them.

Speak BC throughout: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, No. not ID. Every object, table, field, procedure, event, or enum name landing in `CONTEXT.md` or an ADR comes from a lookup made in this session — recall is not evidence.

The thread is done when nothing is left to decide: every question it surfaced is answered in `CONTEXT.md` or an ADR, explicitly parked, or ruled out of scope — and the user confirms it.

## When a rule earns an ADR

Offer one inline, inside the question it came out of, when all four hold:

- hard to reverse — shipped data, a partner integration, a behavioural contract
- surprising to a reader who lacks the context
- a real trade-off, with alternatives someone could reasonably have picked
- domain — a rule about what the business does, rather than how the code is shaped

Three of four earns none: say so in one line and keep going. A question that feels architectural has a domain constraint behind it; grill that one and leave the shape to /al-design.

Where the fork is genuinely open, build out one complete ADR candidate per option and present them together for the user to pick.

Accepted lands as `docs/adr/NNNN-slug.md`, taking the lowest number unused on this branch and on main. The shapes are [ADR-FORMAT.md](ADR-FORMAT.md) and [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md).

## Close

Name what settled: the terms now in `CONTEXT.md`, and any ADR accepted.
A done thread goes up as a steering surface through /al-visualize — each term with the aliases it displaces, each accepted ADR settled.
Commit what this run wrote — `CONTEXT.md` and any accepted ADR — with a plain descriptive message; a stop mid-interview commits what settled the same way.
Then continue in this session with /al-event-model — backend-only features go straight to /al-design.
