#Requires -Version 7.2

<#
.SYNOPSIS
    Business Central symbol feed client and .app manifest reader.

.DESCRIPTION
    One client for the two public symbol feeds (MSSymbols, then AppSourceSymbols): the flat2
    version lookup, the version pick, the .nupkg download, the .nuspec dependency read, and the
    .app extraction. A feed root can also be a local directory laid out as the flat2 paths
    (flat2/<id>/index.json, flat2/<id>/<version>/<id>.<version>.nupkg, package id lower-cased).
    Read-AppManifest reads NavxManifest.xml from a .app file without the AL compiler.
    Test-ReleasePin checks an AppSourceCop.json version against the latest Release on AppSourceSymbols.

.NOTES
    Import this module alongside common.psm1: the download and extract functions call
    Write-BuildMessage, ConvertTo-SafePathSegment, and New-TemporaryDirectory at run time.
    Optional environment variables, one feed root override each (a URL or a local directory):
      - ALBT_MSSYMBOLS_FEED: replaces the MSSymbols feed.
      - ALBT_APPSOURCESYMBOLS_FEED: replaces the AppSourceSymbols feed.
#>

Set-StrictMode -Version Latest

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# =============================================================================
# Feeds
# =============================================================================

$script:PublicSymbolFeeds = [ordered]@{
    MSSymbols         = 'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSSymbols/nuget/v3/index.json'
    AppSourceSymbols  = 'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json'
}

$script:SymbolFeedOverrideVariables = @{
    MSSymbols        = 'ALBT_MSSYMBOLS_FEED'
    AppSourceSymbols = 'ALBT_APPSOURCESYMBOLS_FEED'
}

function Get-SymbolFeeds {
    <#
    .SYNOPSIS
        The symbol feed roots in lookup order: MSSymbols, then AppSourceSymbols.
    .DESCRIPTION
        Each feed is its public URL unless its ALBT_* environment variable names another root,
        a URL or a local directory. With -Feed, returns only that feed's root.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [ValidateSet('MSSymbols', 'AppSourceSymbols')]
        [string[]]$Feed = @('MSSymbols', 'AppSourceSymbols')
    )

    foreach ($name in $Feed) {
        $override = [Environment]::GetEnvironmentVariable($script:SymbolFeedOverrideVariables[$name])
        if ([string]::IsNullOrWhiteSpace($override)) {
            $script:PublicSymbolFeeds[$name]
        } else {
            $override.Trim()
        }
    }
}

function Test-LocalFeedRoot {
    param([string]$Feed)
    return $Feed -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://'
}

