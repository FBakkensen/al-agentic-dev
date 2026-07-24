---
name: al-scope
description: Decompose `architecture.md` into a slice-grouped task list in the `tasks/` folder for AL/Business Central, with one verification task per slice when `event-model.md` is present. Use after `/al-design`, before `/al-provision` on the bracketed `T-001` task.
---

# /al-scope, architecture.md → task list

Decompose `architecture.md` into `specs/<NNN>-<slug>/tasks/`: a `000-feature.md` header plus one file per task, grouped by slice.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, run `/al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/architecture.md` exists. Missing → **Stop**, run `/al-design`.
- User/API-facing features carry `event-model.md` alongside; backend-only features carry `architecture.md` only.
- [task-lifecycle.md](../../references/task-lifecycle.md) owns the `tasks/` folder shape — file naming, frontmatter fields, the status lifecycle, and the surgical-edit floor. Read it, and pattern-match against [examples/tasks/](../../references/examples/tasks/), before writing.

## What goes into the tasks/ folder

- **`000-feature.md`**: lift the Goal from the `event-model.md` journey (user/API-facing) or the `architecture.md` trigger-source (backend-only). Write the per-slice intent as prose.
- **Context only**: each task file carries surface, dependency rationale, constraints, risks, source context, and acceptance intent as prose. `/al-refine` owns and writes fresh every `Test Specification` and `Verification Plan` — `New and Modified Objects`, AAA cases, `Decision Matrix`, `Journey` / `Contract Examples`, `Exploration Charters` — and decides per task which of those apply. Pre-write none of them; prescribe no new objects, procedures, assertions, or payloads. Existing objects, pages, events, APIs, and fields may be named as source context.
- **Slice grouping**: every task carries `slice:`. Take the slug from the `event-model.md` timeline step (user/API-facing) or the `architecture.md` slice (backend-only) the task belongs to.
- **Verify tasks**: when `event-model.md` is present, every slice closes with one `kind: verify` task on the same `slice:`, `depends_on:` every technical task in the slice. Backend-only features have no user/API surface, so no verify tasks.
- **Bracketing ops tasks**: always emit both. `T-001` `kind: provision` `slice: provision` first; `kind: breaking-change` `slice: breaking-change` last. Neither carries a `Test Specification` or `Verification Plan` — run-and-flip. Emit the breaking-change task even when detection is off; `/al-validate-breaking-changes` self-skips.
- **Edges**: source every `depends_on:` / `refactors:` / `fixes:` edge now, from the architecture's slices, module map, and brownfield touchpoints. Titles alone cannot reconstruct them later. Cross-slice gate: slice N+1's first technical task carries `depends_on:` slice N's verify task. Backend-only, the gate points at slice N's last technical task. No mermaid fence: spec artifacts are pure markdown, text-only.
- **Scaffolding context**: permission, caption, translation, and packaging constraints bundle into the task that needs them. Name the constraint, not a code shape.

## Ordering

Every task ships its tests and production code together — TDD granularity.

A slice is a vertical slice the user can exercise end-to-end. One task crosses the slice's trigger. The slice's other technical tasks compose into it. The trigger-crossing task is what the verify task signs off.

Inside a slice: decision-logic tasks first, BC wiring second, page/API surface last, the verify task last. Shape decision logic so its tests land at the unit tier — see [test-layout.md](../../references/testing/test-layout.md). A component two slices need belongs to the first slice that needs it.

Across slices, follow `event-model.md` timeline order (or `architecture.md` slice declaration order, backend-only) so the user verifies slice A end-to-end before slice B.

## Status at scope time

`/al-scope` writes only `ready` and `blocked`. `T-001` provision opens `ready`. Every other task opens `blocked` behind its gate: first-slice technical tasks on `depends_on: [T-001]`, later-slice technical tasks, verify tasks, breaking-change. Every task emitted `blocked` gets its `blocked-on:` line in the same write. Write no `phase:` line. Downstream skills own every other flip ([task-lifecycle.md](../../references/task-lifecycle.md)).

## Descriptions

Lede first: the BC site (object, procedure, field) plus the invariant the task preserves or the contract it ships. Cite ADRs inline as `[ADR-NNNN](../../../docs/adr/NNNN-slug.md)`. `/al-refine` may rewrite a description after walking the codebase.

A verify-task description names the slice's user-facing outcome in `event-model.md` vocabulary — Role, Action, Business Event, View, Status. AL names live in the technical tasks it depends on.

## Replan check before writing

A question `architecture.md` cannot answer, or a gap decomposition surfaces that it does not cover — a missing module, a pattern conflict, an unnamed brownfield touchpoint, a slice absent from `event-model.md` — stops the write: **Stop**, run `/al-steer`. Inventing the answer here corrupts every downstream skill invisibly.

## Document verification

Between writing the folder and the close, run the document-integrity check yourself, inline, no subagent: the `tasks/` profile in [doc-integrity.md](../../references/doc-integrity.md). A **fail** blocks the close and the `/al-refine` handoff — fix it or route to `/al-steer`. A **warn** rides in the close. The check judges structure only, never whether the decomposition is optimal.

## Next step

Close with the task-close gate report ([GROUND-RULES.md](../../references/GROUND-RULES.md) House shapes). The report gives the user the evidence for the greenlight call on `/al-provision T-001`, the only `ready` task after scope. It names the slices, the verify-task count (or *none, backend-only*), the dependency shape (linear or branching), and the feature Goal in user terms. The folder landed with no integrity fail → `Next: /al-provision T-001`. `/al-refine` follows once provision opens the first slice. A gap `architecture.md` could not answer halted the write → `Next: /al-steer`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-design` (architecture.md), `/al-event-model` for user/API-facing (event-model.md source for slice slugs and Goal) |
| **Hands off to**   | `/al-provision` (`T-001`), then `/al-refine` once the first slice opens (one task at a time, technical or verify) |
| **Replan venue**   | `/al-steer` (gap surfaced during decomposition) |
| **Sidebands**      | `/al-research` (non-trivial BC areas), `bc-standard-reference` (BaseApp grounding) |
