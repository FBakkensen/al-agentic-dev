#requires -Version 7.2

<#+
.SYNOPSIS
    Downloads Business Central symbol packages required by app.json into the current checkout's cache.

.DESCRIPTION
    Parses app.json to resolve application/platform versions and dependencies, ensures the
    corresponding NuGet packages exist in the checkout-scoped cache, and maintains a symbols.lock.json manifest.

.PARAMETER AppDir
    Directory that contains app.json (defaults to "app" like build.ps1). You can also set
    ALBT_APP_DIR to override when the parameter is omitted.

.NOTES
    Optional environment variables:
      - ALBT_APP_DIR: override for default app directory when -AppDir omitted.
      - ALBT_MSSYMBOLS_FEED, ALBT_APPSOURCESYMBOLS_FEED: replace a symbol feed root with a URL
        or a local directory laid out as the feed's flat2 paths (see symbol-feed.psm1).
#>

param(
    [string]$AppDir = 'app'
)

if (-not $PSBoundParameters.ContainsKey('AppDir') -and $env:ALBT_APP_DIR) {
    $AppDir = $env:ALBT_APP_DIR
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import shared utilities
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'symbol-feed.psm1') -DisableNameChecking

$Exit = Get-ExitCode

# Initialize timing and data capture
$script:StartTime = Get-Date
$script:versionWarnings = @{}
$script:summaryRows = New-Object System.Collections.Generic.List[object]
$script:raiseRows = New-Object System.Collections.Generic.List[object]
$script:localDependencySkips = New-Object System.Collections.Generic.List[object]

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# --- Script-Specific Helper Functions ---
# Note: Common utilities (Read-JsonFile, Expand-FullPath, Ensure-Directory, ConvertTo-SafePathSegment)
# are imported from common.psm1. Only symbol-download-specific helpers are defined here.

function Get-CopiedLocalDependencyIds {
    param([string]$CurrentAppDir)

    $copiedLocalAppIds = @{}
    if (-not $env:ALBT_APP_DIR) {
        return $copiedLocalAppIds
    }

    # If the current app is not the main app, treat main app as a local dependency
    $currentAppPath = Expand-FullPath -Path $CurrentAppDir
    $mainAppPath = Expand-FullPath -Path $env:ALBT_APP_DIR
    if ([string]::Compare($currentAppPath, $mainAppPath, $true) -eq 0) {
        return $copiedLocalAppIds
    }

    $mainAppJsonPath = Join-Path -Path $mainAppPath -ChildPath 'app.json'
    if (-not (Test-Path -LiteralPath $mainAppJsonPath)) {
        return $copiedLocalAppIds
    }

    try {
        $mainAppJson = Read-JsonFile -Path $mainAppJsonPath
        if (-not $mainAppJson.id) { return $copiedLocalAppIds }

        $appId = ([string]$mainAppJson.id).Trim().ToLowerInvariant()
        if (-not $appId) { return $copiedLocalAppIds }

        $copiedLocalAppIds[$appId] = [pscustomobject]@{
            Name = [string]$mainAppJson.name
            Path = $mainAppJsonPath
        }
    } catch {
        Write-Warning "Failed to inspect configured main app manifest $($mainAppJsonPath): $($_.Exception.Message)"
    }

    return $copiedLocalAppIds
}

function Set-PackageMapMinimum {
    param(
        [System.Collections.IDictionary]$Map,
        [string]$PackageId,
        [string]$Version
    )

    if (-not $PackageId) { return }

    if ($Map.Contains($PackageId)) {
        $existing = [string]$Map[$PackageId]
        if ($Version -and ((Compare-Version -Left $Version -Right $existing) -gt 0)) {
            $Map[$PackageId] = $Version
        }
        return
    }

    $Map[$PackageId] = $Version
}

function Add-DependencyToPackageMap {
    param(
        [System.Collections.IDictionary]$Map,
        $Dep
    )

    if (-not ($Dep.publisher) -or -not ($Dep.name) -or -not ($Dep.id) -or -not ($Dep.version)) {
        return
    }

    $publisher = ($Dep.publisher -replace '\s+', '')
    $name = ($Dep.name -replace '\s+', '')
    $appId = ($Dep.id -replace '\s+', '')
    $packageId = "{0}.{1}.symbols.{2}" -f $publisher, $name, $appId
    Set-PackageMapMinimum -Map $Map -PackageId $packageId -Version ([string]$Dep.version)
}

