---
name: al-next
description: "Names the open moves in plain language. Use when a session picks a feature back up, or when the user asks what is next or what is blocked."
---

# al-next

Read the state, name the move, stop. The user takes the step. This skill writes no file. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## No tasks folder yet

The entry chain runs in one session: `/al-grill-adr` → `/al-event-model` (backend-only skips it) → `/al-design` → `/al-scope`. Landing here is a resumed session — name the step after the last artifact present:

- No `CONTEXT.md` at the repo root → `/al-grill-adr`.
- `CONTEXT.md` present, no `event-model.md` → `/al-event-model` — or `/al-design` once the user confirms backend-only (no human, no API consumer). New vocabulary in this feature reopens `/al-grill-adr` first.
- No `architecture.md` → `/al-design`.
- `architecture.md` present, no `tasks/` → `/al-scope`.

## Tasks exist

Load `/al-routing` — it owns the frontmatter schema, the ladder, the gates, and the derivations. Read every task file's frontmatter in the feature's `specs/<NNN>-<slug>/tasks/`, plus `000-feature.md` for the Goal, then apply `/al-routing`'s derivations and present the moves the way it prescribes.

Asked what is blocked: per task, name the open dependency or the holding gate in the feature's own object, table, and field names, and close with the one thing whose settling opens the most. A closed feature's next move is a fresh idea at `/al-grill-adr`.

Outcome: the viable move(s), each with the state behind it.
The user runs the skill named.
