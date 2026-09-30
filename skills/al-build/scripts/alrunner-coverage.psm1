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
        Derives the main-app-only Cobertura artifact from the Cobertura file
        al-runner wrote through --coverage-out.

        .DESCRIPTION
        al-runner's Cobertura covers every bundle in the run (main app and
        test apps) with repo-relative, forward-slash class filenames. This
        keeps the classes under MainAppPath, sums hits per line, recomputes
        lineRate/linesValid/linesCovered over that set, and writes
        OutputDirectory/cobertura.xml through New-ALRunnerCoberturaDocument.
        The al-runner CLI exposes no per-test attribution, so PerTestPath is
        always $null (coverage status "aggregate-only").
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CoberturaFile,

        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$MainAppPath,

        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    if (-not (Test-Path -LiteralPath $CoberturaFile -PathType Leaf)) {
        throw "al-runner Cobertura file '$CoberturaFile' was not written (see the al-runner log)."
    }

    $document = [System.Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    try {
        $document.Load($CoberturaFile)
    }
    catch {
        throw "al-runner Cobertura file '$CoberturaFile' is not valid XML: $($_.Exception.Message)"
    }

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $resolvedMainAppPath = (Resolve-Path -LiteralPath $MainAppPath).Path
    $declarationCache = @{}

    $sourceLines = [ordered]@{}
    foreach ($class in @($document.SelectNodes('//class'))) {
        $filename = [string]$class.GetAttribute('filename')
        if (-not $filename) { continue }
        $absoluteFile = if ([System.IO.Path]::IsPathRooted($filename)) { $filename } else { Join-Path $resolvedRepoRoot $filename }
        $absoluteFile = [System.IO.Path]::GetFullPath($absoluteFile)
        if (-not (Test-ALRunnerCoveragePathUnderRoot -Path $absoluteFile -Root $resolvedMainAppPath)) {
            continue
        }

        $lineNodes = @($class.SelectNodes('lines/line'))
        if ($lineNodes.Count -eq 0) { continue }

        $sourcePath = Resolve-ALRunnerCoverageRepoRelativePath -RepoRoot $resolvedRepoRoot -Path $absoluteFile
        if (-not $declarationCache.ContainsKey($absoluteFile)) {
            $declarationCache[$absoluteFile] = Get-ALRunnerCoverageObjectDeclaration -FilePath $absoluteFile
        }
        $declaration = $declarationCache[$absoluteFile]

        foreach ($lineNode in $lineNodes) {
            $lineNumber = [int]$lineNode.GetAttribute('number')
            $hits = [int64]$lineNode.GetAttribute('hits')
            $key = '{0}|{1:d10}' -f $sourcePath, $lineNumber
            if ($sourceLines.Contains($key)) {
                $sourceLines[$key].Hits += $hits
            } else {
                $sourceLines[$key] = [pscustomobject]@{
                    SourcePath = $sourcePath
                    LineNumber = $lineNumber
                    ObjectType = $declaration.ObjectType
                    ObjectName = $declaration.ObjectName
                    Hits       = $hits
                }
            }
        }
    }

    $orderedSourceLines = @($sourceLines.Values | Sort-Object { '{0}|{1:d10}' -f $_.SourcePath.ToLowerInvariant(), $_.LineNumber })
    $linesValid = $orderedSourceLines.Count
    $linesCovered = @($orderedSourceLines | Where-Object { $_.Hits -gt 0 }).Count
    $lineRate = if ($linesValid -le 0) { 0 } else { [Math]::Round([double]$linesCovered / [double]$linesValid, 4) }

    $coberturaBytes = New-ALRunnerCoberturaDocument -SourceLines $orderedSourceLines -LinesValid $linesValid -LinesCovered $linesCovered -LineRate $lineRate

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    $coberturaPath = Join-Path $resolvedOutputDirectory 'cobertura.xml'
    [System.IO.File]::WriteAllBytes($coberturaPath, $coberturaBytes)

    [PSCustomObject]@{
        PerTestPath   = $null
        CoberturaPath = $coberturaPath
        LineRate      = $lineRate
        LinesValid    = $linesValid
        LinesCovered  = $linesCovered
    }
}

Export-ModuleMember -Function @(
    'Write-ALRunnerCoverageArtifacts'
)
