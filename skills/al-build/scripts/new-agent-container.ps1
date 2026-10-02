#requires -Version 7.2

<#
.SYNOPSIS
    Create a new BC agent container from a snapshot image.

.DESCRIPTION
    Spawns a new container from a committed BC Docker image.
    If AgentName is not provided, uses the current Git branch name (sanitized).

.PARAMETER AgentName
    Name for the agent container. If not provided, uses current git branch.

.PARAMETER ImageName
    Docker image to use. Defaults to container.imageName from al-build.json.

.PARAMETER MemoryLimit
    Memory limit for the container. Defaults to container.memoryLimit from al-build.json (or '8g' if omitted).

.EXAMPLE
    pwsh -File new-agent-container.ps1
    # Uses current branch name

.EXAMPLE
    pwsh -File new-agent-container.ps1 -AgentName my-agent -MemoryLimit 4g
#>

[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$ImageName,
    [string]$MemoryLimit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules (guarded to avoid unloading parent scope exports)
$commonModuleName = (Split-Path -Path "$PSScriptRoot/common.psm1" -LeafBase)
if (-not (Get-Module -Name $commonModuleName)) {
    Import-Module "$PSScriptRoot/common.psm1" -DisableNameChecking
}
$buildOpsModuleName = (Split-Path -Path "$PSScriptRoot/build-operations.psm1" -LeafBase)
if (-not (Get-Module -Name $buildOpsModuleName)) {
    Import-Module "$PSScriptRoot/build-operations.psm1" -DisableNameChecking
}

# Load configuration and apply defaults if parameters not provided
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config
if (-not $ImageName) { $ImageName = $config.ImageName }
if (-not $MemoryLimit) { $MemoryLimit = $config.MemoryLimit }

$Exit = Get-ExitCode

Write-BuildHeader 'New Agent Container'

# Validate Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-BuildMessage -Type Error -Message "docker command not found"
    exit $Exit.MissingTool
}

# Import BcContainerHelper
Import-BCContainerHelper

# Auto-detect agent name from git branch if not provided
$OriginalBranch = $null
if (-not $AgentName) {
    Write-BuildMessage -Type Step -Message "Detecting agent name from git branch..."
    try {
        $OriginalBranch = git rev-parse --abbrev-ref HEAD 2>$null
        $AgentName = Get-BCAgentContainerName
        Write-BuildMessage -Type Success -Message "Agent name: $AgentName"
    } catch {
        Write-BuildMessage -Type Error -Message "Not in a git repository"
        Write-BuildMessage -Type Detail -Message "Provide -AgentName explicitly"
        exit $Exit.Contract
    }
}

# Prune orphaned containers first (skip in CI)
if (-not $env:CI) {
    Write-BuildHeader 'Orphaned Container Cleanup'
    Remove-OrphanedAgentContainers
}

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "Agent Name: $AgentName"
Write-BuildMessage -Type Detail -Message "Image: $ImageName"
Write-BuildMessage -Type Detail -Message "Memory: $MemoryLimit"

Write-BuildHeader 'Image Validation'

# Check if image exists
Write-BuildMessage -Type Step -Message "Checking for image '$ImageName'..."
$imageExists = docker images -q $ImageName 2>$null
if (-not $imageExists) {
    Write-BuildMessage -Type Error -Message "Image '$ImageName' not found"
    Write-BuildMessage -Type Info -Message "Create it by running:"
    Write-BuildMessage -Type Detail -Message "1. pwsh $PSScriptRoot/new-bc-container.ps1"
    Write-BuildMessage -Type Detail -Message "2. docker stop $($config.GoldenContainerName)"
    Write-BuildMessage -Type Detail -Message "3. pwsh $PSScriptRoot/commit-bc-container.ps1"
    exit $Exit.Contract
}
Write-BuildMessage -Type Success -Message "Snapshot image found"

Write-BuildHeader 'Container Lifecycle'

# Remove existing container if present
$existingContainer = docker ps -a --filter "name=^${AgentName}$" --format "{{.Names}}" 2>$null
if ($existingContainer) {
    Write-BuildMessage -Type Warning -Message "Container '$AgentName' already exists; removing..."
    try {
        Remove-BcContainer -containerName $AgentName -ErrorAction Stop | Out-Null
    } catch {
        Write-BuildMessage -Type Warning -Message "Remove-BcContainer failed; using docker rm -f"
        docker rm -f $AgentName 2>$null | Out-Null
    }
    # Remove stale hosts entries (bare and .test)
    try {
        Remove-BCAgentContainerHost -ContainerName $AgentName
    } catch {
        Write-BuildMessage -Type Warning -Message "Could not remove hosts entries"
    }
    Write-BuildMessage -Type Success -Message "Previous container removed"
}

Write-BuildHeader 'Creating Agent Container'

Write-BuildMessage -Type Step -Message "Creating container '$AgentName' from snapshot..."

# Get extensions path for BcContainerHelper
$bcHelperPath = 'C:\ProgramData\BcContainerHelper'
$extensionsPath = Join-Path $bcHelperPath 'Extensions'
$agentExtPath = Join-Path $extensionsPath $AgentName

# Create extensions folder
if (-not (Test-Path $agentExtPath)) {
    New-Item -ItemType Directory -Path $agentExtPath -Force | Out-Null
}

# Create my folder for container scripts
$myPath = Join-Path $agentExtPath 'my'
if (-not (Test-Path $myPath)) {
    New-Item -ItemType Directory -Path $myPath -Force | Out-Null
}

# BC's service tier and web client take minutes to start. During the start period Docker
# reports 'starting' and failed health checks don't count, so the wait below never mistakes
# a cold start for an unhealthy container (#141).
$healthStartPeriod = '10m'

