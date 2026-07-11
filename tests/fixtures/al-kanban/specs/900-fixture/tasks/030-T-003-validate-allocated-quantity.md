---
task: T-003
status: done
phase: refactored
slice: post-validates-allocation
kind: technical
depends_on: [T-002]
---
# T-003 — Validate allocated quantity against charge quantity

Compare summed allocation quantity per charge line against the charge line quantity; classify balanced vs mismatched.
