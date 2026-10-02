---
name: al-build
description: "Runs the scripted AL/Business Central toolchain: the compile-publish-test gate, provisioning, breaking-change validation, and the container lifecycle. Use when AL production or test code has changed and the change needs the gate before the task moves on, and whenever another skill needs one of these scripts run — this skill is their only invoker."
---

# al-build

Every script below lives in this skill's `scripts/` folder and runs from the consumer repo root. Use one sentence before the first tool call; update on an important finding or direction change; close with the outcome first, standing on its own.

```
pwsh <path to this skill>/scripts/<name>.ps1
```

Run one at a time. `al-build.json` in the repo root is required — without it the scripts throw `Config file required`; `init.ps1` writes one. Host needs PowerShell 7.2+, Docker Desktop, the .NET SDK, Node.js 22+ with `npx` on PATH, and the BcContainerHelper module.

## The gate

| Command | Scope |
|---|---|
| `test.ps1` | The gate. Compiles every app (main, `testApps`, `containerTestApps`) through the analyzer gate, then runs AL Runner once over the main app and every `testApps` bundle — one fresh `al-runner` CLI process per gate, its progress echoed live and kept in `.output/logs/al-runner.log`. Never touches a container. |
| `container-test.ps1` | Container tests for `containerTestApps`: compile the main app and every container test app through the analyzer gate, publish, sync barrier, run. Only when a task explicitly requires the container surface — no ordinary gate or verify step calls it. |

`test.ps1 -Coverage` adds main-app line coverage to the same run through AL Runner's `--coverage`; the CLI exposes no per-test attribution, so the coverage block's status field holds `"aggregate-only"` — see `COVERAGE.md` for the artifact contract.

Green is zero errors and zero warnings. `test.ps1` exits 0 on warnings by default, so set `WARN_AS_ERROR=true` to bind that bar to the exit code.

## Read the result, not the output

After the run, read `.output/TestResults/summary.json` and report from it. It carries `gate` (`al-runner` or `container`), per-runner `totals`, and `runs[]` — one record per run with `runner`, `appName`, `dir`, `passed`, `counts`, `resultFile`. For a red, open the `resultFile` of each run whose `passed` is false (JUnit XML) for the failing test names and their assertion messages. Reading the console stream instead floods the session with thousands of lines of build spew for numbers the summary already holds.

- Totals are per runner, never summed across them — AL Runner and the container are still two separate runners.
- `counts: null` reports as unavailable, not as zeros.
- `Codeunit … Success` console lines count test codeunits, not tests. Counts come from the summary and the JUnit XML alone.
- `test.ps1` clears prior test results at startup, before configuration loads. A malformed config or early compile failure can leave no `summary.json`; take the red signal from the diagnostics instead.
- `.output/logs/al-runner.log` is AL Runner's stderr for the run: the `[bc] selected …` notice line, including any build-skew warning it carries (also echoed in the gate output), and one `[dep] <publisher>/<name> <version> <- <source>` line per resolved dependency, and an informational `[expectations] … classification is OFF this run` line (expected: the gate runs without an expectations manifest). `summary.json`'s `notices` is `[]` today; read `[dep]` notices from the log. A focused single-test run is `al-runner --test <name> <bundle dirs> --package-cache .output/al-runner-deps` typed directly, outside the gate; it never collects coverage.
- Dependencies are self-contained: at each gate run `test.ps1` stages every non-Microsoft, non-bundle dependency from the checkout symbol cache into `.output/al-runner-deps` (one `[deps] …` line per package in the gate output) and passes it as `--package-cache`; Microsoft platform and test libraries come from AL Runner's own artifact cache; every bundle in the run compiles from source. `.alpackages` is never read. A symbols-only third-party package (`[dep] … NO IMPLEMENTATION` in `al-runner.log`, once per bundle) is expected while no test executes into it — vendor symbol feeds carry no code, so the line is a permanent feature of a run with third-party dependencies, and a green summary is the proof. It turns red only when a test crosses into the package, and that red has one shape: `The object with ID 0 does not have a member with that ID` naming an object from that package. Then place the vendor's code-bearing `.app` in that app's symbol cache dir after the symbol download (the download clears the dir) and rerun the gate. The `al-runner provision` / `--auto-provision` hint printed under the `[dep]` line applies to Microsoft test-toolkit packages only; it cannot supply a vendor implementation.
- A red test has three outcomes and no fourth: fix it until genuinely green; when the failure is an AL Runner gap, stop and put the evidence to the user with options; when the test genuinely needs a surface AL Runner refuses by design (`RunnerOutOfScopeException`), move its app to `containerTestApps` — only on the user's explicit ack, never on your own. The gate reds on a `tests/expectations` folder in the repo, since AL Runner's expectations manifest would turn a failing test into exit 0.

Other artifacts: `.output/TestResults/al-runner.xml` (the al-runner gate's JUnit, written by AL Runner's `--output-junit`), `.output/TestResults/al-runner-output.json` (its `--output-json` result), `.output/TestResults/<dirName>/last.xml` (per-app container JUnit), and `.output/logs/build-timing.jsonl`, one entry per gate run on every exit path.

## Every other entry point

