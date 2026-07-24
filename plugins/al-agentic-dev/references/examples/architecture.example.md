# Item charge allocation, validated at posting

The feature intercepts BaseApp's posting write path at exactly one place — event subscribers on `Sales-Post` codeunit 80. Its remaining BaseApp surface is reads and pageextensions; the Brownfield touchpoints table carries the inventory.

| | |
|---|---|
| **Slug**        | sales-charge-validation |
| **ADR**         | ADR-0007 Allocation Mismatch Surfacing — the in-document mismatch surface and audit policy |
| **Event model** | [event-model.example.md](./event-model.example.md) |
| **Tasks**       | [tasks/](./tasks/) |

## Goal

Catch item charge allocation mismatches at posting before the invoice posts, surface the cause inline on the document, and record one `Allocation Ledger Entry` per resolved allocation, tied to its source line.

## Module map

| Module | Responsibility |
|---|---|
| `Charge Validation` (new, `src/ChargeValidation/`) | Reads `Item Charge Assignment (Sales)`. Decides allocation balance from the read rows. No BaseApp write. |
| `Charge Post Subscribers` (new, `src/ChargePostSubscribers/`) | Writes through the brownfield touchpoint in `Sales-Post` codeunit 80. |

## Decision logic and test surfaces

Reads sit on the released document. `Charge Validation` uses `Get` to read the `Sales Header` by `No.`. It iterates the `Sales Line` rows it owns. It resolves each related `Item Charge Assignment (Sales)`. Reads never reach outside the document.

Processing is pure. `Charge Validation` takes the read rows. It decides allocation balance per charge against its receiving lines. It runs no `Insert` or `Modify`. It returns balanced or mismatch with the imbalance quantity, reproducible from its inputs. This pure decision is the unit-test surface.

Writes go through BaseApp. `Charge Post Subscribers` subscribes to `OnAfterCheckSalesDoc` from `Sales-Post`. It calls `Charge Validation`. On success, posting proceeds. On mismatch, `Error` aborts posting. `Charge Post Subscribers` uses `Insert` to write `Allocation Ledger Entry` rows through `Sales-Post`.

## Brownfield touchpoints

| Object | Kind | Touch |
|---|---|---|
| `Sales-Post` codeunit 80 | Event source | Subscribe; never modify. |
| `OnAfterCheckSalesDoc` | Event subscriber | Run `Charge Validation`, raise `Error` on mismatch. |
| `Sales Header`, `Sales Line` | Tables | Read the released document; never write. |
| `Item Charge Assignment (Sales)` | Table | Read allocation rows; never write. |
| `Sales Order` | Page | Pageextension surfaces the mismatch cause inline. |
| `Posted Sales Invoice` | Page | Pageextension carries the audit drill-down. |

## AL realisation per slice

Slice `post-validates-allocation`:

| | |
|---|---|
| Trigger  | subscriber on `Sales-Post` `OnAfterCheckSalesDoc` (new codeunit `Charge Post Subscribers`) |
| Decision | new codeunit `Charge Validation` |
| View     | new page `Allocation Mismatch Breakdown` (ListPart); new pageextension extends `Sales Order` |
| State    | none |

Slice `audit-trail`:

| | |
|---|---|
| State | new table `Allocation Ledger Entry` |
| Write | `Charge Post Subscribers`, new in the posting slice, modified by this slice |
| View  | new page `Allocation Ledger Entries` (List); new pageextension extends `Posted Sales Invoice` carrying the drill-down |
