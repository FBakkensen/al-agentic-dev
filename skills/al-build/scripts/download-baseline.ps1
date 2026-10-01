#requires -Version 7.2

<#
.SYNOPSIS
    Check the Release pin: the `version` in the committed AppSourceCop.json against the latest
    Release on Microsoft's public AppSourceSymbols feed, then fill the compile baseline folder.

.DESCRIPTION
    Sole owner of the pin check for provisioning. A `version` in app/AppSourceCop.json turns it on,
    whatever breakingChange.enabled and al.codeAnalyzers say. With no AppSourceCop.json, or one
    without `version`, it skips and exits 0 without reading a feed.

    The pin check is Test-ReleasePin in symbol-feed.psm1: it reads the 4-part version from the
    manifest of the .app inside the latest Release package. Exit codes are contract:
      0  the pin equals the latest Release, or there is no pin
      4  the pin is stale, the feed lists no Release of the app, or AppSourceCop.json is not JSON
      1  the feed or its package cannot be read

    With a current pin it fills the folder AppSourceCop.json's `baselinePackageCachePath` names,
    resolved against the app folder, with Save-ReleaseBaseline: the symbols-only Release and its
    dependency symbols, Microsoft ones from MSSymbols and the rest from AppSourceSymbols. Only
    *.app files are removed or written. More exit codes:
      4  the version has no `baselinePackageCachePath`, or git tracks a *.app in the folder
      1  git, a feed, or a package cannot be read, or the swap fails; the folder is left as it was

    Never writes AppSourceCop.json or any other tracked file. provision.ps1 runs it after the
    symbol downloads, and exits with its exit code.

.EXAMPLE
    pwsh -File download-baseline.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'symbol-feed.psm1') -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Release Pin Check and Baseline Fill'

# No AppSourceCop.json (a missing app folder holds none) or no `version`: nothing to check.
try {
    $settings = Get-AppSourceCopSettings -AppDir $config.AppDir
} catch {
    # A file the developer must fix is a missing prerequisite, not an environment failure.
    Write-BuildMessage -Type Error -Message $_.Exception.Message
    exit (Get-ExitCode).Contract
}
if (-not $settings -or -not $settings.Version) {
    Write-BuildMessage -Type Info -Message 'AppSourceCop.json pins no version - no Release to check.'
    exit 0
}

$appJson = Get-AppJsonObject $config.AppDir
$pin = Test-ReleasePin -AppJson $appJson -Pin $settings.Version
if ($pin.ExitCode -ne 0) {
    Write-BuildMessage -Type Error -Message $pin.Message
    exit $pin.ExitCode
}
Write-BuildMessage -Type Success -Message $pin.Message

if (-not $settings.BaselinePackageCachePath) {
    Write-BuildMessage -Type Error -Message "AppSourceCop.json pins $($settings.Version) but sets no baselinePackageCachePath. Set baselinePackageCachePath to the folder the compile-time AppSourceCop reads its baseline from."
    exit (Get-ExitCode).Contract
}

$fill = Save-ReleaseBaseline -AppJson $appJson -Version $settings.Version -Folder $settings.BaselinePackageCachePath
if ($fill.ExitCode -eq 0) {
    Write-BuildMessage -Type Success -Message $fill.Message
    foreach ($file in $fill.Files) { Write-BuildMessage -Type Detail -Message $file }
} else {
    Write-BuildMessage -Type Error -Message $fill.Message
}
exit $fill.ExitCode
