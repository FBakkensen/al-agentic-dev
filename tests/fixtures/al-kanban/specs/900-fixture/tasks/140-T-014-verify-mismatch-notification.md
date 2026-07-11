---
task: T-014
status: ready-for-verification
phase: page-scripted
review: clean
slice: mismatch-notification
kind: verify
depends_on: [T-013]
---
# T-014 — Verify: mismatch notification reaches the Order Processor

User-facing slice `mismatch-notification`: releasing an order with a mismatched allocation notifies the Order Processor.

Verification Plan:

## Journey Examples

### V1 NotificationAppearsOnRelease
Scope: E2E
Record: yes
Role: Order Processor
Action:
- Release a Sales Order with allocations 6 + 6 against charge quantity 10.
Observable Checks:
- Notification names the mismatched charge line.

### V2 NotificationAbsentWhenBalanced
Scope: E2E
Record: no
Role: Order Processor
Action:
- Release a Sales Order with balanced allocations.
Observable Checks:
- No mismatch notification appears.
