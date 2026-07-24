# ADR template

ADRs live in `docs/adr/` under sequential numbering — `0001-slug.md`, `0002-slug.md`. The directory materialises lazily, when the first ADR is accepted.

## Short ADR (default)

**Title plus one paragraph is the whole file.**

```md
# {Short title — the decision, not the topic}

{The decision and the hinge of why. One paragraph. Linkify inline ADR references as `[ADR-NNNN](NNNN-slug.md)`.}
```

No Status / Date / Supersedes / Superseded-by metadata block, no frontmatter, and no `docs/adr/README.md` index: the filename carries the number, git carries the date, and the callout under *Supersession* carries the lifecycle.

## Longer ADR

**The longer form is earned by genuinely weighed alternatives — Considered Options and Consequences enter only when the rejected options explain the decision.**

```md
# {Short title — the decision, not the topic}

{Decision paragraph(s). Linkify inline ADR references.}

---

## Considered Options

| Option | Verdict | Reason |
|---|---|---|
| {Full option statement} | rejected | {Why this lost} |
| {Full option statement} | accepted | {Why this won} |

## Consequences

{Paragraph or bullets covering the downstream effects that later skills must surface. Linkify inline ADR references.}

## Related

- [ADR-NNNN](NNNN-slug.md): one-line on why this ADR matters here.
```

## Supersession

**The superseded ADR gains a `> [!CAUTION]` callout at the very top; the new ADR carries normally.** The callout is the supersession marker.

```md
# {Original short title}

> [!CAUTION]
> Superseded by [ADR-0009](0009-slug.md). {One phrase on what changed.}

{The original decision paragraph stays unchanged below.}
```
