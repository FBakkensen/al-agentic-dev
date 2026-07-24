# al-build

The build/test gate for AL/Business Central. It compiles, publishes to a local Docker container, runs tests, and writes results to `.output/TestResults/<dirName>/`.

*Dev-time only — this file never ships. The shipped surface is `SKILL.md` and `scripts/`. See the root `AGENTS.md`, "Shipped vs dev-time files".*

## Layout

```
skills/al-build/
├── SKILL.md            # Agent-facing entry point
├── config/             # al-build.json default shape
└── scripts/            # PowerShell 7.2+: init.ps1, provision.ps1, test.ps1, ...
```

## Lifecycle (in consuming projects)

1. `init.ps1` drops `al-build.json` into the consumer repo root.
2. `provision.ps1` refreshes the build environment per feature: compiler, symbols, ALCops, and the breaking-change baseline when enabled. It installs both compiler channels (stable and prerelease) side by side. Both channels refresh to latest on every run. `-UpdateCompiler` forces a clean reinstall. Symbols re-fetch every run. The baseline advances per release. The per-feature re-run is therefore the norm rather than one-time machine setup.
3. `test.ps1` is the gate. It writes per-run result XML (`last.xml` for the container, `al-runner.xml` for AL Runner), plus `telemetry.jsonl` and `summary.json`.

### Compiler channels (stable / prerelease)

al-build owns two private side-by-side compilers and never touches the global `al` dotnet tool. The global tool is the user's own LSP/MCP daily driver, on whatever version they chose, often a prerelease. `provision.ps1` never installs, updates, uninstalls, or invokes it.

`Install-ALCompiler` installs the latest stable at `<ToolCacheRoot>/al/stable` and the latest prerelease at `<ToolCacheRoot>/al/prerelease`, both via `dotnet tool install --tool-path`. The prerelease channel adds `--prerelease`. It refreshes both channels every provision and runs `Install-ALCops` into each channel's `Analyzers` folder. The sentinel at `<ToolCacheRoot>/al/sentinel.json` (`schemaVersion: 2`) records each channel's `commandPath`, `alcPath`, and `version`, plus `stableMajor` and `prereleaseMajor`.

The build picks the channel from app.json `runtime`. `Get-RequiredRuntimeMajor` takes the max `runtime` major across all apps: main, test, and unit. An app with no `runtime` contributes nothing and is pinned to stable. `Resolve-CompilerChannel` returns `prerelease` only when the required major exceeds the installed stable major, otherwise `stable`. It throws when the required major exceeds even the prerelease major. The mapping rests on one bet: the Tools-package major equals the `runtime` major. That has held for years (stable `17.x` ↔ runtime `17.0`).

`Get-LatestCompilerInfo` resolves the channel offline from the sentinel, keeping NuGet off the gate hot path. It fails loud when the selected channel's compiler is absent on disk. `Invoke-ALBuild` then invokes that channel's `al` by full path. The channel is repo-wide: `test.ps1` computes the major once and passes it to every `Invoke-ALBuild`. A single test app at a higher `runtime` therefore pulls the whole build onto prerelease, production app included. Symbols and the container BC version do not follow the channel. Aligning that scope is the dev's job.

### Breaking-change baseline

`download-baseline.ps1` is the sole baseline fetcher. `provision.ps1` invokes it when `breakingChange.enabled`. It caches the latest release `.app` plus AL-Go deps (flat) under `baselinePackageCachePath`, then writes `version` and `baselinePackageCachePath` into `app/AppSourceCop.json` from that same fetch. Version and cache therefore always match, which makes `AS0003` (version-not-in-cache) structurally impossible. `validate-breaking-changes.ps1` (the heavyweight `Run-AlValidation` path) reads that cache, never downloads, and fails loud on an empty cache. The compile-time path needs no script: once `version` and the cache are set, AppSourceCop reports `AS00xx` during `Invoke-ALBuild`.

## Smoke test

Run this after changing the skill invocation contract, delegation behavior, script contract, or gate behavior.

