#Requires -Version 7.2

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ALRunnerRunTestsRequest {
    <#
        .SYNOPSIS
        Builds the single-line compressed JSON `runTests` request for the al-runner --server NDJSON protocol.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SourcePaths,
        [switch]$Coverage,
        [switch]$PerTestCoverage
    )

    $request = [ordered]@{
        command     = 'runTests'
        sourcePaths = @($SourcePaths)
    }
    if ($Coverage) {
        $request.coverage = $true
    }
    if ($PerTestCoverage) {
        $request.perTestCoverage = $true
    }

    $request | ConvertTo-Json -Compress -Depth 5
}

function Read-ALRunnerRunTestsResponse {
    <#
        .SYNOPSIS
        Reads the al-runner --server NDJSON response stream for a `runTests` request.

        .DESCRIPTION
        Parses per-test `"type":"test"` lines, writes the terminal `"type":"summary"` line
        verbatim to SummaryPath before parsing it (the summary can carry multi-megabyte
        coverage fields and must never be echoed to the console), and throws on a
        `{"error":"..."}` line or on end-of-stream before a summary arrives.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.TextReader]$Reader,
        [Parameter(Mandatory)]
        [string]$SummaryPath
    )

    $tests = [System.Collections.Generic.List[object]]::new()
    $sawSummary = $false

    while ($null -ne ($line = $Reader.ReadLine())) {
        if ($line.StartsWith('{"error"')) {
            throw "al-runner server error: $line"
        }
        elseif ($line.StartsWith('{"type":"summary"')) {
            [IO.File]::WriteAllText($SummaryPath, $line)
            $sawSummary = $true
            break
        }
        elseif ($line.StartsWith('{"type":"test"')) {
            $doc = $null
            try {
                $doc = [System.Text.Json.JsonDocument]::Parse($line)
                $root = $doc.RootElement
                $message = $null
                $messageProp = New-Object System.Text.Json.JsonElement
                if ($root.TryGetProperty('message', [ref]$messageProp)) {
                    $message = $messageProp.GetString()
                }
                $tests.Add([PSCustomObject]@{
                        Name       = $root.GetProperty('name').GetString()
                        Status     = $root.GetProperty('status').GetString()
                        DurationMs = $root.GetProperty('durationMs').GetInt64()
                        Message    = $message
                    })
            }
            finally {
                if ($doc) { $doc.Dispose() }
            }
        }
    }

    if (-not $sawSummary) {
        throw 'al-runner server stream ended before summary'
    }

    # The summary line can carry multi-megabyte perTestCoverage payloads (tens of
    # MB with -PerTestCoverage). ConvertFrom-Json would materialize the whole tree
    # as PSCustomObjects; parse the file we just wrote with JsonDocument instead,
    # streaming it from disk rather than holding a second full-string copy.
    $summaryStream = $null
    $doc = $null
    try {
        $summaryStream = [IO.File]::OpenRead($SummaryPath)
        try {
            $doc = [System.Text.Json.JsonDocument]::Parse($summaryStream)
        }
        catch [System.Text.Json.JsonException] {
            throw "al-runner summary '$SummaryPath' is not valid JSON: $($_.Exception.Message)"
        }
        $root = $doc.RootElement

        [PSCustomObject]@{
            Passed      = ($root.GetProperty('exitCode').GetInt32() -eq 0)
            ExitCode    = $root.GetProperty('exitCode').GetInt32()
            Total       = $root.GetProperty('total').GetInt64()
            Failed      = $root.GetProperty('failed').GetInt64()
            Errors      = $root.GetProperty('errors').GetInt64()
            PassedCount = $root.GetProperty('passed').GetInt64()
            Cached      = $root.GetProperty('cached').GetBoolean()
            WallSeconds = $root.GetProperty('wallSeconds').GetDouble()
            Tests       = $tests
            SummaryFile = $SummaryPath
        }
    }
    finally {
        if ($doc) { $doc.Dispose() }
        if ($summaryStream) { $summaryStream.Dispose() }
    }
}

