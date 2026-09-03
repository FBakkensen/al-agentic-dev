#Requires -Version 7.2

<#
.SYNOPSIS
    Build every configured app, then run al-runner once over the whole set.

.DESCRIPTION
    The canonical build-test gate. Performs the full workflow:
    1. Build the main app.
    2. For each configured test app: provision the main app's symbol into its
       cache, then build it (analyzer gate, host alc).
    3. Run al-runner once over the main app plus every test app, through the
       al-runner server (auto-started on first use). The server is the only
       test path — no fallback.
    4. Write the run to .output/TestResults/al-runner.xml.
    5. Write summary to .output/TestResults/summary.json
       (gate, per-runner totals, one run record with test counts).

    Coverage can be enabled by configuration, ALBT_COVERAGE_ENABLED, or
    -Coverage. It is skipped when testApps is empty.

.PARAMETER Coverage
    Collect complete per-test raw coverage across every configured test app.
    Ignored when testApps is empty.

.EXAMPLE
    pwsh -File test.ps1
    # Compile every app, then run the full al-runner suite.

.EXAMPLE
    pwsh -File test.ps1 -Coverage
    # Run the full suite and retain complete per-test raw coverage.
#>

[CmdletBinding()]
param(
    [switch]$Coverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Track timing
$script:BuildStartTime = [Diagnostics.Stopwatch]::StartNew()
$script:StepTimings = @{}
$script:CurrentStage = $null
$script:LastErrorMessage = $null

function Start-Step {
    param([string]$Name)
    $script:CurrentStage = $Name
    $script:StepTimings[$Name] = [Diagnostics.Stopwatch]::StartNew()
}

function Stop-Step {
    param([string]$Name)
    if ($script:StepTimings.ContainsKey($Name)) {
        $script:StepTimings[$Name].Stop()
    }
}

$isDotSourced = $MyInvocation.InvocationName -eq '.'

# Import modules
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'alrunner-server.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'alrunner-coverage.psm1') -Force -DisableNameChecking

function Invoke-TestGate {
    param(
        [switch]$Coverage
    )

    # Verdict channel. The gate's success stream carries live payload (native
    # command stdout — compiler diagnostics above all), so the exit code never
    # rides it: every verdict sets $script:GateExitCode and returns nothing.
    $script:GateExitCode = 1

# ---------------------------------------------------------------------------
# Startup cleanup — runs for every invocation and always precedes
# configuration loading, so a run never inherits stale JUnit or coverage
# artifacts left behind by a previous run.
# ---------------------------------------------------------------------------
$repoRoot = Get-GitRepoRoot
$baseResultsPath = Join-Path $repoRoot '.output' 'TestResults'
if (Test-Path -LiteralPath $baseResultsPath) {
    try {
        Remove-Item -LiteralPath $baseResultsPath -Recurse -Force -Confirm:$false
    } catch {
        Write-BuildMessage -Type Error -Message "Failed to remove stale test results tree: $baseResultsPath. $_"
        return
    }
}
New-Item -ItemType Directory -Path $baseResultsPath -Force | Out-Null

function Write-ALRunnerFailureSample {
    <#
    .SYNOPSIS
        Print up to 10 failing test names and messages, pointing at the result file.
    .DESCRIPTION
        Reads from the server's per-test stream when available (Tests); falls
        back to parsing the JUnit result file's failure/error nodes when it is
        not.
    #>
    param(
        [Parameter(Mandatory)][string]$ResultFile,
        $Tests
    )
    $samples = [Collections.Generic.List[pscustomobject]]::new()
    if ($Tests) {
        foreach ($t in @($Tests | Where-Object { $_.Status -in @('fail', 'error') })) {
            $samples.Add([pscustomobject]@{ Name = $t.Name; Message = $t.Message })
            if ($samples.Count -ge 10) { break }
        }
    } elseif (Test-Path -LiteralPath $ResultFile) {
        try {
            [xml]$doc = Get-Content -LiteralPath $ResultFile -Raw
            foreach ($case in @($doc.SelectNodes('//testcase'))) {
                $failureNode = $case.SelectSingleNode('failure')
                if (-not $failureNode) { $failureNode = $case.SelectSingleNode('error') }
                if ($failureNode) {
                    $samples.Add([pscustomobject]@{ Name = $case.name; Message = $failureNode.message })
                    if ($samples.Count -ge 10) { break }
                }
            }
        } catch {
            Write-BuildMessage -Type Warning -Message "Could not read failing test detail from ${ResultFile}: $_"
        }
    }
    foreach ($sample in $samples) {
        Write-BuildMessage -Type Error -Message "  - $($sample.Name): $($sample.Message)"
    }
    Write-BuildMessage -Type Error -Message "Results: $ResultFile"
}

# An expectations manifest turns a failing test into exit 0. al-runner
# auto-probes <repo>/tests/expectations from its cwd, so the folder's presence
# alone would hide failures — the gate reds before the server ever starts.
$expectationsDir = Join-Path $repoRoot 'tests' 'expectations'
if (Test-Path -LiteralPath $expectationsDir) {
    $failureMessage = "Expectations manifest found at tests/expectations — the gate never hides a failing test. Remove the folder. A failing test is fixed (green), or is an al-runner gap (stop and ask the user), or needs a surface al-runner refuses by design and moves its app to containerTestApps on the user's explicit ack."
    Write-BuildMessage -Type Error -Message $failureMessage
    return
}

# Load configuration — malformed config throws here, outside the gate's
# try/finally, so no summary.json is written (startup cleanup already left
# an empty TestResults tree).
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config
$coverageEnabled = Resolve-CoverageEnabled -Config $config -Coverage:$Coverage

$testResults = @()

# Coverage lifecycle tracking — read only in the finally block below to
# build summary.json's coverage object. Coverage-disabled runs never touch
# any of these beyond their initial values.
$coverageComplete = $false
$coverageFailureMessage = $null
$coveragePerTestJsonlRelPath = $null
$coverageCoberturaRelPath = $null
$coverageLineRate = $null
$coverageLinesValid = $null
$coverageLinesCovered = $null

# Gate metrics: outcome defaults to 'error' and is only upgraded at the
# verdict points below — any throw (compile, al-runner) keeps it. Workspace
# evidence (dirty fingerprint + HEAD sha) is captured up front; phase
# attribution derives from it at report time, never from a caller tag.
$gateOutcome = 'error'

$headSha = $null
try {
    $headSha = & git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $headSha = $null }
} catch {
    $headSha = $null
}

$dirtyCounts = Get-DirtyFileCounts -AppDir $config.AppDir -TestDirs @($config.TestApps)

# Repo-wide compiler channel: the highest app.json runtime across all apps picks
# stable vs prerelease once, so every app compiles on the same compiler.
$requiredRuntimeMajor = Get-RequiredRuntimeMajor -Config $config

try {

Write-BuildHeader 'Test: Build & Test Gate'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"

# Step 1: Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError) -RequiredRuntimeMajor $requiredRuntimeMajor
Stop-Step 'build'

# Step 2: Provision main app as local symbol and build each secondary target.
# Get-CompileTargets resolves the post-main compile set (every test app, then
# every container-test app not already listed) — compilation runs the
# analyzer gate (alc /analyzer:) on the host for all of them, but only the
# test apps run through al-runner below.
foreach ($target in (Get-CompileTargets -Config $config)) {
    $dirName = Split-Path $target.AppDir -Leaf
    Start-Step "provision-symbols-$dirName"
    Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $target.AppDir
    Stop-Step "provision-symbols-$dirName"

    Start-Step "build-$($target.Role)-$dirName"
    Invoke-ALBuild -AppDir $target.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError) -RequiredRuntimeMajor $requiredRuntimeMajor
    Stop-Step "build-$($target.Role)-$dirName"
}

# Step 3: One al-runner run over the main app plus every test app. Dependencies
# are self-contained (design decision 3): the manager stages every
# non-Microsoft, non-bundle dependency from the checkout symbol cache into
# .output/al-runner-deps before starting the server and passes that dir as
# --package-cache; Microsoft platform and test libraries come from al-runner's
# own artifact cache; every bundle here compiles from source. .alpackages is
# never read.
$bundles = @($config.AppDir) + @($config.TestApps)
$appNames = (@($config.TestApps | ForEach-Object { Split-Path $_ -Leaf })) -join ', '
$resultFile = Join-Path $baseResultsPath 'al-runner.xml'

Start-Step 'al-runner'
$serverSummaryPath = Join-Path $baseResultsPath 'al-runner-summary.json'
$serverLogHint = 'see .output/logs/al-runner-server-manager.log and .output/logs/al-runner-server.log'
try {
    $serverResult = Request-ALRunnerServerRun -RepoRoot $repoRoot -SourcePaths $bundles `
        -Coverage:$coverageEnabled -PerTestCoverage:$coverageEnabled -SummaryPath $serverSummaryPath
} catch {
    throw "al-runner server run failed: $($_.Exception.Message) ($serverLogHint)"
}

if ($null -eq $serverResult) {
    $failureMessage = "al-runner server unavailable ($serverLogHint)"
    $script:LastErrorMessage = $failureMessage
    if ($coverageEnabled) { $coverageFailureMessage = $failureMessage }
    Write-BuildMessage -Type Error -Message $failureMessage
    return
}

Write-ALRunnerJUnit -Tests $serverResult.Tests -Path $resultFile
$skippedCount = @($serverResult.Tests | Where-Object { $_.Status -eq 'skipped' }).Count
$codeunitCount = @($serverResult.Tests | ForEach-Object { ($_.Name -split '\.')[0] } | Select-Object -Unique).Count
$counts = [ordered]@{
    testCodeunits = $codeunitCount
    tests         = $serverResult.Total
    testsPassed   = $serverResult.PassedCount
    testsFailed   = ($serverResult.Failed + $serverResult.Errors)
    testsSkipped  = $skippedCount
}

if ($coverageEnabled) {
    Start-Step 'coverage'
    $coverageArtifacts = Write-ALRunnerCoverageArtifacts -SummaryFile $serverSummaryPath -RepoRoot $repoRoot `
        -MainAppPath $config.AppDir -TestApps $config.TestApps -OutputDirectory (Join-Path $baseResultsPath 'coverage')
    $coverageComplete = $true
    $coverageLineRate = $coverageArtifacts.LineRate
    $coverageLinesValid = $coverageArtifacts.LinesValid
    $coverageLinesCovered = $coverageArtifacts.LinesCovered
    $coveragePerTestJsonlRelPath = ConvertTo-RepoRelativePath -RepoRoot $repoRoot -Path $coverageArtifacts.PerTestPath
    $coverageCoberturaRelPath = ConvertTo-RepoRelativePath -RepoRoot $repoRoot -Path $coverageArtifacts.CoberturaPath
    Stop-Step 'coverage'
}

$runResult = [pscustomobject]@{
    Runner     = 'al-runner'
    AppName    = $appNames
    TestDir    = $baseResultsPath
    Passed     = $serverResult.Passed
    Counts     = $counts
    ResultFile = $resultFile
    Filter     = $null
    Notices    = @()
    RawTests   = $serverResult.Tests
}
$testResults += $runResult
Stop-Step 'al-runner'
Write-Host (ConvertTo-RunRecord $runResult | ConvertTo-Json -Compress -Depth 4)

# Final pass/fail determination — summary.json is written by the finally
# block below regardless of outcome.
$failedRuns = @($testResults | Where-Object { -not $_.Passed })

if ($failedRuns) {
    Write-BuildHeader 'Test FAILED'
    Show-RunnerTotals $testResults
    foreach ($failedRun in $failedRuns) {
        Write-ALRunnerFailureSample -ResultFile $failedRun.ResultFile -Tests $failedRun.RawTests
    }
    $gateOutcome = 'failed'
    return
}

Write-BuildHeader 'Test Complete'
Show-RunnerTotals $testResults
Write-BuildMessage -Type Success -Message "All tests passed with zero warnings and zero errors"
$gateOutcome = 'passed'
$script:GateExitCode = 0

} catch {
    # Preserve the original diagnostics and nonzero exit; capture where we
    # were so the finally block below can attribute the failure.
    $script:LastErrorMessage = $_.Exception.Message
    throw
} finally {
    # One timing entry per gate, on every exit path: pass, fail, and throw.
    # PowerShell runs finally on `exit`, so the al-runner fail-fast path and
    # compile throws land here too.
    if ($script:BuildStartTime.IsRunning) { $script:BuildStartTime.Stop() }
    $finalTotalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

    $finalSteps = @{}
    foreach ($name in $script:StepTimings.Keys) {
        $finalSteps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
    }

    # Executed-test totals per runner (omitted when counts are unavailable)
    $testsByRunner = @{}
    $runnerTotals = Get-RunnerTotals $testResults
    foreach ($runnerName in @($runnerTotals.Keys)) {
        if ($runnerTotals[$runnerName]) {
            $testsByRunner[$runnerName] = $runnerTotals[$runnerName].tests
        }
    }

    # Build the coverage summary block. Disabled runs carry nothing beyond
    # the flag; enabled runs report either the complete artifact set or the
    # failure that stopped short of it.
    if (-not $coverageEnabled) {
        $coverageBlock = [ordered]@{
            enabled = $false
        }
    } elseif ($coverageComplete) {
        $coverageBlock = [ordered]@{
            schemaVersion    = 1
            enabled          = $true
            status           = 'complete'
            complete         = $true
            lineRate         = $coverageLineRate
            linesValid       = $coverageLinesValid
            linesCovered     = $coverageLinesCovered
            perTestJsonlPath = $coveragePerTestJsonlRelPath
            coberturaXmlPath = $coverageCoberturaRelPath
        }
    } else {
        $stage = $script:CurrentStage
        $message = if ($coverageFailureMessage) { $coverageFailureMessage }
            elseif ($script:LastErrorMessage) { $script:LastErrorMessage }
            else { 'Coverage did not complete.' }
        $coverageBlock = [ordered]@{
            schemaVersion = 1
            enabled       = $true
            status        = 'failed'
            complete      = $false
            failure       = [ordered]@{ stage = $stage; message = $message }
        }
    }

    # Agent-useful top-level error context — only present when the gate
    # never reached an explicit passed/failed verdict (an unhandled throw).
    $errorBlock = $null
    if ($gateOutcome -eq 'error') {
        $errorBlock = [ordered]@{
            stage   = $script:CurrentStage
            message = if ($script:LastErrorMessage) { $script:LastErrorMessage } else { 'Gate did not complete.' }
        }
    }

    $summaryPath = Join-Path $baseResultsPath 'summary.json'
    Write-TestSummary -Gate 'al-runner' -Results $testResults -CoverageBlock $coverageBlock `
        -ErrorBlock $errorBlock -Path $summaryPath
    Write-BuildMessage -Type Info -Message "Summary written: $summaryPath"

    $saveArgs = @{
        Task         = 'test'
        Steps        = $finalSteps
        TotalSeconds = $finalTotalSeconds
        Gate         = 'al-runner'
        Outcome      = $gateOutcome
        Tests        = $testsByRunner
    }
    if ($dirtyCounts) { $saveArgs.Dirty = $dirtyCounts }
    if ($headSha) { $saveArgs.HeadSha = $headSha }
    Save-BuildTimingEntry @saveArgs
    Show-BuildTimingHistory -Count 5
}
}

if (-not $isDotSourced) {
    # Invoked bare — never as `exit ( ... )`, which would capture the gate's
    # whole success stream and swallow every native command's stdout (compiler
    # diagnostics above all). The verdict travels via $script:GateExitCode.
    Invoke-TestGate -Coverage:$Coverage
    exit $script:GateExitCode
}
