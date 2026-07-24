# {App / Project name}

{One or two sentences: what this AL extension is and why it exists. Plain prose — the only narrative section.}

## Language

**Record a term only when this project narrows, extends, renames, or names something Microsoft doesn't.** Standard BC terms (Sales Header, Customer, Posting Date, Ledger Entry) are the canonical baseline and stay out; so do general programming concepts (timeouts, error types, utility patterns) even when the project uses them.

The terms here record the project-specific portion of its ubiquitous language: each states what it IS, not what it does. Behaviour belongs in code. Definitions stay independent of AL object and procedure shape. Be opinionated: when plausible synonyms exist in BC English or developer English, pick the best word and list the rest under `_Avoid_:`. The alias line stops the next contributor drifting into "transaction" when the project says **Ledger Entry**. Group terms under `###` subheadings (`### Settlement`, `### Reconciliation`) when natural clusters emerge. A single cohesive area keeps a flat list.

**{Term}**:
{One sentence. What it is, not what it does.}
_Avoid_: {alias 1}, {alias 2}

**{Term}**:
{One sentence. Define against the BC baseline when the term narrows or extends a Microsoft concept, e.g. *"A **Settlement Batch** is a `Cust. Ledger Entry` selection finalised for export; not the same as a posting batch."*}
_Avoid_: {alias}

## Relationships

**State each relationship between bold project-term names, with cardinality where obvious.** Standard BC relationships (Customer → Sales Header → Sales Line) stay out.

- A **{Term A}** produces one or more **{Term B}**.
- A **{Term B}** belongs to exactly one **{Term C}**.
- A **{Term D}** is **closed** when {one phrase}; cannot transition back.

## Example dialogue

**Include a dialogue only when it disambiguates two terms a reader could conflate.** A short exchange between developer and domain expert — a handful of turns — shows how the terms interact.

> **Dev:** "When a **{Term A}** is closed, do we automatically create the **{Term B}**?"
> **Domain expert:** "No, a **{Term B}** is only created once a **{Term C}** is confirmed, even if the **{Term A}** is already closed."
> **Dev:** "So a closed **{Term A}** with no **{Term C}** has no **{Term B}** at all?"
> **Domain expert:** "Right, and that's a valid steady state, not an error."

## Flagged ambiguities

**Record every term caught meaning two things, with its resolution — a one-line *was-conflated → resolved* record.**

- *"account"* was used to mean both **Customer** and **G/L Account**: resolved: **Customer** in the sales context, **G/L Account** in the posting context; never bare *"account"*.
- *"batch"* was used to mean both **Settlement Batch** and **Journal Batch**: resolved: distinct concepts; always qualify.

## Notes

- AppSource prefix: `{PRX}`, used on every shipped object.
- Object ID range: `{50100}–{50199}` (or whichever AppSource range is registered).
- Target BC version: {25.0+}.

## Single vs multi-context repos

**Most AL repos are a single context: one `CONTEXT.md` at the repo root, created lazily when the first term resolves.**

An extension shipping independent features with disjoint vocabularies spans multiple bounded contexts: its context map is `CONTEXT-MAP.md` at the repo root, listing the contexts, where they live, and how they relate:

```md
# Context Map

## Contexts

- [Settlement](./src/settlement/CONTEXT.md), closes settlement batches and exports to bank file
- [Reconciliation](./src/reconciliation/CONTEXT.md), matches bank statements against ledger entries

## Relationships

- **Settlement → Reconciliation**: Settlement emits `OnAfterPostSettlement`; Reconciliation consumes it to seed candidates
- **Settlement ↔ Reconciliation**: shared **Settlement No.** identity
```

Reading order: `CONTEXT-MAP.md` when present, else the root `CONTEXT.md`, else create a root `CONTEXT.md` lazily on the first resolved term. When multiple contexts exist, infer which one the current topic belongs to; if unclear, ask.
