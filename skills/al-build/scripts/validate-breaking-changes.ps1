#requires -Version 7.2

<#
.SYNOPSIS
    Validate the AL app against the real Release .app for breaking changes.

.DESCRIPTION
    The heavyweight AppSource-style check (per-country, install/upgrade) that the
    compile-time AppSourceCop pass cannot do.

    A `version` in the committed AppSourceCop.json first repeats the Release pin check
    (Test-ReleasePin, as download-baseline.ps1 runs it), whatever breakingChange.enabled says, so a
    Release shipped mid-branch stops the run before any compile. Exit codes follow the check: 4 for a
    stale pin or a version with no Release, 1 for an unreachable feed. This script never runs
    download-baseline.ps1.

    breakingChange.enabled then gates only the container install/upgrade test. With it false the
    script stops after the pin check with exit 0. With it true the script takes the real Release .app
    from the folder breakingChange.releaseAppDir (ALBT_RELEASE_APP_DIR, repo-root relative) that the
    developer copied it into, picks it by the id of app.json and the pinned version in its manifest,
    rejects a symbols-only file (`al IsSymbolOnly`), and hands that one .app to Run-AlValidation as the
    previous app. Every prerequisite check - AppSourceCop.json with its affixes and countries, the
    version, the key, the folder guard against AppSourceCop.json's baselinePackageCachePath, the match,
    the symbols-only check - runs first and stops with exit 4, before the build and before
    BcContainerHelper loads.

    Uses AppSourceCop.json for affixes and supported countries.

.EXAMPLE
    pwsh -File validate-breaking-changes.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/symbol-feed.psm1" -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

$Exit = Get-ExitCode

Write-BuildHeader 'Breaking Change Validation'

# The committed AppSourceCop.json: a file the developer must fix is a missing prerequisite.
try {
    $appSourceCop = Get-AppSourceCopSettings -AppDir $config.AppDir
} catch {
    Write-BuildMessage -Type Error -Message $_.Exception.Message
    exit $Exit.Contract
}
$appJson = Get-AppJsonObject $config.AppDir

# The pin check runs whatever breakingChange.enabled says, before any build.
if ($appSourceCop -and $appSourceCop.Version) {
    $pin = Test-ReleasePin -AppJson $appJson -Pin $appSourceCop.Version
    if ($pin.ExitCode -ne 0) {
        Write-BuildMessage -Type Error -Message $pin.Message
        exit $pin.ExitCode
    }
    Write-BuildMessage -Type Success -Message $pin.Message
}

if (-not $config.BreakingChangeEnabled) {
    Write-BuildMessage -Type Info -Message "breakingChange.enabled is false - skipping the container install/upgrade test."
    exit 0
}

Write-BuildHeader 'AppSourceCop Configuration'

if (-not $appSourceCop) {
    Write-BuildMessage -Type Error -Message "AppSourceCop.json not found"
    exit $Exit.Contract
}

# Optional keys read through PSObject.Properties: a missing one must not throw under strict mode.
$appSourceCopJson = Get-Content -LiteralPath $appSourceCop.Path -Raw | ConvertFrom-Json
$readOptionalValue = {
    param([string]$Name)
    $property = if ($appSourceCopJson) { $appSourceCopJson.PSObject.Properties[$Name] } else { $null }
    if ($property) { $property.Value } else { $null }
}

$affixes = & $readOptionalValue 'mandatoryAffixes'
if (-not $affixes -or @($affixes).Count -eq 0) {
    Write-BuildMessage -Type Error -Message "No mandatoryAffixes found"
    exit $Exit.Contract
}
Write-BuildMessage -Type Detail -Message "Affixes: $(@($affixes) -join ', ')"

$supportedCountries = & $readOptionalValue 'supportedCountries'
if (-not $supportedCountries -or @($supportedCountries).Count -eq 0) {
    Write-BuildMessage -Type Error -Message "No supportedCountries found"
    exit $Exit.Contract
}
Write-BuildMessage -Type Detail -Message "Countries: $(@($supportedCountries) -join ', ')"

Write-BuildHeader 'Release App'

if (-not $appSourceCop.Version) {
    Write-BuildMessage -Type Error -Message "AppSourceCop.json pins no version - add version, the Release to validate against ($($appSourceCop.Path))."
    exit $Exit.Contract
}
$appId = if ($appJson -and $appJson.PSObject.Properties['id']) { [string]$appJson.id } else { '' }
if (-not $appId) {
    Write-BuildMessage -Type Error -Message "app.json names no id in $($config.AppDir) - nothing to match the Release .app against."
    exit $Exit.Contract
}
if (-not $config.ReleaseAppDir) {
    Write-BuildMessage -Type Error -Message "breakingChange.releaseAppDir is not set (or ALBT_RELEASE_APP_DIR) - name the folder holding the real Release .app of version $($appSourceCop.Version)."
    exit $Exit.Contract
}
$folderConflict = Get-BaselineFolderConflict -ReleaseAppDir $config.ReleaseAppDir -AppSourceCop $appSourceCop
if ($folderConflict) {
    Write-BuildMessage -Type Error -Message $folderConflict
    exit $Exit.Contract
}

$releaseApps = @(Find-ReleaseApp -Folder $config.ReleaseAppDir -AppId $appId -Version $appSourceCop.Version)
if ($releaseApps.Count -eq 0) {
    Write-BuildMessage -Type Error -Message "No .app with id $appId and version $($appSourceCop.Version) in breakingChange.releaseAppDir '$($config.ReleaseAppDir)'. Copy the real Release .app there."
    exit $Exit.Contract
}

