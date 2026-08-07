#Requires -Version 7.2

<#
.SYNOPSIS
    Build, publish, and run AL tests for all configured test apps.

.DESCRIPTION
    The canonical build-test gate. Performs the full workflow:
    1. Build main app
    2. For each test app: provision symbols, build (analyzer gate, host alc)
    3. If unitTestApp configured: build it (analyzer gate), then run AL Runner
       unit tests (fast, no container)
    4. Publish and run container tests for each test app
    5. Write per-run results to .output/TestResults/<dirName>/
       (al-runner.xml for AL Runner, last.xml for container)
    6. Write summary to .output/TestResults/summary.json
       (gate, per-runner totals, one record per run with test counts)

    If -UnitTestOnly is specified and unitTestApp is configured, compile every app
    (the analyzer gate runs over the whole solution) and run AL Runner unit tests.
    Skips container publish and container tests entirely.

    If -AllTests is specified, run the full gate: AL Runner unit tests when
    configured, then container publish and container tests.

    Coverage can be enabled by configuration, ALBT_COVERAGE_ENABLED, or -Coverage.
    It is mandatory for configured container test apps and skipped when testApps
    is empty.

.PARAMETER Force
    Force republish even if apps are unchanged.

.PARAMETER UnitTestOnly
    Compile every app through the analyzer gate, then run AL Runner unit tests.
    Skips container publish and container tests. Requires unitTestApp configured.

.PARAMETER Coverage
    Collect complete per-test raw coverage for every configured container test app.
    Ignored when testApps is empty. Cannot be combined with -UnitTestOnly.

.EXAMPLE
    pwsh -File test.ps1 -AllTests
    # Run all tests (unit + container)

.EXAMPLE
    pwsh -File test.ps1 -UnitTestOnly
    # Inner loop: compile all apps (analyzer gate) + AL Runner unit tests, no container

.EXAMPLE
    pwsh -File test.ps1 -AllTests -Force
    # Force republish and run all tests

.EXAMPLE
    pwsh -File test.ps1 -AllTests -Coverage
    # Run container tests and retain complete per-test raw coverage
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$UnitTestOnly,
    [switch]$AllTests,
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

function Test-TestModeSelection {
    param(
        [switch]$Force,
        [switch]$UnitTestOnly,
        [switch]$AllTests,
        [switch]$Coverage
    )

    -not (($UnitTestOnly -eq $AllTests) -or ($UnitTestOnly -and ($Force -or $Coverage)))
}

function Write-TestModeUsage {
    $message = @'
Specify exactly one test mode:
-UnitTestOnly: run AL Runner unit tests without a container.
-AllTests: run AL Runner when configured, then container tests.
'@

    if (Get-Command Write-BuildMessage -ErrorAction SilentlyContinue) {
        Write-BuildMessage -Type Error -Message $message
        return
    }

    [Console]::Error.WriteLine($message)
}

$isDotSourced = $MyInvocation.InvocationName -eq '.'
if (-not $isDotSourced -and -not (Test-TestModeSelection -Force:$Force -UnitTestOnly:$UnitTestOnly -AllTests:$AllTests -Coverage:$Coverage)) {
    Write-TestModeUsage
    exit 1
}

# Import modules
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'coverage-runtime.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking

