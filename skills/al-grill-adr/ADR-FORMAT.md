# Architecture Decision Records

ADRs live in `docs/adr/` at the repo root, numbered sequentially by filename — `0001-slug.md`, `0002-slug.md`. The directory is created lazily, when the first ADR is accepted. There is no index file: the filename carries the number and git carries the date.

Reference another ADR by its number and title in prose (`ADR-0007 Allocation Mismatch Surfacing`), or by its `NNNN-slug.md` filename. No frontmatter, and no Status / Date / Supersedes metadata block.

## The form

Title plus one paragraph is the whole file. The title states the decision, not the topic — "Mismatches surface in-document, never as a posting log entry", not "Mismatch surfacing". The paragraph states the decision and the hinge of why; a consequence that binds later work — a constraint on task decomposition, a migration a deprecation window forces, a seam that has to stay — joins it as one line.

```md
# Mismatches surface on the document, not in a posting log

An allocation mismatch is raised on the `Sales Order` page where the Order Processor can act on it, rather than written to a posting log the role never opens. The hinge is ownership: posting hands the document back to the Order Processor on failure, so the correction happens where the document already is.
```

## Supersession

The superseded ADR gains a caution callout at the very top and its original decision paragraph stays unchanged below it. The callout is the whole supersession marker; the new ADR carries nothing special.

```md
# {Original title}

> [!CAUTION]
> Superseded by ADR-0009 {title}. {One phrase on what changed.}

{Original decision paragraph, unchanged.}
```
