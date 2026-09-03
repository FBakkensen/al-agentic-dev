# al-build test gate on AL Runner v2 — design

Date: 2026-09-02. Decided in a brainstorm session with empirical probes against al-runner v2.10.0 and the live consumer repo `GTM-BC-9AAdvMan-ItemConfigurator` (app + unit-tests + integration-tests, 2830 tests). Every decision below carries the evidence that settled it.

## Problem

`al-runner` moved to a new major (v2.10.0). The current gate is broken against it: `Invoke-ALRunnerTest` passes the v1 flags `--packages`, `--no-telemetry`, and `--init-events`, and v2 rejects all three with exit 2 (verified). Beyond the breakage, v2 removes the reason the container sat inside the gate at all: it runs almost any AL test in-process — the full 2830-test suite, unit and integration, ran in one invocation in 117s cold / 66s warm with zero containers (verified). Container tests and container coverage were workarounds, not the destination.

## Decisions

### 1. The gate is compile + one al-runner run — no modes, no container logic

`test.ps1` does one thing: compile every app through the host alc analyzer gate (unchanged), then run al-runner once over `app` + all `testApps` bundles. `-UnitTestOnly`, `-AllTests`, `-Force`, and the mode-selection guard are removed. There is no `-Test` switch (decision 3).

- One invocation, all bundles: each extra invocation costs ~9s warm; one aggregated run shares warm dependencies (verified: 3 bundles, one summary).
- The JUnit XML from `--output-junit` carries per-codeunit `testsuite` elements and no app attribution (verified: 256 suites named `CodeunitNNNN`). `summary.json` therefore records one merged run for the al-runner gate instead of per-app records.
- Gate output surfaces three runner lines verbatim: `[bc] selected BC …` (and its build-skew warning — one fired in probing), `[dep] … NO IMPLEMENTATION` (a live symbols-only trap existed in the consumer repo: the `9A Advanced Manufacturing - License` dependency), and the `[expectations]` status line.

### 2. Config split: `testApps` and `containerTestApps`

The old `unitTestApp` / `testApps` split named v1's capability boundary (unit vs everything else). The new boundary is what al-runner cannot execute honestly.

- `testApps` — every bundle al-runner runs in the gate.
- `containerTestApps` — bundles that need what al-runner refuses by design (`RunnerOutOfScopeException`: SMTP, outbound HTTP, printing, external file I/O, web-service publishing, report layout rendering). Default `[]`. Run only by the explicit container script (decision 5).
- Retired keys: `unitTestApp`, `unitTestInitEvents` (install triggers always fire in v2), `testRunnerCodeunitId`.
- No `bcVersion` key: the runner deduces its BC version from symbols and its artifact cache and prints the selection; the gate surfaces that line (verified: `[bc] selected BC 28.4.53241.53504` with zero flags).
- No `testData` key: out of scope this round (see Out of scope).

Membership moves an app between lists only on a documented runner limitation. Per-test known gaps never move an app; they are expectations-manifest entries (decision 6).

### 3. Server mode, auto-started, with a lifecycle manager

The gate uses `al-runner --server` (JSON-RPC over stdin/stdout, NDJSON). Measured: 7.7s warm for 1676 tests vs 66s for a fresh-process full run; a real 10-step red→green TDD flow against one warm server produced 20/20 correct verdicts, ~8–10s per edited re-run (every cycle a cache miss).