function Get-FeedRootBase {
    param([string]$Feed)
    $base = $Feed.Trim()
    if ($base.EndsWith('/index.json')) {
        $base = $base.Substring(0, $base.Length - '/index.json'.Length)
    }
    return $base.TrimEnd('/', '\')
}

# =============================================================================
# Versions
# =============================================================================

function Get-CleanPackageName {
    param([string]$PackageId)
    # Remove .symbols.<guid> pattern first (for third-party packages)
    $cleaned = $PackageId -replace '\.symbols\.[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', ''
    # Remove .symbols (for Microsoft packages)
    $cleaned = $cleaned -replace '\.symbols$', ''
    return $cleaned
}

function Compare-Version {
    param(
        [string]$Left,
        [string]$Right
    )
    if (-not $Left -and -not $Right) { return 0 }
    if (-not $Left) { return -1 }
    if (-not $Right) { return 1 }

    $normalize = {
        param([string]$v)
        $parts = ($v -split '\.') | Where-Object { $_ -ne '' }
        # Take first 4, pad with zeros
        $nums = @()
        for ($i = 0; $i -lt 4; $i++) {
            if ($i -lt $parts.Count) {
                $segment = $parts[$i]
                $n = 0
                if (-not [int]::TryParse($segment, [ref]$n)) {
                    # Non-numeric; fallback to original string compare later
                    return $null
                }
                $nums += $n
            } else {
                $nums += 0
            }
        }
        return ,$nums
    }

    $lArr = & $normalize $Left
    $rArr = & $normalize $Right

    if ($lArr -and $rArr) {
        for ($i=0; $i -lt 4; $i++) {
            if ($lArr[$i] -lt $rArr[$i]) { return -1 }
            if ($lArr[$i] -gt $rArr[$i]) { return 1 }
        }
        return 0
    }

    return [string]::Compare($Left, $Right, $true)
}

function ConvertTo-VersionComparable {
    param([string]$Version)
    if (-not $Version) { return $null }
    $parts = ($Version -split '\.') | Where-Object { $_ -ne '' }
    $nums = @()
    for ($i = 0; $i -lt 4; $i++) {
        if ($i -lt $parts.Count) {
            $segment = $parts[$i]
            $n = 0
            if (-not [int]::TryParse($segment, [ref]$n)) { return $Version }
            $nums += $n
        } else { $nums += 0 }
    }
    # Construct System.Version with 4 components for consistent sorting
    try { return [System.Version]::new($nums[0], $nums[1], $nums[2], $nums[3]) } catch { return $Version }
}

function Select-PackageVersion {
    param(
        [string[]]$Versions,
        [string]$MinimumVersion
    )

    if (-not $Versions -or $Versions.Count -eq 0) { return $null }

    $ordered = $Versions |
        Sort-Object -Descending -Property { ConvertTo-VersionComparable $_ }

    foreach ($version in $ordered) {
        if (-not $MinimumVersion -or (Compare-Version -Left $version -Right $MinimumVersion) -ge 0) {
            return $version
        }
    }

    return $ordered[0]
}

function Get-MinimumVersionFromRange {
    param([string]$Range)

    if (-not $Range) { return $null }

    $trimmed = $Range.Trim()
    if (-not $trimmed) { return $null }

    if ($trimmed.StartsWith('[') -or $trimmed.StartsWith('(')) {
        $trimmed = $trimmed.TrimStart('[', '(').TrimEnd(']', ')')
        $parts = $trimmed.Split(',')
        if ($parts.Count -eq 0 -or [string]::IsNullOrWhiteSpace($parts[0])) { return $null }
        return $parts[0].Trim()
    }

    return $trimmed
}

# =============================================================================
# Package lookup
# =============================================================================

function New-FeedLookupResult {
    param(
        [Parameter(Mandatory)][ValidateSet('Listed', 'NotListed', 'Unreadable')][string]$Status,
        [Parameter(Mandatory)][string]$Feed,
        [string[]]$Versions = @(),
        [string]$Message = ''
    )
    return [pscustomobject]@{
        Status   = $Status
        Feed     = $Feed
        Versions = $Versions
        Message  = $Message
    }
}

function Find-PackageInFeed {
    <#
    .SYNOPSIS
        Looks one package up in one feed root and says why it was not found.
    .DESCRIPTION
        Returns Status 'Listed' (Feed, Versions), 'NotListed' (the root is readable and does not
        list the package: HTTP 404, or no flat2 index in a local root), or 'Unreadable' (the root
        cannot be read: an HTTP failure other than 404, or a local root directory that does not
        exist). Message carries the reason for 'Unreadable'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Feed
    )

    $packageIdLower = $PackageId.ToLowerInvariant()
    $baseUrl = Get-FeedRootBase -Feed $Feed

    if (Test-LocalFeedRoot -Feed $baseUrl) {
        if (-not (Test-Path -LiteralPath $baseUrl -PathType Container)) {
            return New-FeedLookupResult -Status Unreadable -Feed $baseUrl -Message "Local feed root '$baseUrl' does not exist."
        }
        $indexPath = Join-Path -Path $baseUrl -ChildPath (Join-Path 'flat2' (Join-Path $packageIdLower 'index.json'))
        if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
            return New-FeedLookupResult -Status NotListed -Feed $baseUrl
        }
        try {
            $response = Get-Content -LiteralPath $indexPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            return New-FeedLookupResult -Status Unreadable -Feed $baseUrl -Message "Failed to read ${indexPath}: $($_.Exception.Message)"
        }
    } else {
        $indexUrl = "{0}/flat2/{1}/index.json" -f $baseUrl, $packageIdLower
        try {
            $response = Invoke-RestMethod -Method Get -Uri $indexUrl -ErrorAction Stop
        } catch {
            $httpResponse = $_.Exception.PSObject.Properties['Response']
            if ($httpResponse -and $httpResponse.Value -and [int]$httpResponse.Value.StatusCode -eq 404) {
                return New-FeedLookupResult -Status NotListed -Feed $baseUrl
            }
            return New-FeedLookupResult -Status Unreadable -Feed $baseUrl -Message "Failed to query ${indexUrl}: $($_.Exception.Message)"
        }
    }

    $versionsProperty = if ($response) { $response.PSObject.Properties['versions'] } else { $null }
    if ($versionsProperty -and $versionsProperty.Value) {
        return New-FeedLookupResult -Status Listed -Feed $baseUrl -Versions ([string[]]$versionsProperty.Value)
    }

    return New-FeedLookupResult -Status NotListed -Feed $baseUrl
}