function Compare-ALRunnerVersion {
    <#
        .SYNOPSIS
        Compares two dotted version strings up to 4 numeric components.

        .DESCRIPTION
        Returns -1, 0 or 1. Falls back to an ordinal string compare when either
        side has a non-numeric component (mirrors download-symbols.ps1's own
        Compare-Version so a highest-version pick agrees with the resolver
        that populated the symbol cache).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Left,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Right
    )

    $normalize = {
        param([string]$v)
        $parts = ($v -split '\.') | Where-Object { $_ -ne '' }
        $nums = @()
        for ($i = 0; $i -lt 4; $i++) {
            if ($i -lt $parts.Count) {
                $segment = $parts[$i]
                $n = 0
                if (-not [int]::TryParse($segment, [ref]$n)) {
                    return $null
                }
                $nums += $n
            }
            else {
                $nums += 0
            }
        }
        return , $nums
    }

    $lArr = & $normalize $Left
    $rArr = & $normalize $Right

    if ($lArr -and $rArr) {
        for ($i = 0; $i -lt 4; $i++) {
            if ($lArr[$i] -lt $rArr[$i]) { return -1 }
            if ($lArr[$i] -gt $rArr[$i]) { return 1 }
        }
        return 0
    }

    return [string]::Compare($Left, $Right, $true)
}

function Resolve-ALRunnerDependencySet {
    <#
        .SYNOPSIS
        Resolves the set of third-party (non-Microsoft, non-bundle) symbol
        packages the al-runner server run needs, one record per dependency id.

        .DESCRIPTION
        Loads al-build.json (Get-BuildConfig) from RepoRoot; the bundle set is
        the main app plus every configured test app. For each bundle's
        app.json dependency whose publisher is not Microsoft and whose id is
        not itself one of the bundles, the matching package is located by
        filename in that bundle's own checkout symbol cache dir
        (Get-SymbolCacheInfo): download-symbols.ps1 writes
        '<publisher><name-no-spaces>.<version>.app', so candidates are every
        cache file matching that prefix, and the one with the highest version
        that still satisfies the dependency's declared minimum wins. A
        declared dependency with no satisfying package in the cache is a hard
        failure naming the publisher, name, version and cache dir searched.
        When the same dependency id is declared by more than one bundle, the
        highest matching version across all of them is kept once. Never reads
        .alpackages, never resolves or copies a Microsoft package.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    Push-Location -LiteralPath $RepoRoot
    try {
        $config = Get-BuildConfig
        $bundleDirs = @($config.AppDir) + @($config.TestApps)

        $bundleAppJsons = [System.Collections.Generic.List[object]]::new()
        foreach ($dir in $bundleDirs) {
            $bundleAppJsons.Add((Get-AppJsonObject -AppDir $dir))
        }

        $bundleAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($appJson in $bundleAppJsons) {
            if ($appJson -and $appJson.id) {
                $bundleAppIds.Add(([string]$appJson.id).Trim()) | Out-Null
            }
        }

        $resolved = [ordered]@{}

        for ($i = 0; $i -lt $bundleDirs.Count; $i++) {
            $dir = $bundleDirs[$i]
            $appJson = $bundleAppJsons[$i]
            if (-not $appJson) { continue }
            if (-not (Test-JsonProperty $appJson 'dependencies') -or -not $appJson.dependencies) { continue }

            $cacheInfo = $null
            foreach ($dep in $appJson.dependencies) {
                if (-not $dep.publisher -or -not $dep.name -or -not $dep.id -or -not $dep.version) { continue }
                if (([string]$dep.publisher).Trim() -ieq 'Microsoft') { continue }

                $depId = ([string]$dep.id).Trim()
                if ($bundleAppIds.Contains($depId)) { continue }

                if (-not $cacheInfo) {
                    $cacheInfo = Get-SymbolCacheInfo -AppJson $appJson
                }

                # Mirror download-symbols.ps1: publisher/name with whitespace
                # removed, then ConvertTo-SafePathSegment over the whole stem.
                $publisherClean = ($dep.publisher -replace '\s+', '')
                $nameClean = ($dep.name -replace '\s+', '')
                $cleanName = ConvertTo-SafePathSegment -Value "$publisherClean.$nameClean"
                $pattern = '^' + [regex]::Escape($cleanName) + '\.(?<version>\d+(?:\.\d+){0,3})\.app$'

                $candidates = @(Get-ChildItem -LiteralPath $cacheInfo.CacheDir -Filter '*.app' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match $pattern })

                $best = $null
                $bestVersion = $null
                foreach ($file in $candidates) {
                    $fileVersion = [regex]::Match($file.Name, $pattern).Groups['version'].Value
                    if ((Compare-ALRunnerVersion -Left $fileVersion -Right ([string]$dep.version)) -lt 0) { continue }
                    if ($null -eq $best -or (Compare-ALRunnerVersion -Left $fileVersion -Right $bestVersion) -gt 0) {
                        $best = $file
                        $bestVersion = $fileVersion
                    }
                }

                if (-not $best) {
                    throw "Missing symbol package for dependency '$($dep.publisher)/$($dep.name)' >= $($dep.version) (id $depId) for bundle '$dir' — searched '$($cacheInfo.CacheDir)' for '$cleanName.*.app'. Run download-symbols.ps1 -AppDir '$dir'."
                }

                $existing = if ($resolved.Contains($depId)) { $resolved[$depId] } else { $null }
                if (-not $existing -or (Compare-ALRunnerVersion -Left $bestVersion -Right $existing.Version) -gt 0) {
                    $resolved[$depId] = [pscustomobject]@{
                        Id                      = $depId
                        Name                    = [string]$dep.name
                        Publisher               = [string]$dep.publisher
                        DeclaredVersion         = [string]$dep.version
                        Version                 = $bestVersion
                        SourcePath              = $best.FullName
                        SourceFileName          = $best.Name
                        SourceLength            = $best.Length
                        SourceLastWriteUtcTicks = $best.LastWriteTimeUtc.Ticks
                    }
                }
            }
        }

        return , @($resolved.Values)
    }
    finally {
        Pop-Location
    }
}

