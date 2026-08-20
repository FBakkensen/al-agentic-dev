# al-build

## What it is for

The gate, and the only skill that runs the PowerShell substrate. Every script in this toolkit lives in `skills/al-build/scripts/` and `/al-build` is their sole invoker — any skill that needs a script run reaches it by naming this skill, never by naming a path.

## When you reach for it

- AL production or test code changed and the change needs the gate before the task moves on.
- Another skill needs one of the scripts run.

## What it produces

A green gate with per-runner totals, or a red named by its failing tests and the diagnostic behind them.

| Command | Scope |
|---|---|
| `test.ps1` | Full gate — compile through the analyzers, publish to the branch container, run the container tests. Minutes. |
| `test.ps1 -UnitTestOnly` | Inner loop — compile, run the AL Runner unit tests, skip the container. Seconds. |
| `test.ps1 -Coverage` | Full gate with mandatory per-test container coverage. |

Green is zero errors and zero warnings. `test.ps1` exits 0 on warnings by default; set `WARN_AS_ERROR=true` to bind that bar to the exit code.

The result is read from `.output/TestResults/summary.json`, not from the console stream. The summary carries the gate scope, per-runner totals, one record per run with its JUnit result file, and a coverage block. Reading the console instead floods a session with thousands of lines of build spew for numbers the summary already holds.

## Coverage

Coverage is full-container only. It records the current Business Central test session in `PerTest` mode for every configured test app and combines the results into one main-app line-coverage report.

### Enabling it

A newly generated `al-build.json` enables coverage:

```json
{
  "testApps": ["test"],
  "coverage": {
    "enabled": true
  }
}
```

Existing configs that omit `coverage.enabled` remain disabled for backward compatibility. Resolution is:

1. No configured `testApps`: skip coverage, even with `-Coverage` or `ALBT_COVERAGE_ENABLED=true`.
2. `-Coverage`: enable it for this full gate.
3. `ALBT_COVERAGE_ENABLED`: override the JSON setting.
4. `coverage.enabled`: use the repo setting.
5. Missing field: disabled.

`-UnitTestOnly` never collects coverage. `-Coverage -UnitTestOnly` is invalid rather than silently choosing one mode.

### What it measures

Coverage is combined across all configured `testApps`, but its source universe is the main app. It reports executable-line hits only. Public object identity is:

- AL object type;
- AL object name;
- repo-relative source path.

Object IDs are used internally to match Business Central output to source, but are not the public identity. The reports do not include branch coverage, procedure coverage, thresholds, CRAP scores, tree-sitter analysis, or AL Runner coverage.

### Artifacts

Every run first removes stale `.output/TestResults` artifacts, so a current result cannot inherit coverage from an older gate.

| Artifact | Contents |
|---|---|
| `.output/TestResults/coverage/per-test.jsonl` | Deterministic `source` and `hit` records. Source records identify `objectType`, `objectName`, `sourcePath`, and `lineNumber`; hit records add the test app, test codeunit, test procedure, and hit count. |
| `.output/TestResults/coverage/cobertura.xml` | Combined main-app line coverage for report viewers and CI consumers. |
| `.output/TestResults/summary.json` | The ordinary gate result plus the coverage status and artifact paths. |

For completed coverage, `summary.json` reports `schemaVersion`, `enabled`, `status`, `complete`, `trackingMode`, `lineRate`, `linesValid`, `linesCovered`, `perTestJsonlPath`, and `coberturaXmlPath`. Coverage is complete only when `status` is `complete` and `complete` is `true`. A failure block names the stage and diagnostic.

Coverage completeness is independent of the test verdict. If every container test app finishes, a red test run still retains complete `per-test.jsonl` and `cobertura.xml`. If the test session aborts, or collection, aggregation, or publication cannot complete, partial coverage is deleted. Current-run JUnit results remain available for diagnosing the red gate.

### Helper and recovery

Enabled coverage is mandatory. The gate verifies the exact bundled coverage helper before consumer apps are published or tests run; a missing, stale, or unusable helper stops the gate instead of falling back to tests without coverage.

A fresh golden image compiles, publishes, installs, and verifies that helper. Recover a missing or stale helper through the image lineage:

1. Rebuild the golden container with `new-bc-container.ps1`.
2. Restart the machine so the stopped container releases locked files.
3. Recommit the golden image with `commit-bc-container.ps1`.
4. Recreate the branch container with `new-agent-container.ps1`.

Do not install or patch the helper directly in the branch container; that leaves state the image cannot reproduce.

## The other entry points

| Script | What it does |
|---|---|
| `provision.ps1` | Per-feature refresh: compiler channels, symbol packages, analyzers, breaking-change baseline. |
| `validate-breaking-changes.ps1` | Per-country install-and-upgrade validation against the cached baseline. |
| `publish-apps.ps1` | Clean republish, no build and no tests. |
| `new-bc-container.ps1`, `commit-bc-container.ps1`, `new-agent-container.ps1` | The container lifecycle — one sequence, once per BC version; it also establishes the exact coverage helper. |
| `prune.ps1` | Removes agent containers for dead branches or ones unused past seven days. |
| `init.ps1` | One-time per repo: writes `al-build.json` into the repo root; new configs enable coverage. |
| `clean.ps1` | Deletes compiled `.app` files and clears publish state. |
| `report-gate-metrics.ps1` | Gate wall-clock from `build-timing.jsonl`. |
| `download-symbols.ps1`, `download-baseline.ps1` | The two fetches `provision.ps1` already performs, run alone. |

## Requirements

`al-build.json` in the consumer repo root, written by `init.ps1`. On the host: PowerShell 7.2+, Docker Desktop, the .NET SDK, Node.js 22+ with `npx` on PATH, and BcContainerHelper.

Configuration resolution is switch, environment, JSON, then built-in default. Coverage uses `-Coverage`, `ALBT_COVERAGE_ENABLED`, and `coverage.enabled` in that order, subject to the rule that no `testApps` means no coverage.

Analyzer selection comes from `al.codeAnalyzers` in `.vscode/settings.json`. No `settings.json` means no analyzers, and an analyzer that cannot be resolved stops the build rather than quietly compiling with less lint coverage than you asked for.

The container is disposable. Recovery goes through the scripts, in order — restart, then remove and recreate, then re-provision. Hand-patching through `docker exec` leaves state the scripts cannot reproduce.