- A small detached manager process owns the `al-runner --server` child and relays NDJSON over a named pipe keyed by repo root. `test.ps1` connects; if the pipe is absent it spawns the manager, waits for `{"ready":true}`, and proceeds. The server is the only test path: when it does not answer, the gate is red and names `.output/logs/al-runner-server-manager.log`. No CLI fallback — a fallback would hide a server that cannot start.
- Dependencies are self-contained. At server start the manager builds `.output/al-runner-deps/` from the checkout symbol cache (`download-symbols.ps1` output): every non-Microsoft dependency declared in each bundle's `app.json`, excluding any package whose id is itself a bundle in the run (al-runner synthesizes those from source). It passes the dir as `--package-cache`. Microsoft platform and test libraries come from al-runner's own artifact cache, which is code-bearing and engine-matched; a symbols-only Microsoft copy from the feed must never enter the dir, because al-runner picks the highest version across all dirs and a newer symbols-only copy would win. The dir's id+version set joins the restart fingerprint. `.alpackages` is never read. A symbols-only third-party dependency whose code no test executes is legitimate (al-runner prints a `[deps] NOTE … symbol-only` line, not an error); one whose code does execute needs the vendor's code-bearing `.app` — that remedy is documented, not automated.
- The manager restarts the server on: al-runner version change, table/tableextension source fingerprint change (the reload contract does not see table-shape edits — upstream documents "restart the server after a schema change"), and expectations-manifest change (loads once at startup). It also recycles the server after 50 runs: each warm reload loads a new assembly alongside the old, and probe wall time crept 7.9→10.5s over 20 reloads.
- The server starts with cwd at the consumer repo root so the expectations auto-probe works.
- Request drift, worked around: on the consumer suite the first `runTests` on a server process reports 366 failures and every later identical request 753, stable; a fresh process returns to 366. Reproduced 2026-09-03 on al-runner main over direct stdio with no manager and no coverage — 382 extra failures, 349 of them `NavDateTime with NavGuid` in `"Library - Inventory".ItemNoSeriesSetup`, the rest in `"No. Series - Stateless Impl."`. Filed upstream. Until fixed, `MaxRunsPerChild` in the manager is 1 — every request runs on a fresh child, so the 50-run ceiling and the warm-cache speedup are suspended. The revert recipe is the comment above `MaxRunsPerChild`.
- `runTests` has no test filter, and `test.ps1` has no `-Test`. A focused single-test run is `al-runner --test <name> <bundles>` typed directly; it is a fresh process outside the gate.

### 4. Coverage rebuilds on al-runner; the container coverage machinery is deleted

Container coverage was a workaround until al-runner could do it. It can (verified): `runTests` with `coverage: true` returns per-statement positions and hit counts per file, and `perTestCoverage` returns the same keyed per test — 1676 entries of `{test, coverage: [{file, statements: [{id, scope, line, column, hits}]}]}` with real repo source paths. Cost measured: 15.6s vs 7.7s without, and a 27MB single-line summary — the bridge streams the summary line to disk and parses it there, never through the console.

- The gate (server path) produces `.output/TestResults/coverage/per-test.jsonl` and `cobertura.xml` in today's artifact shapes, derived from `perTestCoverage`. The planned CRAP calculation (future round) consumes these.
- Deleted: `coverage-runtime.psm1`, `coverage-normalizer.psm1`, `coverage-preflight.psm1`, `coverage-helper-golden.psm1`, `code-coverage-helper/` (app + XmlPort), and every container-coverage step in `test.ps1`/`build-operations.psm1`. `COVERAGE.md` is rewritten to the al-runner contract.
- Enabled coverage stays mandatory. Coverage on or off, the server is the only path (decision 3); an unavailable server is red either way, so there is no coverage-specific branch.

### 5. `container-test.ps1` — explicit-only container tests

A new script carries today's container sequence out of the gate: ensure the branch agent container, publish main + `containerTestApps`, wait for the sync barrier, run the container tests, write `last.xml` and a `gate: "container"` summary. No coverage. No normal flow invokes it — a task names it explicitly (for example a Copilot-implementation story that genuinely needs platform surfaces). User verification keeps the container exactly as today: `publish-apps.ps1` + the walkthrough. Container lifecycle scripts, `validate-breaking-changes.ps1`, and `prune.ps1` are unchanged.

### 6. Expected failures live in expectations manifests

