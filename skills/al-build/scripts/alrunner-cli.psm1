#Requires -Version 7.2

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
        packages the al-runner run needs, one record per dependency id.

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
        Builds the self-contained third-party dependency dir passed to the
        al-runner CLI as --package-cache.

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

function Stop-OrphanedALRunnerServer {
    <#
        .SYNOPSIS
        Terminates a leftover `al-runner --server` child whose --package-cache
        points inside RepoRoot, so it cannot hold .output/logs open against
        this run.

        .DESCRIPTION
        Transitional cleanup for the 4.1.x server mode, which re-exec'd
        `dotnet exec ...\al-runner.dll --server` and could orphan that child
        past the manager's exit. Matches on the command line only — process
        name is never used — and stops each match by id. Returns the ids it
        stopped. Remove in a later release once no 4.1.x child can survive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $stopped = [System.Collections.Generic.List[int]]::new()
    $repoFull = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($RepoRoot))

    $processes = @()
    try {
        $processes = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'dotnet.exe' OR Name = 'al-runner.exe'" -ErrorAction Stop)
    }
    catch {
        return , @()
    }

    foreach ($process in $processes) {
        $commandLine = [string]$process.CommandLine
        if (-not $commandLine) { continue }
        if ($commandLine -notmatch 'al-runner(\.dll)?["'']?\s+.*--server') { continue }
        # Quote-aware: a quoted path keeps its spaces; a bare token stops at
        # whitespace.
        $cacheMatch = [regex]::Match($commandLine, '--package-cache\s+(?:"([^"]+)"|(\S+))')
        if (-not $cacheMatch.Success) { continue }
        $cachePath = if ($cacheMatch.Groups[1].Success) { $cacheMatch.Groups[1].Value } else { $cacheMatch.Groups[2].Value }
        # A relative --package-cache belongs to that process's own cwd, not
        # this repo; resolving it here would match a stranger's server.
        if (-not [IO.Path]::IsPathRooted($cachePath)) { continue }
        try {
            $cacheFull = [IO.Path]::GetFullPath($cachePath)
        }
        catch {
            continue
        }
        $prefix = $repoFull + [IO.Path]::DirectorySeparatorChar
        if (-not $cacheFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { continue }

        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
        $stopped.Add([int]$process.ProcessId)
        Write-BuildMessage -Type Info -Message "[i] terminated orphaned al-runner server (pid $($process.ProcessId))"
    }

    return , @($stopped)
}

function Get-ALRunnerCliArguments {
    <#
        .SYNOPSIS
        Builds the argument list for one al-runner CLI run over Bundles.

        .DESCRIPTION
        `<bundles...> --package-cache <dir> --output-json --output-junit <path>`
        plus `--coverage --coverage-out <path>` when -Coverage is set
        (al-runner v2.10: --output-json replaces the text output with per-test
        JSON on stdout; --output-junit writes JUnit XML grouped by codeunit;
        --coverage-out overrides the Cobertura path). --expectations is never
        passed: the gate reds on a tests/expectations folder before this runs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Bundles,
        [Parameter(Mandatory)]
        [string]$PackageCache,
        [Parameter(Mandatory)]
        [string]$JUnitPath,
        [switch]$Coverage,
        [string]$CoverageOutPath
    )

    if ($Coverage -and -not $CoverageOutPath) {
        throw 'CoverageOutPath is required when -Coverage is set.'
    }

    $arguments = [System.Collections.Generic.List[string]]::new()
    foreach ($bundle in $Bundles) { $arguments.Add($bundle) }
    $arguments.Add('--package-cache')
    $arguments.Add($PackageCache)
    $arguments.Add('--output-json')
    $arguments.Add('--output-junit')
    $arguments.Add($JUnitPath)
    if ($Coverage) {
        $arguments.Add('--coverage')
        $arguments.Add('--coverage-out')
        $arguments.Add($CoverageOutPath)
    }

    return , @($arguments)
}

function Invoke-ALRunnerCli {
    <#
        .SYNOPSIS
        Runs one fresh al-runner process, its stdout redirected to StdoutPath
        and its stderr to StderrPath, echoing new stderr lines to the console
        while it runs.

        .DESCRIPTION
        Neither stream rides a PowerShell pipe: al-runner's progress lines
        ([bc] selected, [dep] resolution, per-bundle progress) land in
        StderrPath and are echoed as they arrive, so a long run is never
        silent and the log survives the process. Returns the exit code and
        both paths; never throws on a non-zero exit — the caller maps it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$StdoutPath,
        [Parameter(Mandatory)]
        [string]$StderrPath,
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,
        [string]$Command = 'al-runner',
        [int]$PollIntervalMs = 500
    )

    foreach ($path in @($StdoutPath, $StderrPath)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -Confirm:$false }
    }

    # ProcessStartInfo.ArgumentList quotes each element for the Windows
    # command line; Start-Process -ArgumentList joins with spaces and would
    # split a path with a space into several tokens.
    $resolved = Get-Command -Name $Command -ErrorAction Stop
    $fileName = if ($resolved.Path) { $resolved.Path } else { $resolved.Source }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $fileName
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $null = $process.Start()

    # Both streams drain concurrently into their files; a sequential
    # ReadToEnd would deadlock once the other pipe's buffer fills.
    $stdoutFile = [System.IO.FileStream]::new($StdoutPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $stderrFile = [System.IO.FileStream]::new($StderrPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $stdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdoutFile)
    $stderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderrFile)
    $echoed = 0
    $tail = {
        # Re-read the file each poll; CopyToAsync flushes as the pipe delivers,
        # and FileShare.Read lets this reader see it mid-run.
        $lines = @(Get-Content -LiteralPath $StderrPath -ErrorAction SilentlyContinue)
        for ($i = $echoed; $i -lt $lines.Count; $i++) {
            Write-Host "  [al-runner] $($lines[$i])"
        }
        $lines.Count
    }

    while (-not $process.HasExited) {
        $echoed = & $tail
        Start-Sleep -Milliseconds $PollIntervalMs
    }
    $process.WaitForExit()
    [System.Threading.Tasks.Task]::WaitAll(@($stdoutCopy, $stderrCopy))
    $stdoutFile.Dispose()
    $stderrFile.Dispose()
    $echoed = & $tail

    [pscustomobject]@{
        ExitCode   = $process.ExitCode
        StdoutPath = $StdoutPath
        StderrPath = $StderrPath
    }
}

