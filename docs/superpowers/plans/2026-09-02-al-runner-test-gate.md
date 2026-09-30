# AL Runner v2 Test Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `skills/al-build`'s test gate on al-runner v2.10: compile + one al-runner server run, containers explicit-only, coverage from `perTestCoverage`, container coverage machinery deleted.

**Architecture:** `test.ps1` loses all modes and all container logic; it compiles every app via the host alc analyzer gate, then runs al-runner once over `app` + all `testApps` — through a named-pipe server bridge when available, fresh CLI process otherwise. A new `container-test.ps1` carries the old publish→sync→run sequence for `containerTestApps`, invoked only on explicit request. Coverage artifacts (`per-test.jsonl`, `cobertura.xml`) derive from the server's `perTestCoverage` field.

**Tech Stack:** PowerShell 7.2+, Pester (existing `tests/` suite), al-runner ≥2.10 (`msdyn365bc.al.runner` dotnet tool, NDJSON `--server` protocol), BcContainerHelper (container path only).

**Spec:** `docs/superpowers/specs/2026-09-02-al-runner-test-gate-design.md`

## Global Constraints

- Every `.ps1` starts `#Requires -Version 7.2`; every failure path exits non-zero; no `Read-Host`/`Get-Credential`/`Pause`; destructive cmdlets get `-Confirm:$false`; paths quoted and composed with `Join-Path`.
- Every new script under `skills/al-build/scripts/` gets a Pester test under `tests/al-build/` covering at least its failure path.
- Skill bodies never contain the word "harness"; no model names; no lifecycle fields (`status:`, `phase:` …); `SKILL.md` ≤ 80 lines for al-build, ≤ 60 for others; script names appear only inside `skills/al-build/`.
- Commits: small, frequent, message ends with `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
- Local loop: `pwsh -File scripts/Invoke-Tests.ps1 -Mode Fast`. Full gates before push: `Validate-Json.ps1`, `Validate-PowerShell.ps1`, `Validate-Skills.ps1`, `Update-Review.ps1 -Check`, `Invoke-Tests.ps1 -Mode Full`. Delegate test runs only to a task agent pinned to `gpt-5.6-luna`; it runs `scripts/Invoke-Tests.ps1` once and never reruns Pester to recover output.
- Empirical ground truth from the spec's probes: v1 flags (`--packages`, `--no-telemetry`, `--init-events`) exit 2 on v2.10; `--package-cache` is the v2 spelling; server request fields are `command`/`sourcePaths`/`coverage`/`perTestCoverage`; readiness line is `{"ready":true}`; summary line can be 27 MB — stream it to disk, never through the console.

---

### Task 1: Config model — `containerTestApps` in, unit-test keys out

**Files:**
- Modify: `skills/al-build/scripts/build-operations.psm1:26-260` (`Get-BuildConfig`, `Resolve-CoverageEnabled`, `Get-CompileTargets`)
- Modify: `skills/al-build/config/al-build.json`
- Test: `tests/al-build/Get-BuildConfig.Tests.ps1`, `tests/al-build/CompileTargets.Tests.ps1`

**Interfaces:**
- Consumes: existing `Get-BuildConfig -Overrides` / `Get-GitRepoRoot` / `ConvertTo-Boolean`.
- Produces: `$config.ContainerTestApps` (`string[]` of absolute paths, default `@()`); `$config.TestApps` unchanged; the properties `UnitTestApp` and `UnitTestInitEvents` no longer exist on the config object; `Get-CompileTargets -Config` (no `-UnitTestOnly` switch) returns `@{ AppDir; Role }` for every `testApps` entry (`Role='test'`) then every `containerTestApps` entry not already listed (`Role='container-test'`); `Resolve-CoverageEnabled -Config [-Coverage] [-TestFilter <string>]` returns `$false` when `TestApps` is empty or `-TestFilter` is set, throws on `-Coverage` + `-TestFilter`.

- [ ] **Step 1: Write failing tests**

Add to `tests/al-build/Get-BuildConfig.Tests.ps1` (follow the file's existing fixture pattern for writing a temp `al-build.json`):

```powershell
It 'resolves containerTestApps to absolute paths' {
    Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":["test"],"containerTestApps":["e2e"]}'
    $config = Get-BuildConfig
    @($config.ContainerTestApps).Count | Should -Be 1
    [System.IO.Path]::IsPathRooted($config.ContainerTestApps[0]) | Should -BeTrue
}

It 'defaults containerTestApps to empty' {
    Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":["test"]}'
    (Get-BuildConfig).ContainerTestApps | Should -HaveCount 0
}