al-runner's `--expectations` mechanism is the designed home for "these tests fail on al-runner and that is expected" (the consumer repo has such tests today). Auto-probed at `<repo>/tests/expectations`; entries are Microsoft `DisabledTests`-shaped JSON plus a `Mode` (`expect-oos`, `expect-fail-known-gap`, `expect-divergence`, `skip`).

Verified both directions: a manifest covering 4 real failures took the run to `pass-known-gap: 4`, exit 0; declaring a passing test as a known gap flipped the run red (drift alarm). One trap, verified: an entry with a wrong `CodeunitName` silently matches nothing — the gate documentation tells authors to confirm the `pass-known-gap` counter moved after adding entries.

### 7. `summary.json` schema

`gate` is `"al-runner"` or `"container"`. `runs[]` holds one merged record for the al-runner gate (runner, bundle count, counts, resultFile) and per-app records on the container path. Per-runner totals stay and are never summed across runners. The coverage block keeps its current shape. `build-timing.jsonl` gate names follow.

### 8. `provision.ps1` additions

Ensures the `msdyn365bc.al.runner` dotnet tool is installed at ≥ 2.10 (today's scripts throw "run provision.ps1" without provision knowing how). Symbol, baseline, and ALCops duties unchanged.

### 9. Skill surface

`skills/al-build/SKILL.md` rewrites the gate table: `test.ps1` (the gate), `container-test.ps1` (explicit container surface). A focused run is documented as the direct `al-runner --test <name> <bundles>` command, not a script. The five consumer skills (`al-implement`, `al-refactor`, `al-review`, `al-pr-shepherd`, `al-walkthrough`) drop `-UnitTestOnly`/`-AllTests` mode names; "the gate" is one thing, and container tests appear only as an explicitly named task step. `al-walkthrough`'s publish path is untouched.

## Out of scope this round

- `--test-data` (Cronus hydration). Verified end to end and rejected for now: it fixed 218 of 219 data-class failures but bcdb 0.1.0 refuses key tables on schema drift (`No. Series Line` refusal alone produced 194 new failures; `Item` refused whole), bcdb reads 28.1 backups but refuses 28.4, and the run cost 5.4× wall. Revisit when the reader handles current backups cleanly. No `bcbak`/sandbox-artifact provisioning ships.
- CRAP score calculation (next round; consumes `per-test.jsonl`).
- Mutation testing, `--tdd`, `--dap` plumbing.
- Server-mode verdict drift root-causing — upstream report, filed by the user.

## Implementation-time verifications

Named, not assumed: `--expectations` behavior under `--server`; JUnit synthesis from the NDJSON stream (or CLI `--output-junit` on the fallback path); clean-machine auto-provision behavior; named-pipe relay robustness under concurrent gate attempts; 27MB summary-line handling; the transient first-run crash seen once in probing (`IOException` moving the ncl-shadow variant dir — retry-once semantics in the bridge).

## Evidence index

| Probe | Result |
|---|---|
| v1 flags on v2.10 | `--packages`, `--no-telemetry`, `--init-events` all exit 2 |
| Bare full suite, cold / warm | 2830 tests, 117s / 66s wall, zero containers |
| Warm filtered (one codeunit) | 7–8s wall |
| Server: warm full unit bundle | 7.7s (1676 tests) |
| Server: verdict drift | run1 84 fails, run2+ 89 stable; fresh CLI always 84 |
| Server: 10-step TDD red→green | 20/20 correct verdicts, 8–10s per edited re-run |
| Server: coverage + perTestCoverage | per-test statement hits with source positions; 15.6s; 27MB summary line |
| `--test-data` (28.1 bak + bcdb) | fixes 218/219 data failures, adds 194 No.-Series failures, 5.4× wall |
| Expectations manifest | honest-green (`pass-known-gap`) and drift alarm both verified |
| JUnit shape | one XML, per-codeunit suites, no app attribution |
