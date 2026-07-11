---
task: T-004
status: ready-for-implementation
phase: implemented
slice: post-validates-allocation
kind: technical
depends_on: [T-003]
deviations:
- assumed posting-date currency rounding follows GL setup precision; touched Charge Validation only
---
# T-004 — Subscribe OnCheck, route validator

Subscribe `OnCheckSalesDocument`, route the released document through the allocation validator, raise the mismatch error before posting continues.
