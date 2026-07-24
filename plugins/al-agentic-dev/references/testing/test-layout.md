# Test layout — two peer test apps

A test belongs in `unit-tests/` iff every codepath it traverses is runnable by AL Runner. Sibling axes: [test-strategy.md](test-strategy.md) (the execution pyramid), [tdd.md](tdd.md) (the red-green cycle), [testability.md](testability.md) (seams and doubles).

## The layout

```
app/                  production app
unit-tests/           AL Runner-runnable tests — fast pre-gate, no container
integration-tests/    container-only tests — the authoritative gate
```

The two test apps are peers — no dependency edge between them; both depend on the production app. A production seam (interface in the production app) is doubled independently in each test app (`Stubs/<InterfaceName>/`, `Spies/<InterfaceName>/`): the two doubles implement the same interface but belong to different runtimes, so they are not duplicates and must not be shared. **Five kinds of test double** and the **Stub location rule** live in [testability.md](testability.md).

`/al-build` wires the split: AL Runner runs `unit-tests/` only (the `unitTestApp` config entry); the container gate compiles and tests both apps. The container is authoritative; AL Runner is the fast pre-gate that makes red-first cycles cheap.

## Placement rule

AL Runner can run the test, or it can't — and you confirm the call by running (the auto-stub report), not by predicting it. A test that drifts into needing real BaseApp codeunit behaviour is an integration test: reclassify it, never relax the unit contract to keep it.

| Codepath | Placement call |
|---|---|
| Inserting into BaseApp tables (`Sales Header`, `Item`, `Customer`, …) | Fine — AL Runner has an in-memory table store and handles any table resolvable from the symbol packages |
| Depending on a BaseApp codeunit's behaviour | Not fine — `.app` package code auto-stubs: `Codeunit::"Sales-Post".Run()` executes as a no-op, `ConfirmManagement.GetResponseOrDefault()` returns `false` |
| Reading BaseApp tables your test populated | Fine |
| Reading BaseApp tables that real BaseApp codeunits populate during execution (ledger entries from posting, lines from validation) | Not fine — those codeunits never ran |
| `Commit()` mid-test | A no-op under AL Runner. If the commit must be observable (`asserterror` after a real `Commit`, post-commit state), the test is integration |
| FlowFields | Fine — `CalcFields` evaluates against tables in scope, so asserting on a FlowField over rows the test inserted inline is a unit-test pattern |

### Let the auto-stub report decide placement

1. Write the case against real tables and inject nothing.
2. Run it: AL Runner prints what it auto-stubbed (`Auto-stubbed N dependency object(s) — methods return defaults`).
3. Per stubbed object: does the assertion's truth depend on what it really returns? No → the stub is inert; leave it stubbed. Yes → that behaviour is missing — a unit test behind a real seam, or (when no real seam fits) an integration test.

"Ran" is not "ran faithfully": a `.app` call auto-stubs to `0`/`''`/`false` and keeps going, so a green path may have exercised a default, not real BaseApp behaviour. A unit test whose oracle rides a semantically relevant auto-stub (its return feeds branching, persistence, validation, posting setup, rounding, dimensions) is a false net. The report, not the absence of a throw, is the proof a path was covered.

When a path needs real BaseApp behaviour — `Validate` whose trigger logic lives in BaseApp, posting setup, number series, dimensions — wrapping it in a 1:1 interface only to stub it is a prop seam (**Earned seams**, [testability.md](testability.md)). Reclassify to `integration-tests/`: an earned integration test, not a prop.

## AL Runner capability map

