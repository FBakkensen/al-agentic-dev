# The shape of event-model.md

Markdown only — no HTML, no images, no diagram syntax. Names are the citation: an object, page, or field appears by name, never with a file path or line number.

1. `# <Feature>: <Journey>` — titled for what the user does, not for the module.
2. Two or three sentences: what the journey enables or catches, how many Roles cooperate, how long the chain is.
3. A borderless two-column pointer table — Slug, ADR, Architecture, Tasks — as plain text, no links; omit a row whose artifact does not exist yet.
4. `## Roles` — one paragraph naming each Role in bold, its kind (human, system actor, API consumer), and what it owns.
5. `## Chain` — one `###` per Role in the order that Role first acts, each holding a four-column table: Action, Business Event, View, Status. One row per step, in temporal order, `—` where the step flips no Status. A Role that acts twice, before and after another Role, takes two `###` sections rather than one out-of-order table.
6. One `##` per branch, headed by its condition. Name the Business Event that fires instead, what the observer sees, which Role ends up holding the document, and what does not happen.

---

# Sales Document Posting: Item Charge Allocation Validation

The journey catches item charge allocation mismatches at posting time, before an invoice exists. Two Roles cooperate across one five-step chain.

| | |
|---|---|
| **Slug** | sales-charge-validation |
| **ADR** | ADR-0007 |
| **Architecture** | architecture.md |
| **Tasks** | tasks/ |

## Roles

The **Order Processor**, a human, releases the document and starts posting. The **Posting Engine**, a BC system actor, owns the document once posting starts.

## Chain

### Order Processor (Human)

| Action | Business Event | View | Status |
|---|---|---|---|
| Release Sales Order | Sales Order Released | Sales Order page | Sales Header Status → Released |
| Post Sales Order | Posting Started | Posting Progress | — |

### Posting Engine (System)

| Action | Business Event | View | Status |
|---|---|---|---|
| Validate Item Charge Allocation | Item Charge Allocation Validated | Posting Progress | — |
| Post Sales Invoice | Sales Invoice Posted | Posted Sales Invoice | — |
| Record Allocation Audit Trail | Allocation Ledger Entry Recorded | Allocation Ledger Entries, drill-down from the Posted Sales Invoice | — |

## Branch: allocation mismatch

A mismatch raises *Item Charge Allocation Mismatch Found* instead of *Item Charge Allocation Validated*. The chain returns to the Sales Order page with the allocation breakdown surfaced inline, and the Order Processor owns the document again. The Sales Order stays Released, and no Posted Sales Invoice exists.
