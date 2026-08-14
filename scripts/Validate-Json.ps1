#Requires -Version 7.2
<#
.SYNOPSIS
    Validates JSON syntax repo-wide and the Copilot plugin surface.
.DESCRIPTION
    Recursively validates the syntax of every .json file under the repo root using
    ConvertFrom-Json. On top of the sweep, the plugin surface is validated structurally:
    plugin.json (name and version non-empty; the skills, agents, and mcpServers paths
    exist), .mcp.json (at least one server; every server carries a type and a non-empty
    tools allowlist), and .github/plugin/marketplace.json (name non-empty; at least one
    plugins entry; every entry names a plugin, its source path exists, and an entry whose
    source holds a plugin.json matches that manifest's name). All three files must exist.
    Returns exit code 1 if anything fails.
.EXAMPLE
    pwsh scripts/Validate-Json.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..')
)

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
$errors = @()

Get-ChildItem -Path $RepoRoot -Recurse -Filter "*.json" | ForEach-Object {
    try {
        $null = Get-Content $_.FullName -Raw | ConvertFrom-Json
        Write-Host "OK: $($_.FullName)" -ForegroundColor Green
    } catch {
        $errors += "FAIL: $($_.FullName) - $($_.Exception.Message)"
        Write-Host "FAIL: $($_.FullName)" -ForegroundColor Red
    }
}

function Read-PluginJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $script:errors += "FAIL: $Label is missing"
        return $null
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        $script:errors += "FAIL: $Label does not parse - $($_.Exception.Message)"
        return $null
    }
}

$pluginPath = Join-Path $RepoRoot 'plugin.json'
$mcpPath = Join-Path $RepoRoot '.mcp.json'
$marketplacePath = Join-Path $RepoRoot '.github' 'plugin' 'marketplace.json'

$plugin = Read-PluginJson -Path $pluginPath -Label 'plugin.json'
if ($plugin) {
    if (-not $plugin.name) { $errors += 'FAIL: plugin.json - name must be non-empty' }
    if (-not $plugin.version) { $errors += 'FAIL: plugin.json - version must be non-empty' }
    foreach ($pathKey in @('skills', 'agents', 'mcpServers')) {
        $value = $plugin.$pathKey
        if (-not $value) {
            $errors += "FAIL: plugin.json - $pathKey must name a path"
        } elseif (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $value))) {
            $errors += "FAIL: plugin.json - $pathKey path does not exist: $value"
        }
    }
}

$mcp = Read-PluginJson -Path $mcpPath -Label '.mcp.json'
if ($mcp) {
    $servers = @($mcp.mcpServers.PSObject.Properties)
    if (-not $mcp.mcpServers -or $servers.Count -eq 0) {
        $errors += 'FAIL: .mcp.json - mcpServers must carry at least one server'
    }
    foreach ($server in $servers) {
        if (-not $server.Value.type) {
            $errors += "FAIL: .mcp.json - server '$($server.Name)' must carry a type"
        }
        if (@($server.Value.tools).Count -eq 0) {
            $errors += "FAIL: .mcp.json - server '$($server.Name)' must carry a non-empty tools allowlist"
        }
    }
}

$marketplace = Read-PluginJson -Path $marketplacePath -Label '.github/plugin/marketplace.json'
if ($marketplace) {
    if (-not $marketplace.name) { $errors += 'FAIL: marketplace.json - name must be non-empty' }
    $plugins = @($marketplace.plugins)
    if ($plugins.Count -eq 0) {
        $errors += 'FAIL: marketplace.json - plugins must carry at least one entry'
    }
    foreach ($entry in $plugins) {
        if (-not $entry.name) {
            $errors += 'FAIL: marketplace.json - every plugins entry must name a plugin'
            continue
        }
        if (-not $entry.source) {
            $errors += "FAIL: marketplace.json - plugin '$($entry.name)' must carry a source path"
            continue
        }
        $sourcePath = Join-Path $RepoRoot $entry.source
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            $errors += "FAIL: marketplace.json - plugin '$($entry.name)' source does not exist: $($entry.source)"
            continue
        }
        $sourceManifest = Join-Path $sourcePath 'plugin.json'
        if (Test-Path -LiteralPath $sourceManifest -PathType Leaf) {
            try {
                $manifestName = (Get-Content -LiteralPath $sourceManifest -Raw | ConvertFrom-Json).name
                if ($entry.name -cne $manifestName) {
                    $errors += "FAIL: marketplace.json - plugin '$($entry.name)' does not match the manifest name '$manifestName' at $($entry.source)"
                }
            } catch {
                # The syntax sweep or the plugin.json check reports the parse failure.
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll JSON files validated successfully." -ForegroundColor Cyan