function Invoke-TestGate {
    param(
        [switch]$Force,
        [switch]$UnitTestOnly,
        [switch]$AllTests,
        [switch]$Coverage
    )

    # Verdict channel. The gate's success stream carries live payload (native
    # command stdout — compiler diagnostics above all), so the exit code never
    # rides it: every verdict sets $script:GateExitCode and returns nothing.
    $script:GateExitCode = 1

    if (-not (Test-TestModeSelection -Force:$Force -UnitTestOnly:$UnitTestOnly -AllTests:$AllTests -Coverage:$Coverage)) {
        Write-TestModeUsage
        return
    }

# ---------------------------------------------------------------------------
# Startup cleanup — runs for every invocation (disabled, -UnitTestOnly, full,
# compile-only, and even a run that goes on to fail on a malformed config)
# and always precedes configuration loading, so a run never inherits stale
# JUnit or coverage artifacts left behind by a previous run.
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

function ConvertTo-RunRecord {
    param($Result)
    [ordered]@{
        runner        = $Result.Runner
        appName       = $Result.AppName
        dir           = (Split-Path $Result.TestDir -Leaf)
        passed        = $Result.Passed
        counts        = $Result.Counts
        resultFile    = $Result.ResultFile
    }
}

function Get-RunnerTotals {
    # Totals are aggregated per runner, never across runners: the unit test app
    # runs through both al-runner and the container, so a grand total would
    # count the same tests twice.
    param($Results)
    $totals = [ordered]@{}
    foreach ($runner in @($Results | ForEach-Object { $_.Runner } | Select-Object -Unique)) {
        $runnerResults = @($Results | Where-Object { $_.Runner -eq $runner })
        $counted = @($runnerResults | Where-Object { $_.Counts })
        if ($counted.Count -eq 0) {
            # Counts unknown for every run of this runner — null, never zeros
            $totals[$runner] = $null
            continue
        }
        $totals[$runner] = [ordered]@{
            runs          = $runnerResults.Count
            testCodeunits = [int](($counted | ForEach-Object { $_.Counts.testCodeunits } | Measure-Object -Sum).Sum)
            tests         = [int](($counted | ForEach-Object { $_.Counts.tests } | Measure-Object -Sum).Sum)
            testsPassed   = [int](($counted | ForEach-Object { $_.Counts.testsPassed } | Measure-Object -Sum).Sum)
            testsFailed   = [int](($counted | ForEach-Object { $_.Counts.testsFailed } | Measure-Object -Sum).Sum)
            testsSkipped  = [int](($counted | ForEach-Object { $_.Counts.testsSkipped } | Measure-Object -Sum).Sum)
        }
    }
    return $totals
}

function ConvertTo-RepoRelativePath {
    <#
    .SYNOPSIS
        Format a path repo-relative with forward slashes for summary.json.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Path
    )
    $resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    ([System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedPath)) -replace '\\', '/'
}

function Write-TestSummary {
    param(
        [string]$Gate,
        $Results,
        [Parameter(Mandatory)]
        $CoverageBlock,
        $ErrorBlock,
        [string]$Path
    )
    $summary = [ordered]@{
        gate     = $Gate
        totals   = Get-RunnerTotals $Results
        runs     = @($Results | ForEach-Object { ConvertTo-RunRecord $_ })
        coverage = $CoverageBlock
    }
    if ($ErrorBlock) { $summary.error = $ErrorBlock }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Force
}

function Show-RunnerTotals {
    param($Results)
    $totals = Get-RunnerTotals $Results
    foreach ($runner in $totals.Keys) {
        $t = $totals[$runner]
        if ($null -eq $t) {
            Write-BuildMessage -Type Warning -Message "${runner}: test counts unavailable (no parseable result XML)"
            continue
        }
        $runWord = if ($t.runs -eq 1) { 'run' } else { 'runs' }
        Write-BuildMessage -Type Info -Message "${runner}: $($t.runs) $runWord - $($t.tests) tests in $($t.testCodeunits) test codeunits - $($t.testsPassed) passed, $($t.testsFailed) failed, $($t.testsSkipped) skipped"
    }
}

# Load configuration — malformed config throws here, outside the gate's
# try/finally, so no summary.json is written (startup cleanup already left
# an empty TestResults tree).
$configOverrides = @{}
if ($Coverage) {
    $configOverrides.coverageEnabled = $true
} elseif ($UnitTestOnly) {
    $configOverrides.coverageEnabled = $false
}
$config = Get-BuildConfig -Overrides $configOverrides
Set-BuildEnvironment -Config $config
$coverageEnabled = Resolve-CoverageEnabled -Config $config -Coverage:$Coverage -UnitTestOnly:$UnitTestOnly

$testResults = @()
$coverageContract = $null
$coverageStagingRoot = $null

# Coverage lifecycle tracking — read only in the finally block below to
# build summary.json's coverage object. Coverage-disabled runs never touch
# any of these beyond their initial values.
$coverageContainerTestEntered = $false
$coverageContainerTestCompleted = $false
$coverageComplete = $false
$coverageFailureMessage = $null
$coveragePerTestJsonlRelPath = $null
$coverageCoberturaRelPath = $null
$coverageLineRate = $null
$coverageLinesValid = $null
$coverageLinesCovered = $null
$coverageCleanupFailureMessage = $null