1. From the marketplace repo working tree, capture its path: `$marketplace = $PWD.Path`. Create a disposable dir under `$env:TEMP` with a random suffix and `Set-Location` into it. The rest of the smoke test runs from the disposable dir. `$marketplace` invokes the dev-time scripts.
2. `git init`, `git checkout -b smoke-<scenario>`, then `git commit --allow-empty -m "init"`. The branch name becomes the container name via `Get-BCAgentContainerName`. Without a commit the branch lookup fails and falls back to `bctest`, colliding with the golden container. Never use `main` or `bctest` as branch name.
3. Add a minimal AL app under `app/` and one or more test apps under `test/`, `test-integration/`, etc. Test apps must depend on the main app so provisioning proves local deps are not downloaded as symbol packages.
4. Add repo-root `al-build.json` with `appDir` and a `testApps` array.
5. Verify the snapshot image from `container.imageName` exists. Do not bootstrap a golden container unless that is the explicit target.
6. Run `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/provision.ps1"` from the disposable repo before invoking the skill. This step is mandatory: it installs and verifies the compiler, AL Runner, and symbol caches for the temp app and test apps.
7. From the disposable repo, invoke the `al-build` skill as a black-box skill use. The smoke prompt never runs `test.ps1` directly, never restates the subagent contract, and never describes the model, reasoning, or delegation details from `SKILL.md`. The smoke tests whether the host follows `SKILL.md` on its own.
8. Verify the host spawned the gate worker according to `SKILL.md`. Inspect the worker's returned gate report plus any emitted `.output/TestResults/<dirName>/last.xml` and `telemetry.jsonl` files.
9. Verify `.output/TestResults/summary.json` lists all test runs (`runs[]` with `runner`, `passed`, `counts`) with the expected pass/fail when the full gate reaches result emission.
10. Verify gate metrics. `.output/logs/build-timing.jsonl` gained one entry per gate run, failed gates included. Point `ALBT_GATE_METRICS_GLOBAL_PATH` at a file under the temp dir before running gates, so the smoke never pollutes the real `~/.al-build/gate-metrics.jsonl`. Assert:
    - Each entry carries `gate`, `outcome`, `headSha`, and the `dirty` fingerprint.
    - A seeded assertion failure with a dirty test app gives `outcome=failed` and `dirty.tests>0`.
    - A broken compile with a dirty main app gives `outcome=error` and `dirty.app>0`.
    - A clean committed tree gives all dirty counts 0.
    - The mirror line carries `repo` and `repoPath`.
11. Clean up: `docker rm -f <container-name>`, then delete the temp dir.

The smoke test must exercise the full gate. Never use test-codeunit filtering. Run container tests sequentially, one branch/container at a time.

Smoke runs continue past disposable setup failures. Repair a failure in the temp app, temp test app, generated `al-build.json`, disposable git branch, or other smoke scaffolding in place. Rerun provision when symbols or config changed. Then invoke the `al-build` skill again. The smoke concludes only after at least one real full-gate execution has run through the skill's own instructions and its result has been inspected. A setup error is a final result only when the blocker is non-recoverable or outside the disposable smoke setup.

Smoke prompts spell out the scaffolding: setup, provision, repair, artifacts, and cleanup. They stay black-box on the gate itself. Gate behavior belongs in `SKILL.md`, and the smoke verifies that the skill contract is sufficient on its own.

## Smoke test: golden container with AL-Go dependencies

Run this after changing dependency-install or gh-CLI dispatch in `new-bc-container.ps1`, `Install-AlGoDependencies`, `Get-ReleaseAppFiles`, or `Get-RepoFromUrl`. The standard smoke test above does not exercise `Install-AlGoDependencies` at all.

1. Same setup as the standard smoke test: capture `$marketplace = $PWD.Path` from the marketplace repo working tree, then disposable dir + branch + commit.
2. Add a minimal `app/` and repo-root `al-build.json`.
3. Add `.AL-Go/settings.json` with `appDependencyProbingPaths` containing:
   - one github.com entry (a small public AL-Go-published repo, version `latest`),
   - one `*.ghe.com` entry, only if you have GHE creds. Otherwise omit it.
4. Run `gh auth status` to confirm authentication to each host listed.
5. Run `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/new-bc-container.ps1"`.
6. Expected: each probing-path app downloaded, published, container prepared for commit, script exits 0.

### Failure-mode checks (run each in isolation)