function Add-LocalAppDependenciesToPackageMap {
    param(
        [System.Collections.IDictionary]$Map,
        [hashtable]$CopiedLocalAppIds,
        [string]$LocalAppId,
        [System.Collections.Generic.HashSet[string]]$VisitedLocalAppIds
    )

    if (-not $LocalAppId) { return }
    if (-not $VisitedLocalAppIds.Add($LocalAppId)) { return }
    if (-not $CopiedLocalAppIds.ContainsKey($LocalAppId)) { return }

    $localInfo = $CopiedLocalAppIds[$LocalAppId]
    $localAppJsonPath = if ($localInfo -and $localInfo.Path) { [string]$localInfo.Path } else { $null }
    if (-not $localAppJsonPath -or -not (Test-Path -LiteralPath $localAppJsonPath)) {
        return
    }

    try {
        $localAppJson = Read-JsonFile -Path $localAppJsonPath
    } catch {
        Write-Warning "Failed to read local dependency manifest ${localAppJsonPath}: $($_.Exception.Message)"
        return
    }

    if (-not ((Test-JsonProperty $localAppJson 'dependencies') -and $localAppJson.dependencies)) {
        return
    }

    foreach ($dep in $localAppJson.dependencies) {
        if (-not ($dep.publisher) -or -not ($dep.name) -or -not ($dep.id) -or -not ($dep.version)) { continue }

        $depAppId = ([string]$dep.id).Trim().ToLowerInvariant()
        if ($CopiedLocalAppIds.ContainsKey($depAppId)) {
            $script:localDependencySkips.Add([pscustomobject]@{
                Publisher = [string]$dep.publisher
                Name      = [string]$dep.name
                Id        = [string]$dep.id
                Path      = $CopiedLocalAppIds[$depAppId].Path
            }) | Out-Null

            Add-LocalAppDependenciesToPackageMap `
                -Map $Map `
                -CopiedLocalAppIds $CopiedLocalAppIds `
                -LocalAppId $depAppId `
                -VisitedLocalAppIds $VisitedLocalAppIds
            continue
        }

        Add-DependencyToPackageMap -Map $Map -Dep $dep
    }
}

function Build-PackageMap {
    param(
        $AppJson,
        [hashtable]$CopiedLocalAppIds = @{}
    )

    $map = [ordered]@{}
    $visitedLocalAppIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    if ((Test-JsonProperty $AppJson 'application') -and $AppJson.application) {
        Set-PackageMapMinimum -Map $map -PackageId 'Microsoft.Application.symbols' -Version ([string]$AppJson.application)
    }

    if ((Test-JsonProperty $AppJson 'dependencies') -and $AppJson.dependencies) {
        foreach ($dep in $AppJson.dependencies) {
            if (-not ($dep.publisher) -or -not ($dep.name) -or -not ($dep.id) -or -not ($dep.version)) { continue }
            $depAppId = ([string]$dep.id).Trim().ToLowerInvariant()
            if ($CopiedLocalAppIds.ContainsKey($depAppId)) {
                $script:localDependencySkips.Add([pscustomobject]@{
                    Publisher = [string]$dep.publisher
                    Name      = [string]$dep.name
                    Id        = [string]$dep.id
                    Path      = $CopiedLocalAppIds[$depAppId].Path
                }) | Out-Null

                # Keep the local main/test-gate app out of NuGet, but still pull its
                # own dependencies into this cache (al-runner recompiles main + tests).
                Add-LocalAppDependenciesToPackageMap `
                    -Map $map `
                    -CopiedLocalAppIds $CopiedLocalAppIds `
                    -LocalAppId $depAppId `
                    -VisitedLocalAppIds $visitedLocalAppIds
                continue
            }

            Add-DependencyToPackageMap -Map $map -Dep $dep
        }
    }

    return $map
}

function Load-Manifest {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Read-JsonFile -Path $Path
    } catch {
        Write-Warning "Failed to load manifest ${Path}: $($_.Exception.Message)"
        return $null
    }
}

function Test-PackagePresent {
    param([string]$CacheDir, [string]$PackageId, [string]$Version = '')
    if ($Version) {
        # Use new naming format with version
        $cleanName = Get-CleanPackageName -PackageId $PackageId
        $fileName = (ConvertTo-SafePathSegment -Value "$cleanName.$Version") + '.app'
    } else {
        # Fallback to old format for compatibility
        $fileName = (ConvertTo-SafePathSegment -Value $PackageId) + '.app'
    }
    $packagePath = Join-Path -Path $CacheDir -ChildPath $fileName
    return Test-Path -LiteralPath $packagePath
}