# Gate metrics: outcome defaults to 'error' and is only upgraded at the
# verdict points below — any throw (compile, publish, container) keeps it.
# Workspace evidence (dirty fingerprint + HEAD sha) is captured up front;
# phase attribution derives from it at report time, never from a caller tag.
$gateName = if ($UnitTestOnly) { 'unit' } else { 'full' }
$gateOutcome = 'error'

$headSha = $null
try {
    $headSha = & git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $headSha = $null }
} catch {
    $headSha = $null
}

$dirtyDirs = @($config.TestApps)
if ($config.UnitTestApp) { $dirtyDirs += $config.UnitTestApp }
$dirtyCounts = Get-DirtyFileCounts -AppDir $config.AppDir -TestDirs $dirtyDirs

# Repo-wide compiler channel: the highest app.json runtime across all apps picks
# stable vs prerelease once, so every app compiles on the same compiler.
$requiredRuntimeMajor = Get-RequiredRuntimeMajor -Config $config

try {

# Validate -UnitTestOnly requires unitTestApp and the configured unitTestApp
# path after valid config resolution, so every exit from here on leaves a
# current summary.json.
Start-Step 'validate-config'
if ($UnitTestOnly -and -not $config.UnitTestApp) {
    Write-BuildMessage -Type Error -Message "unitTestApp not configured in al-build.json. Cannot run -UnitTestOnly."
    return
}

if ($config.UnitTestApp -and -not (Test-Path $config.UnitTestApp)) {
    Write-BuildMessage -Type Error -Message "unitTestApp directory not found: $($config.UnitTestApp)"
    return
}
Stop-Step 'validate-config'

$modeName = if ($UnitTestOnly) { 'Unit Test Only' } else { 'Build & Test Gate' }
Write-BuildHeader "Test: $modeName"

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"
if ($config.UnitTestApp) {
    Write-BuildMessage -Type Detail -Message "Unit Test App: $($config.UnitTestApp)"
}
if (-not $UnitTestOnly) {
    Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"
}

# Step 1: Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError) -RequiredRuntimeMajor $requiredRuntimeMajor
Stop-Step 'build'

# If no test apps and not unit-test-only, compile only and exit
if ($config.TestApps.Count -eq 0 -and -not $UnitTestOnly) {
    if (-not $config.UnitTestApp) {
        Write-BuildMessage -Type Warning -Message "No test apps configured. Skipping publish and tests."
        Write-BuildHeader 'Build Complete (no tests)'
        $gateOutcome = 'passed'
        $script:GateExitCode = 0
        return
    }
}

# Step 2: Provision main app as local symbol and build each secondary target.
# Get-CompileTargets resolves the post-main compile set (test apps, then the
# unit-test app) — identical in every mode. Compilation runs the analyzer gate
# (alc /analyzer:) on the host; -UnitTestOnly skips the container publish/run,
# not the compile. The unit-test app is here so its code goes through the
# analyzer gate (AL Runner's internal compile in Step 3 carries no /analyzer:).
foreach ($target in (Get-CompileTargets -Config $config -UnitTestOnly:$UnitTestOnly)) {
    $dirName = Split-Path $target.AppDir -Leaf
    Start-Step "provision-symbols-$dirName"
    Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $target.AppDir
    Stop-Step "provision-symbols-$dirName"

    Start-Step "build-$($target.Role)-$dirName"
    Invoke-ALBuild -AppDir $target.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError) -RequiredRuntimeMajor $requiredRuntimeMajor
    Stop-Step "build-$($target.Role)-$dirName"
}

