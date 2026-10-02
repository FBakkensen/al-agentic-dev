#requires -Version 7.2

<#
.SYNOPSIS
    Publish all configured AL apps to the current branch's agent container — clean republish.

.DESCRIPTION
    Clean-republish primitive. Unconditionally unpublishes every app present in
    the container (secondary apps → main app, dependency-reversed), then
    force-publishes them in dependency order (main → test apps → container test
    apps) per al-build.json — the same secondary set Get-CompileTargets resolves.

    No build, no tests, no replay — caller is responsible for having compiled
    .app artifacts present. Invoke-ALUnpublish internally skips when an app is
    not installed, so the unconditional unpublish is safe on a fresh container.
    Invoke-ALPublish is called with -Force to bypass Test-AppNeedsPublish's
    source-hash cache (stale after unpublish).

    For publishing to a fresh container before a human walk, or any other
    case that needs a deterministic publish without test or replay side
    effects.

    After the container check it re-asserts the Web Client host: both hosts
    lines at the container's current IP and PublicWebBaseUrl on the .test host.
    A failed re-assert exits non-zero before anything is unpublished. The script
    ends with the commit, the main app's version, the .test Web Client URL, and
    the container username.

.EXAMPLE
    pwsh -File publish-apps.ps1
    # Clean republish of main + test apps to the agent container
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Track timing
$script:BuildStartTime = [Diagnostics.Stopwatch]::StartNew()
$script:StepTimings = @{}

function Start-Step {
    param([string]$Name)
    $script:StepTimings[$Name] = [Diagnostics.Stopwatch]::StartNew()
}

function Stop-Step {
    param([string]$Name)
    if ($script:StepTimings.ContainsKey($Name)) {
        $script:StepTimings[$Name].Stop()
    }
}

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

$Exit = Get-ExitCode

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Publish Apps'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"
Write-BuildMessage -Type Detail -Message "Container Test Apps: $($config.ContainerTestApps -join ', ')"
Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"

$secondaryAppDirs = @(Get-CompileTargets -Config $config | ForEach-Object { $_.AppDir })

# Step 1: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Re-assert the .test host: a container created before it, or an IP changed by a restart
Start-Step 'sync-host'
try {
    $webClientUrl = Sync-BCAgentContainerHost -ContainerName $config.ContainerName
}
catch {
    Write-BuildMessage -Type Error -Message "Could not re-assert the .test host or PublicWebBaseUrl: $_"
    exit $Exit.Integration
}
finally {
    Stop-Step 'sync-host'
}

# Step 2: Unpublish all apps in dependency-reverse order
# Invoke-ALUnpublish internally skips when app is not installed → safe on fresh container.
Start-Step 'unpublish'
foreach ($appDir in @($secondaryAppDirs | Sort-Object -Descending)) {
    $appJson = Get-AppJsonObject $appDir
    if ($appJson) {
        Invoke-ALUnpublish -AppName $appJson.name
    }
}
$mainAppJson = Get-AppJsonObject $config.AppDir
if ($mainAppJson) {
    Invoke-ALUnpublish -AppName $mainAppJson.name
}
Stop-Step 'unpublish'

# Step 3: Publish main app
# -Force bypasses Test-AppNeedsPublish's source-hash cache, which is stale after unpublish.
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force
Stop-Step 'publish'

# Step 4: Publish each secondary app (test apps, then container test apps)
foreach ($appDir in $secondaryAppDirs) {
    $dirName = Split-Path $appDir -Leaf
    Start-Step "publish-test-$dirName"
    Invoke-ALPublish -AppDir $appDir -Force
    Stop-Step "publish-test-$dirName"
}

# Show timing summary
$script:BuildStartTime.Stop()
$totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

$steps = @{}
foreach ($name in $script:StepTimings.Keys) {
    $steps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
}

Save-BuildTimingEntry -Task 'publish-apps' -Steps $steps -TotalSeconds $totalSeconds
Show-BuildTimingHistory -Count 5

Write-BuildHeader 'Publish Complete'
Write-BuildMessage -Type Success -Message "All apps published"

Write-RepublishResult -Config $config -AppJson $mainAppJson -WebClientUrl $webClientUrl
