# architecture.md

One file per feature, in the feature's spec folder next to `event-model.md` and the `tasks/` folder. Agent-facing: declarative, present tense, text only with relationships named in prose — no diagram fences, no workflow narration, no history; the story of how the design got here belongs in the commit message.

## Section order

1. **Title and opening** — an H1 naming the feature outcome, then one paragraph stating the single most important structural fact about the design (usually where it touches the base app, or what it deliberately does not touch).
2. **Identity table** — a borderless two-column table: `Slug`, `ADR` (number plus title, or omit the row), `Event model` (`event-model.md`, or omit for backend-only), `Tasks` (`tasks/`). Values are plain text; sibling artifacts are named, not linked.
3. **Goal** — two or three sentences on the behaviour the feature adds, in BC vocabulary.
4. **Module map** — a table of `Module | Responsibility | Precedent`. Each module is a folder under `src/<module>/`, named in the project's ubiquitous language, marked `new` or naming the existing folder. The responsibility states what it decides and what it writes, and where it deliberately writes nothing. `Precedent` is the module's verdict from reading `.bcapps/`: `reused: <Microsoft object>` when the module calls what Microsoft ships, `pattern: <source> — <difference>` when it lifts a shape, or `none in System App / apps` — earned by the search, never assumed.
5. **Decision logic and test surfaces** — prose, one paragraph per stage: the reads, the pure decision, the writes. Name which decision is reproducible from its inputs alone; that paragraph is what unit tests will reach.
6. **Brownfield touchpoints** — a table of `Object | Kind | Touch`. Every existing object the feature reads, subscribes to, extends, or writes through. `Touch` says what happens and what stays untouched.
7. **AL realisation per slice** — one small table per slice, below.

Object level throughout. Fields, signatures, and parameter lists shift during TDD and rot here.

## Slices

A slice is one initiated behaviour: trigger → command → event → state → view. Qualify each slice by the pattern its trigger source implies.

| Pattern | Trigger source |
|---|---|
| **Command** | page action, report request — user-initiated |
| **Automation** | event subscriber, Job Queue, install/upgrade — system-initiated; the most common AL pattern |
| **Translation** | API page, web service, webhook — external-system-initiated |
| **View** | page render, FlowField, report layout — read-only |

For a user/API-facing feature, `event-model.md` has already settled the user-facing slots — Role, Action, Business Event, View, Status. Read them; do not re-decide them. What settles here is the AL realisation: `Trigger` — the object plus the event or action that starts the slice — then `Decision`, `State`, and `View`, plus a `Publication` row only where the slice raises an integration event for other code to subscribe to. A slot the slice genuinely has no use for reads `none`; a slot left unnamed leaves `/al-implement` to invent one or stall. Backend-only slices carry the trigger source directly and have no `event-model.md` counterpart.

Every named object is marked `new` or `extends <existing object>` — `/al-refine` derives each task's New and Modified Objects from these markers. An object created by an earlier slice is named with its owning slice instead of being re-marked.

## Worked example

````md
# Item charge allocation, validated at posting

Posting is intercepted at exactly one place — event subscribers on `Sales-Post` codeunit 80. Everything else the feature touches in the base app is reads and pageextensions.

| | |
|---|---|
| **Slug**        | sales-charge-validation |
| **ADR**         | ADR-0007 Allocation Mismatch Surfacing |
| **Event model** | event-model.md |
| **Tasks**       | tasks/ |

## Goal

Catch item charge allocation mismatches while the invoice is still unposted, surface the cause inline on the document, and record one `Allocation Ledger Entry` per resolved allocation, tied to its source line.

## Module map

| Module | Responsibility | Precedent |
|---|---|---|
| `Charge Validation` (new, `src/ChargeValidation/`) | Reads `Item Charge Assignment (Sales)`. Decides allocation balance from the read rows. Writes nothing. | pattern: `Document Totals` — pure read-and-decide codeunit; ours decides per assignment row |
| `Charge Post Subscribers` (new, `src/ChargePostSubscribers/`) | Carries the subscribers on `Sales-Post` codeunit 80 and owns every write. | none in System App / apps |

## Decision logic and test surfaces

Reads stay inside the released document. `Charge Validation` uses `Get` to read the `Sales Header` by `No.`, iterates its `Sales Line` rows, and resolves each related `Item Charge Assignment (Sales)`.

The decision is pure. `Charge Validation` takes the read rows and returns balanced, or mismatched with the imbalance quantity — reproducible from its inputs, no `Insert` and no `Modify`. This is the unit-test surface.

Writes go through the base app. `Charge Post Subscribers` subscribes to `OnAfterCheckSalesDoc`, calls `Charge Validation`, raises `Error` on a mismatch so posting aborts, and otherwise uses `Insert` to write the `Allocation Ledger Entry` rows.

## Brownfield touchpoints

| Object | Kind | Touch |
|---|---|---|
| `Sales-Post` codeunit 80 | Event source | Subscribe; never modified. |
| `OnAfterCheckSalesDoc` | Event | Run `Charge Validation`; `Error` on mismatch. |
| `Sales Header`, `Sales Line` | Tables | Read the released document; never written. |
| `Item Charge Assignment (Sales)` | Table | Read allocation rows; never written. |
| `Sales Order` | Page | Pageextension surfaces the mismatch cause inline. |
| `Posted Sales Invoice` | Page | Pageextension carries the audit drill-down. |

## AL realisation per slice

Slice `post-validates-allocation` (Automation):

| | |
|---|---|
| Trigger  | `OnAfterCheckSalesDoc` on `Sales-Post` codeunit 80, subscribed by new codeunit `Charge Post Subscribers` |
| Decision | new codeunit `Charge Validation` |
| State    | none |
| View     | new page `Allocation Mismatch Breakdown` (ListPart); new pageextension extends `Sales Order` |

Slice `audit-trail` (Automation):

| | |
|---|---|
| Trigger  | `Charge Post Subscribers`, created by the posting slice, extended here |
| Decision | none |
| State    | new table `Allocation Ledger Entry` |
| View     | new page `Allocation Ledger Entries` (List); new pageextension extends `Posted Sales Invoice` |
````