# Enabled coverage infrastructure is mandatory and is proven before any test
# execution or consumer-app publication mutates the container.
if ($coverageEnabled) {
    Start-Step 'ensure-container'
    Ensure-BCAgentContainer -ContainerName $config.ContainerName
    Stop-Step 'ensure-container'

    Start-Step 'coverage-preflight'
    $coverageContract = Get-CoverageHelperContract
    $coverageCredential = Get-BCCredential -Username $config.ContainerUsername -Password $config.ContainerPassword
    Test-BcCoveragePreflight -ContainerName $config.ContainerName -Tenant $config.Tenant `
        -Credential $coverageCredential -Contract $coverageContract
    $coverageStagingRoot = New-CoverageGateStaging -BaseResultsPath $baseResultsPath
    Stop-Step 'coverage-preflight'
}

# Step 3: AL Runner unit tests (fast gate, before container)
if ($config.UnitTestApp) {
    $unitDirName = Split-Path $config.UnitTestApp -Leaf
    $unitOutputDir = Join-Path $baseResultsPath $unitDirName

    Start-Step 'al-runner'
    $unitResult = Invoke-ALRunnerTest -AppDir $config.AppDir -TestDir $config.UnitTestApp -OutputDir $unitOutputDir -InitEvents:($config.UnitTestInitEvents)
    Stop-Step 'al-runner'

    # The al-runner run is a first-class record in summary.json in every mode
    $testResults += $unitResult
    Write-Host (ConvertTo-RunRecord $unitResult | ConvertTo-Json -Compress -Depth 4)

    if (-not $unitResult.Passed) {
        # Unit tests failed — fail fast; the finally block writes summary.json
        if ($coverageEnabled) {
            $coverageFailureMessage = "Unit tests failed: $($unitResult.AppName)"
        }
        Write-BuildHeader 'Test FAILED (AL Runner)'
        Show-RunnerTotals $testResults
        Write-BuildMessage -Type Error -Message "Unit tests failed: $($unitResult.AppName)"
        Write-BuildMessage -Type Error -Message "Results: $($unitResult.ResultFile)"
        $gateOutcome = 'failed'
        return
    }

    if ($UnitTestOnly) {
        # Unit tests passed — exit; the finally block writes summary.json
        Write-BuildHeader 'Unit Test Complete'
        Show-RunnerTotals $testResults
        Write-BuildMessage -Type Success -Message "All unit tests passed"
        $gateOutcome = 'passed'
        $script:GateExitCode = 0
        return
    }

    Write-BuildMessage -Type Success -Message "AL Runner gate passed — proceeding to container tests"
}

# Step 4: Disabled full gates still need the agent container before publication.
if (-not $coverageEnabled) {
    Start-Step 'ensure-container'
    Ensure-BCAgentContainer -ContainerName $config.ContainerName
    Stop-Step 'ensure-container'
}

# Step 5: Check if main app needs publish
$appJson = Get-AppJsonObject $config.AppDir
$mainAppNeedsPublish = Test-AppNeedsPublish -AppDir $config.AppDir -AppJson $appJson -ContainerName $config.ContainerName -Force:$Force

# Step 6: Unpublish all test apps if main app changed
if ($mainAppNeedsPublish) {
    Start-Step 'unpublish-test-apps'
    foreach ($testAppDir in @($config.TestApps | Sort-Object -Descending)) {
        $testAppJson = Get-AppJsonObject $testAppDir
        if ($testAppJson) {
            Invoke-ALUnpublish -AppName $testAppJson.name
        }
    }
    Stop-Step 'unpublish-test-apps'
}

# Step 7: Publish main app
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
Stop-Step 'publish'

# Step 8: Publish every test app, wait for the sync to settle, then run tests.
# A dev-endpoint ForceSync publish returns before the server-side schema sync
# commits; opening a test session against settling metadata — or publishing
# under an already-open session — invalidates the session's page metadata
# ("Sorry, we just updated this page") and truncates the run, which can surface
# as a partial pass. Publishing all apps before any test session opens, and
# waiting for SyncState to reach Synced, removes that race without a service-tier
# restart (the container stays warm).

# Step 8a: Publish all test apps
foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf
    Start-Step "publish-test-$dirName"
    $testForcePublish = $Force -or $mainAppNeedsPublish
    Invoke-ALPublish -AppDir $testAppDir -Force:$testForcePublish
    Stop-Step "publish-test-$dirName"
}

# Step 8b: Sync-completion barrier — wait until the main app and every test app
# report Synced before the first test session opens.
Start-Step 'wait-apps-synced'
$publishedAppNames = @()
$mainAppJsonForSync = Get-AppJsonObject $config.AppDir
if ($mainAppJsonForSync) { $publishedAppNames += $mainAppJsonForSync.name }
foreach ($testAppDir in $config.TestApps) {
    $testAppJsonForSync = Get-AppJsonObject $testAppDir
    if ($testAppJsonForSync) { $publishedAppNames += $testAppJsonForSync.name }
}
Wait-BCAppsSynced -ContainerName $config.ContainerName -AppNames $publishedAppNames -Tenant $config.Tenant
Stop-Step 'wait-apps-synced'

# Step 8c: Run tests for each test app, now against committed metadata
if ($coverageEnabled) { $coverageContainerTestEntered = $true }
foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf
    Start-Step "test-$dirName"
    $outputDir = Join-Path $baseResultsPath $dirName
    $result = Invoke-ALTest -TestDir $testAppDir -OutputDir $outputDir -Coverage:$coverageEnabled `
        -CoverageStagingRoot $coverageStagingRoot -CoverageContract $coverageContract
    $testResults += $result
    Stop-Step "test-$dirName"

    # Emit JSONL run record
    Write-Host (ConvertTo-RunRecord $result | ConvertTo-Json -Compress -Depth 4)
}
if ($coverageEnabled) { $coverageContainerTestCompleted = $true }

