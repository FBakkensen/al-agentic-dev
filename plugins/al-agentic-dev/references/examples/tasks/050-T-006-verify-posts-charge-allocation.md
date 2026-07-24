---
task: T-006
status: done
slice: post-validates-allocation
kind: verify
depends_on: [T-001, T-002, T-003, T-004]
---
# T-006 — Verify: Order Processor posts a sales document with charge allocation

User-facing slice `post-validates-allocation`: the Order Processor releases and posts a `Sales Header` with `Item Charge Assignment (Sales)` rows. A balanced allocation posts to a Posted Sales Invoice; a mismatched allocation halts posting with an inline breakdown on the `Sales Order Card`.

Verification Plan:

## Journey Examples

### V1 PostsBalancedAllocationFromSalesOrderPage
Scope: E2E
Record: no
Role: Order Processor
Action:
- Open Sales Order Card for a Sales Order with item charge quantity 10 and allocations 4 + 6.
- Choose `Post`.
- Confirm the posting dialog.
Observable Checks:
- Posted Sales Invoice is created.
- Sales Order Status remains `Released`.

### V2 BlocksMismatchedAllocationFromSalesOrderPage
Scope: E2E
Record: no
Role: Order Processor
Action:
- Open Sales Order Card for a Sales Order with item charge quantity 10 and allocations 6 + 6.
- Choose `Post`.
Observable Checks:
- Allocation mismatch error is visible.
- Posted Sales Invoice is not created.
- Breakdown shows both Sales Lines and marks the overflow.

## Exploration Charters

### X1 AllocationMismatchGuidesCorrection
Scope: Exploration
Charter: Judge whether the mismatch breakdown tells the Order Processor which Sales Line allocation to fix.
Prompts:
- Is the affected Sales Line easy to identify?
- Are allocated and required quantities understandable without opening another page?
- Does the flow return the user to a useful correction point?

Closeout:
- E2E: `V1` user walk green
- E2E: `V2` user walk green
- Exploration: `X1` produced no follow-up tasks, no functional failures