It 'no longer exposes unitTestApp keys' {
    Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":["test"],"unitTestApp":"unit"}'
    $config = Get-BuildConfig
    $config.PSObject.Properties.Name | Should -Not -Contain 'UnitTestApp'
    $config.PSObject.Properties.Name | Should -Not -Contain 'UnitTestInitEvents'
}
```

Replace the `Get-CompileTargets` assertions in `tests/al-build/CompileTargets.Tests.ps1` with:

```powershell
It 'lists testApps then containerTestApps, each once' {
    $config = [PSCustomObject]@{ TestApps = @('C:\r\test'); ContainerTestApps = @('C:\r\e2e', 'C:\r\test') }
    $targets = Get-CompileTargets -Config $config
    ($targets | ForEach-Object { $_.AppDir }) | Should -Be @('C:\r\test', 'C:\r\e2e')
    ($targets | Where-Object { $_.AppDir -eq 'C:\r\test' }).Role | Should -Be 'test'
}
```

- [ ] **Step 2: Run to verify failure** — `pwsh -Command "Invoke-Pester tests/al-build/Get-BuildConfig.Tests.ps1, tests/al-build/CompileTargets.Tests.ps1 -Output Detailed"` — new Its FAIL.

- [ ] **Step 3: Implement**

In `Get-BuildConfig`: resolve `containerTestApps` exactly like `testApps` (same array-guard + `Join-Path $workspaceRoot` loop) into `$containerTestApps`, default `@()`. Add `ContainerTestApps = $containerTestApps` to the config object. Delete the `unitTestApp`/`unitTestInitEvents` resolution block (lines 145-154) and both properties. In `Get-CompileTargets`: drop the `-UnitTestOnly` parameter and the `UnitTestApp` branch; append `containerTestApps` entries not already in `TestApps` with `Role = 'container-test'`. In `Resolve-CoverageEnabled`: replace `-UnitTestOnly` with `-TestFilter [string]`; throw `'-Coverage cannot be combined with -Test.'` when both; return `$false` when `TestFilter` non-empty.

In `skills/al-build/config/al-build.json`: remove `"unitTestApp"`, `"unitTestInitEvents"`; add `"containerTestApps": []` after `"testApps"`.

- [ ] **Step 4: Run to verify pass** — same Pester command, all green. Other suites will break until Tasks 6-8 land; that is expected and tracked there.

- [ ] **Step 5: Commit** — `git add -A; git commit -m "Split test config into testApps and containerTestApps"`

---

### Task 2: v2 CLI invocation

**Files:**
- Modify: `skills/al-build/scripts/build-operations.psm1:1480-1592` (replace `Invoke-ALRunnerTest`)
- Test: `tests/al-build/ALRunnerCli.Tests.ps1` (create)

**Interfaces:**
- Consumes: `Get-JUnitTestCounts -ResultFile` (existing, unchanged), `Get-AppJsonObject`, `Write-BuildMessage`, `Ensure-Directory`.
- Produces:
  - `Get-ALRunnerCliArgs -BundleDirs <string[]> -JUnitPath <string> [-TestFilter <string>] [-PackageCachePaths <string[]>]` → `string[]`: `--output-junit <JUnitPath>`, then `--test <TestFilter>` when set, then one `--package-cache <p>` pair per path, then every bundle dir. Never emits `--packages`, `--no-telemetry`, `--init-events`, `--strict`.
  - `Invoke-ALRunnerCli -BundleDirs <string[]> -OutputDir <string> [-TestFilter <string>] [-PackageCachePaths <string[]>]` → `[PSCustomObject]@{ Passed; Runner='al-runner'; ExitCode; Counts; ResultFile; NoticeLines }`. `ResultFile` = `<OutputDir>/al-runner.xml`. `NoticeLines` = every output line matching `^\[(bc|dep|expectations)\]` plus `[dep]` continuation lines (indented lines directly following a `[dep]` line). Exit 0 = passed; 1 = test failures; ≥2 throws with the last 20 output lines in the message (bad invocation / compile failure are gate errors, not red tests).

- [ ] **Step 1: Failing tests** — `tests/al-build/ALRunnerCli.Tests.ps1`:

```powershell
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'build-operations.psm1') -Force -DisableNameChecking
}
Describe 'Get-ALRunnerCliArgs' {
    It 'emits v2 flags in order' {
        $a = Get-ALRunnerCliArgs -BundleDirs @('C:\r\app', 'C:\r\test') -JUnitPath 'C:\o\al-runner.xml' -PackageCachePaths @('C:\cache')
        $a | Should -Be @('--output-junit', 'C:\o\al-runner.xml', '--package-cache', 'C:\cache', 'C:\r\app', 'C:\r\test')
    }
    It 'adds --test only when a filter is set' {
        (Get-ALRunnerCliArgs -BundleDirs @('C:\r\app') -JUnitPath 'x.xml' -TestFilter 'Codeunit60092') | Should -Contain '--test'
        (Get-ALRunnerCliArgs -BundleDirs @('C:\r\app') -JUnitPath 'x.xml') | Should -Not -Contain '--test'
    }
    It 'never emits a retired v1 flag' {
        $a = Get-ALRunnerCliArgs -BundleDirs @('C:\r\app') -JUnitPath 'x.xml' -PackageCachePaths @('C:\c')
        $a | Should -Not -Contain '--packages'
        $a | Should -Not -Contain '--no-telemetry'
        $a | Should -Not -Contain '--init-events'
    }
}
```

- [ ] **Step 2: Verify failure** — `Invoke-Pester tests/al-build/ALRunnerCli.Tests.ps1` — "Get-ALRunnerCliArgs not recognized".

- [ ] **Step 3: Implement** — in `build-operations.psm1`, delete `Invoke-ALRunnerTest` wholesale and add:

```powershell
function Get-ALRunnerCliArgs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$BundleDirs,
        [Parameter(Mandatory)][string]$JUnitPath,
        [string]$TestFilter,
        [string[]]$PackageCachePaths = @()
    )
    $cliArgs = @('--output-junit', $JUnitPath)
    if ($TestFilter) { $cliArgs += @('--test', $TestFilter) }
    foreach ($p in $PackageCachePaths) { $cliArgs += @('--package-cache', $p) }
    $cliArgs + $BundleDirs
}

