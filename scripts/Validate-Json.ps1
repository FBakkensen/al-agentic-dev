#Requires -Version 7.2
<#
.SYNOPSIS
    Validates JSON syntax repo-wide and the Claude Code plugin surface.
.DESCRIPTION
    Recursively validates the syntax of every .json file under the repo root using
    ConvertFrom-Json. On top of the sweep, the plugin surface is validated structurally:
    .claude-plugin/plugin.json (name and version non-empty), .mcp.json (at least one
    server; every server carries a type and no tools allowlist, which makes Claude Code
    silently drop the server), and .claude-plugin/marketplace.json (name non-empty; at
    least one plugins entry; every entry names a plugin and carries a source; a local
    string source resolves to <source>/.claude-plugin/plugin.json with a matching name).
    A re-listed object source is a url or git-subdir source with an https url, and a
    git-subdir source carries a path; neither is path-checked locally. All three files must
    exist. Returns exit code 1 if anything fails.
.EXAMPLE
    pwsh scripts/Validate-Json.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..')
)

function Invoke-JsonValidation {
    [CmdletBinding()]
    param(
        [string]$RepoRoot = (Join-Path $PSScriptRoot '..')
    )

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
$script:jsonValidationErrors = @()

Get-ChildItem -Path $RepoRoot -Recurse -Filter "*.json" |
    Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' } |
    ForEach-Object {
    $file = $_
    try {
        $null = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        Write-Host "OK: $($file.FullName)" -ForegroundColor Green
    } catch {
        $script:jsonValidationErrors += "FAIL: $($file.FullName) - $($_.Exception.Message)"
        Write-Host "FAIL: $($file.FullName)" -ForegroundColor Red
    }
    }

function Read-PluginJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $script:jsonValidationErrors += "FAIL: $Label is missing"
        return $null
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        $script:jsonValidationErrors += "FAIL: $Label does not parse - $($_.Exception.Message)"
        return $null
    }
}

$pluginPath = Join-Path $RepoRoot '.claude-plugin' 'plugin.json'
$mcpPath = Join-Path $RepoRoot '.mcp.json'
$marketplacePath = Join-Path $RepoRoot '.claude-plugin' 'marketplace.json'

$plugin = Read-PluginJson -Path $pluginPath -Label '.claude-plugin/plugin.json'
if ($plugin) {
    if (-not $plugin.name) { $script:jsonValidationErrors += 'FAIL: .claude-plugin/plugin.json - name must be non-empty' }
    if (-not $plugin.version) { $script:jsonValidationErrors += 'FAIL: .claude-plugin/plugin.json - version must be non-empty' }
}

$mcp = Read-PluginJson -Path $mcpPath -Label '.mcp.json'
if ($mcp) {
    $servers = @($mcp.mcpServers.PSObject.Properties | Where-Object { $null -ne $_ })
    if (-not $mcp.mcpServers -or $servers.Count -eq 0) {
        $script:jsonValidationErrors += 'FAIL: .mcp.json - mcpServers must carry at least one server'
    }
    foreach ($server in $servers) {
        if (-not $server.Value.type) {
            $script:jsonValidationErrors += "FAIL: .mcp.json - server '$($server.Name)' must carry a type"
        }
        if ($server.Value.PSObject.Properties.Name -contains 'tools') {
            $script:jsonValidationErrors += "FAIL: .mcp.json - server '$($server.Name)' carries a tools allowlist; Claude Code drops a server that has one"
        }
    }
}

$marketplace = Read-PluginJson -Path $marketplacePath -Label '.claude-plugin/marketplace.json'
if ($marketplace) {
    if (-not $marketplace.name) { $script:jsonValidationErrors += 'FAIL: marketplace.json - name must be non-empty' }
    $plugins = @($marketplace.plugins | Where-Object { $null -ne $_ })
    if ($plugins.Count -eq 0) {
        $script:jsonValidationErrors += 'FAIL: marketplace.json - plugins must carry at least one entry'
    }
    foreach ($entry in $plugins) {
        if (-not $entry.name) {
            $script:jsonValidationErrors += 'FAIL: marketplace.json - every plugins entry must name a plugin'
            continue
        }
        if (-not $entry.source) {
            $script:jsonValidationErrors += "FAIL: marketplace.json - plugin '$($entry.name)' must carry a source"
            continue
        }
        # Re-listed plugins use url / git-subdir object sources over https; they carry no local path.
        if ($entry.source -isnot [string]) {
            $type = $entry.source.source
            if ($type -cnotin @('url', 'git-subdir')) {
                $script:jsonValidationErrors += "FAIL: marketplace.json - plugin '$($entry.name)' source type must be url or git-subdir (found: $type)"
                continue
            }
            $uri = $null
            $isHttpsUrl = $entry.source.url -is [string] -and
                [System.Uri]::TryCreate($entry.source.url, [System.UriKind]::Absolute, [ref]$uri) -and
                $uri.Scheme -eq [System.Uri]::UriSchemeHttps -and $uri.Host
            if (-not $isHttpsUrl) {
                $script:jsonValidationErrors += "FAIL: marketplace.json - plugin '$($entry.name)' source must carry an https url"
            }
            if ($type -ceq 'git-subdir' -and ($entry.source.path -isnot [string] -or -not $entry.source.path.Trim())) {
                $script:jsonValidationErrors += "FAIL: marketplace.json - plugin '$($entry.name)' git-subdir source must carry a path"
            }
            continue
        }

        $sourceManifest = Join-Path $RepoRoot $entry.source '.claude-plugin' 'plugin.json'
        if (-not (Test-Path -LiteralPath $sourceManifest -PathType Leaf)) {
            $script:jsonValidationErrors += "FAIL: marketplace.json - plugin '$($entry.name)' source does not resolve to a plugin manifest: $($entry.source)"
            continue
        }
        try {
            $manifest = Get-Content -LiteralPath $sourceManifest -Raw | ConvertFrom-Json
            if ($entry.name -cne $manifest.name) {
                $script:jsonValidationErrors += "FAIL: marketplace.json - plugin '$($entry.name)' does not match the manifest name '$($manifest.name)' at $($entry.source)"
            }
        } catch {
            # The syntax sweep or the plugin.json check reports the parse failure.
        }
    }
}

if ($script:jsonValidationErrors.Count -gt 0) {
    $script:jsonValidationErrors | ForEach-Object { Write-Error $_ }
    return 1
}

Write-Host "`nAll JSON files validated successfully." -ForegroundColor Cyan
return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-JsonValidation -RepoRoot $RepoRoot)
}
