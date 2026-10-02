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
| `test.ps1` | The gate, on AL Runner. Compiles every app (main, `testApps`, `containerTestApps`) through the analyzer gate, then runs AL Runner once over the main app and every `testApps` bundle, in one fresh `al-runner` CLI process per gate. Its progress is echoed live and kept in `.output/logs/al-runner.log`. It never touches a container. |
| `container-test.ps1` | The container surface for `containerTestApps`: compile the main app and every container test app through the analyzer gate, publish, sync barrier, run. Reached only when a task explicitly requires the container surface; no ordinary gate or verify step calls it. |
| `test.ps1 -Coverage` | The same AL Runner run with main-app line coverage, through AL Runner's `--coverage`. |

`test.ps1` is the one gate; the container is reached only through `container-test.ps1`.

Green is zero errors and zero warnings. `test.ps1` exits 0 on warnings by default; set `WARN_AS_ERROR=true` to bind that bar to the exit code.

### Reading the result

The result is read from `.output/TestResults/summary.json`, not from the console stream. The summary carries:

- `gate`: `al-runner` or `container`;
- per-runner `totals`;
- `runs[]`: one record per run, with `runner`, `appName`, `dir`, `passed`, `counts`, and `resultFile` (the JUnit XML);
- a `coverage` block.

For a red, open the `resultFile` of each run whose `passed` is false for the failing test names and their assertion messages. Reading the console instead floods a session with thousands of lines of build spew for numbers the summary already holds.

- Totals are per runner and never summed across them; AL Runner and the container are two separate runners.
- `counts: null` is unavailable, not zero.
- `Codeunit … Success` console lines count test codeunits, not tests. Counts come from the summary and the JUnit XML alone.
- `test.ps1` clears prior test results at startup, before configuration loads. A malformed config or an early compile failure can leave no `summary.json`; take the red signal from the diagnostics instead.

Other artifacts:

| Artifact | Contents |
|---|---|
| `.output/TestResults/al-runner.xml` | The AL Runner gate's JUnit, from `--output-junit`. |
| `.output/TestResults/al-runner-output.json` | AL Runner's `--output-json` result. |
| `.output/TestResults/<dirName>/last.xml` | Per-app container JUnit. |
| `.output/logs/al-runner.log` | AL Runner's stderr for the run. |
| `.output/logs/build-timing.jsonl` | One entry per gate run, on every exit path. |

### The AL Runner log

`.output/logs/al-runner.log` holds:

- the `[bc] selected …` notice, including any build-skew warning it carries (also echoed in the gate output);
- one `[dep] <publisher>/<name> <version> <- <source>` line per resolved dependency;
- an informational `[expectations] … classification is OFF this run` line, which is expected because the gate runs without an expectations manifest.

`summary.json`'s `notices` is `[]` today, so read the `[dep]` notices from the log. A focused single-test run is `al-runner --test <name> <bundle dirs> --package-cache .output/al-runner-deps`, typed directly outside the gate; it never collects coverage.

### Dependencies

Dependencies are self-contained:

- At each gate run `test.ps1` stages every non-Microsoft, non-bundle dependency from the checkout symbol cache into `.output/al-runner-deps` (one `[deps] …` line per package in the gate output) and passes it as `--package-cache`.
- Microsoft platform and test libraries come from AL Runner's own artifact cache.
- Every bundle in the run compiles from source.
- `.alpackages` is never read.

A symbols-only third-party package (`[dep] … NO IMPLEMENTATION` in `al-runner.log`, once per bundle) is expected while no test executes into it. Vendor symbol feeds carry no code, so the line is a permanent feature of a run with third-party dependencies, and a green summary is the proof. It turns red only when a test crosses into the package, and that red has one shape: `The object with ID 0 does not have a member with that ID` naming an object from that package. Then place the vendor's code-bearing `.app` in that app's symbol cache dir after the symbol download (the download clears the dir) and rerun the gate. The `al-runner provision` / `--auto-provision` hint under the `[dep]` line applies to Microsoft test-toolkit packages only; it cannot supply a vendor implementation.

### When a test is red

A red test has three outcomes and no fourth:

1. Fix it until genuinely green.
2. When the failure is an AL Runner gap, stop and put the evidence to the user with options.
3. When the test genuinely needs a surface AL Runner refuses by design (`RunnerOutOfScopeException`), move its app to `containerTestApps`, and only on the user's explicit ack, never on the agent's own.

The gate reds on a `tests/expectations` folder in the repo, since AL Runner's expectations manifest would turn a failing test into exit 0.

## Coverage

Coverage runs on the AL Runner gate (`test.ps1`), never on the container gate (`container-test.ps1`). A container run's `summary.json` always carries `coverage: {"enabled": false}`; `container-test.ps1` collects no coverage from any source. The authoritative artifact contract is `skills/al-build/COVERAGE.md`.

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

