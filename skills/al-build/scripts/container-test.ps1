#Requires -Version 7.2

<#
.SYNOPSIS
    Publish and run the configured container test apps against the AL agent
    container.

.DESCRIPTION
    The explicit-only container test surface. This script never compiles —
    every configured containerTestApps entry and the main app must already
    carry a compiled .app (run the gate, test.ps1, first). Performs:
    1. Validate containerTestApps is configured, before any BcContainerHelper
       import.
    2. Validate the main app and every containerTestApps entry has a
       compiled .app in its output folder.
    3. Ensure the agent container, decide whether the main app needs
       republishing, unpublish container test apps (dependency-reversed)
       when the main app republishes, publish the main app, publish every
       container test app, wait for every published app to sync, then run
       each container test app.
    4. Write per-app results to .output/TestResults/<dirName>/last.xml and
       the run to .output/TestResults/summary.json (gate: "container").

.PARAMETER Force
    Force republish every app even when unchanged.

.EXAMPLE
    pwsh -File container-test.ps1
    # Publish (as needed) and test every configured container test app.

.EXAMPLE
    pwsh -File container-test.ps1 -Force
    # Force republish every app, then test.
#>

[CmdletBinding()]
param(
    [switch]$Force
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

function Invoke-ContainerTestGate {
    param(
        [switch]$Force
    )

    # Verdict channel. The gate's success stream carries live payload (native
    # command stdout), so the exit code never rides it: every verdict sets
    # $script:GateExitCode and returns nothing.
    $script:GateExitCode = 1

    $repoRoot = Get-GitRepoRoot
    $baseResultsPath = Join-Path $repoRoot '.output' 'TestResults'
    New-Item -ItemType Directory -Path $baseResultsPath -Force | Out-Null

    # Load configuration — malformed config throws here, outside the gate's
    # try/finally, so no summary.json is written.
    $config = Get-BuildConfig

    $testResults = @()

    # Gate metrics: outcome defaults to 'error' and is only upgraded at the
    # verdict points below — any throw (publish, container, test) keeps it.
    # Workspace evidence (dirty fingerprint + HEAD sha) is captured up front;
    # phase attribution derives from it at report time, never from a
    # caller-supplied tag.
    $gateOutcome = 'error'

    $headSha = $null
    try {
        $headSha = & git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -ne 0) { $headSha = $null }
    } catch {
        $headSha = $null
    }

    $dirtyCounts = Get-DirtyFileCounts -AppDir $config.AppDir -TestDirs @($config.ContainerTestApps)

    try {

    Write-BuildHeader 'Container Test Gate'

    # Step 1: configuration check — must fail before any BcContainerHelper
    # import, so a workspace with no configured container test apps never
    # touches the container.
    Start-Step 'validate-config'
    if (@($config.ContainerTestApps).Count -eq 0) {
        Write-BuildMessage -Type Error -Message "containerTestApps not configured in al-build.json. Add at least one app directory to run container tests."
        $gateOutcome = 'failed'
        return
    }

    # Step 2: artifact check — the main app and every container test app
    # must already carry a compiled .app; this script never compiles.
    $artifactCheckDirs = @($config.AppDir) + @($config.ContainerTestApps)
    foreach ($dir in $artifactCheckDirs) {
        $appFilePath = Get-OutputPath $dir
        $dirName = Split-Path $dir -Leaf
        if (-not $appFilePath -or -not (Test-Path -LiteralPath $appFilePath)) {
            Write-BuildMessage -Type Error -Message "Compiled app not found for '$dirName' ($dir). Run the gate (test.ps1) first."
            $gateOutcome = 'failed'
            return
        }
    }
    Stop-Step 'validate-config'

    Write-BuildMessage -Type Info -Message "Configuration:"
    Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
    Write-BuildMessage -Type Detail -Message "Container Test Apps: $($config.ContainerTestApps -join ', ')"
    Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"

    # Step 3: the agent container must be up before any publish.
    Start-Step 'ensure-container'
    Ensure-BCAgentContainer -ContainerName $config.ContainerName
    Stop-Step 'ensure-container'

    # Step 4: check if the main app needs publish.
    $appJson = Get-AppJsonObject $config.AppDir
    $mainAppNeedsPublish = Test-AppNeedsPublish -AppDir $config.AppDir -AppJson $appJson `
        -ContainerName $config.ContainerName -Force:$Force

    # Step 5: unpublish every container test app (dependency-reversed) when
    # the main app is about to republish, so a stale dependent app is never
    # left installed against a main app it no longer matches.
    if ($mainAppNeedsPublish) {
        Start-Step 'unpublish-container-test-apps'
        foreach ($testAppDir in @($config.ContainerTestApps | Sort-Object -Descending)) {
            $testAppJson = Get-AppJsonObject $testAppDir
            if ($testAppJson) {
                Invoke-ALUnpublish -AppName $testAppJson.name
            }
        }
        Stop-Step 'unpublish-container-test-apps'
    }

    # Step 6: publish the main app.
    Start-Step 'publish'
    Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
    Stop-Step 'publish'

    # Step 7: publish every container test app, then wait for the sync
    # barrier before any test session opens. A dev-endpoint ForceSync publish
    # returns before the server-side schema sync commits; opening a test
    # session against settling metadata invalidates the session's page
    # metadata and truncates the run, which can surface as a partial pass.
    foreach ($testAppDir in $config.ContainerTestApps) {
        $dirName = Split-Path $testAppDir -Leaf
        Start-Step "publish-container-test-$dirName"
        $testForcePublish = $Force -or $mainAppNeedsPublish
        Invoke-ALPublish -AppDir $testAppDir -Force:$testForcePublish
        Stop-Step "publish-container-test-$dirName"
    }

    Start-Step 'wait-apps-synced'
    $publishedAppNames = @()
    if ($appJson) { $publishedAppNames += $appJson.name }
    foreach ($testAppDir in $config.ContainerTestApps) {
        $testAppJsonForSync = Get-AppJsonObject $testAppDir
        if ($testAppJsonForSync) { $publishedAppNames += $testAppJsonForSync.name }
    }
    Wait-BCAppsSynced -ContainerName $config.ContainerName -AppNames $publishedAppNames -Tenant $config.Tenant
    Stop-Step 'wait-apps-synced'

    # Step 8: run tests for each container test app, now against committed
    # metadata. Coverage is disabled: container-test.ps1 never collects it.
    foreach ($testAppDir in $config.ContainerTestApps) {
        $dirName = Split-Path $testAppDir -Leaf
        Start-Step "test-$dirName"
        $outputDir = Join-Path $baseResultsPath $dirName
        $result = Invoke-ALTest -TestDir $testAppDir -OutputDir $outputDir
        Stop-Step "test-$dirName"

        $runRecord = [pscustomobject]@{
            Runner     = $result.Runner
            AppName    = $result.AppName
            TestDir    = $result.TestDir
            Passed     = $result.Passed
            Counts     = $result.Counts
            ResultFile = $result.ResultFile
            Filter     = $null
            Notices    = @()
        }
        $testResults += $runRecord

        # Emit JSONL run record
        Write-Host (ConvertTo-RunRecord $runRecord | ConvertTo-Json -Compress -Depth 4)
    }

    # Final pass/fail determination — summary.json is written by the finally
    # block below regardless of outcome.
    $failedRuns = @($testResults | Where-Object { -not $_.Passed })

    if ($failedRuns) {
        Write-BuildHeader 'Container Test FAILED'
        Show-RunnerTotals $testResults
        foreach ($failedRun in $failedRuns) {
            Write-BuildMessage -Type Error -Message "  - $($failedRun.Runner) - $($failedRun.AppName): $($failedRun.ResultFile)"
        }
        $gateOutcome = 'failed'
        return
    }

    Write-BuildHeader 'Container Test Complete'
    Show-RunnerTotals $testResults
    Write-BuildMessage -Type Success -Message "All container tests passed"
    $gateOutcome = 'passed'
    $script:GateExitCode = 0

    } catch {
        # Preserve the original diagnostics and nonzero exit; capture where
        # we were so the finally block below can attribute the failure.
        $script:LastErrorMessage = $_.Exception.Message
        throw
    } finally {
        # One timing entry per gate, on every exit path: pass, fail, and
        # throw. PowerShell runs finally on `return` and `exit`, so every
        # fail-fast path and every container/publish throw lands here too.
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

        # Coverage is never collected by this gate.
        $coverageBlock = [ordered]@{
            enabled = $false
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
        Write-TestSummary -Gate 'container' -Results $testResults -CoverageBlock $coverageBlock `
            -ErrorBlock $errorBlock -Path $summaryPath
        Write-BuildMessage -Type Info -Message "Summary written: $summaryPath"

        $saveArgs = @{
            Task         = 'container-test'
            Steps        = $finalSteps
            TotalSeconds = $finalTotalSeconds
            Gate         = 'container'
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
    # whole success stream and swallow every native command's stdout. The
    # verdict travels via $script:GateExitCode.
    Invoke-ContainerTestGate -Force:$Force
    exit $script:GateExitCode
}
