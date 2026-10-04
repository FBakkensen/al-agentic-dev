#requires -Version 7.2

<#
.SYNOPSIS
    Apply a reviewed namespace map to the main app. The contract is NAMESPACE-MAP.md.

.PARAMETER MapPath
    The reviewed map, a JSON array of { type, id, name, namespace }.

.PARAMETER RootNamespace
    The app's root namespace; every map namespace is the root or below it.

.PARAMETER AppDir
    The app folder. Defaults to appDir in al-build.json.

.EXAMPLE
    pwsh -File apply-namespace-map.ps1 -MapPath namespace-map.json -RootNamespace Naveksa.ShopFloor
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$MapPath,

    [Parameter(Mandatory)]
    [string]$RootNamespace,

    [string]$AppDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'namespace-map.psm1') -Force -DisableNameChecking

Write-BuildHeader 'Apply Namespace Map'

try {
    # al-build.json names the app folder and the test apps nested in it; -AppDir alone needs neither.
    $config = $null
    if (-not $AppDir -or (Test-Path -LiteralPath (Join-Path (Get-GitRepoRoot) 'al-build.json'))) {
        $config = Get-BuildConfig
        Set-BuildEnvironment -Config $config
    }
    if (-not $AppDir) { $AppDir = $config.AppDir }
    $excluded = if ($config) { @($config.TestApps + $config.ContainerTestApps | Select-Object -Unique) } else { @() }

    $symbols = Get-SymbolCacheInfo -AppJson (Get-AppJsonObject $AppDir)
    $result = Invoke-NamespaceMap -MapPath $MapPath -AppDir $AppDir -RootNamespace $RootNamespace -SymbolDir $symbols.CacheDir -ExcludeDirs $excluded
} catch {
    Write-BuildMessage -Type Error -Message $_.Exception.Message
    exit 1
}

$moved = @($result.Files | Where-Object { $_.Source -ne $_.Target }).Count
Write-BuildMessage -Type Success -Message "Applied the namespace map: $(@($result.Files).Count) files organized, $moved moved or renamed. Run test.ps1 to prove the result."
