---
name: al-codebase-design
description: Use whenever /mattpocock-skills:codebase-design runs against AL code.
---

# al-codebase-design - BC shapes for deep modules

In: `/mattpocock-skills:codebase-design` running against AL code, consulted by a developer, `/mattpocock-skills:tdd`, or `/mattpocock-skills:improve-codebase-architecture`. The entry skill owns the deep-module vocabulary; this addition supplies the Business Central shapes, the platform precedent, and the AL seam rule. It needs no work item.

## Speak in BC shapes

Start from the canonical shape the concept belongs to:

- master data with entries
- a document
- a journal with posting
- setup
- dimensions

Another verified Base App precedent can stand in when none fits.

▶ sonnet · shape survey: how the Base App models the concept — tables, seams, events — read in .bcapps/release, clone through /al-clone-bcapps when absent → table of table, seam, event, file:line

Every BC object, table, field, procedure, event, or enum value named here, in the survey and in `docs/patterns.md`, comes from a lookup in this session. Reach for the platform before designing custom structure, and write BC vocabulary: Insert, Post, Validate, Ledger Entry, codeunit, procedure.

## Seams

An AL interface with one implementation is a hypothetical seam; leave it out until a second implementation exists.

## Patterns upkeep

When the Consumer repository gains its first example of a shape, record that shape in `docs/patterns.md`: the shape, the objects that realize it, and the precedent row it follows. Later examples of a recorded shape add nothing.

## Close

The pass ends when the concept has one named shape, each seam has two real implementations or is dropped, and `docs/patterns.md` records any first example. When `docs/patterns.md` changed:

▶ haiku · /al-commit the complete worktree — the `docs/patterns.md` change and the rest → commit hashes and subjects, remaining worktree

Return the shape and the survey table to the entry skill that called.