| Script | What it does |
|---|---|
| `provision.ps1` | Per-feature setup: installs the stable and prerelease AL compiler channels side by side under the tool cache, keeps the `msdyn365bc.al.runner` dotnet tool at the newest NuGet release (a newer local build stays), downloads symbol packages for every app into a cache keyed by checkout path, ensures the ALCops DLL suite is complete and version-consistent without replacing a valid installation, and, after both symbol downloads, runs `download-baseline.ps1` (the pin check, then the fill) and exits with its code — a stale pin stops with exit `4` naming the latest Release. The same folder for `breakingChange.releaseAppDir` and `AppSourceCop.json`'s `baselinePackageCachePath` stops it with `4` first. `-UpdateCompiler` forces a clean reinstall. |
| `validate-breaking-changes.ps1` | The heavyweight AppSource-style check the compile-time cop cannot do. A `version` in `AppSourceCop.json` repeats the Release pin check first, whatever `breakingChange.enabled` says. Under `breakingChange.enabled` it runs the container install and upgrade test, per country, against the real Release `.app` in `breakingChange.releaseAppDir`, matched by manifest id and version; a symbols-only file is rejected. Exit codes are contract: `0` no break, `3` breaking change, `4` prerequisite missing, `1` environment failure. Slice-end or pre-release, never the inner loop. |
| `publish-apps.ps1` | Clean republish with no build and no tests: unpublishes every app dependency-reversed, then force-publishes in dependency order. Needs compiled `.app` artifacts already present. Loads a fresh container before a human walk. Re-asserts the container's `<agent-container>.test` host first (both hosts lines at its current IP, and `PublicWebBaseUrl`) and stops non-zero when that fails. Ends with the deployed commit, the app version, the `.test` Web Client URL, and the username; it never prints the password. |
| `new-bc-container.ps1` | Creates and configures the golden BC container — one per BC version. |
| `commit-bc-container.ps1` | Commits the stopped golden container to the snapshot image. A machine restart comes first — a stopped container still holds files locked that the commit needs released — and only the user can take it: ask, wait for their confirmation, then run the commit. |
| `new-agent-container.ps1` | Spawns an agent container from the snapshot, named after the current git branch. `test.ps1` always derives that name from the branch, with no override. The container is also reachable at `http://<agent-container>.test`, with `PublicWebBaseUrl` on that host so Web Client links stay on it; BcContainerHelper and `ServerUrl` keep the bare name. A failed `PublicWebBaseUrl` set fails creation. |
| `prune.ps1` | Removes agent containers whose branch is gone or that sat unused past seven days, with both hosts entries (bare and `.test`), also for a container that is already gone. `-Preview` for a dry run. |
| `init.ps1` | One-time per repo: writes `al-build.json` into the repo root with detected app and test directories, copied from this folder's `config/al-build.json` template. Set `testApps` afterwards. |
| `clean.ps1` | Deletes compiled `.app` files and clears publish state so the next run republishes. |
| `report-gate-metrics.ps1` | Gate wall-clock per workspace signature and gate scope, from `build-timing.jsonl`; `-GlobalLog` reads the cross-repo mirror. |
| `container-test.ps1` | Container tests for `containerTestApps` — see "The gate" above. Compiles before it publishes; `-Force` republishes unchanged apps. |
| `download-symbols.ps1`, `download-baseline.ps1` | `provision.ps1` already runs both: `download-symbols.ps1` fetches the symbol packages, `download-baseline.ps1` checks a `version` in the committed `AppSourceCop.json` against the latest Release on AppSourceSymbols, and with a current pin downloads the symbols-only Release and its Microsoft and third-party dependency symbols into the folder `AppSourceCop.json`'s `baselinePackageCachePath` names — only `*.app` files are replaced, no committed file changes, and a `version` with no `baselinePackageCachePath` stops with exit `4`. Run one alone to redo just that step. |

The three container scripts are one sequence, run once per BC version: `new-bc-container.ps1`, `commit-bc-container.ps1`, then `new-agent-container.ps1` for each branch off the resulting snapshot.

## Configuration

Resolution order, highest first: script switch, environment variable (`ALBT_*`, plus `WARN_AS_ERROR` and `RULESET_PATH`), `al-build.json` in the repo root, built-in default. The fields that change behaviour are `appDir`, `testApps`, `containerTestApps`, `coverage.enabled`, `breakingChange.enabled`, and `breakingChange.releaseAppDir` (`ALBT_RELEASE_APP_DIR`, no default, repo-root relative). `breakingChange.enabled` gates only the container install/upgrade test. The Consumer repository gitignores both the `releaseAppDir` folder and the folder `AppSourceCop.json`'s `baselinePackageCachePath` names, and the two must be different folders. `containerTestApps` defaults to `[]` — set it to add the container surface. A project with no AL Runner tests sets `"testApps": []`; the `["test"]` default fails loudly without a `test/` folder.

Analyzer selection is `al.codeAnalyzers` in `.vscode/settings.json`, in the AL extension's own notation — `<appDir>/.vscode/settings.json` wins, the repo root file is the shared fallback. No `settings.json` means no analyzers, and a listed analyzer that cannot be resolved stops the build rather than quietly compiling with less lint coverage than asked for. Diagnostic prefixes: `AA` CodeCop, `AW` UICop, `AS` AppSourceCop, `PTE` PerTenantExtensionCop, `AC`/`DC`/`FC`/`LC`/`PC`/`TA` the ALCops family. The Release pin check runs whatever `al.codeAnalyzers` lists. Compile-time breaking-change detection still needs `${AppSourceCop}` listed; a break then arrives as an ordinary `AS00xx` error.

## Container recovery

For ordinary container failures, recovery escalates from outside it: `docker restart <container>` and re-run the gate; then `docker rm -f <container>` and re-run, which recreates it; then re-run `provision.ps1` and the gate. Nothing inside the container is patched by hand — `docker exec` or installing apps by hand leaves state the scripts cannot reproduce.

## Close

A green gate with per-runner totals from `summary.json`, or a red named by its failing tests and the diagnostic behind them.