A config that omits `coverage.enabled` resolves to disabled. Resolution is:

1. No configured `testApps`: coverage is skipped, whatever the switch, environment, or JSON setting.
2. `test.ps1 -Coverage`: enable it for this run.
3. `ALBT_COVERAGE_ENABLED`: overrides the JSON setting.
4. `coverage.enabled`: the repo setting.
5. Missing field: disabled.

Coverage rides the same single `al-runner` CLI process as the tests, through `--coverage --coverage-out .output/TestResults/coverage/cobertura.xml`. Coverage never blocks the gate: when the coverage step fails, the test verdict stands and the failure lands in the `coverage` block of `summary.json`.

### What it measures

Main-app line coverage only. There is no branch coverage, no procedure-level coverage, no thresholds, no CRAP scores, and no tree-sitter analysis.

AL Runner's own Cobertura spans every bundle in the run (main app and test apps). `test.ps1` keeps only the classes under `appDir`, sums hits per line, and rewrites the file over that main-app set, so `lineRate`, `linesValid`, and `linesCovered` describe the main app alone. Lines with zero hits are included.

### Artifacts

A complete run writes, under `.output/TestResults/`:

| Artifact | Contents |
|---|---|
| `coverage/cobertura.xml` | Line-level Cobertura covering every main-app line, including lines with zero hits. |
| `summary.json` | The ordinary gate result plus a `coverage` block. |

There is no `per-test.jsonl`. `al-runner --help` (v2.10) offers no per-test coverage flag: `--output-json` carries each test's pass/fail/error, message, stackTrace, durationMs and the exitCode but no coverage field, and `--coverage` writes Cobertura XML plus a console table. Per-test attribution existed only on the retired `--server` protocol. The coverage block's status field therefore holds `"aggregate-only"`.

The `coverage` block takes one of three shapes:

| Run | Block |
|---|---|
| Disabled | `enabled: false` only. |
| Complete | `schemaVersion`, `enabled: true`, `complete: true`, `lineRate`, `linesValid`, `linesCovered`, `perTestJsonlPath: null`, `coberturaXmlPath`, and a status field holding `"aggregate-only"`. |
| Stopped short | `enabled: true`, `complete: false`, a status field holding `"failed"`, and a `failure` object with `stage` and `message`. |

## The other entry points

| Script | What it does |
|---|---|
| `provision.ps1` | Per-feature setup. Installs the stable and prerelease AL compiler channels side by side under the tool cache; keeps the `msdyn365bc.al.runner` dotnet tool at the newest NuGet release (a newer local build stays); downloads symbol packages for every app into a cache keyed by checkout path; ensures the ALCops DLL suite is complete and version-consistent without replacing a valid installation. After both symbol downloads it runs `download-baseline.ps1` (the pin check, then the fill) and exits with its code. `-UpdateCompiler` forces a clean reinstall. |
| `validate-breaking-changes.ps1` | The heavyweight AppSource-style check the compile-time cop cannot do. A `version` in `AppSourceCop.json` repeats the Release pin check first, whatever `breakingChange.enabled` says. Under `breakingChange.enabled` it runs the container install and upgrade test, per country, against the real Release `.app` in `breakingChange.releaseAppDir`, matched by manifest id and version; a symbols-only file is rejected. Slice-end or pre-release, never the inner loop. |
| `publish-apps.ps1` | Clean republish with no build and no tests: unpublishes every app dependency-reversed, then force-publishes in dependency order. Needs compiled `.app` artifacts already present. Loads a fresh container before a human walk. |
| `container-test.ps1` | Container tests for `containerTestApps`; see "What it produces". Compiles before it publishes; `-Force` republishes unchanged apps. |
| `new-bc-container.ps1`, `commit-bc-container.ps1`, `new-agent-container.ps1` | The container lifecycle: one sequence, once per BC version. |
| `prune.ps1` | Removes agent containers whose branch is gone or that sat unused past seven days, with both hosts entries (bare and `.test`), also for a container that is already gone. `-Preview` for a dry run. |
| `init.ps1` | One-time per repo: writes `al-build.json` into the repo root with detected app and test directories, copied from the skill's `config/al-build.json` template. Set `testApps` afterwards. |
| `clean.ps1` | Deletes compiled `.app` files and clears publish state so the next run republishes. |
| `report-gate-metrics.ps1` | Gate wall-clock per workspace signature and gate scope, from `build-timing.jsonl`; `-GlobalLog` reads the cross-repo mirror. |
| `download-symbols.ps1`, `download-baseline.ps1` | The two fetches `provision.ps1` already performs, run alone to redo just one step. |

### Breaking-change baseline

The baseline is the Release `.app` an upgrade is validated against. It involves two folders, and they must be different:

