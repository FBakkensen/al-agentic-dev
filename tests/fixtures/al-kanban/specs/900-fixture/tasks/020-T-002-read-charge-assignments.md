---
task: T-002
status: done
phase: mutated
slice: post-validates-allocation
kind: technical
depends_on: [T-001]
---
# T-002 — Read released sales order item charge assignments

Resolve `Item Charge Assignment (Sales)` rows for released `Sales Header`, grouped by source `Sales Line`. Reads only; no `Insert` or `Modify`.