function Get-PackageFeedMetadata {
    param(
        [string]$PackageId,
        [string[]]$Feeds
    )

    foreach ($feed in $Feeds) {
        if ([string]::IsNullOrWhiteSpace($feed)) { continue }
        $lookup = Find-PackageInFeed -PackageId $PackageId -Feed $feed
        switch ($lookup.Status) {
            'Listed' {
                return [pscustomobject]@{
                    Feed = $lookup.Feed
                    Versions = $lookup.Versions
                }
            }
            'Unreadable' { Write-Warning $lookup.Message }
        }
    }

    return $null
}

function Download-PackageNupkg {
    param(
        [string]$Feed,
        [string]$PackageId,
        [string]$Version,
        [string]$DestinationDirectory
    )

    $packageIdLower = $PackageId.ToLowerInvariant()
    $fileName = "{0}.{1}.nupkg" -f $packageIdLower, $Version
    $feedBase = Get-FeedRootBase -Feed $Feed
    $isLocalFeed = Test-LocalFeedRoot -Feed $feedBase
    $downloadUrl = if ($isLocalFeed) {
        Join-Path -Path $feedBase -ChildPath (Join-Path 'flat2' (Join-Path $packageIdLower (Join-Path $Version $fileName)))
    } else {
        "{0}/flat2/{1}/{2}/{3}" -f $feedBase, $packageIdLower, $Version, $fileName
    }
    $destinationPath = Join-Path -Path $DestinationDirectory -ChildPath $fileName

    $cleanPackageName = Get-CleanPackageName -PackageId $PackageId
    Write-BuildMessage -Type Step -Message "Downloading: $cleanPackageName"
    Write-BuildMessage -Type Detail -Message "Version: $Version"
    Write-BuildMessage -Type Detail -Message "Source: $Feed"

    try {
        if ($isLocalFeed) {
            Copy-Item -LiteralPath $downloadUrl -Destination $destinationPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop | Out-Null
        }
    } catch {
        throw "Failed to download package $PackageId@$Version from ${downloadUrl}: $($_.Exception.Message)"
    }

    if ((Get-Item -LiteralPath $destinationPath).Length -eq 0) {
        throw "Downloaded package $PackageId@$Version from $downloadUrl is empty."
    }

    return $destinationPath
}

