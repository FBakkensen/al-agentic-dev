---
task: T-010
status: ready
review: clean
slice: audit-trail
kind: verify
depends_on: [T-009]
---
# T-010 — Verify: Allocation Ledger Entry rows persist after successful posting

User-facing slice `audit-trail`: after successful `Post`, audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from `Posted Sales Invoice`.
