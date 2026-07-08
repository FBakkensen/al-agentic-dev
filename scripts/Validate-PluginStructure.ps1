#Requires -Version 7.2
<#
.SYNOPSIS
    Validates the Copilot CLI marketplace and per-plugin manifests.
.DESCRIPTION
    Checks that every plugin listed in .github/plugin/marketplace.json has a folder
    under plugins/ with a root plugin.json manifest whose name matches the marketplace
    entry, that all manifests are valid JSON, that agent files use the .agent.md
    extension, and that any hooks config declares "version": 1 (Copilot CLI hook
    format). This marketplace targets GitHub Copilot CLI.
.EXAMPLE
    pwsh scripts/Validate-PluginStructure.ps1
#>
[CmdletBinding()]
param()

$errors = @()

function Get-MarketplacePluginNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        $script:errors += "Missing marketplace manifest: $Path"
        Write-Host "FAIL: marketplace manifest missing at $Path" -ForegroundColor Red
        return @()
    }

    try {
        $marketplace = Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        $script:errors += "Invalid JSON in marketplace manifest: $Path"
        Write-Host "FAIL: marketplace manifest JSON invalid at $Path" -ForegroundColor Red
        return @()
    }

    $pluginNames = @()
    foreach ($plugin in @($marketplace.plugins)) {
        if ($null -ne $plugin.name -and $plugin.name.ToString().Trim().Length -gt 0) {
            $pluginNames += $plugin.name.ToString()
        }
    }

    Write-Host "OK: marketplace manifest loaded with $($pluginNames.Count) plugins" -ForegroundColor Green
    return $pluginNames
}

$repoRoot = Join-Path $PSScriptRoot ".."
$marketplacePath = Join-Path $repoRoot ".github\plugin\marketplace.json"
$pluginsPath = Join-Path $repoRoot "plugins"

$pluginNames = @(Get-MarketplacePluginNames -Path $marketplacePath)

if ($pluginNames.Count -eq 0) {
    Write-Host "WARN: No plugins found in marketplace manifest." -ForegroundColor Yellow
}

foreach ($pluginName in $pluginNames) {
    $pluginPath = Join-Path $pluginsPath $pluginName
    if (-not (Test-Path $pluginPath)) {
        $errors += "Missing plugin folder for marketplace entry: $pluginName"
        Write-Host "FAIL: plugin folder missing for $pluginName" -ForegroundColor Red
        continue
    }

    $pluginJsonPath = Join-Path $pluginPath "plugin.json"
    if (-not (Test-Path $pluginJsonPath)) {
        $errors += "Missing plugin.json in $pluginName"
        Write-Host "FAIL: $pluginName/plugin.json missing" -ForegroundColor Red
        continue
    }

    $manifest = $null
    try {
        $manifest = Get-Content -Path $pluginJsonPath -Raw | ConvertFrom-Json
        Write-Host "OK: $pluginName/plugin.json exists and is valid JSON" -ForegroundColor Green
    } catch {
        $errors += "Invalid JSON in $pluginName/plugin.json"
        Write-Host "FAIL: $pluginName/plugin.json is invalid JSON" -ForegroundColor Red
        continue
    }

    if ($manifest.name -ne $pluginName) {
        $errors += "plugin.json name '$($manifest.name)' does not match marketplace entry '$pluginName'"
        Write-Host "FAIL: $pluginName/plugin.json name mismatch ('$($manifest.name)')" -ForegroundColor Red
    }

    $legacyDir = Join-Path $pluginPath ".claude-plugin"
    if (Test-Path $legacyDir) {
        $errors += "Legacy .claude-plugin/ directory present in $pluginName"
        Write-Host "FAIL: $pluginName contains a legacy .claude-plugin/ directory" -ForegroundColor Red
    }

    $agentsDir = Join-Path $pluginPath "agents"
    if (Test-Path $agentsDir) {
        $strayAgents = @(Get-ChildItem -Path $agentsDir -Filter *.md -File |
            Where-Object { $_.Name -notlike '*.agent.md' })
        foreach ($stray in $strayAgents) {
            $errors += "Agent file without .agent.md extension: $pluginName/agents/$($stray.Name)"
            Write-Host "FAIL: $pluginName/agents/$($stray.Name) must use the .agent.md extension" -ForegroundColor Red
        }
        if ($strayAgents.Count -eq 0) {
            Write-Host "OK: $pluginName agents use the .agent.md extension" -ForegroundColor Green
        }
    }

    $hooksCandidates = @(
        (Join-Path $pluginPath "hooks.json"),
        (Join-Path $pluginPath "hooks\hooks.json")
    )
    if ($null -ne $manifest.hooks -and $manifest.hooks -is [string]) {
        $hooksCandidates += (Join-Path $pluginPath $manifest.hooks)
    }
    foreach ($hooksPath in ($hooksCandidates | Select-Object -Unique)) {
        if (-not (Test-Path $hooksPath)) { continue }
        try {
            $hooksConfig = Get-Content -Path $hooksPath -Raw | ConvertFrom-Json
        } catch {
            $errors += "Invalid JSON in hooks config: $hooksPath"
            Write-Host "FAIL: hooks config invalid JSON at $hooksPath" -ForegroundColor Red
            continue
        }
        if ($hooksConfig.version -ne 1) {
            $errors += "Hooks config missing 'version': 1 (Copilot CLI format): $hooksPath"
            Write-Host "FAIL: hooks config at $hooksPath must declare `"version`": 1" -ForegroundColor Red
        } else {
            Write-Host "OK: $pluginName hooks config declares version 1" -ForegroundColor Green
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll plugins have valid Copilot CLI marketplace structure." -ForegroundColor Cyan