function Get-PackageDependenciesFromArchive {
    param([System.IO.Compression.ZipArchive]$Archive)

    $nuspecEntry = $Archive.Entries | Where-Object { $_.FullName -match '\.nuspec$' } | Select-Object -First 1
    if (-not $nuspecEntry) { return @() }

    $reader = New-Object System.IO.StreamReader($nuspecEntry.Open())
    try {
        $content = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }

    if (-not $content) { return @() }

    try {
        $xml = [xml]$content
    } catch {
        Write-Warning "Failed to parse nuspec for package: $($_.Exception.Message)"
        return @()
    }

    $namespaceUri = $xml.DocumentElement.NamespaceURI
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    if ($namespaceUri) {
        $namespaceManager.AddNamespace('ns', $namespaceUri)
    }

    $results = New-Object System.Collections.Generic.List[object]

    if ($namespaceUri) {
        $directDependencies = $xml.SelectNodes('//ns:package/ns:metadata/ns:dependencies/ns:dependency', $namespaceManager)
        foreach ($dep in $directDependencies) {
            if (-not $dep) { continue }
            $id = [string]$dep.Attributes['id']?.Value
            if (-not $id) { continue }
            $range = [string]$dep.Attributes['version']?.Value
            $minVersion = Get-MinimumVersionFromRange -Range $range
            $results.Add([pscustomobject]@{ Id = $id; MinimumVersion = $minVersion }) | Out-Null
        }

        $groupDependencies = $xml.SelectNodes('//ns:package/ns:metadata/ns:dependencies/ns:group/ns:dependency', $namespaceManager)
        foreach ($dep in $groupDependencies) {
            if (-not $dep) { continue }
            $id = [string]$dep.Attributes['id']?.Value
            if (-not $id) { continue }
            $range = [string]$dep.Attributes['version']?.Value
            $minVersion = Get-MinimumVersionFromRange -Range $range
            $results.Add([pscustomobject]@{ Id = $id; MinimumVersion = $minVersion }) | Out-Null
        }
    } else {
        $directDependencies = $xml.SelectNodes('//package/metadata/dependencies/dependency')
        foreach ($dep in $directDependencies) {
            if (-not $dep) { continue }
            $id = [string]$dep.Attributes['id']?.Value
            if (-not $id) { continue }
            $range = [string]$dep.Attributes['version']?.Value
            $minVersion = Get-MinimumVersionFromRange -Range $range
            $results.Add([pscustomobject]@{ Id = $id; MinimumVersion = $minVersion }) | Out-Null
        }

        $groupDependencies = $xml.SelectNodes('//package/metadata/dependencies/group/dependency')
        foreach ($dep in $groupDependencies) {
            if (-not $dep) { continue }
            $id = [string]$dep.Attributes['id']?.Value
            if (-not $id) { continue }
            $range = [string]$dep.Attributes['version']?.Value
            $minVersion = Get-MinimumVersionFromRange -Range $range
            $results.Add([pscustomobject]@{ Id = $id; MinimumVersion = $minVersion }) | Out-Null
        }
    }

    return $results.ToArray()
}

function Extract-SymbolApp {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$PackageId,
        [string]$Version,
        [string]$OutputDirectory
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $appEntry = $Archive.Entries | Where-Object { $_.FullName.ToLowerInvariant().EndsWith('.app') } | Select-Object -First 1
    if (-not $appEntry) {
        Write-Warning "No .app file found inside package $PackageId."
        return $null
    }

    # Create filename using clean package name + version instead of full package ID
    $cleanName = Get-CleanPackageName -PackageId $PackageId
    $destinationName = (ConvertTo-SafePathSegment -Value "$cleanName.$Version") + '.app'
    $destinationPath = Join-Path -Path $OutputDirectory -ChildPath $destinationName

    $sourceStream = $appEntry.Open()
    try {
        $fileStream = [System.IO.File]::Open($destinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $sourceStream.CopyTo($fileStream)
        } finally {
            $fileStream.Dispose()
        }
    } finally {
        $sourceStream.Dispose()
    }

    $cleanPackageName = Get-CleanPackageName -PackageId $PackageId
    Write-BuildMessage -Type Success -Message "Extracted: $cleanPackageName"
    Write-BuildMessage -Type Detail -Message "Location: $destinationPath"

    return $destinationPath
}

