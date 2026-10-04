---
name: al-codebase-design
description: Use whenever /mattpocock-skills:codebase-design runs against AL code.
---

# al-codebase-design - BC shapes for deep modules

In: `/mattpocock-skills:codebase-design` running against AL code, consulted by a developer, `/mattpocock-skills:tdd`, `/mattpocock-skills:improve-codebase-architecture`, or `/al-to-spec`. The entry skill owns the deep-module vocabulary; this addition supplies the Business Central shapes, the platform precedent, and the AL seam rule. It needs no work item and writes no repo file.

## Speak in BC shapes

Start from the canonical shape the concept belongs to:

- master data with entries
- a document
- a journal with posting
- setup
- dimensions

Every BC name shown or written here comes from a lookup in this session. Reach for the platform before designing custom structure, and write BC vocabulary: Insert, Post, Validate, Ledger Entry, codeunit, procedure.

When the consultation names a concept or candidate, survey the platform for it. A consultation for vocabulary only gets the shape list and the grounding rule, with no survey.

▶ sonnet · shape survey: how the Base App models <the named concept, in the caller's words> — tables, seams, events — read in .bcapps/release, clone through /al-clone-bcapps when absent → table of table, seam, event, file:line

## Seams

A module is a namespace carved out of a feature cluster as a child namespace. Its root namespace is its interface: the codeunits callers call, plus the tables, pages, and enums callers use. `<module>.Internal` holds its internals, and folder path equals namespace. The cluster's parent namespace is open code, and so is everything outside a module. Design a seam as a module interface.

An AL interface with one implementation stays out unless a second implementation or a stable external contract proves the seam. An extensible enum plus an interface that other apps implement is such a contract.

## Close

For a named concept, the pass ends when it has one named shape backed by the survey table. Return that shape, the table, and one proposed `docs/patterns.md` row — shape, the objects expected to realize it, the survey's Base App precedent (object and file:line) it follows — to the entry skill that called. `/al-to-spec` persists the precedent in the module's black box, and `/al-implement` records the row once the objects exist.
