# AL TDD

Task grammar: [test-specification.md](test-specification.md). Execution pyramid: [test-strategy.md](test-strategy.md). Placement: [test-layout.md](test-layout.md).

TDD applies to all new development, feature changes, and bug fixes. The only exception is the user explicitly saying to skip ("skip TDD", "no tests", "without TDD"). "Quickly add X" does not count.

## Three layers of trust

| Layer | Proves | Mechanism |
|---|---|---|
| Process discipline | Tests drove the production code | The three laws |
| Coverage direction | Unit proof lands first; Integration only where behaviour needs the BC runtime | Task execution order |
| Behavioural proof | Assertions catch seeded faults | Mutation testing |

## Three laws

1. Write no production code without a failing test.
2. Write no more test than is enough to fail.
3. Write no more production code than is enough to make the failing test pass.

## Five phases

A failure counts only on an assertion — never a compile or runtime error. Fix compile errors first, then get to an assertion failure.

| Phase | Exit criterion |
|---|---|
| **Scaffold** | Compilable stubs exist; build green; new test codeunit and production procedure declared but empty |
| **Red** | Target test fails on an assertion; existing suite still passes |
| **Green** | Minimal production change makes the target test pass; full suite green |
| **Refactor** | A full grep for `DEBUG-` returns nothing before committing; full suite green |
| **Mutate** | Targeted mutations compile, run, and die to ≥ 1 failing assertion; reverted; green confirmed |

## Task execution order

1. `Unit` AAA cases red → green → gate.
2. `Integration` AAA cases red → green → gate.
3. Refactor the full task diff once.
4. Full gate.
5. Mutation at task end for whatever arrived without a red.

Within each scope, ascending coverage ID order from the `Test Specification`: `B1`, `B2`, `B3`, … or `R1`, `R2`, `R3`, …

When a unit seam should exist but does not, an Integration characterization test may land first to anchor current behaviour; then extract the seam and add Unit proof. Unit vs Integration is the **Placement rule**'s call ([test-layout.md](test-layout.md)).

### Test naming

One short PascalCase test procedure per AAA case, BaseApp style: `RuleSetWithBlockedRecordThrowsError`.

### Test data tokens

Test-data literals carry UPPER_SNAKE role tokens derived from the scenario. A token is never a task, scenario, PR, or ticket identifier: the procedure name already carries scenario identity, and the literal outlives the workflow that minted it. Paired variables sharing a role share a role prefix (`CLONE_BASE_SRC` / `CLONE_BASE_TGT`). Respect the target field's width — a `Code[20]` field rejects a 21-character token at the first `Insert`. Keep tokens distinct across test procedures: per-test isolation in both runners depends on it.

## Mutation operators

A mutant must compile and die to a failing assertion. A mutant the compiler rejects never ran — `invalid_stillborn`, not a kill; re-plan a compiling operator. Qualifying sites are branching, comparisons, boolean ops, guards, and arithmetic where code or assertions moved without a red — a test edited after green lost its red the same way refactor-added production logic never had one. Plain delegation, property-only, and metadata edits carry no test-rigor signal.

| Operator | Before | After |
|---|---|---|
| Flip boolean condition | `if IsBlocked then` | `if not IsBlocked then` |
| Swap equality | `if Amount = 0 then` | `if Amount <> 0 then` |
| Swap comparator | `if Qty > MaxQty then` | `if Qty >= MaxQty then` or `if Qty < MaxQty then` |
| Swap arithmetic | `BaseAmount + Discount` | `BaseAmount - Discount` |
| Comment out assignment | `Amount := Base * Factor;` | *(line removed)* |
| Replace literal | `if Factor = 1 then` | `if Factor = 0 then` |
| Early-return insertion | *(add `exit` before logic block)* | |
| Skip Validate() | `Rec.Validate("Amount", Value);` | `Rec.Amount := Value;` |

The `Validate()` skip is BC-specific: it bypasses trigger firing.

Two operators risk a stillborn in AL. **Comment out assignment** can leave an unused or unwritten local — a compile error under `warningsAsErrors`; prefer replacing the RHS value where the variable is later read, so the wrong value flows and a test must catch it. **Early-return insertion** makes the code after `exit` unreachable — an AL compile error; prefer a guard flip that reaches the same skip behaviourally.

### Selection heuristics

One operator per qualifying site, picked to expose underassertion at *that* site: a boundary flip in money math, guard inversion in a validation chain, statement removal in a posting subscriber, a `Validate()` bypass when the field trigger carries the contract. A second operator at the same site only when a survivor might be equivalent and the second distinguishes equivalence from gap. Skip obvious equivalences (`x >= 1` vs. `x > 0` for integers). Confirm at least one test exercises the target line before mutating; an unreached line routes to `/al-refine` (add coverage) or `/al-refactor` (delete the dead branch), not to a killer test.

## No-touch invariants

Tactical "tidy" passes break these with no compile error — the edit silently drops a test, greens falsely, or fails only under the runner.

| Object | Why it must stay |
|---|---|
| `[Test]` attribute | Removing it silently drops the test from the runner, no error |
| `Subtype = Test` | Removing it makes the codeunit uncallable as a test — the suite shrinks silently |
| `TestPermissions = Disabled` | Removing it raises permission errors under the test-runner principal |
| `[TransactionModel(TransactionModel::AutoCommit)]` | Changing to `AutoRollback` causes false-pass ([test-layout.md](test-layout.md), TransactionModel) |
| `[HandlerFunctions('...')]` | String literal, invisible to symbol tools; rename the handler procedure without updating the string and the runner errors at runtime |
| `Initialize()` call in `[Test]` | Removing it invites test-order dependence, even where it looks redundant |
| `Library Assert` calls | Replacing them with `Error()`, `Message()`, or custom guards can green without asserting |

Presence rationale for the attributes, `Initialize()`, and assertions: **Authoring contract**, [test-layout.md](test-layout.md).

### Rename safety

`[HandlerFunctions('...')]` binds by string literal, invisible to symbol-aware tools. Before renaming any test procedure:

```powershell
rg "ProcedureName" --type al    # from the test app folder
```

A match inside a `[HandlerFunctions(...)]` attribute gets the string updated before the rename.

### Object ID allocation

Allocate test codeunit IDs via the available allocator (e.g., `mcp__al-objid-mcp-server__ninja_assignObjectId`). An ID allocated for a codeunit that is never created (scaffold aborted, task dropped) is unassigned immediately — a reserved-but-unused ID leaks from the pool.
