# al-kanban fixture — expected board state

Point the al-kanban canvas at this folder (`open_canvas` input `{ "tasksFolder": "<repo>/tests/fixtures/al-kanban/specs/900-fixture/tasks" }`) and assert against these numbers.

## Technical strip (columns × count)

| Column | Cards | Count |
|---|---|---|
| Ready | T-006 | 1 |
| Refined | T-005, T-007 (blocked flag) | 2 |
| Implemented | T-004 | 1 |
| Refactored | T-003 | 1 |
| Mutated | T-002, T-009, T-011, T-013, T-015 | 5 |

10 technical cards across 5 swimlanes (slices): post-validates-allocation (6), audit-trail (1), charge-summary-fact-box (1), mismatch-notification (1), posting-preview (1).

## Verify strip

| Column | Cards | Count |
|---|---|---|
| Waiting on gate | T-008 (blocked flag, `blocked-on:` verbatim) | 1 |
| Opened by review | T-010 | 1 |
| Planned | T-012 | 1 |
| Page-scripted | T-014 | 1 |
| Verified | T-016 | 1 |

## Chips (not cards)

- Header: T-001 provision, `done`.
- Footer: T-017 breaking-change, `blocked`.

## Unparseable

- T-018 (`180-T-018-unparseable.md`) renders as one visible unparseable card; the board must not crash.

## Blocked flags

- T-007 (technical, Refined column): `blocked-on: ADR-0009 rounding rule for partial invoicing unsettled; implementation paused after refine`
- T-008 (verify, Waiting on gate): `blocked-on: slice technical tasks T-005, T-006, T-007 not yet done; verify opens behind the per-slice review gate`

## Advance buttons expected

| Card | Command |
|---|---|
| T-006 | Run the /al-refine skill on task T-006 |
| T-005 | Run the /al-implement skill on task T-005 |
| T-004 | Run the /al-refactor skill on task T-004 |
| T-003 | Run the /al-mutate skill on task T-003 |
| T-010 | Run the /al-refine skill on task T-010 |
| T-012 | Run the /al-page-script skill on task T-012 (`Record: yes` present, phase `planned`) |
| T-014 | Run the /al-user-verification skill on task T-014 |
| all others (incl. both chips) | no button |

## Drawer spot-checks

- T-004: one `deviations:` entry.
- T-007 / T-008: `blocked-on:` text verbatim; `depends_on:` list rendered.
