---
name: al-scope
description: Decompose a settled architecture.md into the slice-grouped work-item tree the rest of the pipeline runs on. Run it after al-design, before any task runs.
disable-model-invocation: true
---

# Scope a feature into work items

`architecture.md` says what gets built. The work-item tree under the customer's root work item says in what order, behind which edges, and where one task stops.

## Before you write

Load `/al-routing` — it owns the work-item schema, and your write is creation only: the structural shape and each item's opening state come from that schema, and every later transition is `/al-routing`'s write, never yours. Entry checks, a stop naming the missing one: the Azure DevOps work-item tools are available — see the README note; the `al-ado.json` binding resolves and the branch carries the bound root id as `ab<rootId>`; the feature's `architecture.md` exists in its `specs/` folder — missing, name `/al-design`. An `event-model.md` beside it means the feature is user/API-facing; `architecture.md` alone means backend-only. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch — then proceed.

Every BC name you put in a work item — table, field, procedure, event — comes from a lookup in this session rather than recall. BC vocabulary in every line you write: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, codeunit not class, procedure not method.

## The interview

Ask one question per message, land each slice's work items as that slice settles, and where a fork stands open, build out the affected slice's full task list per candidate, edges included, before asking. A contested slice order or dependency shape may go to the user as a steering surface through `/al-visualize`. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

- **Where does one task end?** A task lands one behaviour with the tests that prove it. Two behaviours in one task hide one of them from its own red.
- **Which slice ships first?** `event-model.md` timeline order — or `architecture.md` slice order, backend-only — is the default. Ask only where two slices are genuinely independent, because that answer decides what the user can exercise soonest.
- **Which dependency edge is real?** Source every edge from the architecture. Ask only where the evidence leaves two credible sequences standing: a false edge serialises work that could land together, a missing one opens a task before its ground exists.
- **Which constraint never reached the architecture?** Permission, caption, translation, packaging, rollout order. Bundle each into the task that needs it, named as a constraint rather than a code shape.

A gap `architecture.md` cannot answer — a missing module, a pattern conflict, an unnamed brownfield touchpoint, a slice absent from `event-model.md` — stops the write. Name the gap and hand it back to `/al-design`; answered here, it corrupts every downstream skill invisibly.

## What lands in the tree

Creation goes through `wit_work_item_write` under the binding's `areaPath`, every dependency edge through `wit_work_item_link_write` as a Predecessor/Successor link — the edges are the sole encoding of order, so a task inserts between two by relinking:

- The `Design` User Story — its Description opens with the Goal in user terms, lifted from the `event-model.md` journey or the `architecture.md` trigger source, then carries the settled `architecture.md` and, when present, `event-model.md`, so the consultant reads the feature's shape where the work lives.
- One User Story per vertical slice — Description is the slice contract in user terms, `Microsoft.VSTS.Common.AcceptanceCriteria` the slice's behaviour checks in `event-model.md` vocabulary (Role, Action, Business Event, View, Status).
- One Task per pipeline task, child of its slice story — a title naming the behaviour, a description paragraph, and the kind, tier, and slice tags per `/al-routing`'s schema; the ops tasks take the mechanical tier, their work is scripted. The task body belongs to `/al-refine`; existing objects, pages, events, APIs, and fields may be named as source context.

## Slices, order, brackets

A slice is a vertical slice the user can exercise end-to-end. One task in it crosses the slice's trigger and the others compose into that one; inside the slice, decision logic comes first, BC wiring second, page or API surface last, the verify task after all of them. A component two slices need belongs to the first slice that needs it.

Bracket the feature every time: provision → clone-bcapps → clone-bcquality as three Predecessor-chained Tasks under the Design story first, and one breaking-change Task there last, Successor of the final feature task — created even where detection is off, and last of all.

When `event-model.md` is present, every slice closes with one verify task on that slice, Successor of every technical task in the slice, and slice N+1's first technical task takes a Predecessor link to slice N's verify task. Backend-only, that cross-slice edge points at slice N's last technical task.

The write ends when every `event-model.md` timeline step — or, backend-only, every `architecture.md` slice — appears as a slice story carrying its `al-slice-<slug>` tag, and both ops brackets hang in the tree.

## Descriptions

Lede first: the BC site — object, procedure, field — plus the invariant the task preserves or the contract it ships. Cite an ADR by id, `ADR-0007`, never by path. A verify task's description names the slice's user-facing outcome in `event-model.md` vocabulary and leaves AL names to the technical tasks it precedes.

## Re-entry on a scoped tree

A tree already fully scoped means the architecture was reshaped over settled work items: reconcile instead of create. Re-source every dependency link against the reshaped `architecture.md`, create the new tasks the new map needs, and put to the user, one question each: an unstarted task whose module the map no longer carries is retired on their yes — named as an outcome to `/al-routing`, whose write it is — and a finished task the new map contradicts takes their ruling: the landed work stays as it is, or a new task per the schema unwinds or reworks it.

## Close

A fully scoped tree first goes blind through `/al-spec-review` — the tree read back through `wit_work_item` and `wit_query`, `architecture.md`, `event-model.md` when present, and the interview's settled answers as locked constraints; its findings land per that skill's disposition before the tree stands.
Name what landed: the slices, the task and verify-task counts (or *none, backend-only*), whether the dependency shape is linear or branching, and the Goal in user terms.
The tree goes up as a steering surface through `/al-visualize` — what ships, and in what order.
Then `/al-routing` presents the opening move.