function Invoke-ALRunnerCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$BundleDirs,
        [Parameter(Mandatory)][string]$OutputDir,
        [string]$TestFilter,
        [string[]]$PackageCachePaths = @()
    )
    $alRunner = Get-Command al-runner -ErrorAction SilentlyContinue
    if (-not $alRunner) { throw 'al-runner not found on PATH. Run provision.ps1 to install it.' }
    Ensure-Directory -Path $OutputDir
    $resultFile = Join-Path $OutputDir 'al-runner.xml'
    $cliArgs = Get-ALRunnerCliArgs -BundleDirs $BundleDirs -JUnitPath $resultFile -TestFilter $TestFilter -PackageCachePaths $PackageCachePaths
    Write-BuildMessage -Type Detail -Message "Command: al-runner $($cliArgs -join ' ')"
    $notices = [Collections.Generic.List[string]]::new()
    $tail = [Collections.Generic.Queue[string]]::new()
    & $alRunner.Source @cliArgs 2>&1 | ForEach-Object {
        $line = "$_"
        $line | Out-Host
        $isNotice = $line -match '^\[(bc|dep|expectations)\]'
        $isDepContinuation = ($notices.Count -gt 0) -and ($line -match '^\s+\S') -and ($notices[$notices.Count - 1] -match '^(\[dep\]|\s)')
        if ($isNotice -or $isDepContinuation) { $notices.Add($line) }
        $tail.Enqueue($line); if ($tail.Count -gt 20) { $null = $tail.Dequeue() }
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ge 2) { throw "al-runner could not run the suite (exit $exitCode). Last output:`n$($tail -join [Environment]::NewLine)" }
    [PSCustomObject]@{
        Passed      = ($exitCode -eq 0)
        Runner      = 'al-runner'
        ExitCode    = $exitCode
        Counts      = Get-JUnitTestCounts -ResultFile $resultFile
        ResultFile  = if (Test-Path -LiteralPath $resultFile) { $resultFile } else { '' }
        NoticeLines = $notices
    }
}
```

- [ ] **Step 4: Verify pass** — same Pester file green.

- [ ] **Step 5: Empirical check against the live fixture** — from `C:\Users\FlemmingBK\repo\GTM-BC-9AAdvMan-ItemConfigurator`: import the module, run `Invoke-ALRunnerCli -BundleDirs @("$pwd\app","$pwd\unit-tests") -OutputDir "$env:TEMP\alr-task2"` → expect `Passed=$false`, `ExitCode=1`, counts ≈ 1676 tests / 84 failed, `NoticeLines` containing a `[bc] selected` line and the `[dep] … License … NO IMPLEMENTATION` block. Clean up `$env:TEMP\alr-task2`.

- [ ] **Step 6: Commit** — `git commit -am "Replace v1 al-runner invocation with v2 CLI gate"`

---

### Task 3: Server protocol client — request builder, stream reader, JUnit synthesis

**Files:**
- Create: `skills/al-build/scripts/alrunner-server.psm1`
- Test: `tests/al-build/ALRunnerServerProtocol.Tests.ps1` (create)

**Interfaces:**
- Consumes: nothing from other modules (pure protocol; loadable in isolation).
- Produces:
  - `New-ALRunnerRunTestsRequest -SourcePaths <string[]> [-Coverage] [-PerTestCoverage]` → single-line compressed JSON `{"command":"runTests","sourcePaths":[...]}` plus `"coverage":true` / `"perTestCoverage":true` only when the switches are set.
  - `Read-ALRunnerRunTestsResponse -Reader <System.IO.TextReader> -SummaryPath <string>` → `[PSCustomObject]@{ Passed; ExitCode; Total; Failed; Errors; PassedCount; Cached; WallSeconds; Tests; SummaryFile }` where `Tests` is a list of `{ Name; Status; DurationMs; Message }`. Reads NDJSON: parses each `"type":"test"` line; writes the raw `"type":"summary"` line verbatim to `SummaryPath` (the 27 MB case — never through the console) then parses only its scalar fields; a line starting `{"error":` throws with that line; end-of-stream before summary throws `'al-runner server stream ended before summary'`.
  - `Write-ALRunnerJUnit -Tests <IEnumerable> -Path <string>` → JUnit XML: one `<testsuite name="CodeunitNNNN">` per codeunit prefix of `Name` (`Codeunit60092.Method` → suite `Codeunit60092`), one `<testcase name="Method" classname="CodeunitNNNN" time="...">` per test, `<failure message="...">` for `fail`, `<error message="...">` for `error`; suite and root `tests`/`failures`/`errors` attributes summed. Written with `[System.Xml.XmlWriter]` so messages are escaped.

- [ ] **Step 1: Failing tests**:

```powershell
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'alrunner-server.psm1') -Force -DisableNameChecking
}
Describe 'New-ALRunnerRunTestsRequest' {
    It 'emits coverage fields only when asked' {
        $r = New-ALRunnerRunTestsRequest -SourcePaths @('C:\a') | ConvertFrom-Json
        $r.command | Should -Be 'runTests'
        $r.PSObject.Properties.Name | Should -Not -Contain 'coverage'
        $r2 = New-ALRunnerRunTestsRequest -SourcePaths @('C:\a') -Coverage -PerTestCoverage | ConvertFrom-Json
        $r2.coverage | Should -BeTrue
        $r2.perTestCoverage | Should -BeTrue
    }
}
Describe 'Read-ALRunnerRunTestsResponse' {
    It 'parses a stream and lands the summary on disk' {
        $ndjson = @(
            '{"type":"test","name":"Codeunit50100.A","status":"pass","durationMs":3}'
            '{"type":"test","name":"Codeunit50100.B","status":"fail","durationMs":2,"message":"boom"}'
            '{"type":"summary","exitCode":1,"passed":1,"failed":1,"errors":0,"total":2,"cached":true,"wallSeconds":1.5,"protocolVersion":2}'
        ) -join "`n"
        $summaryPath = Join-Path $TestDrive 'summary.json'
        $r = Read-ALRunnerRunTestsResponse -Reader ([IO.StringReader]::new($ndjson)) -SummaryPath $summaryPath
        $r.Passed | Should -BeFalse
        $r.Total | Should -Be 2
        $r.Tests[1].Message | Should -Be 'boom'
        (Get-Content $summaryPath -Raw) | Should -Match '"protocolVersion":2'
    }
    It 'throws on a server error line' {
        $reader = [IO.StringReader]::new('{"error":"missing sourcePaths"}')
        { Read-ALRunnerRunTestsResponse -Reader $reader -SummaryPath (Join-Path $TestDrive 's.json') } | Should -Throw '*missing sourcePaths*'
    }
    It 'throws when the stream ends before a summary' {
        $reader = [IO.StringReader]::new('{"type":"test","name":"Codeunit1.A","status":"pass","durationMs":1}')
        { Read-ALRunnerRunTestsResponse -Reader $reader -SummaryPath (Join-Path $TestDrive 's.json') } | Should -Throw '*before summary*'
    }
}
Describe 'Write-ALRunnerJUnit' {
    It 'groups by codeunit and escapes messages' {
        $tests = @(
            [pscustomobject]@{ Name = 'Codeunit50100.A'; Status = 'pass'; DurationMs = 3; Message = $null }
            [pscustomobject]@{ Name = 'Codeunit50100.B'; Status = 'fail'; DurationMs = 2; Message = 'x < y & "z"' }
        )
        $path = Join-Path $TestDrive 'junit.xml'
        Write-ALRunnerJUnit -Tests $tests -Path $path
        [xml]$x = Get-Content $path
        $x.testsuites.tests | Should -Be '2'
        $x.testsuites.testsuite.name | Should -Be 'Codeunit50100'
        ($x.testsuites.testsuite.testcase | Where-Object name -eq 'B').failure.message | Should -Be 'x < y & "z"'
    }
}
```

- [ ] **Step 2: Verify failure** — module not found.
- [ ] **Step 3: Implement** `alrunner-server.psm1` to exactly the Produces contract. Read loop: `while ($null -ne ($line = $Reader.ReadLine()))`; dispatch on `$line.StartsWith('{"type":"summary"')` (write raw with `[IO.File]::WriteAllText($SummaryPath, $line)`, then `ConvertFrom-Json` for scalars), `$line.StartsWith('{"type":"test"')` (parse, add), `$line.StartsWith('{"error"')` (throw).
- [ ] **Step 4: Verify pass.**
- [ ] **Step 5: Commit** — `git commit -am "Add al-runner server protocol client with JUnit synthesis"`

---

### Task 4: Server lifecycle — manager script, pipe client, fingerprints

**Files:**
- Create: `skills/al-build/scripts/alrunner-server-manager.ps1`
- Modify: `skills/al-build/scripts/alrunner-server.psm1` (client-side connect/auto-start)
- Test: `tests/al-build/ALRunnerServerManager.Tests.ps1` (create)

**Interfaces:**
- Consumes: Task 3's `New-ALRunnerRunTestsRequest` / `Read-ALRunnerRunTestsResponse`.
- Produces (in `alrunner-server.psm1`):
  - `Get-ALRunnerPipeName -RepoRoot <string>` → `'albt-alr-' + first 16 hex chars of SHA256 of the lowercased full path`.
  - `Get-ALRunnerServerFingerprint -RepoRoot <string>` → SHA256 hex over: `al-runner --version` output, then one `path|lastWriteUtcTicks|length` line per schema-bearing `.al` file (first 4 KB matches `(?m)^\s*(table|tableextension)\s+\d`), sorted by path, then the same line per file under `tests/expectations/` when that directory exists.
  - `Request-ALRunnerServerRun -RepoRoot <string> -SourcePaths <string[]> [-Coverage] [-PerTestCoverage] -SummaryPath <string> [-NoAutoStart] [-ConnectTimeoutSec <int>]` → Task 3 response object, or `$null` when the server is unavailable (caller falls back to CLI). Connect: `[IO.Pipes.NamedPipeClientStream]::new('.', $pipeName, InOut)` with 500 ms timeout; on failure and not `-NoAutoStart`: `Start-Process pwsh -ArgumentList '-NoProfile','-File',<manager path>,'-RepoRoot',$RepoRoot -WindowStyle Hidden`, then retry-connect for up to `ConnectTimeoutSec` (default 120) seconds; still failing → `$null`. On connect: write the request line, wrap the pipe in a `StreamReader`, delegate to `Read-ALRunnerRunTestsResponse`.
- Produces (manager script): `alrunner-server-manager.ps1 -RepoRoot <path>` — second instance exits 0 immediately when the pipe already answers; owns one `al-runner --server` child (`WorkingDirectory = $RepoRoot`, stderr appended to `<RepoRoot>/.output/logs/al-runner-server.log`); waits for `{"ready":true}`; serves one pipe connection at a time: read one request line → recompute fingerprint; on change, run-count ≥ 50, or dead child → graceful `shutdown` + restart child → forward request to child stdin → relay child stdout lines to the pipe until (and including) the summary or error line → disconnect. Exits non-zero, logging why, when the child cannot be (re)started.

- [ ] **Step 1: Failing tests**:

```powershell
Describe 'Get-ALRunnerPipeName' {
    It 'is deterministic and path-case-insensitive' {
        (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\X') | Should -Be (Get-ALRunnerPipeName -RepoRoot 'c:\repo\x')
        (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\X') | Should -Match '^albt-alr-[0-9a-f]{16}$'
        (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\Y') | Should -Not -Be (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\X')
    }
}
Describe 'Get-ALRunnerServerFingerprint' {
    It 'changes on table edits, ignores codeunit edits' {
        $repo = Join-Path $TestDrive 'repo'; New-Item -ItemType Directory -Path (Join-Path $repo 'app\src') -Force | Out-Null
        Set-Content (Join-Path $repo 'app\src\T.Table.al') 'table 50100 "T" { fields { field(1; A; Integer) { } } }'
        Set-Content (Join-Path $repo 'app\src\C.Codeunit.al') 'codeunit 50101 "C" { }'
        $f1 = Get-ALRunnerServerFingerprint -RepoRoot $repo
        Set-Content (Join-Path $repo 'app\src\C.Codeunit.al') 'codeunit 50101 "C" { procedure P() begin end; }'
        Get-ALRunnerServerFingerprint -RepoRoot $repo | Should -Be $f1
        Start-Sleep -Milliseconds 20
        Set-Content (Join-Path $repo 'app\src\T.Table.al') 'table 50100 "T" { fields { field(1; A; Decimal) { } } }'
        Get-ALRunnerServerFingerprint -RepoRoot $repo | Should -Not -Be $f1
    }
}
Describe 'Request-ALRunnerServerRun failure path' {
    It 'returns null fast with -NoAutoStart and no pipe' {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = Request-ALRunnerServerRun -RepoRoot (Join-Path $TestDrive 'nowhere') -SourcePaths @('C:\a') -SummaryPath (Join-Path $TestDrive 's.json') -NoAutoStart
        $r | Should -BeNullOrEmpty
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 5
    }
}
```

- [ ] **Step 2: Verify failure.**
- [ ] **Step 3: Implement.** Manager core (complete shape — single client, one request/response per connection):

```powershell
$pipeName = Get-ALRunnerPipeName -RepoRoot $RepoRoot
$logPath = Join-Path $RepoRoot '.output' 'logs' 'al-runner-server.log'
$script:child = $null; $script:runCount = 0; $script:fingerprint = ''
function Start-Child {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $env:ComSpec
    $psi.Arguments = "/c al-runner --server 2>>`"$logPath`""
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true
    $script:child = [Diagnostics.Process]::Start($psi)
    $ready = $script:child.StandardOutput.ReadLine()
    if ($ready -notmatch '"ready":true') { throw "al-runner --server did not signal ready: $ready" }
    $script:fingerprint = Get-ALRunnerServerFingerprint -RepoRoot $RepoRoot
    $script:runCount = 0
}
Start-Child
while ($true) {
    $pipe = [IO.Pipes.NamedPipeServerStream]::new($pipeName, [IO.Pipes.PipeDirection]::InOut, 1)
    $pipe.WaitForConnection()
    try {
        $reader = [IO.StreamReader]::new($pipe); $writer = [IO.StreamWriter]::new($pipe); $writer.AutoFlush = $true
        $request = $reader.ReadLine()
        if ($null -eq $request) { continue }
        $current = Get-ALRunnerServerFingerprint -RepoRoot $RepoRoot
        if ($current -ne $script:fingerprint -or $script:runCount -ge 50 -or $script:child.HasExited) {
            if (-not $script:child.HasExited) { $script:child.StandardInput.WriteLine('{"command":"shutdown"}'); $null = $script:child.WaitForExit(5000) }
            if (-not $script:child.HasExited) { $script:child.Kill() }
            Start-Child
        }
        $script:child.StandardInput.WriteLine($request)
        while ($null -ne ($line = $script:child.StandardOutput.ReadLine())) {
            $writer.WriteLine($line)
            if ($line.StartsWith('{"type":"summary"') -or $line.StartsWith('{"error"')) { break }
        }
        $script:runCount++
    } finally { $pipe.Dispose() }
}
```

Single-instance guard before `Start-Child`: try a 200 ms client connect to `$pipeName`; success → another manager runs → `exit 0`.

- [ ] **Step 4: Verify pass** — pipe-name/fingerprint/failure-path tests green (no live server needed).
- [ ] **Step 5: Live smoke** — from the ItemConfigurator repo: `Request-ALRunnerServerRun -RepoRoot $pwd -SourcePaths @("$pwd\app","$pwd\unit-tests") -SummaryPath "$env:TEMP\alr-task4.json"` twice; first call auto-starts (allow ~90 s), second returns ≤15 s with `Total = 1676`. Stop manager and child with `Stop-Process -Id <PID>` (never by name); delete the temp summary.
- [ ] **Step 6: Commit** — `git commit -am "Add al-runner server manager with named-pipe bridge"`

---

### Task 5: Coverage artifacts from perTestCoverage

**Files:**
- Create: `skills/al-build/scripts/alrunner-coverage.psm1`
- Test: `tests/al-build/ALRunnerCoverage.Tests.ps1` (create), fixture `tests/al-build/fixtures/alrunner-summary/small-summary.json` (create)

**Interfaces:**
- Consumes: the summary file written by Task 3. Verified shapes: `coverage: [{file, statements:[{id,scope,line,column,endLine,endColumn,hits}]}]` and `perTestCoverage: [{test:"Codeunit60000.Method", coverage:[…same shape…]}]`; file paths are absolute with forward slashes.
- Produces: `Write-ALRunnerCoverageArtifacts -SummaryFile <string> -RepoRoot <string> -MainAppPath <string> -TestApps <string[]> -OutputDirectory <string>` → `[PSCustomObject]@{ PerTestPath; CoberturaPath; LineRate; LinesValid; LinesCovered }`.
  - `per-test.jsonl`: `source` records first — one per distinct (file, line) in the aggregate `coverage`, main-app files only: `{"kind":"source","objectType":"codeunit","objectName":"TDD Price Calc","sourcePath":"app/src/X.Codeunit.al","lineNumber":12}`. `objectType`/`objectName` parsed from the file's first object-declaration line (regex `^\s*(codeunit|table|tableextension|page|pageextension|report|reportextension|query|xmlport|enum|enumextension|interface|permissionset|controladdin)\s+\d*\s*"?([^"{\r\n]+?)"?\s*($|\{|implements|extends)`). `sourcePath` repo-relative, forward slashes. Then `hit` records — one per (test, file, line), hits summed across that test's statements on the line: `{"kind":"hit","testApp":"unit-tests","testCodeunit":"Codeunit60000","testProcedure":"Method","sourcePath":"…","lineNumber":12,"hits":1}`. `testApp` = leaf name of the `TestApps` entry whose `app.json` `idRanges` contain the test codeunit id; unresolvable id → `"unknown"`. All records sorted (`sourcePath`, `lineNumber`, test name) — two runs over the same summary produce byte-identical files.
  - `cobertura.xml`: from the aggregate `coverage`, main-app files only: `<coverage line-rate=…><packages><package name="app"><classes><class name=… filename=… line-rate=…><lines><line number=… hits=…/>`, statements grouped by line, hits summed. `LinesValid` = distinct lines; `LinesCovered` = distinct lines with hits > 0; `LineRate` = covered/valid rounded to 4 decimals (0 valid lines → rate 0).
- Failure paths: summary missing `coverage` or `perTestCoverage` → throw naming the missing field; a covered main-app file whose object declaration cannot be parsed → throw naming the file.

- [ ] **Step 1: Build the fixture** — `small-summary.json`: aggregate `coverage` for 3 files (`app/src/Calc.Codeunit.al` 4 lines / 3 hit, `app/src/T.Table.al` 1 line hit, `test/src/CalcTest.Codeunit.al` — must be excluded), `perTestCoverage` with 2 tests (`Codeunit50150.A`, `Codeunit50150.B`) overlapping on one line, scalars `exitCode:0,total:2,…`. Also create matching source files under a `$TestDrive` fake repo in the test's `BeforeAll` (fixture stores the summary; the test synthesizes the repo layout with `app.json` files whose `idRanges` cover 50150 for the test app).
- [ ] **Step 2: Failing tests** — assert: source records exclude non-main files; hit records carry `testApp='test'`, `testCodeunit='Codeunit50150'`, `testProcedure`; `LineRate` = 0.8 for 4/5 covered; byte-identical double run; both failure paths throw with the named field/file.
- [ ] **Step 3: Implement.** **Step 4: Verify pass.**
- [ ] **Step 5: Commit** — `git commit -am "Derive per-test and Cobertura coverage from al-runner"`

---

### Task 6: `test.ps1` rewrite

**Files:**
- Modify: `skills/al-build/scripts/test.ps1` (rewrite; keep `Start-Step`/`Stop-Step`, `ConvertTo-RunRecord`, `Get-RunnerTotals`, `Write-TestSummary`, `Show-RunnerTotals`, the gate-metrics finally block)
- Test: `tests/al-build/TestModes.Tests.ps1` (rewrite), `tests/al-build/GateOutputStreaming.Tests.ps1` (update)

**Interfaces:**
- Consumes: Task 1 config (`TestApps`, `ContainerTestApps`, no unit-test keys), Task 2 `Invoke-ALRunnerCli`, Task 3 `Write-ALRunnerJUnit`, Task 4 `Request-ALRunnerServerRun`, Task 5 `Write-ALRunnerCoverageArtifacts`, existing `Invoke-ALBuild`, `Copy-ALSymbolToCache`, `Get-RequiredRuntimeMajor`, `Get-SymbolCacheInfo`, `Get-AppJsonObject`.
- Produces: `test.ps1 [-Test <pattern>] [-Coverage]` — no other switches, no mode guard. Exit 0 = green. `summary.json`: `gate:"al-runner"`; `runs` = one record `{ runner:"al-runner", appName:"<comma-joined test bundle leaf names>", dir:"TestResults", passed, counts, resultFile, filter (only when -Test), notices }`; `totals` per-runner as today; `coverage` block in today's schema fed from Task 5's return values. Gate-metrics task name stays `test`.

Flow:
1. Startup cleanup (unchanged) → config → `$coverageEnabled = Resolve-CoverageEnabled -Config $config -Coverage:$Coverage -TestFilter $Test`.
2. Compile main app; then for each `Get-CompileTargets -Config $config` entry: `Copy-ALSymbolToCache` + `Invoke-ALBuild` (container test apps compile through the analyzer gate here; they never run here).
3. `$bundles = @($config.AppDir) + @($config.TestApps)`. `$packageCaches` = distinct `(Get-SymbolCacheInfo -AppJson (Get-AppJsonObject $_)).CacheDir` over `$config.TestApps`, errors surfaced as today's "run provision.ps1 first".
4. Run:
   - `-Test` set → `Invoke-ALRunnerCli -BundleDirs $bundles -OutputDir $baseResultsPath -TestFilter $Test -PackageCachePaths $packageCaches`.
   - else → `$serverResult = Request-ALRunnerServerRun -RepoRoot $repoRoot -SourcePaths $bundles -Coverage:$coverageEnabled -PerTestCoverage:$coverageEnabled -SummaryPath (Join-Path $baseResultsPath 'al-runner-summary.json')`.
     - response: `Write-ALRunnerJUnit -Tests $serverResult.Tests -Path (Join-Path $baseResultsPath 'al-runner.xml')`; counts from the stream (`tests`=Total, `testsPassed`=PassedCount, `testsFailed`=Failed+Errors, `testsSkipped`=0, `testCodeunits`=distinct codeunit prefixes); coverage enabled → `Write-ALRunnerCoverageArtifacts -SummaryFile … -RepoRoot $repoRoot -MainAppPath $config.AppDir -TestApps $config.TestApps -OutputDirectory (Join-Path $baseResultsPath 'coverage')`.
     - `$null` + coverage enabled → gate red: `"al-runner server unavailable and enabled coverage requires it (see .output/logs/al-runner-server.log)"`.
     - `$null` + coverage disabled → `Invoke-ALRunnerCli` (no filter). If that throws exit-2 with the ncl-shadow signature (`Access to the path.*ncl-shadow`), retry once before rethrowing — the transient first-run crash from the spec.
5. Notices: every `NoticeLines`/server-log notice line re-emitted `Write-BuildMessage -Type Detail`; lines matching `NO IMPLEMENTATION` escalate to `-Type Warning`.
6. Red: print up to 10 failing test names + messages (stream or JUnit), point at `resultFile`. Summary written in the `finally` as today.

- [ ] **Step 1: Rewrite `tests/al-build/TestModes.Tests.ps1`**:

```powershell
It 'exposes only Test and Coverage parameters beyond common ones' {
    $cmd = Get-Command (Join-Path $scriptsDir 'test.ps1')
    $cmd.Parameters.Keys | Should -Contain 'Test'
    $cmd.Parameters.Keys | Should -Contain 'Coverage'
    foreach ($gone in 'UnitTestOnly', 'AllTests', 'Force') { $cmd.Parameters.Keys | Should -Not -Contain $gone }
}
It 'Resolve-CoverageEnabled rejects -Coverage with a test filter' {
    $config = [PSCustomObject]@{ TestApps = @('C:\r\test'); CoverageEnabled = $true }
    { Resolve-CoverageEnabled -Config $config -Coverage -TestFilter 'X' } | Should -Throw '*-Test*'
}
It 'test.ps1 contains no container vocabulary' {
    $content = Get-Content (Join-Path $scriptsDir 'test.ps1') -Raw
    foreach ($banned in 'Ensure-BCAgentContainer', 'Invoke-ALPublish', 'Wait-BCAppsSynced', 'Invoke-ALTest', 'ContainerName') {
        $content | Should -Not -Match $banned
    }
}
```

- [ ] **Step 2: Verify failure.** **Step 3: Rewrite `test.ps1`** per the flow; delete old Steps 4-8c and every container/coverage-staging reference.
- [ ] **Step 4: Verify** — `Invoke-Pester tests/al-build/TestModes.Tests.ps1, tests/al-build/GateOutputStreaming.Tests.ps1`.
- [ ] **Step 5: Live gate run** — in the ItemConfigurator repo, with its local `al-build.json` temporarily edited (add `"containerTestApps": ["integration-tests"]`, keep `"testApps": ["integration-tests","unit-tests"]`? No — set `"testApps": ["unit-tests","integration-tests"]`, `"containerTestApps": []`, drop `"unitTestApp"`): `pwsh -File …/test.ps1` → red, ≈2830 total with named failures, `summary.json` `gate:"al-runner"`, `al-runner.xml` present; `pwsh -File …/test.ps1 -Test Codeunit60047` → exit 0. Revert the fixture repo's `al-build.json` after (leave no local changes).
- [ ] **Step 6: Commit** — `git commit -am "Rewrite test gate: compile plus one al-runner run, no modes, no container"`

---

### Task 7: `container-test.ps1` — explicit container surface

**Files:**
- Create: `skills/al-build/scripts/container-test.ps1`
- Modify: `skills/al-build/scripts/build-operations.psm1` (move `ConvertTo-RunRecord`, `Get-RunnerTotals`, `Write-TestSummary`, `Show-RunnerTotals` here from `test.ps1` so both scripts share one definition; `test.ps1` imports them)
- Test: `tests/al-build/ContainerTest.Tests.ps1` (create)

**Interfaces:**
- Consumes: `Get-BuildConfig` (`ContainerTestApps`), existing `Ensure-BCAgentContainer`, `Test-AppNeedsPublish`, `Invoke-ALPublish`, `Invoke-ALUnpublish`, `Wait-BCAppsSynced`, `Invoke-ALTest` (coverage-free after Task 8 — this task lands first with the parameters still present but passed as disabled), `Get-AppJsonObject`, shared summary helpers.
- Produces: `container-test.ps1 [-Force]`:
  1. Config check: empty `ContainerTestApps` → `Write-BuildMessage -Type Error` naming `containerTestApps` in `al-build.json`, exit 1 — before any BcContainerHelper import.
  2. Artifact check: every `containerTestApps` entry and the main app must have a compiled `.app` in their output folders — a missing one exits 1 naming the app and "run the gate (test.ps1) first"; this script never compiles.
  3. Container flow (today's test.ps1 Steps 4-8c, minus coverage): `Ensure-BCAgentContainer` → main-app publish decision (`Test-AppNeedsPublish`, `-Force`) → dependency-reversed unpublish of container test apps when main republishes → publish main → publish each container test app (`-Force` inherits) → `Wait-BCAppsSynced` over main + container test apps → `Invoke-ALTest` per app into `.output/TestResults/<dir>/` (`last.xml`).
  4. `summary.json`: `gate:"container"`, per-app `runs[]` records (today's shape). Gate-metrics task name `container-test`. Exit 0 only when every run passed.

- [ ] **Step 1: Failing tests** — `ContainerTest.Tests.ps1`: parameter surface (`-Force` present, `-Coverage`/`-Test` absent); empty-config failure (temp repo with `"containerTestApps": []` → run script → exit 1, stderr names `containerTestApps`, and BcContainerHelper was never imported — assert by absence of its import side-effect message in output); missing-artifact failure (config names an app dir with `app.json` but no `.app` → exit 1 naming the app).
- [ ] **Step 2: Verify failure.** **Step 3: Implement** (validation order exactly as in Produces). **Step 4: Verify pass.**
- [ ] **Step 5: Commit** — `git commit -am "Add explicit-only container test surface"`

---

### Task 8: Delete the container coverage machinery

**Files:**
- Delete: `skills/al-build/scripts/coverage-runtime.psm1`, `coverage-normalizer.psm1`, `coverage-preflight.psm1`, `coverage-helper-golden.psm1`, `skills/al-build/code-coverage-helper/` (whole folder)
- Delete: `tests/al-build/CoverageNormalizer.Tests.ps1`, `CoverageRuntime.Tests.ps1`, `CoveragePreflight.Tests.ps1`, `CoverageAggregation.Tests.ps1`, `CoverageConfiguration.Tests.ps1`, `CoverageLiveFixture.Tests.ps1`, `CodeCoverageHelperGolden.Tests.ps1`, `tests/al-build/fixtures/code-coverage-live/` (whole folder)
- Modify: `skills/al-build/scripts/build-operations.psm1` (`Invoke-ALTest`: remove `-Coverage`, `-CoverageStagingRoot`, `-CoverageContract` parameters and their body branches), `skills/al-build/scripts/common.psm1` (remove functions whose only callers were the deleted modules — find candidates with `grep -n 'Coverage' skills/al-build/scripts/common.psm1`, keep any function `test.ps1`/`container-test.ps1`/surviving modules still call), `skills/al-build/scripts/container-test.ps1` (drop the disabled-coverage arguments from its `Invoke-ALTest` calls)
- Modify: `skills/al-build/COVERAGE.md` (rewrite)

- [ ] **Step 1: Delete + strip.** Verify zero survivors: `grep -rn "coverage-runtime|coverage-normalizer|coverage-preflight|coverage-helper-golden|code-coverage-helper|CoverageStagingRoot|CoverageContract" skills tests` → no hits.
- [ ] **Step 2: Rewrite `COVERAGE.md`** — new contract: coverage runs on the al-runner gate; enable via `-Coverage` or `coverage.enabled`; artifacts `.output/TestResults/coverage/per-test.jsonl` (document the `source` and `hit` record fields exactly as Task 5 produces them) + `cobertura.xml`; enabled coverage requires the al-runner server and goes red without it; `-Coverage -Test` invalid; container runs collect no coverage.
- [ ] **Step 3: Fast suite** — task agent (pinned `gpt-5.6-luna`) runs `pwsh -File scripts/Invoke-Tests.ps1 -Mode Fast` once. Green required.
- [ ] **Step 4: Commit** — `git commit -am "Delete container coverage machinery"`

---

### Task 9: provision.ps1 — al-runner mandatory, floor 2.10

**Files:**
- Modify: `skills/al-build/scripts/build-operations.psm1:514-572` (`Install-ALRunner`, new `ConvertTo-ALRunnerVersion`), `skills/al-build/scripts/provision.ps1:88-91` (unconditional call)
- Test: `tests/al-build/Provision.Tests.ps1` (extend)

**Interfaces:**
- Produces: `ConvertTo-ALRunnerVersion -VersionLine <string>` → `[version]` (`'al-runner v2.10.0.0'` → `2.10.0.0`; no match → throw naming the line). `Install-ALRunner [-Update]` after ensuring presence runs `al-runner --version`, parses via `ConvertTo-ALRunnerVersion`; below `[version]'2.10'` → `dotnet tool update --global MSDyn365BC.AL.Runner` and re-check; still below → throw `"al-runner $found found, 2.10 required"`.

- [ ] **Step 1: Failing tests**:

```powershell
It 'parses the al-runner version banner' {
    ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0.0' | Should -Be ([version]'2.10.0.0')
}
It 'throws on an unrecognizable banner' {
    { ConvertTo-ALRunnerVersion -VersionLine 'nonsense' } | Should -Throw '*nonsense*'
}
It 'provision.ps1 calls Install-ALRunner unconditionally' {
    $content = Get-Content (Join-Path $scriptsDir 'provision.ps1') -Raw
    $content | Should -Match '(?m)^Install-ALRunner'
}
```

- [ ] **Step 2-4: Implement, verify, commit** — `git commit -am "Require al-runner 2.10 in provisioning"`

---

### Task 10: report-gate-metrics task names

**Files:**
- Modify: `skills/al-build/scripts/report-gate-metrics.ps1:38-58` (default `-Task @('test','unit-test')` → `@('test','container-test')`; matching doc-comment text)
- Test: `tests/al-build/GateMetrics.Tests.ps1` (update the default-filter expectation)

- [ ] **Steps: update test → verify failure → update script → verify pass → commit** — `git commit -am "Track gate metrics for test and container-test tasks"`

---

### Task 11: Skill surface — SKILL.md + five consumers

**Files:**
- Modify: `skills/al-build/SKILL.md`, `skills/al-build/COVERAGE.md` (cross-check only, rewritten in Task 8), `skills/al-implement/SKILL.md:23,35`, `skills/al-refactor/SKILL.md:23,37`, `skills/al-review/SKILL.md:31`, `skills/al-pr-shepherd/SKILL.md:25`, `skills/al-walkthrough/SKILL.md:18`

Binding rules: read `.github/instructions/skills.instructions.md` first. Consumer skills never name a `.ps1` — they say "/al-build's gate" or "/al-build's container tests". al-build's `SKILL.md` stays ≤ 80 lines.

- [ ] **Step 1: `skills/al-build/SKILL.md`** — replace the gate table with:

```markdown
| Command | Scope |
|---|---|
| `test.ps1` | The gate. Compiles every app (main, `testApps`, `containerTestApps`) through the analyzer gate, then runs AL Runner once over the main app and every `testApps` bundle — through the warm AL Runner server when available, a fresh process otherwise. Never touches a container. |
| `test.ps1 -Test <pattern>` | One test or codeunit through a fresh AL Runner process, for focused debugging. Never collects coverage. |
| `container-test.ps1` | Container tests for `containerTestApps`: publish, sync barrier, run. Only when a task explicitly requires the container surface — no ordinary gate or verify step calls it. |
```

"Read the result" section updates: `gate` is `al-runner` or `container`; the al-runner gate writes one merged run record; its JUnit is `.output/TestResults/al-runner.xml`; container runs keep per-app `last.xml`. Add: surface and read the `[bc] selected` line, treat `[dep] … NO IMPLEMENTATION` as a red-flag warning, and keep expected AL Runner failures in the consumer repo's `tests/expectations` manifest — after adding an entry, confirm the `pass-known-gap` counter moved (a mistyped codeunit name matches nothing, silently). Configuration section: `testApps`, `containerTestApps`; delete the `unitTestApp`/`unitTestInitEvents` sentences; drop `-Force` from the gate row (it belongs to `container-test.ps1` and `publish-apps.ps1`). Script table: add `container-test.ps1` and `alrunner-server-manager.ps1` (one line: owns the warm AL Runner server; started automatically by `test.ps1`; restarts on tool update, table-shape change, expectations change, every 50 runs).

- [ ] **Step 2: Consumer skill edits** (exact replacements):
  - `al-implement:23` / `al-refactor:23`: "run /al-build in `UnitTestOnly` mode for unit proof or `AllTests` mode for integration proof and require its current scope green" → "run /al-build's gate and require its current scope green".
  - `al-implement:35`: "Run the same /al-build mode until green, then run /al-build in `AllTests` mode." → "Run /al-build's gate until green."
  - `al-refactor:37`: "Run /al-build in `UnitTestOnly` mode after a unit-only edit or `AllTests` mode after an integration edit, then finish in `AllTests` mode." → "Run /al-build's gate after each edit and finish on a green gate."
  - `al-review:31`: "Run /al-build in `UnitTestOnly` mode for missing unit evidence or `AllTests` mode for missing integration evidence." → "Run /al-build's gate for missing test evidence."
  - `al-pr-shepherd:25`: "/al-build -AllTests gates the synced tree before the push." → "/al-build's gate proves the synced tree before the push."
  - `al-walkthrough:18`: "Run /al-build in `AllTests` mode with forced republish into that container." → "Run /al-build's clean republish into that container."
- [ ] **Step 3: Gates** — `pwsh -File scripts/Validate-Skills.ps1` green; `(Get-Content skills/al-build/SKILL.md).Count -le 84` (80 body + frontmatter).
- [ ] **Step 4: Commit** — `git commit -am "Rewrite gate vocabulary across al-build and consumers"`

---

### Task 12: Version bump + full verification

**Files:**
- Modify: `plugin.json` (`"version": "2.4.13"` → `"version": "3.0.0"` — the gate contract is breaking)

- [ ] **Step 1: Bump + commit** — `git commit -am "al-agentic-dev 3.0.0: test gate on AL Runner v2"`
- [ ] **Step 2: Full gate battery** — task agent pinned to `gpt-5.6-luna` runs once: `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, `scripts/Update-Review.ps1 -Check`, `scripts/Invoke-Tests.ps1 -Mode Full` — all five green.
- [ ] **Step 3: End-to-end against the live fixture** — in the ItemConfigurator repo (its `al-build.json` edited as in Task 6 Step 5, reverted after): `provision.ps1` (2.10 floor verified), `test.ps1` (red, named failures, `gate:"al-runner"`), `test.ps1 -Test Codeunit60047` (exit 0), second full `test.ps1` (server warm, faster; `.output/logs/al-runner-server.log` exists). Nothing committed in that repo.
- [ ] **Step 4: Spec's implementation-time verifications, recorded in the PR description** — `--expectations` honored through the server bridge (temp one-entry manifest → `pass-known-gap` visible); JUnit synthesis spot-check (one failing test's message present in `al-runner.xml`); ncl-shadow retry behavior exercised or code-reviewed (Task 6 flow step 4).

---

## Self-review notes

- Spec coverage: §1→Task 6, §2→Task 1, §3→Tasks 3+4, §4→Tasks 5+8, §5→Task 7, §6→Task 11 (expectations wording; mechanism is al-runner's own), §7→Tasks 6+7, §8→Task 9, §9→Task 11; report-gate-metrics ripple→Task 10; version→Task 12. Out-of-scope spec items (`--test-data`, CRAP, mutation, `--tdd`, drift root-causing) have no tasks by design.
- Placeholder scan: no TBDs; the one deliberately deferred behavior (mandatory-coverage on fallback) is specified exactly (red with a named cause) in Task 6 flow step 4.
- Name consistency: `ContainerTestApps` (Task 1) ↔ Tasks 6/7/11; `Get-ALRunnerCliArgs`/`Invoke-ALRunnerCli` (Task 2) ↔ Task 6; `New-ALRunnerRunTestsRequest`/`Read-ALRunnerRunTestsResponse`/`Write-ALRunnerJUnit` (Task 3) ↔ Tasks 4/6; `Get-ALRunnerPipeName`/`Get-ALRunnerServerFingerprint`/`Request-ALRunnerServerRun` (Task 4) ↔ Task 6; `Write-ALRunnerCoverageArtifacts` (Task 5) ↔ Task 6; `ConvertTo-ALRunnerVersion` (Task 9) self-contained.

### Task 13a: Server is the only test path

Removed the CLI fallback the plan's Task 6 originally left in `test.ps1`: the `-Test <pattern>` parameter, the `Invoke-ALRunnerCliWithRetry` wrapper and its ncl-shadow retry, and both server-unavailable CLI fallback branches. An unavailable server now fails the gate directly, naming `.output/logs/al-runner-server-manager.log` and `.output/logs/al-runner-server.log` — no coverage-specific branch, since the server is the only path whether coverage is on or off. `Invoke-ALRunnerCli`, `Get-ALRunnerCliArgs`, and `Select-ALRunnerNoticeLines` are deleted from `build-operations.psm1` (no remaining caller); `Resolve-CoverageEnabled` drops `-TestFilter`. `ALRunnerCli.Tests.ps1` is deleted; `TestModes.Tests.ps1`, `GateOutputStreaming.Tests.ps1`, `CoverageResolution.Tests.ps1` lose their `-Test`/fallback cases and gain a server-unavailable assertion. `SKILL.md` and `COVERAGE.md` drop the `-Test`/CLI-fallback mentions; a focused single-test run is documented as `al-runner --test <name> <bundle dirs>` typed directly, outside the gate.

### T13 — self-contained dependency dir

**What:** Closed the gap named in design decision 3: the gate previously passed no `--package-cache` and only worked because the consumer's gitignored `.alpackages/` happened to hold the one non-Microsoft symbols-only dependency (the `9A Advanced Manufacturing - License` package). `alrunner-server.psm1` gained `Resolve-ALRunnerDependencySet` (private-by-convention, exported for tests), `New-ALRunnerDependencyDirectory -RepoRoot -OutputDirectory`, `Get-ALRunnerDependencySetFingerprintLines`, and `Get-ALRunnerDependencySetFingerprint`. For every bundle (`AppDir` + `TestApps`), every `app.json` dependency whose publisher is not Microsoft and whose id is not itself a bundle is matched by filename against that bundle's own checkout symbol cache dir (`Get-SymbolCacheInfo`) — `download-symbols.ps1` names files `<publisher><name-no-spaces>.<version>.app` — taking the highest cache version that still satisfies the declared minimum. A dependency with no satisfying file is a hard failure naming the publisher, name, version and cache dir searched, and pointing at `download-symbols.ps1`. `New-ALRunnerDependencyDirectory` empties and rebuilds `.output/al-runner-deps` from that set; it never copies a Microsoft package, never copies a bundle's own id, and never reads `.alpackages`. `alrunner-server-manager.ps1` now `Set-Location`s to `-RepoRoot` before importing `common.psm1`/`build-operations.psm1` (the symbol-cache root is checkout-scoped), and `Start-Child` calls the builder first, logs one `[deps] <publisher>/<name> <version> <- <source>` line per placed package plus the package-cache dir, then starts `al-runner --server --package-cache "<dir>"`; a builder failure propagates as a failed start, same as an unready child. `Get-ALRunnerServerFingerprint` folds in the dependency-set lines, so a new dependency, a version bump, or a re-downloaded package now also triggers the manager's existing restart check.

**Where:** `skills/al-build/scripts/alrunner-server.psm1`, `alrunner-server-manager.ps1`, `test.ps1` (comment only), `skills/al-build/SKILL.md`.

**How verified:** `tests/al-build/ALRunnerDependencyDirectory.Tests.ps1` (new, 9 cases: third-party inclusion, Microsoft exclusion, bundle-id exclusion, missing-package throw naming the cache dir, highest-satisfying-version pick, stale-output-dir cleanup, and three fingerprint cases) — all green. `ALRunnerServerManager.Tests.ps1` fixtures gained a minimal `al-build.json` (fingerprint now depends on `Get-BuildConfig`) and the never-ready process test now asserts the `[deps] package-cache: …` log line. `ALRunnerServerProtocol.Tests.ps1`, `TestModes.Tests.ps1`, and `GateOutputStreaming.Tests.ps1` re-run unaffected and green.

