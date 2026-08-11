---
name: al-scope
description: Decompose a settled architecture.md into the slice-grouped, ordered tasks/ folder the rest of the pipeline runs on. Run it after al-design, before any task runs.
disable-model-invocation: true
---

# Scope a feature into tasks

`architecture.md` says what gets built. The `tasks/` folder says in what order, behind which edges, and where one task stops.

## Before you write

The branch matches `^\d{3}-` and `specs/<branch>/architecture.md` exists; missing either, say which one and name `/al-design`. An `event-model.md` beside it means the feature is user/API-facing; `architecture.md` alone means backend-only. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch — then proceed.

Every BC name you put in a task — table, field, procedure, event — comes from a lookup in this session rather than recall. BC vocabulary in every line you write: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, codeunit not class, procedure not method.

## The interview

Ask one question per message, land each slice's files as that slice settles, and where a fork stands open, build out the affected slice's full task list per candidate, edges included, before asking. A contested slice order or dependency shape may go to the user as a steering surface through `/al-visualize`. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

- **Where does one task end?** A task lands one behaviour with the tests that prove it. Two behaviours in one task hide one of them from its own red.
- **Which slice ships first?** `event-model.md` timeline order — or `architecture.md` slice order, backend-only — is the default. Ask only where two slices are genuinely independent, because that answer decides what the user can exercise soonest.
- **Which dependency edge is real?** Source every edge from the architecture. Ask only where the evidence leaves two credible sequences standing: a false edge serialises work that could land together, a missing one opens a task before its ground exists.
- **Which constraint never reached the architecture?** Permission, caption, translation, packaging, rollout order. Bundle each into the task that needs it, named as a constraint rather than a code shape.

A gap `architecture.md` cannot answer — a missing module, a pattern conflict, an unnamed brownfield touchpoint, a slice absent from `event-model.md` — stops the write. Name the gap and hand it back to `/al-design`; answered here, it corrupts every downstream skill invisibly.

## What lands in tasks/

- `000-feature.md` — the Goal in user terms, lifted from the `event-model.md` journey or the `architecture.md` trigger source. Prose only — state and order live in the task files.
- `NNN-T-MMM-<slug>.md`, one per task. `NNN` is the execution-order prefix, gapped by 10 (`010`, `020`, `030`) and the sole encoding of order — insert between two tasks by taking a gap.

A task file is frontmatter, an H1 title, then a description paragraph — that is your whole write; existing objects, pages, events, APIs, and fields may be named as source context. The body belongs to `/al-refine`, whose format file governs its shape.

## Frontmatter

Load `/al-routing` — it owns the task-state schema. Your write sets the structural fields it declares — `task:`, `kind:`, `slice:`, `depends_on:` — and opens every task per that schema, stamping each task's tier as that schema defines it; the ops brackets take mechanical, their work is scripted. The lifecycle stamps arrive later and are `/al-routing`'s writes, never yours.

## Slices, order, brackets

A slice is a vertical slice the user can exercise end-to-end. One task in it crosses the slice's trigger and the others compose into that one; inside the slice, decision logic comes first, BC wiring second, page or API surface last, the verify task after all of them. A component two slices need belongs to the first slice that needs it.

Bracket the feature with both ops tasks every time: `T-001` `kind: provision` `slice: provision` first, `kind: breaking-change` `slice: breaking-change` last and depending on the final feature task. Emit the breaking-change task even where detection is off, and write its file last of all. Each carries its description and stops there.

When `event-model.md` is present, every slice closes with one `kind: verify` task on that `slice:`, `depends_on:` every technical task in the slice, and slice N+1's first technical task depends on slice N's verify task. Backend-only, that cross-slice edge points at slice N's last technical task.

The write ends when every `event-model.md` timeline step — or, backend-only, every `architecture.md` slice — appears as a `slice:` value in `tasks/`, and both ops brackets are on disk.

## Descriptions

Lede first: the BC site — object, procedure, field — plus the invariant the task preserves or the contract it ships. Cite an ADR by id, `ADR-0007`, never by path. A verify task's description names the slice's user-facing outcome in `event-model.md` vocabulary — Role, Action, Business Event, View, Status — and leaves AL names to the technical tasks it depends on.

## Re-entry on a scoped folder

A folder already fully scoped means the architecture was reshaped over settled tasks: reconcile instead of create. Re-source every `depends_on:` edge against the reshaped `architecture.md`, write the new tasks the new map needs, and put to the user, one question each: an open task whose module the map no longer carries is deleted from `tasks/` on their yes — git history is the archive — and a `done` task the new map contradicts takes their ruling: the landed work stays as it is, or a new task per the schema unwinds or reworks it.

## Close

A fully scoped folder first goes blind through `/al-spec-review` — the folder, `architecture.md`, `event-model.md` when present, and the interview's settled answers as locked constraints; its findings land per that skill's disposition before the commit.
Name what landed: the slices, the task and verify-task counts (or *none, backend-only*), whether the dependency shape is linear or branching, and the Goal in user terms.
A fully scoped folder goes up as a steering surface through `/al-visualize` — what ships, and in what order.
Commit the `tasks/` folder with a plain descriptive message; a write stopped on a gap commits the slices already landed the same way.
Then `/al-routing` presents the opening move.
