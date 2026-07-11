---
task: T-006
status: ready
slice: post-validates-allocation
kind: technical
depends_on: [T-005]
---
# T-006 — Guard partial-post allocation recalculation

Recalculate remaining allocation quantities after a partial post so subsequent posts validate against the remaining quantity, not the original.