- **Non-existent repo.** Add a probing path pointing at a repo that does not exist on that host. Expect a warning naming the host and the gh exit code, `exit 1` from `new-bc-container.ps1`, and a container NOT stopped or prepared for commit.
- **GHE auth gap.** `gh auth logout --hostname <tenant>.ghe.com`, then re-run. Expect: github.com entries still install, the warning names the GHE host plus the `gh auth login --hostname` fix command, `exit 1`.
- **Unparseable URL.** Set a probing path's `repo` to garbage (`"not a url"`). Expect a warning naming the entry, that probing path counted as failed, `exit 1`.

The failure-mode runs validate the fail-loud contract. Silent partial-success is the shape of the original GHE-host defect.

## Smoke test: analyzers

All ten diagnostic families must surface from seeded violations.

Run this after changing `Install-ALCops`, `Get-EnabledAnalyzerPath`, `Select-CompilerCandidate`, or the analyzer wiring in `Invoke-ALBuild`. It is container-free: analyzers act at `alc` time on the host, and Docker is never involved.

Seed one violation per family (`AA` `AW` `AS` `PTE` `AC` `DC` `FC` `LC` `PC` `TA`). "Compile exits 0 with `/analyzer:` args" is a weak oracle: alc can fail to load one DLL, warn, and still compile green. Only a surfaced diagnostic proves each DLL loaded *and* executed.

1. Same scaffolding as the standard smoke: capture `$marketplace`, disposable dir, `git init`, branch `smoke-analyzers`, empty commit.
2. Minimal `app/` (idRange 50000-50149) and a unit-test app (idRange 50150-50199, depends on the main app, configured as `unitTestApp` in `al-build.json`). The main `app.json` needs `"application"` and `"features": ["TranslationFile"]`. Without them AppSourceCop aborts the build with AS0100/AS0015 before any seed surfaces.
3. `AppSourceCop.json` in the main app: `{"mandatoryAffixes": ["SMK"]}` only. No `name`/`publisher`/`version` keys — those activate baseline comparison and fire AS0003.
4. Repo-root `.vscode/settings.json`, official AL notation only: `${CodeCop}`, `${UICop}`, `${AppSourceCop}`, `${PerTenantExtensionCop}`, six `${analyzerFolder}ALCops.*.dll` entries plus `${analyzerFolder}ALCops.Common.dll`.
5. Repo-root `al.ruleset.json`: downgrade `AS0011` + `PTE0008` (Error→Warning, else the build aborts before warnings print) and escalate `AC0014`, `DC0001`, `TA0001` (Info→Warning, else invisible). In `al-build.json`: `warnAsError: false` and `"testApps": []`. The empty `testApps` is required since v0.72.0: `-UnitTestOnly` now compiles every `testApps` entry, so the `['test']` default would throw on the missing `test/` dir.
6. Seed one violation per family. The proven set below is from v0.8.6. Severities are read from tagged `DiagnosticDescriptors.cs`, which overrules the alcops.dev rule tables when they disagree:

| Family | Rule | Seed |
|---|---|---|
| AA | AA0008 | parameterless call without `()` |
| AW | AW0008 | `repeater` on a Card page |
| AS | AS0011 | object name without the SMK affix (empty codeunit) |
| PTE | PTE0008 | action without `ApplicationArea` on a table-free page named with the affix |
| AC | AC0014 | `ToolTip` not ending with a dot (table field; `InherentPermissions = RIMD` keeps AC0010 quiet) |
| DC | DC0001 | `Commit()` without a `//` comment (local procedure keeps DC0004 quiet) |
| FC | FC0001 | `procedure Foo();` — trailing semicolon with a `begin end` body |
| LC | LC0003 | `Customer: Record 18;` — numeric object reference |
| PC | PC0001 | FlowField without `Editable = false` |
| TA | TA0001 | global non-`[Test]` procedure in a `Subtype = Test` codeunit, seeded **in the main app** |

The TA seed stays in the main app: Step 1 compiles main in every mode, so the seed is path-independent. Since v0.72.0 `test.ps1` also runs `Invoke-ALBuild` on the unit-test app in every mode (`-UnitTestOnly` included). A unit-test-app TA seed therefore surfaces too. To prove that path, add a second TA seed in the unit-test app as a dedicated assertion. Never relocate the main-app one.

