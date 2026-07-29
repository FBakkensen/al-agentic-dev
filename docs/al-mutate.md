# al-mutate

## What it is for

Tests the tests. A suite that passes a broken program proves nothing, so this skill breaks the program on purpose — one production site at a time — runs the gate, and sees whether anything notices.

It is the rigor step, and it is what actually closes a task.

## When you reach for it

- A technical task is refactored — or implemented with no reshape planned — and the green baseline is committed.
- Standalone, on legacy code whose tests were written after the code.

The tree has to be clean and the baseline committed, because revert returns to `HEAD`.

## What it produces

A classified pass over the planned sites, and a report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`:

| Verdict | Means |
|---|---|
| `killed` | the gate went red with a named failing test |
| `survived` | the gate stayed green and the mutation changed reachable behaviour |
| `equivalent` | green, with a written reason the mutant cannot behave differently |
| `stillborn` | the compiler rejected the mutant — a hole in the pass, re-planned with a compiling operator |
| `blocked` | the gate failed on infrastructure |

A **clean verdict** — no survivors, no unresolved stillborns — is handed to `/al-routing`, which settles the task and opens every same-slice task whose edges are now all done. An **open verdict** holds the task open until a follow-up round closes clean.

## Worth knowing

Sites qualify on provenance alone: **code that arrived without a red**. Legacy paths, tests written after their code, branches a refactor introduced, work absorbed inline. Reading the tests and judging the assertions rigorous is the exact judgment mutation exists to replace.

A survivor's killer test is TDD work — it is named here and written in [`/al-implement`](al-implement.md), under the task that owns it.
