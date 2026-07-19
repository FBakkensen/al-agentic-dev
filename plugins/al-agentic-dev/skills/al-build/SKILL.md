---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
allowed-tools: ["execute", "read"]
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-build — build and test gate

Run after every AL change and before committing. Zero warnings and zero errors → green; anything else → red.

**Layers.** Runs **Unit** (AL-Runner) and **Integration** (container + TestPage). See [`test-strategy.md`](../../references/test-strategy.md).

## Setup

1. `pwsh "<skill-folder>/scripts/init.ps1"` → drops `al-build.json` in repo root.
2. Set `testApps` to list your test app directories.
3. `pwsh "<skill-folder>/scripts/provision.ps1"` → one-time symbol + container setup.

Compiler or symbols missing → **Stop.** Run `pwsh "<skill-folder>/scripts/provision.ps1"` first.

## Canonical gate

Set location to consumer repo root, then:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Always run the full gate. Do not filter by codeunit or use bare `alc.exe`: `test.ps1` owns symbol resolution, container publish, and telemetry capture.

Force republish: `pwsh "<skill-folder>/scripts/test.ps1" -Force`

### Gate metrics (automatic)

Each `test.ps1` run records one entry in `.output/logs/build-timing.jsonl` and mirrors it to `~/.al-build/gate-metrics.jsonl` (override: `ALBT_GATE_METRICS_GLOBAL_PATH`). Phase attribution derives from recorded evidence; callers pass no flags. Report repo-local metrics with `pwsh "<skill-folder>/scripts/report-gate-metrics.ps1"` or cross-repo metrics with `-GlobalLog`.

### Fast unit test (inner loop)

When `unitTestApp` configured in `al-build.json`, run only AL Runner unit tests:

```powershell
pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
```

Compiles the main app, every `testApps` entry, and the unit-test app through the analyzer gate; then runs AL Runner and exits without a container. `testApps` must resolve in this mode: unit-only projects set `"testApps": []`; the default `["test"]` fails loudly without `test/`. Use this fast feedback loop during `/al-implement` RED→GREEN.

**Outputs (per test run):**

- `.output/TestResults/<dirName>/last.xml` → JUnit XML from the container run.
- `.output/TestResults/<dirName>/al-runner.xml` → JUnit XML from the AL Runner run. Separate file — a full gate must never overwrite the unit result.
- `.output/TestResults/<dirName>/telemetry.jsonl` → feature telemetry per container run. `/al-debug-logging` reads this.
- `.output/TestResults/summary.json` → machine-readable summary: `gate` (`full`/`unit`), `totals` per runner, `runs[]` with one record per test run (`runner`, `appName`, `dir`, `passed`, `counts`, `resultFile`, `telemetryFile`).
- `.output/logs/build-timing.jsonl` → one gate-metrics entry per run (every exit path: pass, fail, throw), mirrored to `~/.al-build/gate-metrics.jsonl`.

Take `resultFile` paths from `summary.json` run records; never glob because stale files can sit beside fresh output. `test.ps1` writes `summary.json` only after a unit-test failure, unit-only pass, or full-gate completion; bad `al-build.json` or a compile failure leaves a prior file untouched. `missing` means no file exists; a present file is current-run evidence only when the relayed exit code and bounded excerpt corroborate it.

Test failure with an unclear cause → name `/al-debug-logging` as the next step; a clear assertion or compile failure needs no telemetry. Don't grep the build log for clues telemetry already answers.

## Delegation

Fresh `/al-build` runs delegate to the named `al-gate-runner` custom agent — the bounded executor that relays authoritative result files (see [delegation.md](../../references/delegation.md)). Keep verbose build output out of the main session.

Already inside an agent mid-workflow → run the gate script inline; nested custom-agent spawning does not occur. `al-gate-runner` unavailable for a fresh spawn → report `BLOCKED`, name it as missing, and stop. No generic-subagent or inline substitution (see [delegation.md](../../references/delegation.md)).

After the worker returns the gate report, close the completed thread before interpreting or reporting the result. Report the outcome as the mid-task Gate one-liner per [voice-contract.md](../../references/voice-contract.md) — never paste the worker's block raw.

