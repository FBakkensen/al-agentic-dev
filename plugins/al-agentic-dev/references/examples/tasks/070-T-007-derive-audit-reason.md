---
task: T-007
status: ready
slice: audit-trail
kind: technical
depends_on: [T-002]
---
# T-007 — Derive allocation audit reason values

Translate `Charge Validation`'s per-allocation outcome into an audit reason value — allocation resolved on a single receiving `Sales Line`, or spread across several — so the audit trail labels each successful posting's entries.
