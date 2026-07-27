---
name: al-build
description: "Build and test AL/Business Central projects: compile, publish, and run the tests. Use after modifying AL code or tests, and as the required gate before committing. Other skills and agents reach for this skill whenever they need the gate; it delegates execution to the isolated al-gate-runner agent."
allowed-tools: ["execute", "read", "agent"]
---

# /al-build — build and test gate

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Zero warnings and zero errors → green; anything else → red. `test.ps1` exits 0 on warnings by default (`WARN_AS_ERROR=false`), so the zero-warning bar is this skill's: treat any warning in the gate output as red, or set `WARN_AS_ERROR=true` to bind the bar to the exit code.

The gate runs two test layers: Unit (AL Runner) and Integration (container + TestPage). See [`test-strategy.md`](../../references/testing/test-strategy.md).

## The gate

**`al-gate-runner` executes every gate run.** The named custom agent runs one gate command once and relays the exit code, artifacts, and one bounded output excerpt — its own body carries the worker rules. This holds from the main session and from inside another agent alike, and the worker's isolation is what keeps verbose build output out of the caller's context.

`al-gate-runner` unavailable → report `BLOCKED`, name it as missing, and stop; the gate has no substitute runner.

Two preconditions hold before the spawn: `al-build.json` sits in the repo root, and the compiler and symbols are provisioned. Either missing → **Stop.** Provision first — `/al-provision` on a `kind: provision` task, or the Setup bootstrap below.

The gate command handed to the worker, run from the consumer repo root:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Force republish adds `-Force`. The full gate is the scope: `test.ps1` owns symbol resolution and container publish, which codeunit filtering and a bare `alc.exe` invocation both bypass.

Run one gate at a time. The spawn prompt carries exactly what the caller alone knows:

- the one gate command — full, or `-UnitTestOnly`;
- the authoritative artifact paths, marking the summary for mechanical expansion: `.output/TestResults/summary.json (expand: resultFile where passed=false)`;
- this line verbatim: **findings must name file, object, and the observed fact; no verdict words without the check that produced them.**

The caller — never the worker — judges whether a relayed `summary.json` is this run's own: `missing` means no file exists; a present file is current-run evidence only when the relayed exit code and bounded excerpt corroborate it.

After the worker returns, close the completed thread before interpreting or reporting the result. Report the outcome as the mid-task Gate one-liner per [GROUND-RULES.md](../../references/GROUND-RULES.md) — never paste the worker's block raw.

Test failure with an unclear runtime path → invoke the `al-debug-logging` custom agent; a clear assertion or compile failure needs no probes.

### Fast unit test (inner loop)

When `unitTestApp` is configured in `al-build.json`, the gate command narrows to AL Runner unit tests:

```powershell
pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
```

Compiles the main app, every `testApps` entry, and the unit-test app through the analyzer gate; then runs AL Runner and exits without a container. `testApps` must resolve in this mode: unit-only projects set `"testApps": []`; the default `["test"]` fails loudly without `test/`. No container publish means this is the cheap variant — seconds where the full gate spends minutes.

## Results

### Outputs (per test run)

- `.output/TestResults/<dirName>/last.xml` → JUnit XML from the container run.
- `.output/TestResults/<dirName>/al-runner.xml` → JUnit XML from the AL Runner run. Separate file, so a full gate leaves the unit result intact.
- `.output/TestResults/summary.json` → machine-readable summary: `gate` (`full`/`unit`), `totals` per runner, `runs[]` with one record per test run (`runner`, `appName`, `dir`, `passed`, `counts`, `resultFile`).
- `.output/logs/build-timing.jsonl` → one gate-metrics entry per run, mirrored to `~/.al-build/gate-metrics.jsonl`.

Take `resultFile` paths from `summary.json` run records; a glob can pick up stale files sitting beside fresh output. `test.ps1` writes `summary.json` only after a unit-test failure, unit-only pass, or full-gate completion; bad `al-build.json` or a compile failure leaves a prior file untouched.

### Gate metrics (automatic)

Each `test.ps1` run records one entry in `.output/logs/build-timing.jsonl` — on every exit path: pass, fail, throw — and mirrors it to `~/.al-build/gate-metrics.jsonl` (override: `ALBT_GATE_METRICS_GLOBAL_PATH`). Phase attribution derives from recorded evidence; callers pass no flags. Report repo-local metrics with `pwsh "<skill-folder>/scripts/report-gate-metrics.ps1"` or cross-repo metrics with `-GlobalLog`.

### Gate report

Derive the gate report from the worker's relay — the exit code, the artifacts, and the bounded excerpt it returns. Format: YAML-like plain text in a fenced `text` block, `VERDICT: PASS|FAIL` on line 1. `gate:` names the executed variant — `full`, or `unit` for `-UnitTestOnly`.