if ($coverageEnabled) {
    Start-Step 'coverage-collection'
    $coverageApps = @($config.TestApps | ForEach-Object { Split-Path $_ -Leaf })
    $publishedCoveragePath = Publish-CoverageGateStaging -StagePath $coverageStagingRoot `
        -BaseResultsPath $baseResultsPath -ExpectedTestApps $coverageApps
    Stop-Step 'coverage-collection'

    Start-Step 'coverage-aggregation'
    # Combines every configured test app's published raw coverage into one
    # deterministic per-test JSONL and Cobertura XML pair. The two artifacts
    # are written together only after every app's coverage universe resolves
    # and cross-checks clean, so a thrown error here (an app's collection
    # folder is missing, or its universe conflicts with another app's) leaves
    # neither artifact behind. The finally block removes every incomplete raw,
    # temporary, or final coverage artifact while preserving test results.
    Import-Module (Join-Path $PSScriptRoot 'coverage-normalizer.psm1') -Force -DisableNameChecking
    $coverageOutputDirectory = Join-Path $baseResultsPath 'coverage'
    $coverageArtifacts = Write-BcCoverageArtifacts -RepoRoot $repoRoot -MainAppPath $config.AppDir `
        -TestAppPaths $config.TestApps -RawCollectionPath $publishedCoveragePath `
        -OutputDirectory $coverageOutputDirectory
    Stop-Step 'coverage-aggregation'

    Start-Step 'coverage-publication'
    $coverageLineRate = $coverageArtifacts.LineRate
    $coverageLinesValid = $coverageArtifacts.LinesValid
    $coverageLinesCovered = $coverageArtifacts.LinesCovered
    $coveragePerTestJsonlRelPath = ConvertTo-RepoRelativePath -RepoRoot $repoRoot -Path $coverageArtifacts.PerTestPath
    $coverageCoberturaRelPath = ConvertTo-RepoRelativePath -RepoRoot $repoRoot -Path $coverageArtifacts.CoberturaPath
    # Success: the published raw per-test payloads are no longer needed once
    # the aggregate JSONL/Cobertura exist — the final coverage directory
    # keeps only per-test.jsonl and cobertura.xml.
    if (Test-Path -LiteralPath $publishedCoveragePath) {
        Remove-Item -LiteralPath $publishedCoveragePath -Recurse -Force -Confirm:$false
    }
    $coverageComplete = $true
    Stop-Step 'coverage-publication'
}

# Final pass/fail determination — summary.json is written by the finally
# block below regardless of outcome.
$failedRuns = $testResults | Where-Object { -not $_.Passed }

if ($failedRuns) {
    Write-BuildHeader 'Test FAILED'
    Show-RunnerTotals $testResults
    Write-BuildMessage -Type Error -Message "Failed test runs:"
    foreach ($failed in $failedRuns) {
        Write-BuildMessage -Type Error -Message "  - $($failed.Runner) - $($failed.AppName): $($failed.ResultFile)"
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
    if ($coverageEnabled -and -not $coverageComplete) {
        $coverageRoot = Join-Path $baseResultsPath 'coverage'
        if (Test-Path -LiteralPath $coverageRoot) {
            try {
                Remove-Item -LiteralPath $coverageRoot -Recurse -Force -Confirm:$false
            } catch {
                $coverageCleanupFailureMessage =
                    "Failed to remove incomplete coverage artifacts from '$coverageRoot': $($_.Exception.Message)"
                try {
                    Write-BuildMessage -Type Warning -Message $coverageCleanupFailureMessage
                } catch {
                    # Summary and the active primary failure remain authoritative.
                }
            }
        }
    }

    # One timing entry per gate, on every exit path: pass, fail, and throw.
    # PowerShell runs finally on `exit`, so the AL Runner fail-fast path and
    # compile/publish throws land here too.
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

    # Build the coverage summary block — always present, schemaVersion 1.
    if (-not $coverageEnabled) {
        $coverageBlock = [ordered]@{
            schemaVersion = 1
            enabled       = $false
            status        = 'disabled'
            complete      = $false
        }
    } elseif ($coverageComplete) {
        $coverageBlock = [ordered]@{
            schemaVersion    = 1
            enabled          = $true
            status           = 'complete'
            complete         = $true
            trackingMode     = 'PerTest'
            lineRate         = $coverageLineRate
            linesValid       = $coverageLinesValid
            linesCovered     = $coverageLinesCovered
            perTestJsonlPath = $coveragePerTestJsonlRelPath
            coberturaXmlPath = $coverageCoberturaRelPath
        }
    } elseif ($coverageContainerTestEntered -and -not $coverageContainerTestCompleted) {
        # The selected container test run started but did not finish.
        $stage = $script:CurrentStage
        $message = if ($coverageFailureMessage) { $coverageFailureMessage }
            elseif ($script:LastErrorMessage) { $script:LastErrorMessage }
            else { 'Container coverage run did not complete.' }
        if ($coverageCleanupFailureMessage) {
            $message = "$message Cleanup failure: $coverageCleanupFailureMessage"
        }
        $coverageBlock = [ordered]@{
            schemaVersion = 1
            enabled       = $true
            status        = 'aborted'
            complete      = $false
            failure       = [ordered]@{ stage = $stage; message = $message }
        }
    } elseif (-not $coverageContainerTestEntered) {
        # Stopped before container coverage execution ever started.
        $stage = $script:CurrentStage
        $message = if ($coverageFailureMessage) { $coverageFailureMessage }
            elseif ($script:LastErrorMessage) { $script:LastErrorMessage }
            else { "Gate stopped before container coverage execution (stage: $stage)." }
        if ($coverageCleanupFailureMessage) {
            $message = "$message Cleanup failure: $coverageCleanupFailureMessage"
        }
        $coverageBlock = [ordered]@{
            schemaVersion = 1
            enabled       = $true
            status        = 'not-run'
            complete      = $false
            failure       = [ordered]@{ stage = $stage; message = $message }
        }
    } else {
        # Container run completed, but collection, aggregation, or
        # publication did not — includes a completed red test run.
        $stage = $script:CurrentStage
        $message = if ($coverageFailureMessage) { $coverageFailureMessage }
            elseif ($script:LastErrorMessage) { $script:LastErrorMessage }
            else { 'Coverage collection, aggregation, or publication failed.' }
        if ($coverageCleanupFailureMessage) {
            $message = "$message Cleanup failure: $coverageCleanupFailureMessage"
        }
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
    Write-TestSummary -Gate $gateName -Results $testResults -CoverageBlock $coverageBlock `
        -ErrorBlock $errorBlock -Path $summaryPath
    Write-BuildMessage -Type Info -Message "Summary written: $summaryPath"

    $timingTask = if ($UnitTestOnly) { 'unit-test' } else { 'test' }
    $saveArgs = @{
        Task         = $timingTask
        Steps        = $finalSteps
        TotalSeconds = $finalTotalSeconds
        Gate         = $gateName
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
    Invoke-TestGate -Force:$Force -UnitTestOnly:$UnitTestOnly -AllTests:$AllTests -Coverage:$Coverage
    exit $script:GateExitCode
}
