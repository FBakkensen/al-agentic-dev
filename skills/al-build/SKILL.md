---
name: al-build
description: "Runs the scripted AL/Business Central toolchain: the compile-publish-test gate, provisioning, breaking-change validation, and the container lifecycle. Use when AL production or test code has changed and the change needs the gate before the task moves on, and whenever another skill needs one of these scripts run — this skill is their only invoker."
---

# al-build

Every script below lives in this skill's `scripts/` folder and runs from the consumer repo root. Use one sentence before the first tool call; update only on an important finding or direction change; put the outcome first when finishing. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

```
pwsh <path to this skill>/scripts/<name>.ps1
```

Run one at a time. `al-build.json` in the repo root is required — without it the scripts throw `Config file required`; `init.ps1` writes one. Host needs PowerShell 7.2+, Docker Desktop, the .NET SDK, Node.js 22+ with `npx` on PATH, and the BcContainerHelper module.

## The gate

| Command | Scope |
|---|---|
| `test.ps1 -UnitTestOnly` | AL Runner unit tests only. Compiles every app through the analyzer gate and never touches the container. Needs `unitTestApp` set in `al-build.json`. |
| `test.ps1 -AllTests` | Full gate. Compiles the main app and every `testApps` entry through the analyzer gate, runs AL Runner when configured, then publishes to the branch's agent container and runs the container tests. `-Force` republishes unchanged apps. |

Green is zero errors and zero warnings. `test.ps1` exits 0 on warnings by default, so set `WARN_AS_ERROR=true` to bind that bar to the exit code.

Name one mode in every request. `/al-build` runs only that sequence; it never selects or extends a test mode for its caller.

## Read the result, not the output

After the run, read `.output/TestResults/summary.json` and report from it. It carries `gate` (`full` or `unit`), per-runner `totals`, and `runs[]` — one record per run with `runner`, `appName`, `dir`, `passed`, `counts`, `resultFile`. For a red, open the `resultFile` of each run whose `passed` is false (JUnit XML) for the failing test names and their assertion messages. Reading the console stream instead floods the session with thousands of lines of build spew for numbers the summary already holds.

- Totals are per runner, never summed across them — the unit-test app runs under both AL Runner and the container, so a sum counts those tests twice.
- `counts: null` reports as unavailable, not as zeros.
- `Codeunit … Success` console lines count test codeunits, not tests. Counts come from the summary and the JUnit XML alone.
- `test.ps1` clears prior test results after its mode validation. A malformed config or early compile failure can leave no `summary.json`; take the red signal from the diagnostics instead.

Other artifacts: `.output/TestResults/<dir>/al-runner.xml` and `last.xml` (unit and container JUnit, separate files so a full gate leaves the unit result intact), and `.output/logs/build-timing.jsonl`, one entry per gate run on every exit path.

## Every other entry point

| Script | What it does |
|---|---|
| `provision.ps1` | Per-feature setup: installs the stable and prerelease AL compiler channels side by side under the tool cache, downloads symbol packages for every app into a cache keyed by checkout path, ensures the ALCops DLL suite is complete and version-consistent without replacing a valid installation, and — when `breakingChange.enabled` — caches the previous release as the breaking-change baseline. `-UpdateCompiler` forces a clean reinstall. |
| `validate-breaking-changes.ps1` | The heavyweight AppSource-style check the compile-time cop cannot do: per-country, install and upgrade, against the cached baseline. Reads the cache and never downloads — an empty cache stops with *run provision.ps1*. Exit codes are contract: `0` no break, `3` breaking change, `4` prerequisite missing, `1` environment failure. Feature-end or pre-release, never the inner loop. |
| `publish-apps.ps1` | Clean republish with no build and no tests: unpublishes every app dependency-reversed, then force-publishes in dependency order. Needs compiled `.app` artifacts already present. Loads a fresh container before a human walk. |
| `new-bc-container.ps1` | Creates and configures the golden BC container — one per BC version. |
| `commit-bc-container.ps1` | Commits the stopped golden container to the snapshot image. A machine restart comes first — a stopped container still holds files locked that the commit needs released — and only the user can take it: ask, wait for their confirmation, then run the commit. |
| `new-agent-container.ps1` | Spawns an agent container from the snapshot, named after the current git branch. `test.ps1` always derives that name from the branch, with no override. |
| `prune.ps1` | Removes agent containers whose branch is gone or that sat unused past seven days. `-Preview` for a dry run. |
| `init.ps1` | One-time per repo: writes `al-build.json` into the repo root with detected app and test directories, copied from this folder's `config/al-build.json` template. Set `testApps` afterwards. |
| `clean.ps1` | Deletes compiled `.app` files and clears publish state so the next run republishes. |
| `report-gate-metrics.ps1` | Gate wall-clock per workspace signature and gate scope, from `build-timing.jsonl`; `-GlobalLog` reads the cross-repo mirror. |
| `download-symbols.ps1`, `download-baseline.ps1` | The two fetches `provision.ps1` already performs. Run one alone to refresh only the symbols or only the baseline. |

The three container scripts are one sequence, run once per BC version: `new-bc-container.ps1`, `commit-bc-container.ps1`, then `new-agent-container.ps1` for each branch off the resulting snapshot.

## Configuration

Resolution order, highest first: script switch, environment variable (`ALBT_*`, plus `WARN_AS_ERROR` and `RULESET_PATH`), `al-build.json` in the repo root, built-in default. The fields that change behaviour are `appDir`, `testApps`, `unitTestApp`, `unitTestInitEvents`, and `breakingChange.enabled`. A unit-only project sets `"testApps": []`; the `["test"]` default fails loudly without a `test/` folder.

Analyzer selection is `al.codeAnalyzers` in `.vscode/settings.json`, in the AL extension's own notation — `<appDir>/.vscode/settings.json` wins, the repo root file is the shared fallback. No `settings.json` means no analyzers, and a listed analyzer that cannot be resolved stops the build rather than quietly compiling with less lint coverage than asked for. Diagnostic prefixes: `AA` CodeCop, `AW` UICop, `AS` AppSourceCop, `PTE` PerTenantExtensionCop, `AC`/`DC`/`FC`/`LC`/`PC`/`TA` the ALCops family. `${AppSourceCop}` must be listed for compile-time breaking-change detection to run at all; a break then arrives as an ordinary `AS00xx` error.

## Container recovery

For ordinary container failures, recovery escalates from outside it: `docker restart <container>` and re-run the gate; then `docker rm -f <container>` and re-run, which recreates it; then re-run `provision.ps1` and the gate. Nothing inside the container is patched by hand — `docker exec` or installing apps by hand leaves state the scripts cannot reproduce.

## Close

A green gate with per-runner totals from `summary.json`, or a red named by its failing tests and the diagnostic behind them.