function Resolve-SymbolPackage {
    param(
        [string]$PackageId,
        [string]$MinimumVersion,
        [string[]]$Feeds,
        [string]$CacheDir
    )

    $metadata = Get-PackageFeedMetadata -PackageId $PackageId -Feeds $Feeds
    if (-not $metadata) {
        throw "Unable to locate package $PackageId on the configured feeds."
    }

    $selectedVersion = Select-PackageVersion -Versions $metadata.Versions -MinimumVersion $MinimumVersion
    if (-not $selectedVersion) {
        throw "No available versions found for package $PackageId"
    }

    $maxAvailableVersion = Select-PackageVersion -Versions $metadata.Versions -MinimumVersion $null

    $tempDir = New-TemporaryDirectory
    $downloadedNupkg = $null
    try {
        $downloadedNupkg = Download-PackageNupkg -Feed $metadata.Feed -PackageId $PackageId -Version $selectedVersion -DestinationDirectory $tempDir
        $archive = [System.IO.Compression.ZipFile]::OpenRead($downloadedNupkg)
        try {
            $appPath = Extract-SymbolApp -Archive $archive -PackageId $PackageId -Version $selectedVersion -OutputDirectory $CacheDir
            if (-not $appPath) {
                throw "Package $PackageId@$selectedVersion did not contain a .app file."
            }

            $dependencies = Get-PackageDependenciesFromArchive -Archive $archive

            $uniqueDependencies = @{}
            foreach ($dependency in $dependencies) {
                $depId = [string]$dependency.Id
                if (-not $depId) { continue }
                $depMinimum = $dependency.MinimumVersion

                if ($uniqueDependencies.ContainsKey($depId)) {
                    $existing = $uniqueDependencies[$depId]
                    if ($depMinimum -and (-not $existing.MinimumVersion -or (Compare-Version -Left $depMinimum -Right $existing.MinimumVersion) -gt 0)) {
                        $uniqueDependencies[$depId] = [pscustomobject]@{ Id = $depId; MinimumVersion = $depMinimum }
                    }
                } else {
                    $uniqueDependencies[$depId] = [pscustomobject]@{ Id = $depId; MinimumVersion = $depMinimum }
                }
            }

            return [pscustomobject]@{
                Version = $selectedVersion
                MaxAvailableVersion = $maxAvailableVersion
                Dependencies = @($uniqueDependencies.Values)
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        if ($downloadedNupkg -and (Test-Path -LiteralPath $downloadedNupkg)) {
            Remove-Item -LiteralPath $downloadedNupkg -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# .app manifest
# =============================================================================

function Read-AppManifest {
    <#
    .SYNOPSIS
        Reads NavxManifest.xml from a .app file without the AL compiler.
    .DESCRIPTION
        A .app file is a NAVX header in front of a zip. The header's second field is its own
        length, so the zip starts there. Returns Id, Name, Publisher, and Version exactly as the
        manifest carries them, so a 4-part version keeps its trailing zero. Throws, naming the
        file, when it is no .app file or holds no NavxManifest.xml.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "App file '$Path' does not exist."
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $headerLength = if ($bytes.Length -ge 8) { [BitConverter]::ToInt32($bytes, 4) } else { 0 }
    $hasNavxHeader = $bytes.Length -ge 8 -and
        $bytes[0] -eq 0x4E -and $bytes[1] -eq 0x41 -and $bytes[2] -eq 0x56 -and $bytes[3] -eq 0x58 -and
        $headerLength -ge 8 -and $headerLength -lt $bytes.Length
    if (-not $hasNavxHeader) {
        throw "File '$Path' is not a .app file: no NAVX header."
    }

    $zipStream = [System.IO.MemoryStream]::new($bytes, $headerLength, $bytes.Length - $headerLength, $false)
    try {
        $archive = try {
            [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Read)
        } catch {
            throw "File '$Path' is not a .app file: its zip cannot be read: $($_.Exception.Message)"
        }
        try {
            $entry = $archive.GetEntry('NavxManifest.xml')
            if (-not $entry) {
                $entry = $archive.Entries | Where-Object { $_.FullName -ieq 'NavxManifest.xml' } | Select-Object -First 1
            }
            if (-not $entry) {
                throw "File '$Path' has no NavxManifest.xml."
            }

            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8)
            try {
                $xml = [xml]$reader.ReadToEnd()
            } catch {
                throw "File '$Path' has an unreadable NavxManifest.xml: $($_.Exception.Message)"
            } finally {
                $reader.Dispose()
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $zipStream.Dispose()
    }

    $app = $xml.SelectSingleNode("//*[local-name()='App']")
    if (-not $app) {
        throw "File '$Path' has a NavxManifest.xml with no App element."
    }

    return [pscustomobject]@{
        Id        = [string]$app.GetAttribute('Id')
        Name      = [string]$app.GetAttribute('Name')
        Publisher = [string]$app.GetAttribute('Publisher')
        Version   = [string]$app.GetAttribute('Version')
    }
}

# =============================================================================
# Release pin
# =============================================================================

function New-ReleasePinResult {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [string]$LatestRelease,
        [Parameter(Mandatory)][string]$Message
    )
    return [pscustomobject]@{
        ExitCode      = $ExitCode
        LatestRelease = if ($LatestRelease) { $LatestRelease } else { $null }
        Message       = $Message
    }
}

function Test-ReleasePin {
    <#
    .SYNOPSIS
        Checks a committed AppSourceCop.json version against the latest Release on AppSourceSymbols.
    .DESCRIPTION
        Looks {Publisher}.{Name without spaces}.symbols.{AppId} up on AppSourceSymbols with no token,
        takes the latest Release version the feed lists, and reads the 4-part version from the
        manifest of the .app inside that package. The NuGet version trims a trailing zero, so the
        pin is compared with the manifest, never with the NuGet version.
        Returns ExitCode, LatestRelease, and Message: 0 when the pin equals the latest Release, 4
        when it differs, when the feed lists no Release of the app, or when app.json names no
        app, and 1 when the feed or the package cannot be read.
    .PARAMETER AppJson
        The parsed app.json: id, name, and publisher.
    .PARAMETER Pin
        The version AppSourceCop.json pins.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]$AppJson,
        [Parameter(Mandatory)][string]$Pin
    )

    $exit = Get-ExitCode
    $app = @{}
    foreach ($key in 'id', 'name', 'publisher') {
        $property = if ($AppJson) { $AppJson.PSObject.Properties[$key] } else { $null }
        $app[$key] = if ($property) { [string]$property.Value } else { '' }
    }
    if (-not ($app.id -and $app.name -and $app.publisher)) {
        return New-ReleasePinResult -ExitCode $exit.Contract -Message "app.json is missing or names no id, name, and publisher; AppSourceCop.json pins $Pin."
    }

    $packageId = '{0}.{1}.symbols.{2}' -f $app.publisher, ($app.name -replace '\s', ''), $app.id
    $feed = Get-SymbolFeeds -Feed AppSourceSymbols
    $lookup = Find-PackageInFeed -PackageId $packageId -Feed $feed
    if ($lookup.Status -eq 'Unreadable') {
        return New-ReleasePinResult -ExitCode $exit.GeneralError -Message "AppSourceSymbols feed '$($lookup.Feed)' cannot be read: $($lookup.Message)"
    }

    # A Release version has no prerelease suffix.
    $releases = @($lookup.Versions | Where-Object { $_ -match '^\d+(\.\d+){1,3}$' })
    if ($lookup.Status -ne 'Listed' -or $releases.Count -eq 0) {
        return New-ReleasePinResult -ExitCode $exit.Contract -Message "AppSourceSymbols lists no Release of $packageId; AppSourceCop.json pins $Pin."
    }
    $latestNuGetVersion = Select-PackageVersion -Versions $releases

    $tempDir = New-TemporaryDirectory
    try {
        $manifest = $null
        try {
            $nupkg = Download-PackageNupkg -Feed $lookup.Feed -PackageId $packageId -Version $latestNuGetVersion -DestinationDirectory $tempDir
            $archive = [System.IO.Compression.ZipFile]::OpenRead($nupkg)
            try {
                $appPath = Extract-SymbolApp -Archive $archive -PackageId $packageId -Version $latestNuGetVersion -OutputDirectory $tempDir
            } finally {
                $archive.Dispose()
            }
            if (-not $appPath) { throw "the package holds no .app file." }
            $manifest = Read-AppManifest -Path $appPath
        } catch {
            return New-ReleasePinResult -ExitCode $exit.GeneralError -Message "Cannot read the latest Release of $packageId ($latestNuGetVersion) from '$($lookup.Feed)': $($_.Exception.Message)"
        }
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $latest = $manifest.Version
    if ($Pin.Trim() -eq $latest) {
        return New-ReleasePinResult -ExitCode $exit.Success -LatestRelease $latest -Message "AppSourceCop.json pins $latest, the latest Release of $packageId on AppSourceSymbols."
    }
    return New-ReleasePinResult -ExitCode $exit.Contract -LatestRelease $latest -Message "AppSourceCop.json pins $Pin, but the latest Release on AppSourceSymbols is $latest. Update version in AppSourceCop.json."
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    # Feeds
    'Get-SymbolFeeds'
    'Find-PackageInFeed'
    'Get-PackageFeedMetadata'

    # Versions
    'Compare-Version'
    'ConvertTo-VersionComparable'
    'Select-PackageVersion'
    'Get-MinimumVersionFromRange'
    'Get-CleanPackageName'

    # Packages
    'Download-PackageNupkg'
    'Get-PackageDependenciesFromArchive'
    'Extract-SymbolApp'
    'Resolve-SymbolPackage'

    # .app manifest
    'Read-AppManifest'

    # Release pin
    'Test-ReleasePin'
)
