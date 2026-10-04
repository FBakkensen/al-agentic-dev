#requires -Version 7.2

<#
.SYNOPSIS
    Apply a reviewed namespace map to the main app in one deterministic pass.

.DESCRIPTION
    Gives every .al file of the app its namespace line and the using lines its
    references need, moves it to the folder its namespace names below the source
    root, and renames it to the CodeCop file name. The whole map is checked
    before the first write: an unknown object, an app object the map leaves out,
    two files sent to one path, or a namespace that is not a dotted AL identifier
    under the root fails with nothing written. The map format is in
    NAMESPACE-MAP.md.

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
    $config = Get-BuildConfig
    if (-not $AppDir) { $AppDir = $config.AppDir }
    $result = Invoke-NamespaceMap -MapPath $MapPath -AppDir $AppDir -RootNamespace $RootNamespace `
        -ExcludeDirs @($config.TestApps + $config.ContainerTestApps | Select-Object -Unique)
} catch {
    Write-BuildMessage -Type Error -Message $_.Exception.Message
    exit 1
}

$moved = @($result.Files | Where-Object { $_.Source -ne $_.Target }).Count
Write-BuildMessage -Type Success -Message "Applied the namespace map: $(@($result.Files).Count) files organized, $moved moved or renamed. Run test.ps1 to prove the result."