[AL Runner](https://github.com/StefanMaron/BusinessCentral.AL.Runner)'s boundary moves with the tool: when a claim here contradicts an observed run, re-derive against the current release.

| Category | What falls in it |
|---|---|
| **Runs** | All `.al` source in scope: tables, codeunits, enums, interfaces, queries, page extensions (business logic), report triggers. All record operations (`Insert`, `Modify`, `Delete`, `Get`, `Find*`, `SetRange`, `SetFilter`, `Validate`, `Copy`, `TransferFields`, `CalcFields`, `CalcSums`) with composite and secondary keys and field triggers defined in workspace source. Cross-codeunit, interface, and event-subscriber dispatch. Mocked subsystems: TestPage, Notification, BigText, JSON, BLOB streams, File, IsolatedStorage, TaskScheduler, DataTransfer, single-dataitem queries. |
| **Auto-stubs** (compile and link, run as no-ops returning `0` / `''` / `false`) | Everything inside `.app` package dependencies: BaseApp codeunits and trigger logic, BaseApp test libraries (`Library - Sales`, `Library - Inventory`, `Library - ERM`, …), any project test-library app (**Zero `Library*` calls in unit tests**, [testability.md](testability.md)). |
| **Throws** | Real `HttpClient.Send()` (inject via an AL interface); XmlPort `Import`/`Export`; multi-dataitem queries with JOINs. |
| **Changed semantics** | Real `Commit()`/`Rollback()` run as no-ops — transaction boundaries don't exist; `StartSession` runs inline synchronous. |
| **Not evaluated** | UI rendering: page layout, field visibility, report rendering. |
| **Auto-loaded test toolkit** (no stubs needed) | `Library Assert`, `Library - Variable Storage`, `Any`, `Library - Random`, `Library - Utility`, `Library - Test Initialize`. |

## Container isolation semantics

The container gate runs both test apps under a test-runner codeunit declared `TestIsolation = Codeunit;` (the [TestIsolation property](https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/properties/devenv-testisolation-property)). All `[Test]` procedures in one codeunit share one transaction; all changes roll back at codeunit end, including changes committed via `Commit()`. Per-test isolation is the test's job: `Initialize()` resets state (typically `DeleteAll()` on every table the codeunit writes), called as the first statement of every `[Test]`.

AL Runner has no test-runner-codeunit concept (`Commit`/`Rollback` are no-ops there). The explicit per-test reset is what makes a test portable between AL Runner and the container — never lean on runner-specific isolation.

### TransactionModel

Add `[TransactionModel(TransactionModel::AutoCommit)]` only when the code under test calls `Commit()` explicitly, with a comment naming which `Commit()` it covers. The default (no attribute) is `AutoRollback`; under it an explicit production `Commit()` fails and every side effect (ledger entries, status changes) silently vanishes — the test greens while testing nothing. That false-pass is why the attribute sits on the no-touch list in [tdd.md](tdd.md).

## Authoring contract

A test codeunit's contract is identical in both apps — the tier changes the runner, never the authoring rules.

| Requirement | Rule and consequence |
|---|---|
| Attributes, mandatory | `Subtype = Test;` (without it the codeunit is not callable as a test), `TestPermissions = Disabled;` (permission checks under the test-runner principal fail otherwise), `Access = Internal;` (prevents accidental production dependency on test code). |
| `Initialize()` guard | The `if IsInitialized then exit;` pattern for one-time setup, plus per-test state reset; every `[Test]` calls it as its first statement, even when it looks redundant — it is what prevents test-order dependence (the no-touch list, [tdd.md](tdd.md)). |
| Handlers | Live on the test codeunit itself, never in a shared handlers codeunit — `[HandlerFunctions('…')]` binds by string literal, and a shared home turns every handler rename into a cross-file runtime failure. |
| Assertions | `Library Assert` only — never `Error()`, `Message()`, or custom guards. For computed decimals where `Round()` leaves a residual, `Assert.AreNearlyEqual(Expected, Actual, 0.01, Msg)`; `Assert.AreEqual` for exact values only. |
| Naming | The codeunit is named for the feature or scenario it proves; no tier infix (`Unit`, `Intg`) — the app already says the tier. |

### Integration-test libraries

Setup helpers in `integration-tests/` are deliberately anti-DRY — duplicate the procedure before sharing it, because a shared library couples its consumers' test data and change surface.

| Discipline | Rule |
|---|---|
| One focused library codeunit per test codeunit | Co-located in the same folder. No library serves two test codeunits — an edit for one silently reshapes the other's test data. |
| One shared base library, at most | Carries only cross-suite foundational setup — company, posting periods, basic ledger. Feature-specific setup lives in the per-test library. |
| Libraries are stateless | No global variables, no `OnRun` state. |
| No assertions in libraries | Assertions live on the test codeunit, where the failure message points at the scenario. |
| No event subscribers in libraries | A subscriber in shared plumbing fires for every test in the app. |

`unit-tests/` needs none of this: each test codeunit owns its setup inline. An arrange phase that outgrows inline setup routes to the **Earned seams** question ([testability.md](testability.md)) — is an MS-behaviour dependency hiding in the setup? Setup size alone earns no seam.
