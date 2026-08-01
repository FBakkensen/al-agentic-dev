# CONTEXT.md

The project's ubiquitous language: the terms this project narrows, extends, renames, or names because Microsoft has no word for it. One `CONTEXT.md` at the repo root for most AL apps, created lazily when the first term resolves. It opens with an H1 naming the app and one or two sentences on what the extension is and why it exists — the only narrative in the file.

## Language

Record a term only when the project moves it off the BC baseline. Standard BC terms — Sales Header, Customer, Posting Date, Ledger Entry — are the baseline and stay out, as do general programming concepts the project merely uses.

Each entry states what the term **is**, not what it does; behaviour belongs in code, and definitions stay independent of AL object and procedure shape. Be opinionated: where plausible synonyms exist in BC English or developer English, pick the best word and list the rest under `_Avoid_`. That line is what stops the next contributor drifting into "transaction" where the project says **Ledger Entry**.

```md
**Settlement Batch**:
A `Cust. Ledger Entry` selection finalised for export to the bank file. Not a posting batch.
_Avoid_: payment batch, export run
```

Group terms under `###` subheadings when natural clusters emerge (`### Settlement`, `### Reconciliation`). A single cohesive area keeps a flat list.

A term is also the noun of every AL name that carries it — later skills derive object, field, and procedure names from these entries rather than inventing technical ones. When a term plus the app's object-name prefix outgrows AL's 30-character object names, the design interview settles the sanctioned short form once and records it on the entry as `_As name_: Stlmt. Batch` — the one AL-shape fact an entry carries.

## Relationships

Each relationship between two bold project terms, with cardinality where it is obvious. Standard BC relationships (Customer → Sales Header → Sales Line) stay out.

```md
- A **Settlement Batch** produces one or more **Settlement Lines**.
- A **Settlement Line** belongs to exactly one **Settlement Batch**.
- A **Settlement Batch** is **closed** when its bank file is acknowledged; it cannot reopen.
```

## Example dialogue

Include one only where it separates two terms a reader could conflate. A handful of turns between developer and domain expert, showing the terms interacting.

```md
> **Dev:** "When a Settlement Batch closes, is the Reconciliation Candidate created automatically?"
> **Domain expert:** "No — only once the bank acknowledgement arrives, even if the batch closed days earlier."
> **Dev:** "So a closed batch with no acknowledgement has no candidates at all?"
> **Domain expert:** "Right, and that is a valid steady state, not an error."
```

## Notes

The facts every later skill needs and none can infer: the AppSource object-name prefix used on every shipped object, the registered object ID range, and the target BC version.

## Multi-context repos

An extension shipping independent features with disjoint vocabularies spans several bounded contexts. Then the root file is `CONTEXT-MAP.md`, listing each context, the folder its own `CONTEXT.md` sits in, and how the contexts relate — the events one publishes for another, and any shared identity.

Reading order: `CONTEXT-MAP.md` when it exists, otherwise the root `CONTEXT.md`, otherwise create a root `CONTEXT.md` on the first resolved term. With several contexts, infer which one the current topic belongs to, and ask when it is unclear.