function New-ALRunnerDependencyDirectory {
    <#
        .SYNOPSIS
        Builds the self-contained third-party dependency dir passed to
        al-runner --server as --package-cache.

        .DESCRIPTION
        Resolves the dependency set (Resolve-ALRunnerDependencySet), empties
        and recreates OutputDirectory (default
        '<RepoRoot>/.output/al-runner-deps'), and copies each resolved
        package's .app file into it. Never copies a Microsoft package or a
        package whose id is one of the bundles being run — al-runner
        synthesizes those from source. Never reads .alpackages.

        .OUTPUTS
        A PSCustomObject with OutputDirectory (string) and Packages (array of
        Id/Name/Publisher/Version/Source records for what was placed).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [string]$OutputDirectory
    )

    if (-not $OutputDirectory) {
        $OutputDirectory = Join-Path $RepoRoot '.output' 'al-runner-deps'
    }

    # The directory is emptied below; refuse anything outside <RepoRoot>/.output
    # so a bad caller cannot point the wipe at the repo or a drive root.
    $outputRoot = [IO.Path]::GetFullPath((Join-Path $RepoRoot '.output'))
    $outputFull = [IO.Path]::GetFullPath($OutputDirectory)
    $prefix = [IO.Path]::TrimEndingDirectorySeparator($outputRoot) + [IO.Path]::DirectorySeparatorChar
    if (-not $outputFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "OutputDirectory '$OutputDirectory' must be inside '$outputRoot'."
    }
    $OutputDirectory = $outputFull

    $entries = Resolve-ALRunnerDependencySet -RepoRoot $RepoRoot

    if (Test-Path -LiteralPath $OutputDirectory) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force -Confirm:$false
    }
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

    $packages = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $entries) {
        $destPath = Join-Path $OutputDirectory $entry.SourceFileName
        Copy-Item -LiteralPath $entry.SourcePath -Destination $destPath -Force
        $packages.Add([pscustomobject]@{
                Id        = $entry.Id
                Name      = $entry.Name
                Publisher = $entry.Publisher
                Version   = $entry.Version
                Source    = $entry.SourcePath
            })
    }

    [pscustomobject]@{
        OutputDirectory = $OutputDirectory
        Packages        = @($packages)
    }
}

