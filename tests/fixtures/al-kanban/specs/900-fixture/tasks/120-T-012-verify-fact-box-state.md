---
task: T-012
status: ready-for-verification
phase: planned
review: clean
slice: charge-summary-fact-box
kind: verify
depends_on: [T-011]
---
# T-012 — Verify: charge summary fact box reflects allocation state

User-facing slice `charge-summary-fact-box`: the fact box tracks allocation edits live on `Sales Order Card`.

Verification Plan:

## Journey Examples

### V1 FactBoxUpdatesOnAllocationEdit
Scope: E2E
Record: yes
Role: Order Processor
Action:
- Open Sales Order Card with a mismatched charge allocation.
- Correct the allocation on the Item Charge Assignment page.
Observable Checks:
- Fact box balance state flips to balanced without a page refresh.
