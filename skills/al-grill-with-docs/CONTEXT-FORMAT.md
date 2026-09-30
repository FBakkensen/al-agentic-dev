# CONTEXT.md in an AL app

`/mattpocock-skills:domain-modeling`'s format holds, with three BC deltas.

## The BC baseline

Standard BC terms — Sales Header, Customer, Posting Date, Ledger Entry — and standard BC relationships — Customer → Sales Header → Sales Line — are the baseline and stay out. A term enters when the project narrows, extends, or renames one, or names what BC has no word for.

## `_As name_:`

A term is the noun of every AL name that carries it; object, field, and procedure names derive from the entry. When the term plus the app's object-name prefix outgrows AL's 30-character object names, settle the short form once with the user and record it on the entry — the one AL-shape fact an entry carries.

```md
**Settlement Batch**:
A `Cust. Ledger Entry` selection finalised for export to the bank file. Not a posting batch.
_Avoid_: payment batch, export run
_As name_: Stlmt. Batch
```

## Notes

A `## Notes` section after Language holds the facts every later skill needs and none can infer: the AppSource object-name prefix used on every shipped object, the registered object ID range, and the target BC version.
