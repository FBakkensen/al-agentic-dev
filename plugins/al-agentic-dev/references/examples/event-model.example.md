# Sales Document Posting: Item Charge Allocation Validation

The user-facing journey catches item charge allocation mismatches at posting time. Two Roles cooperate across one five-step chain.

| | |
|---|---|
| **Slug**         | sales-charge-validation |
| **ADR**          | ADR-0007 |
| **Architecture** | [architecture.example.md](./architecture.example.md) |
| **Tasks**        | [tasks/](./tasks/) |

## Roles

The **Order Processor**, a human, releases the document and triggers posting. The **Posting Engine**, a BC system actor, owns the document once posting starts.

## Chain

### Order Processor (Human)

| Action | Business Event | View | Status |
|---|---|---|---|
| Release Sales Order | Sales Order Released | Sales Order page | Status → Released |
| Post Sales Order | Posting Started | Posting Progress | — |

### Posting Engine (System)

| Action | Business Event | View | Status |
|---|---|---|---|
| Validate Item Charge Allocation | Item Charge Allocation Validated | Posting Progress | — |
| Post Sales Invoice | Sales Invoice Posted | Posted Sales Invoice | — |
| Record Allocation Audit Trail | Allocation Ledger Entry Recorded | Allocation Ledger Entries, drill-down from the Posted Sales Invoice | — |

## Branch on validation failure

A mismatch raises *Item Charge Allocation Mismatch Found* instead of *Item Charge Allocation Validated*. The chain returns to the Sales Order page, with the allocation breakdown surfaced inline. Ownership of the document returns to the Order Processor. The Sales Order stays Released, and no Posted Sales Invoice exists.
