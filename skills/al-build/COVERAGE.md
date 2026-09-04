# Coverage contract

Coverage runs on the al-runner gate (`test.ps1`), never on the container gate (`container-test.ps1`). A container run's `summary.json` always carries `coverage: {"enabled": false}` — `container-test.ps1` collects no coverage from any source.

## Enablement

`test.ps1 -Coverage` explicitly enables coverage. Otherwise `ALBT_COVERAGE_ENABLED` overrides `coverage.enabled` in `al-build.json`. Newly generated configs set `coverage.enabled` to `true`; a config that omits the field resolves to `false`.

With no `testApps` configured, coverage is skipped regardless of the switch, environment, or JSON setting.

Coverage rides the same single `al-runner` CLI process as the tests, through `--coverage --coverage-out .output/TestResults/coverage/cobertura.xml`. Coverage never blocks the gate: when the coverage step fails, the test verdict stands and the failure lands in the `coverage` block below.

## Artifacts

A complete run writes, under `.output/TestResults/coverage/`:

- `cobertura.xml` — line-level Cobertura covering every main-app line, including lines with zero hits. AL Runner's own Cobertura spans every bundle in the run (main app and test apps); `test.ps1` keeps only the classes under `appDir`, sums hits per line, and rewrites the file over that main-app set, so `lineRate`, `linesValid`, and `linesCovered` describe the main app alone.

There is no `per-test.jsonl`. `al-runner --help` (v2.10) offers no per-test coverage flag — `--output-json` gives "per-test JSON on stdout" with each test's pass/fail/error, message, stackTrace, durationMs and the exitCode, and `--coverage` "Writes Cobertura XML (default ./cobertura.xml) plus a console table"; the `--output-json` document carries no coverage field at all. Per-test attribution existed only on the retired `--server` protocol.

`.output/TestResults/summary.json` carries the gate result plus a `coverage` block. A disabled run has only `enabled: false`. A complete run adds `schemaVersion`, `enabled: true`, `complete: true`, `lineRate`, `linesValid`, `linesCovered`, `perTestJsonlPath: null`, `coberturaXmlPath`, and a status field holding `"aggregate-only"`. A run that stops short of completion instead carries `enabled: true`, `complete: false`, a status field holding `"failed"`, and a `failure` object with `stage` and `message`.

## Scope boundary

Coverage is main-app line coverage only — no branch coverage, no procedure-level coverage, no thresholds, no CRAP scores, no tree-sitter analysis.