- **`breakingChange.releaseAppDir`** (`ALBT_RELEASE_APP_DIR`, no default, repo-root relative) holds the real Release `.app` that `validate-breaking-changes.ps1` installs and upgrades from.
- **`baselinePackageCachePath`** in `AppSourceCop.json` names the folder `download-baseline.ps1` fills with the symbols-only Release and its Microsoft and third-party dependency symbols. Only `*.app` files there are replaced; no committed file changes.

The Consumer repository gitignores both folders.

The Release pin check compares a `version` in the committed `AppSourceCop.json` against the latest Release on AppSourceSymbols. It runs in `download-baseline.ps1` (so in `provision.ps1`) and again at the start of `validate-breaking-changes.ps1`, whatever `breakingChange.enabled` says and whatever `al.codeAnalyzers` lists. With a current pin, `download-baseline.ps1` downloads the baseline into the `baselinePackageCachePath` folder.

Exit codes of `validate-breaking-changes.ps1` are contract:

| Code | Meaning |
|---|---|
| `0` | No breaking change. |
| `3` | Breaking change. |
| `4` | Prerequisite missing. |
| `1` | Environment failure. |

`provision.ps1` stops with `4` first when `releaseAppDir` and `baselinePackageCachePath` name the same folder. After both symbol downloads it runs `download-baseline.ps1` and exits with its code; a stale pin (naming the latest Release) or a `version` with no `baselinePackageCachePath` stops with `4`.

### Republish

`publish-apps.ps1` re-asserts the container's `<agent-container>.test` host first: both hosts lines at its current IP, and `PublicWebBaseUrl`. It stops non-zero when that fails. On success it ends with the deployed commit, the app version, the `.test` Web Client URL, and the username.

### Container lifecycle

The three container scripts run as one sequence, once per BC version.

| Script | What it does |
|---|---|
| `new-bc-container.ps1` | Creates and configures the golden BC container, one per BC version. |
| `commit-bc-container.ps1` | Commits the stopped golden container to the snapshot image. A machine restart comes first, because a stopped container still holds locked files the commit needs released; only the user can take it, so the skill asks, waits for their confirmation, then runs the commit. |
| `new-agent-container.ps1` | Spawns an agent container from the snapshot, named after the current git branch. `test.ps1` always derives that name from the branch, with no override. The container is also reachable at `http://<agent-container>.test`, with `PublicWebBaseUrl` on that host so Web Client links stay on it; BcContainerHelper and `ServerUrl` keep the bare name. A failed `PublicWebBaseUrl` set fails creation. |

## Requirements

`al-build.json` in the consumer repo root, written by `init.ps1`. Without it the scripts throw `Config file required`. On the host: PowerShell 7.2+, Docker Desktop, the .NET SDK, Node.js 22+ with `npx` on PATH, and BcContainerHelper.

## Configuration

Resolution order, highest first:

1. script switch;
2. environment variable (`ALBT_*`, plus `WARN_AS_ERROR` and `RULESET_PATH`);
3. `al-build.json` in the repo root;
4. built-in default.

The fields that change behaviour:

| Field | Notes |
|---|---|
| `appDir` | The main app folder. |
| `testApps` | AL Runner test apps. A project with no AL Runner tests sets `"testApps": []`; the `["test"]` default fails loudly without a `test/` folder. |
| `containerTestApps` | Container test apps. Defaults to `[]`; set it to add the container surface. |
| `coverage.enabled` | See "Coverage". |
| `breakingChange.enabled` | Gates only the container install and upgrade test. |
| `breakingChange.releaseAppDir` | See "Breaking-change baseline". |

**Container login.** `container.username` and `container.password` (defaults `admin` and `P@ssw0rd`) are the throwaway login of a local test container, and they are not secrets. They are read from `al-build.json` and may be printed, echoed, logged, or passed on a command line wherever a tool needs them; nobody is asked for them.

### Analyzers

Analyzer selection is `al.codeAnalyzers` in `.vscode/settings.json`, in the AL extension's own notation. `<appDir>/.vscode/settings.json` wins; the repo root file is the shared fallback. No `settings.json` means no analyzers, and a listed analyzer that cannot be resolved stops the build rather than quietly compiling with less lint coverage than asked for.

Diagnostic prefixes: `AA` CodeCop, `AW` UICop, `AS` AppSourceCop, `PTE` PerTenantExtensionCop, and `AC`/`DC`/`FC`/`LC`/`PC`/`TA` the ALCops family. Compile-time breaking-change detection still needs `${AppSourceCop}` listed; a break then arrives as an ordinary `AS00xx` error.

## Container recovery

For ordinary container failures, recovery escalates from outside the container:

1. `docker restart <container>` and re-run the gate.
2. `docker rm -f <container>` and re-run, which recreates it.
3. Re-run `provision.ps1` and the gate.

Nothing inside the container is patched by hand: `docker exec` or installing apps by hand leaves state the scripts cannot reproduce.
