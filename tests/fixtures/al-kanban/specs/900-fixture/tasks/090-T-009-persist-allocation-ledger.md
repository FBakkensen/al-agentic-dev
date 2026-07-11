---
task: T-009
status: ready-for-implementation
phase: mutated
slice: audit-trail
kind: technical
depends_on: [T-002]
---
# T-009 — Persist allocation ledger entries

Persist one `Allocation Ledger Entry` row per resolved allocation during posting, tied back to the source Sales Line.