The spawn prompt includes verbatim: findings must name file, object, and the observed fact; no verdict words without the check that produced them.

### Worker rules

```
Do not edit source, specs, tasks, config, or git state. Running `test.ps1` may write build/test artifacts under `.output`; that is allowed.

Run exactly one requested gate, exactly once. Do not rerun on failure. Do not run multiple `/al-build` gates in parallel. Do not shadow the worker with an inline build.

Relay the observed exit code and the authoritative artifact paths and content verbatim — `.output/TestResults/summary.json (expand: resultFile, telemetryFile where passed=false)` — plus the runner's bounded verbatim stdout/stderr excerpt. The expand marker tells the runner to mechanically follow each failing run's `resultFile`/`telemetryFile` out of `summary.json` itself and relay them too, without opening any other file. A relayed `missing` means no file exists at the supplied path; the worker does not distinguish a stale prior-run `summary.json` from this run's own — the caller judges that from the relayed exit code and bounded output excerpt, never the worker. The runner selects the stdout/stderr excerpt mechanically: first matching error/diagnostic line with up to two preceding and six following lines (nine lines maximum), or the last nine lines when no match exists. Do not parse, interpret, classify, or summarize any relayed evidence — that is the caller's job. Do not make routing decisions. Do not invoke follow-up skills.
```

### Gate report

The worker relays only the exit code, raw artifacts, and one mechanically selected output excerpt — never a verdict. Then derive the gate report as YAML-like plain text in a fenced `text` block.

Take `gate`, `totals`, and all counts from the relayed `.output/TestResults/summary.json` content — the source of truth; echo `appName`, `dir`, `resultFile`, `telemetryFile`, and every `counts` number verbatim. **Never derive counts from console lines: `Codeunit … Success` lines are test codeunits (containers of tests), not tests.** Report totals per runner; never sum across runners — the unit test app runs through both al-runner and the container, so a cross-runner sum counts the same tests twice. If `counts` is `null` for a run, report `counts: unavailable` — do not substitute zeros. Omit `totals` and `runs` if no summary exists.

For a non-zero exit, parse the failing relayed `resultFile` (JUnit XML from either runner) for test names and `<failure message=…>`. If XML is unavailable, use explicit failure lines from the bounded excerpt; if neither exists, omit `failing_tests`. A compilation failure can leave `summary.json` stale: `missing`, or present but uncorroborated by this exit code and excerpt, makes its counts unusable; derive required `root_signal` from the excerpt instead. With a missing excerpt, use only `command exited <exit_code>; no command output captured`. Omit `first_error` and `log_excerpt` without evidence; cap `log_excerpt` at the relayed nine lines. `root_signal` is mandatory for `FAIL` and compresses observed evidence only — never cause speculation.

PASS example:

```text
VERDICT: PASS
cmd: pwsh "<skill-folder>/scripts/test.ps1"
gate: full
exit_code: 0

totals:
  al-runner: 1 run - 563 tests in 54 test codeunits - 563 passed, 0 failed, 0 skipped
  container: 2 runs - 601 tests in 58 test codeunits - 601 passed, 0 failed, 0 skipped

runs:
- runner: al-runner | app: unit-tests | passed: true | tests: 563 (54 test codeunits)
  resultFile: .output/TestResults/unit-tests/al-runner.xml
- runner: container | app: unit-tests | passed: true | tests: 563 (54 test codeunits)
  resultFile: .output/TestResults/unit-tests/last.xml
  telemetryFile: .output/TestResults/unit-tests/telemetry.jsonl
- runner: container | app: integration-tests | passed: true | tests: 38 (4 test codeunits)
  resultFile: .output/TestResults/integration-tests/last.xml
  telemetryFile: .output/TestResults/integration-tests/telemetry.jsonl
```

FAIL example:

