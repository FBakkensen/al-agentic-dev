#Requires -Version 7.2
<#
.SYNOPSIS
    Fetches every Base plugin into .base-plugins/ for the trigger evals.
.DESCRIPTION
    Resolves every declared dependency through Test-BasePluginDrift.ps1's Resolve-BasePlugin:
    mattpocock-skills at the commit claude-plugins-official lists, bcquality and the AL language
    server at their upstream default branches. The language server ships no skill, but an eval
    run drops a plugin whose dependency is not loaded beside it, so every case loads all three.
    Everything resolves into a staging folder first. Only when every dependency resolves does
    each plugin replace <Destination>/<name> whole, so a rerun refreshes the copies and drops
    files upstream no longer ships. A dependency that cannot be fetched exits 1 and leaves the
    existing copies untouched.
    -PluginRoot maps namespaces to local directories ('ns=path') and skips every fetch.
.EXAMPLE
    pwsh scripts/Update-EvalBasePlugins.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),

    [string]$Destination,

    [string[]]$PluginRoot
)

# Dot-sourcing binds the drift script's parameters, which share these names, so keep ours first.
$requested = @{ RepoRoot = $RepoRoot; Destination = $Destination; PluginRoot = $PluginRoot }
. (Join-Path $PSScriptRoot 'Test-BasePluginDrift.ps1')

function Update-EvalBasePlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$Destination,
        [hashtable]$PluginRoot
    )

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
    if (-not $Destination) {
        $Destination = Join-Path $RepoRoot '.base-plugins'
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    # Staged beside the copies, because Move-Item cannot move a folder across volumes.
    $staging = Join-Path $Destination ('.staging-' + [guid]::NewGuid().ToString('N'))
    try {
        $plugins = @(Resolve-BasePlugin -RepoRoot $RepoRoot -Destination $staging -PluginRoot $PluginRoot)
        $failed = @($plugins | Where-Object Error)
        foreach ($plugin in $failed) {
            Write-Error "FAIL: dependency '$($plugin.Name)' could not be fetched: $($plugin.Error)" -ErrorAction Continue
        }
        if ($failed.Count -gt 0) {
            return 1
        }

        foreach ($plugin in $plugins) {
            $target = Join-Path $Destination $plugin.Name
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            Move-Item -LiteralPath $plugin.Root -Destination $target
            Write-Host "OK: $($plugin.Name) -> $target" -ForegroundColor Green
        }
    } finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Update-EvalBasePlugin -RepoRoot $requested.RepoRoot -Destination $requested.Destination `
            -PluginRoot (ConvertTo-PluginRootMap -Pair $requested.PluginRoot))
}