# Run container from snapshot
$runArgs = @(
    'run', '-d',
    '--name', $AgentName,
    '--hostname', $AgentName,
    '--memory', $MemoryLimit,
    '--health-start-period', $healthStartPeriod,
    '--restart', 'unless-stopped',
    '--network', 'nat',
    '--dns', '8.8.8.8',
    '--isolation', 'process',
    '-v', 'c:\windows\system32\drivers\etc:C:\driversetc',
    '-v', 'c:\bcartifacts.cache:c:\dl',
    '-v', "${bcHelperPath}:${bcHelperPath}",
    '-v', "${myPath}:c:\run\my",
    $ImageName
)

docker @runArgs

if ($LASTEXITCODE -ne 0) {
    Write-BuildMessage -Type Error -Message "docker run failed with exit code $LASTEXITCODE"
    exit $Exit.Integration
}

Write-BuildMessage -Type Success -Message "Container started"

Write-BuildHeader 'Container Configuration'

# Wait for container to be healthy with log streaming
Write-BuildMessage -Type Step -Message "Waiting for container to become healthy..."
Write-BuildMessage -Type Info -Message "Streaming container logs while waiting..."

$logJob = Start-Job -ScriptBlock {
    param($containerName)
    docker logs -f $containerName 2>&1
} -ArgumentList $AgentName

$ready = $false
$pollDelaySeconds = 2
$unhealthyCount = 0
$unhealthyThreshold = 15  # 15 consecutive polls × 2s = 30 seconds of 'unhealthy' after the start period
$healthTimeout = [TimeSpan]::FromMinutes(20)  # the whole wait, start period included
$waitClock = [System.Diagnostics.Stopwatch]::StartNew()

try {
    while ($true) {
        # Drain log output
        Receive-Job $logJob -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -ne $null) {
                Write-BuildMessage -Type Info -Message "  $_"
            }
        }

        $running = docker inspect $AgentName --format '{{.State.Running}}' 2>$null
        $health = docker inspect $AgentName --format '{{.State.Health.Status}}' 2>$null

        $decision = Get-BCContainerWaitDecision -Running $running -Health $health `
            -UnhealthyCount $unhealthyCount -UnhealthyThreshold $unhealthyThreshold `
            -Elapsed $waitClock.Elapsed -Timeout $healthTimeout
        $unhealthyCount = $decision.UnhealthyCount

        if ($decision.Action -eq 'Ready') {
            $ready = $true
            break
        }

        if ($decision.Action -in 'Exited', 'Unhealthy', 'TimedOut') {
            $message = switch ($decision.Action) {
                'Exited' {
                    $exitCode = docker inspect $AgentName --format '{{.State.ExitCode}}' 2>$null
                    "Container exited before becoming healthy (exit code $exitCode)"
                }
                'Unhealthy' { "Container health check reported 'unhealthy' ($unhealthyCount consecutive checks)" }
                'TimedOut' { "Container did not become healthy within $($healthTimeout.TotalMinutes) minutes (last health status: '$health')" }
            }
            Write-BuildMessage -Type Error -Message $message

            # Drain remaining logs before exiting
            Start-Sleep -Milliseconds 500
            Receive-Job $logJob -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -ne $null) {
                    Write-BuildMessage -Type Info -Message "  $_"
                }
            }
            exit $Exit.Integration
        }

        if ($health -eq 'unhealthy') {
            Write-BuildMessage -Type Warning -Message "Container health check reported 'unhealthy' (attempt $unhealthyCount of $unhealthyThreshold, waiting...)"
        }

        Start-Sleep -Seconds $pollDelaySeconds
    }
}
finally {
    Stop-Job $logJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $logJob -ErrorAction SilentlyContinue | Out-Null
}

if (-not $ready) {
    Write-BuildMessage -Type Error -Message "Container did not become healthy"
    exit $Exit.Integration
}

Write-BuildMessage -Type Success -Message "Container is healthy"

# Get container IP, write the hosts lines, and put PublicWebBaseUrl on the .test host
Write-BuildMessage -Type Step -Message "Configuring network..."
$containerIP = Get-BCAgentContainerIP -ContainerName $AgentName
try {
    $null = Set-BCAgentContainerHost -ContainerName $AgentName -IPAddress $containerIP
    Write-BuildMessage -Type Success -Message "Hosts entries and PublicWebBaseUrl set"
} catch {
    Write-BuildMessage -Type Error -Message "Could not set the .test host or PublicWebBaseUrl: $_"
    # Registration comes after this step, so prune would never remove the container; the next
    # Ensure-BCAgentContainer would also reuse it with PublicWebBaseUrl off the .test host.
    Write-BuildMessage -Type Warning -Message "Removing container '$AgentName' and its hosts entries"
    try {
        Remove-BcContainer -containerName $AgentName -ErrorAction Stop | Out-Null
    } catch {
        Write-BuildMessage -Type Warning -Message "Remove-BcContainer failed; using docker rm -f"
        docker rm -f $AgentName 2>$null | Out-Null
    }
    try {
        Remove-BCAgentContainerHost -ContainerName $AgentName
    } catch {
        Write-BuildMessage -Type Warning -Message "Could not remove hosts entries: $($_.Exception.Message)"
    }
    exit $Exit.Integration
}

# Register container
$branch = if ($OriginalBranch) { $OriginalBranch } else { $AgentName }
Register-AgentContainer -ContainerName $AgentName -Branch $branch

Write-BuildHeader 'Agent Container Ready'
Write-BuildMessage -Type Success -Message "Container '$AgentName' is ready for use"
Write-BuildMessage -Type Detail -Message "Server URL: http://$AgentName"