function Get-ALRunnerDependencySetFingerprintLines {
    <#
        .SYNOPSIS
        Raw, sorted fingerprint lines for the third-party dependency set —
        shared by Get-ALRunnerDependencySetFingerprint and
        Get-ALRunnerServerFingerprint so both hash the same evidence.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $entries = @(Resolve-ALRunnerDependencySet -RepoRoot $RepoRoot)

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in ($entries | Sort-Object -Property Id)) {
        $lines.Add("$($entry.Publisher)|$($entry.Name)|$($entry.Id)|$($entry.DeclaredVersion)")
    }
    foreach ($entry in ($entries | Sort-Object -Property SourceFileName)) {
        $lines.Add("$($entry.SourceFileName)|$($entry.SourceLength)|$($entry.SourceLastWriteUtcTicks)")
    }

    return , @($lines)
}

function Get-ALRunnerDependencySetFingerprint {
    <#
        .SYNOPSIS
        Hashes the third-party dependency set for RepoRoot without copying
        anything — changes when a dependency is added, its declared version
        bumps, or its matching cache file is replaced.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $lines = Get-ALRunnerDependencySetFingerprintLines -RepoRoot $RepoRoot
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n")))
    ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Get-ALRunnerPipeName {
    <#
        .SYNOPSIS
        Derives a deterministic named-pipe name for a repo root.

        .DESCRIPTION
        Hashes the lowercased full path with SHA256 so the same repo always maps to
        the same pipe regardless of path casing, and different repos map to
        different pipes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $normalized = $RepoRoot.ToLowerInvariant()
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($normalized))
    $hex = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
    'albt-alr-' + $hex.Substring(0, 16)
}

