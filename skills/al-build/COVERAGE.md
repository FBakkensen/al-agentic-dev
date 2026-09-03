# Coverage contract

Coverage runs on the al-runner gate (`test.ps1`), never on the container gate (`container-test.ps1`). A container run's `summary.json` always carries `coverage: {"enabled": false}` — `container-test.ps1` collects no coverage from any source.

## Enablement

`test.ps1 -Coverage` explicitly enables coverage. Otherwise `ALBT_COVERAGE_ENABLED` overrides `coverage.enabled` in `al-build.json`. Newly generated configs set `coverage.enabled` to `true`; a config that omits the field resolves to `false`.

With no `testApps` configured, coverage is skipped regardless of the switch, environment, or JSON setting.

The al-runner server is the only test path — enabled coverage runs on it whether it is warm or auto-starts. When the server is unavailable, the gate stops with `al-runner server unavailable (see .output/logs/al-runner-server-manager.log and .output/logs/al-runner-server.log)` — coverage on or off, the same failure covers both, and there is no coverage-less fallback.

## Artifacts

A complete run writes, under `.output/TestResults/coverage/`:

- `per-test.jsonl` — one compact JSON object per line: every `source` record first, sorted by source path then line number, followed by every `hit` record, sorted by source path, line number, then test name.
  - `source` record, one per covered main-app source line: `{kind: "source", objectType, objectName, sourcePath, lineNumber}`. `sourcePath` is repo-relative with forward slashes.
  - `hit` record, one per (test, line) pair that actually executed: `{kind: "hit", testApp, testCodeunit, testProcedure, sourcePath, lineNumber, hits}`. `hits` is the statement hit count summed per line; only executed lines (`hits > 0`) get a record.
- `cobertura.xml` — line-level Cobertura covering every main-app line, including lines with zero hits.

`.output/TestResults/summary.json` carries the gate result plus a `coverage` block. A disabled run has only `enabled: false`. A complete run adds `schemaVersion`, `enabled: true`, `complete: true`, `lineRate`, `linesValid`, `linesCovered`, `perTestJsonlPath`, `coberturaXmlPath`, and a status field holding `"complete"`. A run that stops short of completion instead carries `enabled: true`, `complete: false`, a status field holding `"failed"`, and a `failure` object with `stage` and `message`.

## Scope boundary

Coverage is main-app line coverage only — no branch coverage, no procedure-level coverage, no thresholds, no CRAP scores, no tree-sitter analysis.
