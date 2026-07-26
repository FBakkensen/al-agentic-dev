---
task: T-001
status: done
phase: mutated
slice: post-validates-allocation
kind: technical
depends_on: []
---
# T-001 — Read released sales order item charge assignments

Resolve `Item Charge Assignment (Sales)` rows for a released `Sales Header`, grouped by source `Sales Line`, without `Insert` or `Modify`.

Test Specification:

## New and Modified Objects

- New: codeunit `Charge Validation`
  - `internal procedure FindItemChargeAssignments(SalesHeader: Record "Sales Header"; var TempItemChargeAssignmentSales: Record "Item Charge Assignment (Sales)" temporary)` — S

## Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | One released Sales Order item charge assignment is returned with source Sales Line reference | ReadsSingleItemChargeAssignment |
| B2 | Released Sales Order with no item charge assignments returns empty result | ReadsNoItemChargeAssignmentsAsEmpty |

## AAA Cases

### ReadsSingleItemChargeAssignment
Scope: Unit
Covers: B1
Arrange:
- Released Sales Order has one freight charge line.
- One item charge assignment exists for the freight charge line.
Act:
- Read item charge assignments for the Sales Order.
Assert:
- One assignment is returned.
- Assignment carries source Sales Line reference.

### ReadsNoItemChargeAssignmentsAsEmpty
Scope: Unit
Covers: B2
Arrange:
- Released Sales Order has no item charge assignment rows.
Act:
- Read item charge assignments for the Sales Order.
Assert:
- Empty result is returned.

Closeout:
- Unit: `ReadsSingleItemChargeAssignment`, `ReadsNoItemChargeAssignmentsAsEmpty`
- Integration: none
- Build: full gate green

Mutation verdict:

| | |
|---|---|
| Baseline | `6e94b3a7` |
| Report | `.output/mutation-report/20260110-154421.md` |
| Mutants | 2 — assignment filter scope, empty-buffer early exit |
| Killed | 2 by named tests |
| Survivors | 0 |
| Final gate | full green |