function Get-ALRunnerServerFingerprint {
    <#
        .SYNOPSIS
        Fingerprints the al-runner binary and the repo's schema surface, so the
        server manager can detect a stale cached child process and restart it.

        .DESCRIPTION
        Hashes (SHA256) the `al-runner --version` output, then one
        'path|lastWriteUtcTicks|length' line per .al file whose first 4 KB matches a
        table/tableextension declaration (sorted by path), then the same line per
        file under tests/expectations when that directory exists. A codeunit-only
        edit never changes the fingerprint. A missing al-runner binary contributes
        an empty version line instead of throwing, so the fingerprint stays
        computable without a live al-runner install.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    $versionText = ''
    try {
        $versionText = ((& al-runner --version) 2>&1 | Out-String).Trim()
    }
    catch {
        $versionText = ''
    }
    $lines.Add($versionText)

    $schemaPattern = '(?m)^\ufeff?\s*(table|tableextension)\s+\d'
    $schemaFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    if (Test-Path -LiteralPath $RepoRoot) {
        foreach ($file in (Get-ChildItem -LiteralPath $RepoRoot -Filter '*.al' -Recurse -File -ErrorAction SilentlyContinue)) {
            $stream = [System.IO.File]::OpenRead($file.FullName)
            try {
                $buffer = [byte[]]::new(4096)
                $read = $stream.Read($buffer, 0, $buffer.Length)
            }
            finally {
                $stream.Dispose()
            }
            $sample = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
            if ($sample -match $schemaPattern) {
                $schemaFiles.Add($file)
            }
        }
    }
    foreach ($file in ($schemaFiles | Sort-Object -Property FullName)) {
        $lines.Add("$($file.FullName)|$($file.LastWriteTimeUtc.Ticks)|$($file.Length)")
    }

    $expectationsDir = Join-Path $RepoRoot 'tests' 'expectations'
    if (Test-Path -LiteralPath $expectationsDir) {
        foreach ($file in (Get-ChildItem -LiteralPath $expectationsDir -Recurse -File -ErrorAction SilentlyContinue | Sort-Object -Property FullName)) {
            $lines.Add("$($file.FullName)|$($file.LastWriteTimeUtc.Ticks)|$($file.Length)")
        }
    }

    foreach ($line in (Get-ALRunnerDependencySetFingerprintLines -RepoRoot $RepoRoot)) {
        $lines.Add($line)
    }

    $hashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n")))
    ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Test-ALRunnerPipeConnect {
    <#
        .SYNOPSIS
        Attempts a client connect to a named pipe, returning the connected stream or
        $null when nothing answers within TimeoutMs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PipeName,
        [Parameter(Mandatory)]
        [int]$TimeoutMs
    )

    $client = [System.IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
    try {
        $client.Connect($TimeoutMs)
        return $client
    }
    catch {
        $client.Dispose()
        return $null
    }
}

function Request-ALRunnerServerRun {
    <#
        .SYNOPSIS
        Runs SourcePaths through a cached al-runner --server process reached over a
        per-repo named pipe, auto-starting the manager on the first call.

        .DESCRIPTION
        Connects to the repo's named pipe with a 500 ms timeout. On failure, unless
        -NoAutoStart is set, launches the sibling alrunner-server-manager.ps1 and
        retries the connect for up to -ConnectTimeoutSec seconds (default 120).
        Returns $null when no pipe answers in time, so the caller can fall back to
        the plain CLI path. On a successful connect, writes one request line and
        delegates the response stream to Read-ALRunnerRunTestsResponse.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string[]]$SourcePaths,
        [switch]$Coverage,
        [switch]$PerTestCoverage,
        [Parameter(Mandatory)]
        [string]$SummaryPath,
        [switch]$NoAutoStart,
        [int]$ConnectTimeoutSec = 120
    )

    $pipeName = Get-ALRunnerPipeName -RepoRoot $RepoRoot
    $pipe = Test-ALRunnerPipeConnect -PipeName $pipeName -TimeoutMs 500

    if ($null -eq $pipe) {
        if ($NoAutoStart) {
            return $null
        }

        $managerPath = Join-Path $PSScriptRoot 'alrunner-server-manager.ps1'
        Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $managerPath, '-RepoRoot', $RepoRoot) -WindowStyle Hidden | Out-Null

        $deadline = [DateTime]::UtcNow.AddSeconds($ConnectTimeoutSec)
        while ($null -eq $pipe -and [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 500
            $pipe = Test-ALRunnerPipeConnect -PipeName $pipeName -TimeoutMs 500
        }

        if ($null -eq $pipe) {
            return $null
        }
    }

    try {
        $request = New-ALRunnerRunTestsRequest -SourcePaths $SourcePaths -Coverage:$Coverage -PerTestCoverage:$PerTestCoverage
        $writer = [System.IO.StreamWriter]::new($pipe)
        $writer.AutoFlush = $true
        $writer.WriteLine($request)
        $reader = [System.IO.StreamReader]::new($pipe)
        Read-ALRunnerRunTestsResponse -Reader $reader -SummaryPath $SummaryPath
    }
    finally {
        $pipe.Dispose()
    }
}