- Take `totals` and all counts from the relayed `.output/TestResults/summary.json` content — the source of truth. Echo `appName`, `dir`, `resultFile`, and every `counts` number verbatim.
- Counts come from that summary and the JUnit XML only: `Codeunit … Success` console lines are test codeunits (containers of tests), not tests.
- Report totals per runner; never sum across runners — the unit test app runs through both AL Runner and the container, so a cross-runner sum counts the same tests twice.
- `counts` of `null` for a run → report `counts: unavailable`, never zeros.
- No summary → omit `totals` and `runs`.
- For a non-zero exit, parse the failing relayed `resultFile` (JUnit XML from either runner) for test names and `<failure message=…>`. XML unavailable → use explicit failure lines from the bounded excerpt. Neither → omit `failing_tests`.
- A compilation failure can leave `summary.json` stale: `missing`, or present but uncorroborated by this exit code and excerpt, makes its counts unusable. Derive `root_signal` from the excerpt instead.
- Missing excerpt → use only `command exited <exit_code>; no command output captured`.
- Omit `first_error` and `log_excerpt` without evidence. Cap `log_excerpt` at the relayed nine lines.
- `root_signal` is mandatory for `FAIL` and compresses observed evidence only — never cause speculation.

A PASS report has the same head plus `totals` and `runs`: totals per runner, with the unit-test app legitimately listed under both `al-runner` and `container`.

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

## Prerequisites

PowerShell 7.2+ (`pwsh`), Docker Desktop, .NET SDK, Node.js ≥ 22 with `npx` on PATH (ALCops analyzers install through the official `@alcops/core` CLI), and the BcContainerHelper PowerShell module.

## Setup

One-time per repo, run by the developer:

1. `pwsh "<skill-folder>/scripts/init.ps1"` → drops `al-build.json` in repo root.
2. Set `testApps` to list your test app directories.
3. `pwsh "<skill-folder>/scripts/provision.ps1"` → compiler, symbols, and analyzers. Inside a feature with a `kind: provision` task, `/al-provision` owns this run.

Provision keeps two private compiler channels side by side — latest stable at `<ToolCacheRoot>/al/stable`, latest prerelease at `<ToolCacheRoot>/al/prerelease` — refreshed every run, the user's global `al` dotnet tool untouched. The build picks the channel repo-wide from the highest app.json `runtime` major across all apps; prerelease only when that major exceeds the installed stable. `-UpdateCompiler` forces a clean reinstall.

### Container lifecycle

One golden container per BC version, snapshotted once, then cheap branch-scoped copies:

1. `new-bc-container.ps1` → golden BC container, fully configured.
2. Restart the PC — the stopped container still holds locked files the snapshot commit needs released.
3. `commit-bc-container.ps1` → snapshot image.
4. `new-agent-container.ps1` → agent container from the snapshot, named from the current git branch.

`prune.ps1` removes agent containers whose branch is gone or that sat unused past seven days (`-Preview` for a dry run). `publish-apps.ps1` clean-republishes every configured app: unpublish all dependency-reversed, then publish in dependency order — no build, no tests.

## Configuration

**`al-build.json` in the repo root is required — the gate throws `Config file required` without it.** Fields may default; the file may not. Resolution order, highest wins:

1. **CLI flag** — script switches such as `-Force`; app/test paths come from env/config.
2. **Env var** — `ALBT_*`, plus `WARN_AS_ERROR` and `RULESET_PATH`.
3. **`al-build.json`** in repo root.
4. **Built-in defaults.**

Key config fields:

- `appDir` — path to main app folder (default: `"app"`)
- `testApps` — array of test app directory paths (default: `["test"]`)
- `unitTestApp` — path to AL Runner unit test app (default: `""`, disabled). When set, `test.ps1` runs AL Runner unit tests as fast gate before container tests. App may also appear in `testApps` → container tests run all `testApps` regardless.
- `unitTestInitEvents` — fire BC lifecycle events (`OnCompanyInitialize`, `OnInstallAppPerCompany`) before AL Runner tests (default: `false`). Enable if unit tests depend on install-time data.
- `breakingChange.enabled` — enable breaking-change detection (default: `false`). See below.
- `breakingChange.baselinePackageCachePath` — baseline package cache dir (default: `.output/baseline-cache`, gitignored).

Env overrides, with their built-in defaults:

