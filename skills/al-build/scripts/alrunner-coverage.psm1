#Requires -Version 7.2

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Matches the first AL object-declaration line in a source file. Group 1 is the
# declaration keyword (lowercased for the JSONL/Cobertura output), group 2 is the
# object name with any surrounding quotes stripped.
$script:AlObjectDeclarationPattern = '^\s*(codeunit|table|tableextension|page|pageextension|report|reportextension|query|xmlport|enum|enumextension|interface|permissionset|controladdin)\s+\d*\s*"?([^"{\r\n]+?)"?\s*($|\{|implements|extends)'

function Test-ALRunnerCoveragePathUnderRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Root
    )

    $normalizedPath = ($Path -replace '\\', '/').TrimEnd('/')
    $normalizedRoot = ($Root -replace '\\', '/').TrimEnd('/')

    $normalizedPath.Equals($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $normalizedPath.StartsWith("$normalizedRoot/", [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-ALRunnerCoverageRepoRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    # A ".."-prefix check on GetRelativePath's result misses a cross-drive Path
    # (e.g. RepoRoot on C:, Path on D:): .NET returns Path unchanged rather than
    # a ".."-prefixed relative path when no relative path can be constructed.
    # The prefix check below is drive/UNC-agnostic and catches both cases.
    if (-not (Test-ALRunnerCoveragePathUnderRoot -Path $Path -Root $RepoRoot)) {
        throw "al-runner coverage file '$Path' is outside repo root '$RepoRoot'."
    }

    [System.IO.Path]::GetRelativePath($RepoRoot, $Path).Replace('\', '/')
}

function Get-ALRunnerCoverageObjectDeclaration {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $text = [System.IO.File]::ReadAllText($FilePath)
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
    $match = [regex]::Match($text, $script:AlObjectDeclarationPattern, $options)
    if (-not $match.Success) {
        throw "Cannot parse an object declaration from covered main-app file '$FilePath'."
    }

    [pscustomobject]@{
        ObjectType = $match.Groups[1].Value.ToLowerInvariant()
        ObjectName = $match.Groups[2].Value.Trim()
    }
}

function Get-ALRunnerCoverageTestAppIndex {
    param(
        [Parameter(Mandatory)]
        [string[]]$TestAppPaths
    )

    $index = [System.Collections.Generic.List[object]]::new()
    foreach ($testAppPath in $TestAppPaths) {
        $manifestPath = Join-Path $testAppPath 'app.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw "Test app '$testAppPath' has no app.json."
        }

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $ranges = [System.Collections.Generic.List[object]]::new()
        if ($manifest.PSObject.Properties['idRanges']) {
            foreach ($range in @($manifest.idRanges)) {
                $ranges.Add([pscustomobject]@{ From = [int]$range.from; To = [int]$range.to })
            }
        }

        $index.Add([pscustomobject]@{
            Leaf     = (Split-Path -Path $testAppPath -Leaf)
            IdRanges = $ranges
        })
    }

    $index
}

function Resolve-ALRunnerCoverageTestApp {
    <#
        .SYNOPSIS
        Resolves the test-app leaf name whose app.json idRanges contains CodeunitId.
        CodeunitId is untyped so a $null (unparseable codeunit id) is not coerced to 0.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$TestAppIndex,

        $CodeunitId
    )

    if ($null -eq $CodeunitId) {
        return 'unknown'
    }

    $id = [int]$CodeunitId
    foreach ($entry in $TestAppIndex) {
        foreach ($range in $entry.IdRanges) {
            if ($id -ge $range.From -and $id -le $range.To) {
                return $entry.Leaf
            }
        }
    }

    'unknown'
}

function ConvertFrom-ALRunnerCoverageTestName {
    <#
        .SYNOPSIS
        Splits a perTestCoverage `test` value ("Codeunit50150.MethodName") into its
        codeunit token, procedure name, and the codeunit id parsed from the trailing
        digits of the codeunit token.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TestName
    )

    $dotIndex = $TestName.IndexOf('.')
    if ($dotIndex -lt 0) {
        $codeunitToken = $TestName
        $procedure = ''
    } else {
        $codeunitToken = $TestName.Substring(0, $dotIndex)
        $procedure = $TestName.Substring($dotIndex + 1)
    }

    $idMatch = [regex]::Match($codeunitToken, '\d+$')
    $codeunitId = if ($idMatch.Success) { [int]$idMatch.Value } else { $null }

    [pscustomobject]@{
        TestCodeunit   = $codeunitToken
        TestProcedure  = $procedure
        TestCodeunitId = $codeunitId
    }
}