function Write-ALRunnerJUnit {
    <#
        .SYNOPSIS
        Synthesizes a JUnit XML report from al-runner NDJSON test results.

        .DESCRIPTION
        Groups tests by the codeunit prefix of their Name (up to the first '.'; a name
        with no dot becomes its own single-test suite), emitting one <testsuite> per
        group and one <testcase> per test. A 'fail' status yields a <failure> child, an
        'error' status yields an <error> child, a 'skipped' status yields a <skipped>
        child. Suite and root tests/failures/errors/skipped attributes are summed
        (tests counts every status). Written with [System.Xml.XmlWriter] so
        failure/error messages are XML-escaped.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Tests,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $testList = @($Tests)

    $suites = [ordered]@{}
    foreach ($test in $testList) {
        $dotIndex = $test.Name.IndexOf('.')
        if ($dotIndex -ge 0) {
            $suiteName = $test.Name.Substring(0, $dotIndex)
            $caseName = $test.Name.Substring($dotIndex + 1)
        }
        else {
            $suiteName = $test.Name
            $caseName = $test.Name
        }

        if (-not $suites.Contains($suiteName)) {
            $suites[$suiteName] = [System.Collections.Generic.List[object]]::new()
        }
        $suites[$suiteName].Add([PSCustomObject]@{
                CaseName   = $caseName
                Status     = $test.Status
                DurationMs = $test.DurationMs
                Message    = $test.Message
            })
    }

    $totalTests = $testList.Count
    $totalFailures = @($testList | Where-Object { $_.Status -eq 'fail' }).Count
    $totalErrors = @($testList | Where-Object { $_.Status -eq 'error' }).Count
    $totalSkipped = @($testList | Where-Object { $_.Status -eq 'skipped' }).Count

    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)

    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('testsuites')
        $writer.WriteAttributeString('tests', $totalTests.ToString())
        $writer.WriteAttributeString('failures', $totalFailures.ToString())
        $writer.WriteAttributeString('errors', $totalErrors.ToString())
        $writer.WriteAttributeString('skipped', $totalSkipped.ToString())

        foreach ($suiteName in $suites.Keys) {
            $suiteTests = $suites[$suiteName]
            $suiteFailures = @($suiteTests | Where-Object { $_.Status -eq 'fail' }).Count
            $suiteErrors = @($suiteTests | Where-Object { $_.Status -eq 'error' }).Count
            $suiteSkipped = @($suiteTests | Where-Object { $_.Status -eq 'skipped' }).Count

            $writer.WriteStartElement('testsuite')
            $writer.WriteAttributeString('name', $suiteName)
            $writer.WriteAttributeString('tests', $suiteTests.Count.ToString())
            $writer.WriteAttributeString('failures', $suiteFailures.ToString())
            $writer.WriteAttributeString('errors', $suiteErrors.ToString())
            $writer.WriteAttributeString('skipped', $suiteSkipped.ToString())

            foreach ($case in $suiteTests) {
                $writer.WriteStartElement('testcase')
                $writer.WriteAttributeString('name', $case.CaseName)
                $writer.WriteAttributeString('classname', $suiteName)
                $timeSeconds = [double]$case.DurationMs / 1000.0
                $writer.WriteAttributeString('time', $timeSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

                if ($case.Status -eq 'fail') {
                    $writer.WriteStartElement('failure')
                    $writer.WriteAttributeString('message', [string]$case.Message)
                    $writer.WriteEndElement()
                }
                elseif ($case.Status -eq 'error') {
                    $writer.WriteStartElement('error')
                    $writer.WriteAttributeString('message', [string]$case.Message)
                    $writer.WriteEndElement()
                }
                elseif ($case.Status -eq 'skipped') {
                    $writer.WriteStartElement('skipped')
                    $writer.WriteEndElement()
                }

                $writer.WriteEndElement() # testcase
            }

            $writer.WriteEndElement() # testsuite
        }

        $writer.WriteEndElement() # testsuites
        $writer.WriteEndDocument()
    }
    finally {
        $writer.Close()
    }
}

Export-ModuleMember -Function @(
    'New-ALRunnerRunTestsRequest',
    'Read-ALRunnerRunTestsResponse',
    'Write-ALRunnerJUnit',
    'Get-ALRunnerPipeName',
    'Get-ALRunnerServerFingerprint',
    'Request-ALRunnerServerRun',
    'Resolve-ALRunnerDependencySet',
    'New-ALRunnerDependencyDirectory',
    'Get-ALRunnerDependencySetFingerprintLines',
    'Get-ALRunnerDependencySetFingerprint'
)
