---
task: T-008
status: blocked
blocked-on: slice technical tasks T-005, T-006, T-007 not yet done; verify opens behind the per-slice review gate
slice: post-validates-allocation
kind: verify
depends_on: [T-002, T-003, T-004, T-005, T-006, T-007]
---
# T-008 — Verify: Order Processor posts a sales document with charge allocation

User-facing slice `post-validates-allocation`: balanced allocations post cleanly; mismatched allocations halt posting with inline breakdown on `Sales Order Card`.