function New-ALRunnerCoberturaDocument {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SourceLines,

        [Parameter(Mandatory)]
        [int]$LinesValid,

        [Parameter(Mandatory)]
        [int]$LinesCovered,

        [Parameter(Mandatory)]
        [double]$LineRate
    )

    $rateString = $LineRate.ToString('F4', [System.Globalization.CultureInfo]::InvariantCulture)

    $classOrder = [System.Collections.Generic.List[string]]::new()
    $classGroups = @{}
    foreach ($line in $SourceLines) {
        if (-not $classGroups.ContainsKey($line.SourcePath)) {
            $classGroups[$line.SourcePath] = [pscustomobject]@{
                ObjectName = $line.ObjectName
                SourcePath = $line.SourcePath
                Lines      = [System.Collections.Generic.List[object]]::new()
            }
            $classOrder.Add($line.SourcePath)
        }
        $classGroups[$line.SourcePath].Lines.Add($line)
    }
    $classOrder.Sort([System.StringComparer]::OrdinalIgnoreCase)

    $memoryStream = [System.IO.MemoryStream]::new()
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.NewLineChars = "`n"
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $settings.OmitXmlDeclaration = $false

    $writer = [System.Xml.XmlWriter]::Create($memoryStream, $settings)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('coverage')
        $writer.WriteAttributeString('line-rate', $rateString)
        $writer.WriteAttributeString('branch-rate', '0.0000')
        $writer.WriteAttributeString('lines-covered', [string]$LinesCovered)
        $writer.WriteAttributeString('lines-valid', [string]$LinesValid)
        $writer.WriteAttributeString('branches-covered', '0')
        $writer.WriteAttributeString('branches-valid', '0')
        $writer.WriteAttributeString('complexity', '0')
        $writer.WriteAttributeString('timestamp', '0')

        $writer.WriteStartElement('sources')
        $writer.WriteElementString('source', '.')
        $writer.WriteEndElement()

        $writer.WriteStartElement('packages')
        $writer.WriteStartElement('package')
        $writer.WriteAttributeString('name', 'app')
        $writer.WriteAttributeString('line-rate', $rateString)
        $writer.WriteAttributeString('branch-rate', '0.0000')
        $writer.WriteAttributeString('complexity', '0')

        $writer.WriteStartElement('classes')
        foreach ($sourcePath in $classOrder) {
            $classInfo = $classGroups[$sourcePath]
            $classLines = @($classInfo.Lines | Sort-Object LineNumber)
            $classValid = $classLines.Count
            $classCovered = @($classLines | Where-Object { $_.Hits -gt 0 }).Count
            $classRate = if ($classValid -le 0) { 0 } else { [Math]::Round([double]$classCovered / [double]$classValid, 4) }
            $classRateString = $classRate.ToString('F4', [System.Globalization.CultureInfo]::InvariantCulture)

            $writer.WriteStartElement('class')
            $writer.WriteAttributeString('name', $classInfo.ObjectName)
            $writer.WriteAttributeString('filename', $classInfo.SourcePath)
            $writer.WriteAttributeString('line-rate', $classRateString)
            $writer.WriteAttributeString('branch-rate', '0.0000')
            $writer.WriteAttributeString('complexity', '0')

            $writer.WriteStartElement('methods')
            $writer.WriteEndElement()

            $writer.WriteStartElement('lines')
            foreach ($line in $classLines) {
                $writer.WriteStartElement('line')
                $writer.WriteAttributeString('number', [string]$line.LineNumber)
                $writer.WriteAttributeString('hits', [string]$line.Hits)
                $writer.WriteAttributeString('branch', 'false')
                $writer.WriteEndElement()
            }
            $writer.WriteEndElement()
            $writer.WriteEndElement()
        }
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndDocument()
        $writer.Flush()
    } finally {
        $writer.Close()
    }

    $bytes = $memoryStream.ToArray()
    $memoryStream.Dispose()
    $bytes
}