```text
VERDICT: FAIL
cmd: pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
gate: unit
exit_code: 1

totals:
  al-runner: 1 run - 563 tests in 54 test codeunits - 561 passed, 2 failed, 0 skipped

runs:
- runner: al-runner | app: unit-tests | passed: false | tests: 563 (54 test codeunits, 2 failed)
  resultFile: .output/TestResults/unit-tests/al-runner.xml

failed_phase: test
root_signal: two tests failed on `Combination Logic`; expected `OR`, actual `AND`
failing_tests:
- DefaultRuleNestedMintPersistsRevisedDescriptionAndPreservesPriorHeader: Assert.AreEqual failed. Expected: OR. Actual: AND.
- DefaultWarningNestedMintPersistsRevisedDescriptionAndPreservesPriorHeader: Assert.AreEqual failed. Expected: OR. Actual: AND.
```

### Full gate delegation

Run:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Report `gate: full`.

### Fast unit test delegation (inner loop)

Run:

```powershell
pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
```

Report `gate: unit`.

## Configuration

Resolution order, highest wins:

1. **CLI flag** — script switches such as `-Force`; app/test paths come from env/config.
2. **Env var** — `ALBT_APP_DIR`, `ALBT_BC_CONTAINER_NAME`, `WARN_AS_ERROR`.
3. **`al-build.json`** in repo root.
4. **Built-in defaults.**

Key config fields:
- `appDir` — path to main app folder (default: `"app"`)
- `testApps` — array of test app directory paths (default: `["test"]`)
- `unitTestApp` — path to AL Runner unit test app (default: `""`, disabled). When set, `test.ps1` runs AL Runner unit tests as fast gate before container tests. App may also appear in `testApps` → container tests run all `testApps` regardless.
- `unitTestInitEvents` — fire BC lifecycle events (`OnCompanyInitialize`, `OnInstallAppPerCompany`) before AL Runner tests (default: `false`). Enable if unit tests depend on install-time data.
- `breakingChange.enabled` — enable breaking-change detection (default: `false`). See below.
- `breakingChange.baselinePackageCachePath` — baseline package cache dir (default: `.output/baseline-cache`, gitignored).

_Avoid_: editing plugin's template `config/al-build.json`. It's a template, not the live config. Repo-root copy is the live one.

## Breaking-change detection

Off by default (`breakingChange.enabled`). When on, two mechanisms, split by cost:

- **Compile-time, in every gate.** `provision.ps1` caches the latest release + deps and points `AppSourceCop.json` at them. A break then surfaces as a normal `AS00xx` diagnostic inside `test.ps1`'s compile (`-UnitTestOnly` included). `AS0001`–`AS0018` default to Error → red gate, like any cop. Not a special verdict — the rule ID is the signal; tune severity in `al.ruleset.json`. No `summary.json` change.
- **Standalone heavyweight.** `validate-breaking-changes.ps1` runs the broader AppSource sim (per-country, install/upgrade) against the same cache. Reads the cache, never downloads; empty cache → stops with *"run provision.ps1"*. Not wired into `test.ps1` — a feature-end / pre-release check, never the inner loop.

`provision.ps1` is the sole baseline fetcher and now refreshes per feature (re-run when a new release is cut). No release yet → detection stays cleanly off, never a false green.

## Container recovery

Situation → action:

| Symptom | Action |
|---|---|
| `test.ps1` fails on container connect / publish | `docker restart <container>`, re-run `test.ps1`. |
| Restart didn't fix it | `docker rm -f <container>`, re-run `test.ps1`. Script recreates it. |
| Recreate didn't fix it | Re-run `provision.ps1`, then `test.ps1`. |

**Anti-pattern: edit container manually.** No `docker exec`, no `Invoke-ScriptInBcContainer` to patch state, no hand-installing apps. Container is disposable; reproducibility lives in scripts.

## Next step

- **Green:** `Next:` resume the calling skill — usually `/al-implement` (continue the red→green cycle).
- **Red:** fix the failing test or production code, then re-run `/al-build`. Test failure with an unclear cause → `/al-debug-logging` first.

## Composition

- `/al-implement` — calls this after every RED, GREEN, `/al-refactor`, before stamping the task `phase: implemented`.
- `/al-debug-logging` — consumes `telemetry.jsonl` produced here (in per-app subfolders).
- `init.ps1`, `provision.ps1` — one-time setup before this skill is usable.

## Out of scope

- Provisioning symbols or installing compiler → `pwsh "<skill-folder>/scripts/provision.ps1"`.
- Debugging test failures → `/al-debug-logging`.
- Editing AL code → caller's job.
