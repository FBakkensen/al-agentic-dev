# al-build

## What it is for

The gate, and the only skill that runs the PowerShell substrate. Every script in this toolkit lives in `skills/al-build/scripts/` and `/al-build` is their sole invoker — [`/al-provision`](al-provision.md), [`/al-validate-breaking-changes`](al-validate-breaking-changes.md), and [`/al-user-verification`](al-user-verification.md) all reach them by naming this skill, never by naming a path.

## When you reach for it

- AL production or test code changed and the change needs the gate before the task moves on.
- Another skill needs one of the scripts run.

## What it produces

A green gate with per-runner totals, or a red named by its failing tests and the diagnostic behind them.

| Command | Scope |
|---|---|
| `test.ps1` | Full gate — compile through the analyzers, publish to the branch container, run the container tests. Minutes. |
| `test.ps1 -UnitTestOnly` | Inner loop — compile, run the AL Runner unit tests, skip the container. Seconds. |

Green is zero errors and zero warnings. `test.ps1` exits 0 on warnings by default; set `WARN_AS_ERROR=true` to bind that bar to the exit code.

The result is read from `.output/TestResults/summary.json`, not from the console stream. The summary carries the gate scope, per-runner totals, and one record per run with its JUnit result file. Reading the console instead floods a session with thousands of lines of build spew for numbers the summary already holds.

## The other entry points

| Script | What it does |
|---|---|
| `provision.ps1` | Per-feature refresh: compiler channels, symbol packages, analyzers, breaking-change baseline. |
| `validate-breaking-changes.ps1` | Per-country install-and-upgrade validation against the cached baseline. |
| `pagescript-replay.ps1` | Replays Page Scripting recordings against the container. |
| `publish-apps.ps1` | Clean republish, no build and no tests. |
| `new-bc-container.ps1`, `commit-bc-container.ps1`, `new-agent-container.ps1` | The container lifecycle — one sequence, once per BC version. |
| `prune.ps1` | Removes agent containers for dead branches or ones unused past seven days. |
| `init.ps1` | One-time per repo: writes `al-build.json` into the repo root. |
| `clean.ps1` | Deletes compiled `.app` files and clears publish state. |
| `report-gate-metrics.ps1` | Gate wall-clock from `build-timing.jsonl`. |
| `download-symbols.ps1`, `download-baseline.ps1` | The two fetches `provision.ps1` already performs, run alone. |

## Requirements

`al-build.json` in the consumer repo root, written by `init.ps1`. On the host: PowerShell 7.2+, Docker Desktop, the .NET SDK, Node.js 22+ with `npx` on PATH, and BcContainerHelper.

Analyzer selection comes from `al.codeAnalyzers` in `.vscode/settings.json`. No `settings.json` means no analyzers, and an analyzer that cannot be resolved stops the build rather than quietly compiling with less lint coverage than you asked for.

The container is disposable. Recovery goes through the scripts, in order — restart, then remove and recreate, then re-provision. Hand-patching through `docker exec` leaves state the scripts cannot reproduce.