function Write-ALRunnerCoverageArtifacts {
    <#
        .SYNOPSIS
        Derives per-test and Cobertura coverage artifacts from an al-runner
        `runTests` summary (`coverage` and `perTestCoverage`) for the main app only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SummaryFile,

        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$MainAppPath,

        [Parameter(Mandatory)]
        [string[]]$TestApps,

        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    # The summary can carry a multi-megabyte perTestCoverage payload (tens of MB
    # with -PerTestCoverage). ConvertFrom-Json would materialize the whole tree as
    # PSCustomObjects; parse the file with JsonDocument from a FileStream instead
    # so the raw text is never held twice in memory as PowerShell strings.
    $summaryStream = $null
    $doc = $null
    try {
        $summaryStream = [IO.File]::OpenRead($SummaryFile)
        try {
            $doc = [System.Text.Json.JsonDocument]::Parse($summaryStream)
        }
        catch [System.Text.Json.JsonException] {
            throw "al-runner summary '$SummaryFile' is not valid JSON: $($_.Exception.Message)"
        }
        $summaryRoot = $doc.RootElement

        $coverageProp = New-Object System.Text.Json.JsonElement
        if (-not $summaryRoot.TryGetProperty('coverage', [ref]$coverageProp)) {
            throw "al-runner summary '$SummaryFile' is missing 'coverage'."
        }
        $perTestCoverageProp = New-Object System.Text.Json.JsonElement
        if (-not $summaryRoot.TryGetProperty('perTestCoverage', [ref]$perTestCoverageProp)) {
            throw "al-runner summary '$SummaryFile' is missing 'perTestCoverage'."
        }

        $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
        $resolvedMainAppPath = (Resolve-Path -LiteralPath $MainAppPath).Path
        $resolvedTestApps = @($TestApps | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })

        $testAppIndex = Get-ALRunnerCoverageTestAppIndex -TestAppPaths $resolvedTestApps
        $declarationCache = @{}

        # Aggregate `coverage`: distinct (sourcePath, lineNumber) source lines, main-app
        # only, plus the aggregate hit total per line (drives both the source records
        # and the Cobertura document).
        $sourceLines = [ordered]@{}
        foreach ($fileEntry in $coverageProp.EnumerateArray()) {
            $absoluteFile = $fileEntry.GetProperty('file').GetString()
            if (-not (Test-ALRunnerCoveragePathUnderRoot -Path $absoluteFile -Root $resolvedMainAppPath)) {
                continue
            }

            $statementsProp = $fileEntry.GetProperty('statements')
            if ($statementsProp.GetArrayLength() -eq 0) {
                continue
            }

            $sourcePath = Resolve-ALRunnerCoverageRepoRelativePath -RepoRoot $resolvedRepoRoot -Path $absoluteFile
            if (-not $declarationCache.ContainsKey($absoluteFile)) {
                $declarationCache[$absoluteFile] = Get-ALRunnerCoverageObjectDeclaration -FilePath $absoluteFile
            }
            $declaration = $declarationCache[$absoluteFile]

            $lineHits = @{}
            foreach ($statement in $statementsProp.EnumerateArray()) {
                $lineNumber = $statement.GetProperty('line').GetInt32()
                $current = if ($lineHits.ContainsKey($lineNumber)) { $lineHits[$lineNumber] } else { [Int64]0 }
                $lineHits[$lineNumber] = $current + [Int64]$statement.GetProperty('hits').GetInt64()
            }

            foreach ($lineNumber in $lineHits.Keys) {
                $key = '{0}|{1:d10}' -f $sourcePath, $lineNumber
                $sourceLines[$key] = [pscustomobject]@{
                    SourcePath = $sourcePath
                    LineNumber = $lineNumber
                    ObjectType = $declaration.ObjectType
                    ObjectName = $declaration.ObjectName
                    Hits       = $lineHits[$lineNumber]
                }
            }
        }

        $orderedSourceLines = @($sourceLines.Values | Sort-Object { '{0}|{1:d10}' -f $_.SourcePath.ToLowerInvariant(), $_.LineNumber })

        $linesValid = $orderedSourceLines.Count
        $linesCovered = @($orderedSourceLines | Where-Object { $_.Hits -gt 0 }).Count
        $lineRate = if ($linesValid -le 0) { 0 } else { [Math]::Round([double]$linesCovered / [double]$linesValid, 4) }

        # perTestCoverage: one hit record per (test, file, line), main-app only, hits
        # summed across that test's statements on the line. Lines with zero hits are
        # not "hit" and are not emitted.
        $hitRecords = [System.Collections.Generic.List[object]]::new()
        foreach ($testEntry in $perTestCoverageProp.EnumerateArray()) {
            $testName = $testEntry.GetProperty('test').GetString()
            $testInfo = ConvertFrom-ALRunnerCoverageTestName -TestName $testName
            $testApp = Resolve-ALRunnerCoverageTestApp -TestAppIndex $testAppIndex -CodeunitId $testInfo.TestCodeunitId

            foreach ($fileEntry in $testEntry.GetProperty('coverage').EnumerateArray()) {
                $absoluteFile = $fileEntry.GetProperty('file').GetString()
                if (-not (Test-ALRunnerCoveragePathUnderRoot -Path $absoluteFile -Root $resolvedMainAppPath)) {
                    continue
                }

                $sourcePath = Resolve-ALRunnerCoverageRepoRelativePath -RepoRoot $resolvedRepoRoot -Path $absoluteFile

                $lineHits = @{}
                foreach ($statement in $fileEntry.GetProperty('statements').EnumerateArray()) {
                    $lineNumber = $statement.GetProperty('line').GetInt32()
                    $current = if ($lineHits.ContainsKey($lineNumber)) { $lineHits[$lineNumber] } else { [Int64]0 }
                    $lineHits[$lineNumber] = $current + [Int64]$statement.GetProperty('hits').GetInt64()
                }

                foreach ($lineNumber in $lineHits.Keys) {
                    $hits = $lineHits[$lineNumber]
                    if ($hits -le 0) {
                        continue
                    }

                    $hitRecords.Add([pscustomobject]@{
                        TestName      = $testName
                        TestApp       = $testApp
                        TestCodeunit  = $testInfo.TestCodeunit
                        TestProcedure = $testInfo.TestProcedure
                        SourcePath    = $sourcePath
                        LineNumber    = [int]$lineNumber
                        Hits          = $hits
                    })
                }
            }
        }
    }
    finally {
        if ($doc) { $doc.Dispose() }
        if ($summaryStream) { $summaryStream.Dispose() }
    }

    $orderedHitRecords = @($hitRecords | Sort-Object {
        '{0}|{1:d10}|{2}' -f $_.SourcePath.ToLowerInvariant(), $_.LineNumber, $_.TestName.ToLowerInvariant()
    })

    $jsonRecords = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $orderedSourceLines) {
        $record = [ordered]@{
            kind       = 'source'
            objectType = $line.ObjectType
            objectName = $line.ObjectName
            sourcePath = $line.SourcePath
            lineNumber = [int]$line.LineNumber
        }
        $jsonRecords.Add(($record | ConvertTo-Json -Compress))
    }
    foreach ($hit in $orderedHitRecords) {
        $record = [ordered]@{
            kind          = 'hit'
            testApp       = $hit.TestApp
            testCodeunit  = $hit.TestCodeunit
            testProcedure = $hit.TestProcedure
            sourcePath    = $hit.SourcePath
            lineNumber    = [int]$hit.LineNumber
            hits          = [int]$hit.Hits
        }
        $jsonRecords.Add(($record | ConvertTo-Json -Compress))
    }
    $jsonlContent = if ($jsonRecords.Count -eq 0) { '' } else { ($jsonRecords -join "`n") + "`n" }

    $coberturaBytes = New-ALRunnerCoberturaDocument -SourceLines $orderedSourceLines -LinesValid $linesValid -LinesCovered $linesCovered -LineRate $lineRate

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    $perTestPath = Join-Path $resolvedOutputDirectory 'per-test.jsonl'
    $coberturaPath = Join-Path $resolvedOutputDirectory 'cobertura.xml'

    [System.IO.File]::WriteAllText($perTestPath, $jsonlContent, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllBytes($coberturaPath, $coberturaBytes)

    [PSCustomObject]@{
        PerTestPath   = $perTestPath
        CoberturaPath = $coberturaPath
        LineRate      = $lineRate
        LinesValid    = $linesValid
        LinesCovered  = $linesCovered
    }
}

Export-ModuleMember -Function @(
    'Write-ALRunnerCoverageArtifacts'
)
