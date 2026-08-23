#Requires -Version 7.2

[CmdletBinding()]
param(
    [Parameter(DontShow)]
    [string]$NpxPath = 'C:\Program Files\nodejs\npx.cmd'
)

$ErrorActionPreference = 'Stop'

try {
    Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking `
        -WarningAction SilentlyContinue -InformationAction SilentlyContinue -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking `
        -WarningAction SilentlyContinue -InformationAction SilentlyContinue -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot 'business-central-mcp.psm1') -Force -DisableNameChecking `
        -WarningAction SilentlyContinue -InformationAction SilentlyContinue -ErrorAction Stop

    $repoRoot = Get-GitRepoRoot
    $configPath = Join-Path $repoRoot 'al-build.json'
    try {
        $config = Get-BuildConfig 3>$null 4>$null 5>$null 6>$null
    } catch {
        throw "Could not load al-build configuration at '$configPath'."
    }

    $settings = Get-BusinessCentralMcpSettings -Config $config -RepoRoot $repoRoot
    Set-BusinessCentralMcpEnvironment -Settings $settings

    if (-not (Test-Path -LiteralPath $NpxPath -PathType Leaf)) {
        throw "Company Portal Node launcher not found at '$NpxPath'."
    }

    [Console]::Error.WriteLine(
        "[business-central] Starting $($settings.Package) for container '$($settings.ContainerName)'."
    )
    & $NpxPath '-y' $settings.Package
    if ($LASTEXITCODE -ne 0) {
        throw "$($settings.Package) exited with code $LASTEXITCODE."
    }
} catch {
    [Console]::Error.WriteLine("[business-central] $($_.Exception.Message)")
    exit 1
}