function Read-ALRunnerCliOutput {
    <#
        .SYNOPSIS
        Parses the --output-json document al-runner wrote to Path.

        .DESCRIPTION
        al-runner v2.10 writes one JSON document: `tests[]` (name, status
        pass|fail|error|skipped, durationMs, optional message and stackTrace)
        and the counters passed, failed, errors, skipped, total, exitCode,
        wallSeconds. Parsed with JsonDocument from a FileStream. An empty
        file, a truncated document, or a document without `tests` throws
        naming Path — an aborted run never reads as zero tests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path) -or (Get-Item -LiteralPath $Path).Length -eq 0) {
        throw "al-runner output '$Path' is empty — the run ended before it wrote its result (see the al-runner log)."
    }

    $stream = $null
    $doc = $null
    try {
        $stream = [IO.File]::OpenRead($Path)
        try {
            $doc = [System.Text.Json.JsonDocument]::Parse($stream)
        }
        catch [System.Text.Json.JsonException] {
            throw "al-runner output '$Path' is not a complete JSON document — the run ended before it wrote its result: $($_.Exception.Message)"
        }
        $root = $doc.RootElement

        $testsProp = New-Object System.Text.Json.JsonElement
        if (-not $root.TryGetProperty('tests', [ref]$testsProp)) {
            throw "al-runner output '$Path' has no 'tests' array."
        }

        $tests = [System.Collections.Generic.List[object]]::new()
        foreach ($element in $testsProp.EnumerateArray()) {
            $message = $null
            $messageProp = New-Object System.Text.Json.JsonElement
            if ($element.TryGetProperty('message', [ref]$messageProp) -and $messageProp.ValueKind -eq [System.Text.Json.JsonValueKind]::String) {
                $message = $messageProp.GetString()
            }
            $durationMs = [int64]0
            $durationProp = New-Object System.Text.Json.JsonElement
            if ($element.TryGetProperty('durationMs', [ref]$durationProp) -and $durationProp.ValueKind -eq [System.Text.Json.JsonValueKind]::Number) {
                $durationMs = [int64][Math]::Round($durationProp.GetDouble())
            }
            $tests.Add([pscustomobject]@{
                    Name       = $element.GetProperty('name').GetString()
                    Status     = $element.GetProperty('status').GetString()
                    DurationMs = $durationMs
                    Message    = $message
                })
        }

        $getInt = {
            param([string]$Name, [int64]$Default)
            $prop = New-Object System.Text.Json.JsonElement
            if ($root.TryGetProperty($Name, [ref]$prop) -and $prop.ValueKind -eq [System.Text.Json.JsonValueKind]::Number) {
                return $prop.GetInt64()
            }
            return $Default
        }

        $exitCode = [int](& $getInt 'exitCode' 1)
        $wallSeconds = 0.0
        $wallProp = New-Object System.Text.Json.JsonElement
        if ($root.TryGetProperty('wallSeconds', [ref]$wallProp) -and $wallProp.ValueKind -eq [System.Text.Json.JsonValueKind]::Number) {
            $wallSeconds = $wallProp.GetDouble()
        }

        [pscustomobject]@{
            Passed      = ($exitCode -eq 0)
            ExitCode    = $exitCode
            Total       = (& $getInt 'total' $tests.Count)
            PassedCount = (& $getInt 'passed' @($tests | Where-Object { $_.Status -eq 'pass' }).Count)
            Failed      = (& $getInt 'failed' @($tests | Where-Object { $_.Status -eq 'fail' }).Count)
            Errors      = (& $getInt 'errors' @($tests | Where-Object { $_.Status -eq 'error' }).Count)
            Skipped     = (& $getInt 'skipped' @($tests | Where-Object { $_.Status -eq 'skipped' }).Count)
            WallSeconds = $wallSeconds
            Tests       = @($tests)
            OutputFile  = $Path
        }
    }
    finally {
        if ($doc) { $doc.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function Get-ALRunnerSelectedBcLine {
    <#
        .SYNOPSIS
        Returns the `[bc] selected BC ...` notice from an al-runner stderr log,
        or $null when the log has none.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $LogPath)) { return $null }
    $line = Get-Content -LiteralPath $LogPath -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\[bc\] selected' } |
        Select-Object -First 1
    if ($line) { return [string]$line }
    return $null
}

Export-ModuleMember -Function @(
    'Resolve-ALRunnerDependencySet',
    'New-ALRunnerDependencyDirectory',
    'Stop-OrphanedALRunnerServer',
    'Get-ALRunnerCliArguments',
    'Invoke-ALRunnerCli',
    'Read-ALRunnerCliOutput',
    'Get-ALRunnerSelectedBcLine'
)