7. `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/provision.ps1"` → expect exit 0, the seven `ALCops.*.dll` files in **each channel's** compiler `Analyzers` folder (`<ToolCacheRoot>/al/stable` and `.../prerelease`), and no `BusinessCentral.LinterCop.dll`. Provision deletes the legacy DLL: it shares diagnostic IDs with ALCops, and the two must never co-load. A runtime-less smoke app builds with the stable channel, so assert that one. Assert the prerelease folder is populated too, proving both channels provisioned.
8. `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/test.ps1" -UnitTestOnly`, full output captured → assert every one of the ten prefixes appears as a diagnostic.
9. When a seed will not fire, switch to another rule in the same family. Do not keep tuning the seed. The smoke proves the *prefix family*, never any specific rule ID. ALCops is pre-1.0, and rule IDs and default severities churn between releases.
10. Failure-mode check (fail-loud contract): remove one ALCops DLL from the **stable** channel's Analyzers folder (the channel a runtime-less smoke app builds with) and re-run the gate. Expect the build to throw naming the unresolvable analyzer, never a green compile with reduced coverage. Re-run provision to restore.
11. Per-app config check: drop a reduced `app/.vscode/settings.json` (e.g. only `${CodeCop}` + `${analyzerFolder}ALCops.LinterCop.dll`), re-run, and expect exactly those families and nothing else. Delete it after. App-local settings win over the repo-root fallback. Each app — main, every test app, and the unit-test app — resolves analyzers from its own `.vscode/settings.json`. Each compiles through the analyzer gate in every mode (`-UnitTestOnly` included). Unit-test-app analyzer config therefore takes effect there too.
12. Cleanup: delete the temp dir. No container to remove.

## Editing rules

- **The config priority chain is fixed.** CLI flag > env var (`ALBT_*`) > `al-build.json` > built-in defaults. Never reorder it or add a fifth tier.
- **`provision.ps1` is the only script that writes consumer source.** It writes `version` and `baselinePackageCachePath` into `app/AppSourceCop.json`, via `download-baseline.ps1`. The gate worker (`test.ps1`, delegated, runs constantly) stays read-only on source. Never give it a source-mutating step. AppSourceCop edits use a PSCustomObject read-modify-write, which preserves key order and keeps diffs stable. The `version`/`baselinePackageCachePath` keys are provision-owned. The rest (affixes, countries) are the dev's.
- **`validateCurrent` is a `Run-AlValidation` param, not the enable switch.** `breakingChange.enabled` gates the feature. Resolve `validateCurrent` through `ConvertTo-Boolean`, never `-eq "1"`. The env round-trip stringifies the JSON boolean (`true` → `"True"`), so a string compare reads false silently.
- **Never pass `throwOnError` to `Run-AlValidation`. Classify its returned strings.** The verdict comes from `Get-AlValidationVerdict` on the *returned* strings: findings → exit 3 (`Analysis`, stop for a human), environment errors → exit 1 (fix, re-run). A throw conflates the two, so a docker hiccup masquerades as a breaking change. Without the classification the result strings return unthrown — the original false-green, where the gate exited 0 on everything, breaking changes included.
- **The verdict classifier couples to two BcContainerHelper internals.** One: the `Unexpected error while validating app` prefix its internal catch stamps on environment errors. Two: `Run-AlValidation` emitting only `$validationResult` to the pipeline. Re-verify both on module bumps.
- **`skipVerification = $true` protects the same verdict.** Without it, signature-verification lines (`...is not signed, result is NotSigned`) land in the result list and classify as findings. Locally built apps and default AL-Go CI baselines are both unsigned, so the gate could never pass. Signing belongs to the publish pipeline, not this gate.
- **The `NewBcContainer` override must keep forcing `isolation = 'process'`.** The module has no isolation parameter. Auto-detection picks hyperv on kernel mismatch, failing hosts without Hyper-V.
- **Outputs are the contract.** `.output/TestResults/<dirName>/last.xml` (container, JUnit), `.output/TestResults/<dirName>/al-runner.xml` (AL Runner, JUnit), `.output/TestResults/<dirName>/telemetry.jsonl`, and `.output/TestResults/summary.json` (`gate` + per-runner `totals` + `runs[]` with `counts`). `/al-debug-logging` reads `telemetry.jsonl` from the subfolders. Never rename or relocate them.
- **Gate metrics record evidence, never claimed intent.** `test.ps1` self-captures the dirty-workspace fingerprint (`dirty.app`/`dirty.tests`/`dirty.other` via `Get-DirtyFileCounts`) plus `headSha` at gate start. Phase attribution (prod-only ≈ mutation, test-only ≈ RED, mixed ≈ TDD loop, clean ≈ closeout) is derived at report time by `Get-GateMetricsSummary`. Never add a caller-supplied phase tag: an agent-set flag silently corrupts attribution, while tree state cannot lie.
  - One `build-timing.jsonl` entry lands per gate on *every* exit path — pass, fail, throw. The try/finally in `test.ps1` is that invariant. The AL Runner fail-fast path must never again exit before logging.
  - Each entry mirrors to `~/.al-build/gate-metrics.jsonl` (override with `ALBT_GATE_METRICS_GLOBAL_PATH`). A mirror failure warns and continues. Telemetry must not fail the build.
  - Timestamps are written with `ToString('yyyy-MM-dd HH:mm:ss', InvariantCulture)`, so every locale emits `:` time separators. A bare `ToString` was the historical bug: da-DK wrote `.` time separators. The parser accepts both shapes for legacy entries, which bucket as `unknown`.
