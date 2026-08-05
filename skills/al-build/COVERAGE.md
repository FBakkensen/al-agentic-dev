# Coverage contract

Coverage belongs to the full container gate. It records the current Business Central test session in `PerTest` mode for every configured `testApps` entry, then combines those runs into main-app line coverage.

## Enablement

`test.ps1 -Coverage` explicitly enables coverage. Otherwise `ALBT_COVERAGE_ENABLED` overrides `coverage.enabled` in `al-build.json`. Newly generated configs set `coverage.enabled` to `true`; a config that omits the field resolves to `false` for backward compatibility.

The configured test apps are the outer boundary:

- With no `testApps`, skip coverage regardless of the switch, environment, or JSON setting.
- `-UnitTestOnly` does not collect coverage.
- `-Coverage -UnitTestOnly` is invalid.

## Public result

Coverage is one combined report across all configured test apps. It covers executable lines in the main app only. Each public source identity is the AL object type, object name, and repo-relative source path; object IDs are internal matching data, not report identity.

The published artifacts are:

- `.output/TestResults/coverage/per-test.jsonl` — deterministic `source` and `hit` records. Source records carry `objectType`, `objectName`, `sourcePath`, and `lineNumber`; hit records add the test app, test codeunit, test procedure, and hit count.
- `.output/TestResults/coverage/cobertura.xml` — combined main-app line coverage for standard report consumers.
- `.output/TestResults/summary.json` — the gate result plus its `coverage` block.

A complete coverage block has `schemaVersion`, `enabled`, `status`, `complete`, `trackingMode`, `lineRate`, `linesValid`, `linesCovered`, `perTestJsonlPath`, and `coberturaXmlPath`. Treat enabled coverage as satisfied only when `status` is `complete` and `complete` is `true`. Failure blocks name the stage and message.

## Lifecycle

Every gate invocation clears stale test and coverage artifacts before configuration is read. Enabled coverage is mandatory: helper preflight, collection, aggregation, or publication failure keeps the gate red rather than falling back to tests without coverage.

A completed container run publishes complete coverage even when tests are red. An aborted test session deletes partial coverage. Aggregation or publication failure also removes incomplete final artifacts while retaining current-run test results.

The golden image owns the helper:

1. A fresh golden container compiles, publishes, installs, and verifies the exact bundled helper.
2. A branch container must contain that exact helper identity and version before consumer apps publish or tests run.
3. If the helper is missing or stale, rebuild the golden container, restart the machine, recommit the golden image, then recreate the branch container.

Repair the image lineage; do not patch the branch container.

## Scope boundary

Coverage does not provide branch coverage, procedure coverage, thresholds, CRAP scores, tree-sitter analysis, or AL Runner coverage.