| Env var | Default |
|---|---|
| `ALBT_APP_DIR` | `app` |
| `WARN_AS_ERROR` | `false` |
| `RULESET_PATH` | `al.ruleset.json` |
| `ALBT_BC_ARTIFACT_COUNTRY` | `w1` |
| `ALBT_BC_ARTIFACT_SELECT` | `Latest` |
| `ALBT_BC_MEMORY_LIMIT` | `8g` |
| `ALBT_BC_SERVER_INSTANCE` | `BC` |
| `ALBT_BREAKING_CHANGE_ENABLED` | `false` |
| `ALBT_BASELINE_CACHE_PATH` | `.output/baseline-cache` |
| `ALBT_BC_CONTAINER_USERNAME` / `ALBT_BC_CONTAINER_PASSWORD` | `admin` / `P@ssw0rd` |
| `ALBT_BC_GOLDEN_CONTAINER_NAME` | `bctest` |
| `ALBT_BC_IMAGE_NAME` | `bctest:snapshot` |
| `ALBT_TOOL_CACHE_ROOT` | `~/.bc-tool-cache` |

The agent container name has no override: `test.ps1` always derives it from the current git branch.

The live config is the copy in the consumer repo root; the plugin's `config/al-build.json` is the template `init.ps1` copies from.

## Analyzers

Microsoft's four cops (CodeCop, UICop, AppSourceCop, PerTenantExtensionCop) ship with the compiler. `provision.ps1` adds the community ALCops analyzers — six cops plus `ALCops.Common.dll` — into each compiler channel's `Analyzers` folder, latest release on every run, no pinning. ALCops replaces the discontinued BusinessCentral.LinterCop: the two share diagnostic IDs and must never load together; provision deletes a leftover LinterCop DLL.

Selection is `al.codeAnalyzers` in `.vscode/settings.json`, official AL notation (`${CodeCop}`, `${analyzerFolder}ALCops.LinterCop.dll`, …) — the same file drives the AL extension in VS Code. Resolution is per app: `<appDir>/.vscode/settings.json` wins, repo-root `.vscode/settings.json` is the shared fallback. Every app — main, test apps, and the unit-test app — compiles through the analyzer gate in every mode (`-UnitTestOnly` included). No `settings.json` → no analyzers. A requested analyzer that cannot be resolved fails fast — the build stops rather than silently compiling with less lint coverage than the settings ask for. `ALCops.Common.dll` is appended automatically when missing from the list.

Diagnostic prefixes: `AA` CodeCop, `AW` UICop, `AS` AppSourceCop, `PTE` PerTenantExtensionCop, `AC` ApplicationCop, `DC` DocumentationCop, `FC` FormattingCop, `LC` LinterCop, `PC` PlatformCop, `TA` TestAutomationCop.

## Breaking-change detection

**Off by default (`breakingChange.enabled`); when on, compile-time detection runs in every gate while heavyweight validation runs standalone at feature end or pre-release.**

- **Compile-time, in every gate.** `provision.ps1` caches the latest release + deps and points `AppSourceCop.json` at them. `${AppSourceCop}` must be listed in the applicable `.vscode/settings.json` — without it the compile-time path never runs. A break then surfaces as a normal `AS00xx` diagnostic inside `test.ps1`'s compile (`-UnitTestOnly` included). `AS0001`–`AS0018` default to Error → red gate, like any cop. Not a special verdict — the rule ID is the signal; tune severity in `al.ruleset.json`. No `summary.json` change.
- **Standalone heavyweight.** `validate-breaking-changes.ps1` runs the broader AppSource-style validation (per-country, install/upgrade) against the same cache, driven by `/al-validate-breaking-changes`. Reads the cache, never downloads; empty cache → stops with *"run provision.ps1"*. Not wired into `test.ps1` — a feature-end / pre-release check, never the inner loop.

`provision.ps1` is the sole baseline fetcher and refreshes per feature (re-run when a new release is cut). No release yet → detection stays cleanly off, never a false green.

## Container recovery

| Symptom | Action |
|---|---|
| `test.ps1` fails on container connect / publish | `docker restart <container>`, re-run the gate. |
| Restart didn't fix it | `docker rm -f <container>`, re-run the gate. `test.ps1` recreates it. |
| Recreate didn't fix it | Re-run `provision.ps1`, then the gate. |

The container is disposable and reproducibility lives in the scripts, so recover only through the scripted lifecycle above — restart → delete → re-run. A hand patch (`docker exec`, `Invoke-ScriptInBcContainer`, hand-installing apps) leaves container state the scripts cannot reproduce.

## Next step

- **Green:** `Next:` resume the calling skill.
- **Red:** fix the failing test or production code, then delegate the gate again. An unclear runtime path → invoke the `al-debug-logging` custom agent first.

## Composition

- **Called by** — every skill and agent that needs the gate. Which variant to run, and how often, is each caller's own contract; this skill states neither.
- **Spawns** — `al-gate-runner`, the worker for every gate run.

## Out of scope

- Editing AL code → caller's job.