- **Both result XMLs are deliberately JUnit, one parser.** `Invoke-ALTest` passes `JUnitResultFileName`, not `XUnitResultFileName` — BcContainerHelper supports both, and the XUnit dialect differs down to the failure element. AL Runner's `--output-junit` is also JUnit. `Get-JUnitTestCounts` parses both. Counts are never derived from console lines: the `Codeunit … Success` stream lines are test codeunits, not tests. Missing or unparseable XML → `counts: null`, never zeros.
- **Scripts run from the consumer repo root.** Never from this marketplace repo. Keep `Set-Location` discipline, and never assume `$PSScriptRoot` is the working dir.
- **PowerShell 7.2+ only.** `#Requires -Version 7.2`. _Avoid_: `powershell.exe` (5.1) — pipeline-chain `&&`/`||` and `??` aren't there.
- **SKILL.md's subagent block is the canonical invocation.** Build output is verbose, and the subagent contains it. Keep that block accurate.
- **Container recovery is restart → delete → re-run.** Never document a manual fix path inside the container.
- **Keep the publish-all → sync barrier → test-all order.** `test.ps1` Step 8 publishes every test app, then calls `Wait-BCAppsSynced` (polls `Get-BcContainerAppInfo -tenantSpecificProperties` until each published app's `SyncState` is `Synced`), then runs tests. Never re-interleave publish-then-test per app, and never drop the barrier.
  - The barrier closes a race: the dev-endpoint `ForceSync` publish returns before the server-side sync commits. A test session opened against still-settling metadata raises *"Sorry, we just updated this page"*, and the truncated run can read as a partial pass — the original false-green.
  - A service-tier restart was rejected as the recovery: a cold NST is too slow, and the poll keeps the tier warm.
  - `SyncState` arrives as a deserialized enum: `GetType()` is `Int32`, `-eq 'Synced'` is false, but `.ToString()` is `'Synced'`. Compare via `.ToString()`, or every app reads pending and the barrier times out on every gate.
  - Covered by `tests/al-build/WaitAppsSynced.Tests.ps1`.
- **AL Runner is a fast gate, not a replacement for container tests.** `Invoke-ALRunnerTest` runs before the container and lands as a first-class `runner: al-runner` record in `summary.json` in every mode, writing `al-runner.xml` so the container's `last.xml` never overwrites it. The unit test app legitimately appears twice in a full gate (al-runner + container). That is why `totals` aggregate per runner and never across.
- **AL Runner stays a global dotnet tool. The AL compiler does not.** `Install-ALRunner` installs `MSDyn365BC.AL.Runner` as a **global** dotnet tool. `Get-Command al-runner` guards the install. The install skips when `unitTestApp` is not configured. The AL **compiler** lives under `--tool-path` per *Compiler channels* above. "Re-aligning" the two by moving the compiler back to `--global` would clobber the user's own compiler.
