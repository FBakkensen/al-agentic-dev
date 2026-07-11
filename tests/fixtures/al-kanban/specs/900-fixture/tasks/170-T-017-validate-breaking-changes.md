---
task: T-017
status: blocked
blocked-on: feature tasks not all done; breaking-change validation runs last
slice: breaking-change
kind: breaking-change
depends_on: [T-016]
---
# T-017 — Validate breaking changes against released baseline

Run validate-breaking-changes.ps1 against the provisioned baseline once every other task is done.
