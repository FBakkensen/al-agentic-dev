# al-scope

## What it is for

Cuts the Design User Story into the work-item tree. The Design page says what gets built; the tree under the customer's root work item says in what order, behind which dependency edges, and where one task stops.

Tasks are grouped into slices — vertical slices you can exercise end to end — and the whole feature is bracketed by the ops tasks.

## When you reach for it

- The Design story has a Modules section and there are no slice stories under the bound root yet.
- You want a designed feature broken into units of work.

A gap the Design page cannot answer — a missing module, a pattern conflict, an unnamed brownfield touchpoint — stops the write and goes back to [`/al-design`](al-design.md). Answered here, it corrupts every downstream skill invisibly.

## What it produces

A work-item tree in Azure DevOps under the customer's root work item (`al-ado.json` names the binding):

- The `Design` User Story already exists — this skill does not create a second one, and slice stories do not copy its sections.
- One User Story per vertical slice — the slice contract in its Description, pointing at the Design story, the behaviour checks in happy-path vocabulary as acceptance criteria, and the slice branch it ships from.
- One Task per unit of work, child of its slice story, every dependency edge a Predecessor/Successor link. The edges are the sole encoding of order; blocked and ready are derived from them, never written.

A task lands with a title and one description paragraph — the body is deliberately left for [`/al-refine`](al-refine.md) to write.

Every feature is bracketed: provision → clone-bcapps → clone-bcquality chained first, a breaking-change task last. Where a happy path is present, every slice also closes with a verify task.
