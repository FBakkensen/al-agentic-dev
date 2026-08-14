---
name: al-next
description: "Names the open moves in plain language. Use when a session picks a feature back up, or when the user asks what is next or what is blocked."
---

# al-next

Read the state, name the move, stop. This skill writes nothing. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## No work-item tree yet

The entry chain runs in one session: `/al-grill-adr` → `/al-event-model` (backend-only skips it) → `/al-design` → `/al-scope`. Landing here is a resumed session — name the step after the last artifact present; every entry-chain move wants a frontier-class model, so say so beside it:

- No `CONTEXT.md` at the repo root → `/al-grill-adr`.
- `CONTEXT.md` present, no `event-model.md` → `/al-event-model` — or `/al-design` once the user confirms backend-only (no human, no API consumer). New vocabulary in this feature reopens `/al-grill-adr` first.
- No `architecture.md` → `/al-design`.
- `architecture.md` present but no `al-ado.json` binding at the repo root → the move is binding the repo first: the user fills `organization`, `project`, `rootWorkItemId`, and `areaPath` per `/al-routing`'s schema, then `/al-scope`.
- Binding resolved, no `al-pipeline` item under the bound root → `/al-scope`.

## The tree exists

The Azure DevOps work-item tools answer everything from here — see the README note when they are absent, and stop with that message. Load `/al-routing` — it owns the schema, the ladder, the gates, the sweeps, and the derivations. Run its level-by-level one-hop sweep and batch read through `azure-devops-wit_query` and `azure-devops-wit_work_item`; no repo file carries task state. Present the moves the way `/al-routing` prescribes.

Asked what is blocked: per task, name the open Predecessor or the holding gate in the feature's own object, table, and field names — a task carrying `al-question` names the question waiting on the user, from its newest comment — and close with the one thing whose settling opens the most. A feature whose items are all closed points at a fresh idea through `/al-grill-adr`.

Outcome: the viable move(s), each glyphed with the state behind it — `▶` ready, `⛔` blocked, `✅` done.
The user runs the skill named.