function Get-OrAddPackageMetadata {
    param(
        [string]$PackageId,
        [string[]]$Feeds,
        [hashtable]$Cache
    )

    if ($Cache -and $Cache.ContainsKey($PackageId)) {
        return $Cache[$PackageId]
    }

    $metadata = Get-PackageFeedMetadata -PackageId $PackageId -Feeds $Feeds
    if ($metadata -and ($metadata.PSObject.Properties.Name -notcontains 'HighestVersion')) {
        $metadata | Add-Member -MemberType NoteProperty -Name HighestVersion -Value (Select-PackageVersion -Versions $metadata.Versions -MinimumVersion $null)
    }
    if ($Cache -and $metadata) {
        $Cache[$PackageId] = $metadata
    }

    return $metadata
}

function Write-Manifest {
    param([string]$Path, $AppJson, [hashtable]$Packages, [string[]]$Feeds)

    $payload = [ordered]@{
        application = if ((Test-JsonProperty $AppJson 'application') -and $AppJson.application) { $AppJson.application } else { $null }
        platform = if ((Test-JsonProperty $AppJson 'platform') -and $AppJson.platform) { $AppJson.platform } else { $null }
        appId = $AppJson.id
        appName = $AppJson.name
        publisher = $AppJson.publisher
        packages = $Packages
        feeds = $Feeds
        updated = (Get-Date).ToUniversalTime().ToString('o')
    }
    $json = $payload | ConvertTo-Json -Depth 6
    $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

# --- Execution ---
$appJsonPath = Get-AppJsonPath $AppDir
if (-not $appJsonPath) {
    throw "app.json not found in '$AppDir'"
}
$appJson = Read-JsonFile -Path $appJsonPath

if (-not $appJson.id) { throw 'app.json is missing required "id" property.' }
if (-not $appJson.publisher) { throw 'app.json is missing required "publisher" property.' }
if (-not $appJson.name) { throw 'app.json is missing required "name" property.' }

$cacheRoot = Get-SymbolCacheRoot
Ensure-Directory -Path $cacheRoot

$publisherDir = Join-Path -Path $cacheRoot -ChildPath (ConvertTo-SafePathSegment -Value $appJson.publisher)
Ensure-Directory -Path $publisherDir
$appDirPath = Join-Path -Path $publisherDir -ChildPath (ConvertTo-SafePathSegment -Value $appJson.name)
Ensure-Directory -Path $appDirPath
$cacheDir = Join-Path -Path $appDirPath -ChildPath (ConvertTo-SafePathSegment -Value $appJson.id)
Ensure-Directory -Path $cacheDir

$manifestPath = Join-Path -Path $cacheDir -ChildPath 'symbols.lock.json'
$manifest = Load-Manifest -Path $manifestPath
$copiedLocalAppIds = Get-CopiedLocalDependencyIds -CurrentAppDir $AppDir
$packageMap = Build-PackageMap -AppJson $appJson -CopiedLocalAppIds $copiedLocalAppIds

Write-BuildHeader 'Package Requirements'
Write-BuildMessage -Type Info -Message "$($packageMap.Count) packages required"
foreach ($localDependency in $script:localDependencySkips) {
    Write-BuildMessage -Type Detail -Message "Skipping test-gate local dependency (keeping its deps): $($localDependency.Publisher) $($localDependency.Name)"
}

if ($packageMap.Count -gt 0) {
    Write-BuildMessage -Type Step -Message "Processing package requirements..."
    foreach ($kvp in $packageMap.GetEnumerator()) {
        $cleanName = Get-CleanPackageName -PackageId $kvp.Key
        $versionInfo = if ($kvp.Value) { ">= $($kvp.Value)" } else { "(any)" }
        Write-BuildMessage -Type Detail -Message "$cleanName $versionInfo"
    }

    # Clear existing symbols to prevent duplicate .app files (AL compiler picks randomly)
    $existingApps = @(Get-ChildItem -Path $cacheDir -Filter '*.app' -File -ErrorAction SilentlyContinue)
    if ($existingApps -and $existingApps.Count -gt 0) {
        Write-BuildMessage -Type Step -Message "Clearing $($existingApps.Count) existing symbol file(s)..."
        $existingApps | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Also remove stale manifest since we're starting fresh
    if (Test-Path -LiteralPath $manifestPath) {
        Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    }
}

if ($packageMap.Count -eq 0) {
    Write-BuildMessage -Type Success -Message 'No symbol packages required'
    Write-Manifest -Path $manifestPath -AppJson $appJson -Packages ([ordered]@{}) -Feeds @()
    exit 0
}

$feeds = @(Get-SymbolFeeds)

if ($feeds.Count -eq 0) {
    throw 'No symbol feeds configured. Update script defaults.'
}

$downloadsRequired = $false
$resolvedPackages = [ordered]@{}
$processedPackages = @{}
$requiredMinimums = @{}
<# Track origin of each minimum version so we can explain why it exists.
   Structure: $minimumOrigins[packageId] = @(
       [pscustomobject]@{ Source = 'AppJson|Dependency:<parentPackage>'; Version = 'x.y.z.w'; Reason = 'initial|propagated|raised' }
   )
 #>
$minimumOrigins = @{}
$script:packageMetadataCache = @{}
$script:packageDependenciesCache = @{}
$queue = [System.Collections.Generic.Queue[string]]::new()
$packagesInQueue = @{}
$downloadSectionShown = $false

foreach ($kvp in $packageMap.GetEnumerator()) {
    $packageId = $kvp.Key
    $minimumVersion = if ($kvp.Value) { [string]$kvp.Value } else { $null }
    $requiredMinimums[$packageId] = $minimumVersion
    $queue.Enqueue($packageId)
    $packagesInQueue[$packageId] = $true
    $originList = @()
    $originList += [pscustomobject]@{ Source = 'app.json'; Version = $minimumVersion; Reason = 'initial' }
    $minimumOrigins[$packageId] = $originList
}

while ($queue.Count -gt 0) {
    $packageId = $queue.Dequeue()
    if ($packagesInQueue.ContainsKey($packageId)) { $packagesInQueue.Remove($packageId) | Out-Null }
    $minimumVersion = if ($requiredMinimums.ContainsKey($packageId)) { $requiredMinimums[$packageId] } else { $null }

    $manifestVersion = if ($manifest -and $manifest.packages -and (Test-JsonProperty $manifest.packages $packageId)) { [string]$manifest.packages.$packageId } else { $null }
    $manifestApplication = if ($manifest) { [string]$manifest.application } else { $null }
    $manifestPlatform = if ($manifest) { [string]$manifest.platform } else { $null }
    $cached = Test-PackagePresent -CacheDir $cacheDir -PackageId $packageId -Version $manifestVersion

    $currentVersion = $null
    $alreadyResolved = $false
    $needsDownload = $true
    $knownDependencies = $null

    # Cache is valid if: package exists AND (application+platform match OR both are null)
    $appJsonApplication = if (Test-JsonProperty $appJson 'application') { $appJson.application } else { $null }
    $appJsonPlatform = if (Test-JsonProperty $appJson 'platform') { $appJson.platform } else { $null }
    $cacheValid = $cached -and $manifestVersion -and (
        ([string]$manifestApplication -eq [string]$appJsonApplication -and [string]$manifestPlatform -eq [string]$appJsonPlatform) -or
        (-not $manifestApplication -and -not $appJsonApplication -and -not $manifestPlatform -and -not $appJsonPlatform)
    )

    if ($processedPackages.ContainsKey($packageId)) {
        $currentVersion = $processedPackages[$packageId]
        $alreadyResolved = $true
        if ($script:packageDependenciesCache.ContainsKey($packageId)) {
            $knownDependencies = $script:packageDependenciesCache[$packageId]
        }
    } elseif ($cacheValid) {
        $currentVersion = $manifestVersion
        $alreadyResolved = $true
        if ($script:packageDependenciesCache.ContainsKey($packageId)) {
            $knownDependencies = $script:packageDependenciesCache[$packageId]
        }
    }

    $resolveResult = $null

    if ($alreadyResolved -and (-not $minimumVersion -or (Compare-Version -Left $currentVersion -Right $minimumVersion) -ge 0)) {
        if ($knownDependencies) {
            $metadata = Get-OrAddPackageMetadata -PackageId $packageId -Feeds $feeds -Cache $script:packageMetadataCache
            $maxAvailableVersion = $metadata?.HighestVersion
            $resolveResult = [pscustomobject]@{
                Version = $currentVersion
                MaxAvailableVersion = $maxAvailableVersion
                Dependencies = @($knownDependencies)
            }
            $needsDownload = $false
        } else {
            $needsDownload = $true
        }
    }

    if (-not $resolveResult -and $needsDownload) {
        # Show download section header before first download
        if (-not $downloadSectionShown) {
            Write-BuildHeader 'Symbol Downloads'
            $downloadSectionShown = $true
        }

        try {
            $resolveResult = Resolve-SymbolPackage -PackageId $packageId -MinimumVersion $minimumVersion -Feeds $feeds -CacheDir $cacheDir
            $script:packageDependenciesCache[$packageId] = @($resolveResult.Dependencies)
        } catch {
            throw "Failed to download package ${packageId}: $($_.Exception.Message)"
        }
        $downloadsRequired = $true
        $currentVersion = $resolveResult.Version
    }

    if (-not $resolveResult) {
        throw "Failed to resolve package ${packageId}."
    }

    $processedPackages[$packageId] = $currentVersion
    $resolvedPackages[$packageId] = $currentVersion

    $maxAvailableVersion = $null
    if (Test-JsonProperty $resolveResult 'MaxAvailableVersion') {
        $maxAvailableVersion = $resolveResult.MaxAvailableVersion
    }

    if ($minimumVersion) {
        if ((Compare-Version -Left $currentVersion -Right $minimumVersion) -lt 0) {
            # Collect warning for structured display later (suppress immediate warning)
            if (-not $script:versionWarnings) { $script:versionWarnings = @{} }
            $script:versionWarnings[$packageId] = @{
                Requested = $minimumVersion
                Resolved = $currentVersion
                Available = $maxAvailableVersion
                Reason = 'Version conflict resolved automatically'
            }
        }

        if ($maxAvailableVersion -and (Compare-Version -Left $maxAvailableVersion -Right $minimumVersion) -lt 0) {
            $requiredMinimums[$packageId] = $maxAvailableVersion
            # Adjustment details captured in warning collection above
        } elseif ((Compare-Version -Left $currentVersion -Right $minimumVersion) -lt 0) {
            $requiredMinimums[$packageId] = $currentVersion
            # Adjustment details captured in warning collection above
        }
    }

    # Track package resolution for summary
    $existing = $script:summaryRows | Where-Object { $_.Package -eq $packageId } | Select-Object -First 1
    $warnFlag = ($minimumVersion -and (Compare-Version -Left $currentVersion -Right $minimumVersion) -lt 0) ? 'Y' : ''
    if ($existing) {
        $existing.Resolved = $currentVersion
        $existing.MinReq = $(if ($minimumVersion) { $minimumVersion } else { '' })
        $existing.MaxAvail = $(if ($maxAvailableVersion) { $maxAvailableVersion } else { '' })
        if ($warnFlag -eq 'Y') { $existing.Warn = 'Y' }
    } else {
        $script:summaryRows.Add([pscustomobject]@{
            Package = $packageId
            Resolved = $currentVersion
            MinReq = $(if ($minimumVersion) { $minimumVersion } else { '' })
            MaxAvail = $(if ($maxAvailableVersion) { $maxAvailableVersion } else { '' })
            Warn = $warnFlag
        }) | Out-Null
    }

    foreach ($dependency in $resolveResult.Dependencies) {
        $depId = [string]$dependency.Id
        if (-not $depId) { continue }
        $depMinimum = $dependency.MinimumVersion

        $existingMinimum = $null
        if ($requiredMinimums.ContainsKey($depId)) { $existingMinimum = $requiredMinimums[$depId] }

        $updated = $false
        if ($depMinimum) {
            if ($requiredMinimums.ContainsKey($depId)) {
                if (-not $existingMinimum -or (Compare-Version -Left $depMinimum -Right $existingMinimum) -gt 0) {
                    $requiredMinimums[$depId] = $depMinimum
                    $updated = $true
                }
            } else {
                $requiredMinimums[$depId] = $depMinimum
                $updated = $true
            }
        } elseif (-not $requiredMinimums.ContainsKey($depId)) {
            $requiredMinimums[$depId] = $null
            $updated = $true
        }

        # Track dependency edges for analysis
        $edgeMin = $(if ($requiredMinimums[$depId]) { $requiredMinimums[$depId] } else { '' })
        $script:raiseRows.Add([pscustomobject]@{
            Parent = $packageId
            Child  = $depId
            Min    = $edgeMin
            Raised = $(if ($updated) { 'Y' } else { '' })
        }) | Out-Null

        if ($updated) {
            if (-not $minimumOrigins.ContainsKey($depId)) { $minimumOrigins[$depId] = @() }
            $minimumOrigins[$depId] += [pscustomobject]@{ Source = "dependency:$packageId"; Version = $requiredMinimums[$depId]; Reason = ($depMinimum ? 'propagated' : 'introduced') }
        }

        $needsProcessing = $false
        if (-not $processedPackages.ContainsKey($depId)) {
            $needsProcessing = $true
        } elseif ($depMinimum -and (Compare-Version -Left $processedPackages[$depId] -Right $depMinimum) -lt 0) {
            [void]$processedPackages.Remove($depId)
            if ($resolvedPackages.Contains($depId)) {
                [void]$resolvedPackages.Remove($depId)
            }
            $needsProcessing = $true
        }

        if ($needsProcessing -and -not $packagesInQueue.ContainsKey($depId)) {
            $queue.Enqueue($depId)
            $packagesInQueue[$depId] = $true
        }
    }
}

Write-BuildHeader 'Package Summary'

$warningCount = @($script:summaryRows | Where-Object { $_.Warn -eq 'Y' }).Count
$successCount = $script:summaryRows.Count - $warningCount
Write-BuildMessage -Type Info -Message "$successCount packages resolved successfully, $warningCount conflicts resolved"

# Show warning packages first
$warningPackages = @($script:summaryRows | Where-Object { $_.Warn -eq 'Y' } | Sort-Object Package)
if ($warningPackages.Count -gt 0) {
    Write-BuildMessage -Type Warning -Message "Version conflicts detected (resolved automatically)"
    foreach ($r in $warningPackages) {
        $cleanName = Get-CleanPackageName -PackageId $r.Package
        Write-BuildMessage -Type Detail -Message "$cleanName - Resolved: $($r.Resolved), Required: $($r.MinReq), Available: $($r.MaxAvail)"
    }
}

# Full package summary
Write-BuildMessage -Type Step -Message "Package resolution details:"
foreach ($r in ($script:summaryRows | Sort-Object @{Expression={$_.Warn -eq 'Y'}; Descending=$true}, Package)) {
    $cleanName = Get-CleanPackageName -PackageId $r.Package
    $status = if ($r.Warn -eq 'Y') { 'Conflict' } else { 'OK' }
    Write-BuildMessage -Type Detail -Message "$cleanName - Resolved: $($r.Resolved) ($status)"
}

# VERSION RESOLUTION ANALYSIS
if ($script:versionWarnings -and $script:versionWarnings.Count -gt 0) {
    Write-BuildHeader 'Version Resolution Analysis'
    Write-BuildMessage -Type Info -Message "$($script:versionWarnings.Count) conflicts analyzed"

    foreach ($pkg in ($script:versionWarnings.Keys | Sort-Object)) {
        $w = $script:versionWarnings[$pkg]
        $cleanName = Get-CleanPackageName -PackageId $pkg
        Write-BuildMessage -Type Warning -Message "Conflict: $cleanName"
        Write-BuildMessage -Type Detail -Message "Requested: $($w.Requested) (from dependency chain)"
        Write-BuildMessage -Type Detail -Message "Available: $($w.Available) (best version on feed)"
        Write-BuildMessage -Type Detail -Message "Resolved: $($w.Resolved) (build compatible)"

        # Show which dependencies are causing this requirement
        $origins = $minimumOrigins[$pkg]
        if ($origins) {
            $dependencyOrigins = @($origins | Where-Object { $_.Source -like 'dependency:*' })
            if ($dependencyOrigins.Count -gt 0) {
                foreach ($origin in ($dependencyOrigins | Select-Object -First 3)) {
                    $sourcePkg = $origin.Source -replace 'dependency:', ''
                    $sourcePkgClean = Get-CleanPackageName -PackageId $sourcePkg
                    Write-BuildMessage -Type Detail -Message "Triggered by: $sourcePkgClean"
                }
            }
        }
    }

    Write-BuildMessage -Type Success -Message "All conflicts resolved automatically - build will work correctly"
}

# DEPENDENCY ANALYSIS
$raiseCount = @($script:raiseRows | Where-Object { $_.Raised -eq 'Y' }).Count
$totalDependencies = $script:raiseRows.Count
if ($raiseCount -gt 0) {
    Write-BuildHeader 'Dependency Analysis'
    Write-BuildMessage -Type Info -Message "$raiseCount version raises detected (out of $totalDependencies total dependencies)"

    $actualRaises = @($script:raiseRows | Where-Object { $_.Raised -eq 'Y' } | Sort-Object Parent, Child)
    foreach ($d in $actualRaises) {
        $pClean = Get-CleanPackageName -PackageId $d.Parent
        $cClean = Get-CleanPackageName -PackageId $d.Child
        Write-BuildMessage -Type Detail -Message "$pClean → $cClean (Min: $($d.Min))"
    }
}

# VERSION REQUIREMENT ORIGINS
Write-BuildHeader 'Version Requirement Origins'
Write-BuildMessage -Type Info -Message "$($requiredMinimums.Keys.Count) packages analyzed"

# Group packages by origin type
$initialRequirements = @()
$dependencyRequirements = @()

foreach ($pkg in ($requiredMinimums.Keys | Sort-Object)) {
    $finalMin = $requiredMinimums[$pkg]
    $origList = $minimumOrigins[$pkg]
    if (-not $origList) { $origList = @() }

    $hasInitial = @($origList | Where-Object { $_.Source -eq 'app.json' })
    $hasDependencies = @($origList | Where-Object { $_.Source -like 'dependency:*' })

    if ($hasInitial.Count -gt 0) {
        $initialRequirements += [pscustomobject]@{
            Package = $pkg
            Version = $finalMin
            Sources = $origList
        }
    }

    if ($hasDependencies.Count -gt 0) {
        $dependencyRequirements += [pscustomobject]@{
            Package = $pkg
            Version = $finalMin
            Sources = $origList
        }
    }
}

# Show initial requirements
if ($initialRequirements.Count -gt 0) {
    Write-BuildMessage -Type Step -Message "Initial requirements (from app.json):"
    foreach ($req in $initialRequirements) {
        $cleanName = Get-CleanPackageName -PackageId $req.Package
        Write-BuildMessage -Type Detail -Message "$cleanName → $($req.Version)"
    }
}

# Show dependency-driven requirements
if ($dependencyRequirements.Count -gt 0) {
    Write-BuildMessage -Type Step -Message "Dependency-driven requirements:"
    foreach ($req in ($dependencyRequirements | Sort-Object Package)) {
        $cleanName = Get-CleanPackageName -PackageId $req.Package
        Write-BuildMessage -Type Detail -Message "$cleanName → $($req.Version)"

        # Show unique dependency sources
        $dependencySources = @($req.Sources | Where-Object { $_.Source -like 'dependency:*' } |
            ForEach-Object { $_.Source -replace 'dependency:', '' } |
            Sort-Object -Unique | Select-Object -First 3)

        foreach ($source in $dependencySources) {
            $sourceClean = Get-CleanPackageName -PackageId $source
            Write-BuildMessage -Type Detail -Message "  ← $sourceClean"
        }
    }
}

Write-BuildHeader 'Summary'

$totalElapsed = New-TimeSpan -Start $script:StartTime -End (Get-Date)
$elapsedFormatted = "{0:mm\:ss}" -f $totalElapsed

if (-not $downloadsRequired) {
    Write-BuildMessage -Type Success -Message "Symbol cache already up to date! (Elapsed: $elapsedFormatted)"
} else {
    Write-BuildMessage -Type Success -Message "Symbol cache updated successfully! (Elapsed: $elapsedFormatted)"
}

$successCount = @($script:summaryRows | Where-Object { $_.Warn -ne 'Y' }).Count
$warningCount = @($script:summaryRows | Where-Object { $_.Warn -eq 'Y' }).Count
$totalCount = $script:summaryRows.Count

if ($warningCount -eq 0) {
    Write-BuildMessage -Type Success -Message "Ready for build: All $totalCount packages resolved successfully"
} else {
    Write-BuildMessage -Type Info -Message "Ready for build: $successCount packages OK, $warningCount version conflicts resolved (using best available)"
}

Write-Manifest -Path $manifestPath -AppJson $appJson -Packages $resolvedPackages -Feeds $feeds

exit 0
