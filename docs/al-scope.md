# al-scope

## What it is for

Cuts `architecture.md` into a task list. The architecture says what gets built; the task list says in what order, behind which dependency edges, and where one task stops.

Tasks are grouped into slices — vertical slices you can exercise end to end — and the whole feature is bracketed by two ops tasks.

## When you reach for it

- The feature branch has `architecture.md` and no `tasks/` folder yet.
- You want a designed feature broken into units of work.

A gap the architecture cannot answer — a missing module, a pattern conflict, an unnamed brownfield touchpoint — stops the write and goes back to [`/al-design`](al-design.md). Answered here, it corrupts every downstream skill invisibly.

## What it produces

`specs/<NNN>-<slug>/tasks/`, where the filenames carry the order and there is no index file:

- `000-feature.md` — the Goal in user terms plus one paragraph of intent per slice.
- `NNN-T-MMM-<slug>.md`, one per task. `NNN` is the execution-order prefix, gapped by 10 so you can insert between two tasks. `T-MMM` is a stable id that is never reused and never renumbered.

Each task file is frontmatter per `/al-routing`'s schema (structural fields only — every task opens open with its dependency edges), a title, and a description paragraph — the body is deliberately left for [`/al-refine`](al-refine.md) to write. Blocked and ready are derived from the edges at read time, never written.

Every feature is bracketed: a `kind: provision` task first, a `kind: breaking-change` task last. Where `event-model.md` is present, every slice also closes with a `kind: verify` task.

The task body shape ships as `TASK-FORMAT.md` inside the skill.
