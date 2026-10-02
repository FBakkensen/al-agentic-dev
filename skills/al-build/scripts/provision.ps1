#Requires -Version 7.2

<#
.SYNOPSIS
    Per-feature setup: refresh BcContainerHelper, install AL compiler channels, and download symbols.

.DESCRIPTION
    Runs provisioning for main app and all configured test apps:
    - Installs PSGallery's newest BcContainerHelper version every run. Older installed
      versions are left in place for side-by-side use.
    - Installs both AL compiler channels (stable + prerelease) side-by-side under the
      tool cache, refreshed to latest every run. The global 'al' dotnet tool is the
      user's own and is left untouched; the build picks a channel per app.json runtime.
    - Downloads symbol packages for app/
    - Downloads symbol packages for each test app
    - Checks the `version` pinned in the committed AppSourceCop.json against the latest Release on
      AppSourceSymbols; a stale pin stops with exit 4. With a current pin, fills the folder
      `baselinePackageCachePath` names with the Release and its dependency symbols (see
      download-baseline.ps1)
    - Stops with exit 4 first when breakingChange.releaseAppDir and AppSourceCop.json's
      baselinePackageCachePath name one folder

.PARAMETER UpdateCompiler
    Force a clean reinstall of both compiler channels. By default each channel is
    refreshed to latest in place every run.

.EXAMPLE
    pwsh -File provision.ps1

.EXAMPLE
    pwsh -File provision.ps1 -UpdateCompiler
#>

[CmdletBinding()]
param(
    [switch]$UpdateCompiler
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Install-LatestBcContainerHelper {
    Write-BuildMessage -Type Step -Message 'Refreshing BcContainerHelper from PSGallery...'

    try {
        $latestModule = Find-Module `
            -Name 'BcContainerHelper' `
            -Repository 'PSGallery' `
            -ErrorAction Stop |
            Select-Object -First 1

        if (-not $latestModule.Version) {
            throw 'PSGallery returned no BcContainerHelper version.'
        }

        Install-Module `
            -Name 'BcContainerHelper' `
            -Repository 'PSGallery' `
            -RequiredVersion $latestModule.Version `
            -Scope CurrentUser `
            -Force `
            -AllowClobber `
            -ErrorAction Stop
    } catch {
        throw "BcContainerHelper refresh failed: $($_.Exception.Message)"
    }

    Write-BuildMessage -Type Success -Message "BcContainerHelper $($latestModule.Version) is installed"
}

# Import modules
$commonModule = Join-Path $PSScriptRoot 'common.psm1'
$buildOperationsModule = Join-Path $PSScriptRoot 'build-operations.psm1'
Import-Module $commonModule -Force -DisableNameChecking
Import-Module $buildOperationsModule -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Provision: Environment Setup'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"

# Step 1: Refresh BcContainerHelper
Install-LatestBcContainerHelper

# Step 2: Ensure compiler
Install-ALCompiler -Update:$UpdateCompiler

# Step 2b: Ensure AL Runner (containerless test execution always uses it)
Install-ALRunner

# Step 3: Download symbols for main app
$downloadSymbolsScript = Join-Path $PSScriptRoot 'download-symbols.ps1'
if (Test-Path $config.AppDir) {
    & $downloadSymbolsScript -AppDir $config.AppDir
    if ($LASTEXITCODE -ne 0) {
        throw "Symbol download failed for $($config.AppDir)"
    }
} else {
    Write-BuildMessage -Type Warning -Message "App directory not found: $($config.AppDir)"
}

# Step 4: Download symbols for each test app
foreach ($testAppDir in $config.TestApps) {
    if (Test-Path $testAppDir) {
        & $downloadSymbolsScript -AppDir $testAppDir
        if ($LASTEXITCODE -ne 0) {
            throw "Symbol download failed for $testAppDir"
        }
    } else {
        $dirName = Split-Path $testAppDir -Leaf
        Write-BuildMessage -Type Detail -Message "Test app directory not found: $dirName (skipping)"
    }
}

# Step 5: The Release .app folder and the compile baseline folder stay two folders, so a baseline
# fill never replaces the real Release .app. Runs after both symbol steps (symbols.lock.json is
# written first) and before the baseline step. A file download-baseline.ps1 rejects as not JSON
# is its to report.
$appSourceCop = try { Get-AppSourceCopSettings -AppDir $config.AppDir } catch { $null }
$folderConflict = Get-BaselineFolderConflict -ReleaseAppDir $config.ReleaseAppDir -AppSourceCop $appSourceCop
if ($folderConflict) {
    Write-BuildMessage -Type Error -Message $folderConflict
    exit (Get-ExitCode).Contract
}

# Step 6: Check the Release pin and fill the baseline folder. Its exit code (4 stale, no Release, or no
# baselinePackageCachePath, 1 feed unreachable or a package missing) is ours; symbols.lock.json is
# written by then even when the pin is stale.
$downloadBaselineScript = Join-Path $PSScriptRoot 'download-baseline.ps1'
& $downloadBaselineScript
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-BuildHeader 'Provision Complete'
Write-BuildMessage -Type Success -Message "Environment is ready for development"
Write-BuildMessage -Type Info -Message "Next: Run 'pwsh $PSScriptRoot/test.ps1' to build and test"