# The folder must hold only the real Release: a symbols-only match is rejected, wherever it sits.
try {
    Get-LatestCompilerInfo | Out-Null
} catch {
    Write-BuildMessage -Type Error -Message $_.Exception.Message
    exit $Exit.Contract
}
foreach ($releaseApp in $releaseApps) {
    try {
        $symbolOnly = Test-SymbolOnlyApp -Path $releaseApp.FullName
    } catch {
        Write-BuildMessage -Type Error -Message $_.Exception.Message
        exit $Exit.GeneralError
    }
    if ($symbolOnly) {
        Write-BuildMessage -Type Error -Message "$($releaseApp.FullName) is a symbols-only .app. breakingChange.releaseAppDir must hold only the real Release .app - remove it."
        exit $Exit.Contract
    }
}
if ($releaseApps.Count -gt 1) {
    Write-BuildMessage -Type Error -Message "breakingChange.releaseAppDir '$($config.ReleaseAppDir)' holds $($releaseApps.Count) real .app files of version $($appSourceCop.Version): $(($releaseApps | ForEach-Object { $_.Name }) -join ', '). Keep one."
    exit $Exit.Contract
}
$previousApps = @($releaseApps[0].FullName)
Write-BuildMessage -Type Success -Message "Release app: $($releaseApps[0].Name)"

# Build the current app
Write-BuildMessage -Type Step -Message "Building current app..."
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)

$absoluteAppDir = (Resolve-Path -Path $config.AppDir).Path
Write-BuildMessage -Type Detail -Message "App Directory: $absoluteAppDir"

# ConvertTo-Boolean handles bool/'1'/'true'/'True' uniformly — the env round-trip
# stringifies the JSON boolean, so a plain -eq "1" test silently reads false.
$validateCurrent = ConvertTo-Boolean $config.ValidateCurrent
Write-BuildMessage -Type Detail -Message "Validate Current: $validateCurrent"

Write-BuildHeader 'Current App'

$currentAppPath = Get-OutputPath $absoluteAppDir
if (-not $currentAppPath -or -not (Test-Path $currentAppPath)) {
    Write-BuildMessage -Type Error -Message "Current app not found"
    exit $Exit.Contract
}

$currentApp = Get-Item $currentAppPath
Write-BuildMessage -Type Success -Message "Found: $($currentApp.Name)"

Write-BuildHeader 'Running Validation'

Import-BCContainerHelper

# No throwOnError: Run-AlValidation RETURNS its result lines (findings and
# environment errors alike — its internal catch swallows container failures
# into the same list). The verdict comes from classifying those lines via
# Get-AlValidationVerdict; a throw-based gate cannot tell a breaking change
# from a docker hiccup, and an unthrown result is a silent green.
# Warnings stay at the compile-time AppSourceCop pass; this gate is errors-only.
$validationParams = @{
    countries          = $supportedCountries
    apps               = @($currentAppPath)
    previousApps       = $previousApps
    affixes            = $affixes
    supportedCountries = $supportedCountries
    validateCurrent    = $validateCurrent
    failOnError        = $true
    includeWarnings    = $false
    # Locally built apps are unsigned by construction and AL-Go CI builds
    # unsigned baselines unless codesigning is configured — without this switch
    # every run yields "...is not signed, result is NotSigned", which classifies
    # as a finding and the gate can never pass. Signing is the publish
    # pipeline's concern, not this schema gate's.
    skipVerification   = $true
    # Mirror the module's default NewBcContainer scriptblock, forcing process
    # isolation: Run-AlValidation has no isolation parameter and auto-detection
    # picks hyperv on host/image kernel mismatch — failing hosts without
    # Hyper-V. al-build standardizes on process isolation everywhere.
    NewBcContainer     = {
        Param([Hashtable]$parameters)
        $parameters.isolation = 'process'
        New-BcContainer @parameters
        Invoke-ScriptInBcContainer $parameters.ContainerName -scriptblock { $progressPreference = 'SilentlyContinue' }
    }
}

Write-BuildMessage -Type Step -Message "Running AL validation..."

try {
    $validationResult = @(Run-AlValidation @validationParams)
} catch {
    # Backstop for genuine throws (artifact resolution, parameter validation)
    # that never reach the result list — environment-shaped, never a finding.
    Write-BuildHeader 'Validation Failed'
    Write-BuildMessage -Type Error -Message "Validation could not run"
    if ($_.Exception.Message) {
        Write-BuildMessage -Type Error -Message $_.Exception.Message
    }
    exit $Exit.GeneralError
}

$verdict = Get-AlValidationVerdict -ValidationResult $validationResult

switch ($verdict.Verdict) {
    'BreakingChange' {
        Write-BuildHeader 'Validation Failed'
        Write-BuildMessage -Type Error -Message "Breaking changes detected"
        # Verdict evidence, not diagnostics: Detail is verbose-gated and would
        # leave a detected break undiagnosable in default runs.
        $verdict.Findings | ForEach-Object { Write-BuildMessage -Type Error -Message $_ }
        exit $Exit.Analysis
    }
    'EnvironmentError' {
        Write-BuildHeader 'Validation Failed'
        Write-BuildMessage -Type Error -Message "Environment failure during validation - no verdict on breaking changes; fix and re-run"
        $verdict.EnvironmentErrors | ForEach-Object { Write-BuildMessage -Type Error -Message $_ }
        exit $Exit.GeneralError
    }
    default {
        Write-BuildHeader 'Validation Complete'
        Write-BuildMessage -Type Success -Message "No breaking changes detected"
    }
}
