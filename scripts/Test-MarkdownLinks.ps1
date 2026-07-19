#Requires -Version 7.2
<#
.SYNOPSIS
    Audits tracked Markdown links whose local targets do not exist.
.DESCRIPTION
    Reads the tracked Markdown corpus with git ls-files, ignores fenced code
    blocks and non-local targets, and writes one sorted, unique
    source-file<TAB>literal-target pair for each unresolved target.

    Use -BaselinePath with -FailOnUnresolved to fail only for unresolved pairs
    not already present in the baseline. Use -WriteBaseline to refresh it.
.EXAMPLE
    pwsh scripts/Test-MarkdownLinks.ps1
.EXAMPLE
    pwsh scripts/Test-MarkdownLinks.ps1 -BaselinePath .link-baseline.txt -FailOnUnresolved
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),

    [string]$BaselinePath,

    [switch]$WriteBaseline,

    [switch]$FailOnUnresolved
)

function Get-MarkdownLinkContents {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Line
    )

    $contents = [System.Collections.Generic.List[string]]::new()
    $linkStart = [regex]'\[(?:\\.|[^\]])*\]\('
    $searchIndex = 0

    while ($searchIndex -lt $Line.Length) {
        $match = $linkStart.Match($Line, $searchIndex)
        if (-not $match.Success) {
            break
        }

        $contentStart = $match.Index + $match.Length
        $depth = 1
        $escaped = $false
        $index = $contentStart
        while ($index -lt $Line.Length -and $depth -gt 0) {
            $character = $Line[$index]
            if ($escaped) {
                $escaped = $false
            } elseif ($character -eq '\') {
                $escaped = $true
            } elseif ($character -eq '(') {
                $depth++
            } elseif ($character -eq ')') {
                $depth--
            }

            $index++
        }

        if ($depth -eq 0) {
            $contents.Add($Line.Substring($contentStart, $index - $contentStart - 1))
            $searchIndex = $index
        } else {
            $searchIndex = $match.Index + $match.Length
        }
    }

    return $contents
}

function Get-MarkdownLinkTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Contents
    )

    $contents = $Contents.Trim()
    if ($contents.StartsWith('<')) {
        $end = $contents.IndexOf('>')
        if ($end -lt 0) {
            return $null
        }

        return $contents.Substring(1, $end - 1)
    }

    $titleStart = ([regex]'\s').Match($contents)
    if ($titleStart.Success) {
        return $contents.Substring(0, $titleStart.Index)
    }

    return $contents
}

function Get-TrackedMarkdownFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $files = & git -C $Root ls-files -z -- '*.md'
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list tracked Markdown files in '$Root'."
    }

    return @($files -split "`0" | Where-Object { $_ })
}

function Test-LocalMarkdownTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralTarget,

        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory
    )

    if ([string]::IsNullOrWhiteSpace($LiteralTarget) -or
        $LiteralTarget.StartsWith('#') -or
        $LiteralTarget.StartsWith('//') -or
        $LiteralTarget -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
        return $true
    }

    $targetWithoutFragment = $LiteralTarget.Split('#', 2)[0]
    if ([string]::IsNullOrWhiteSpace($targetWithoutFragment)) {
        return $true
    }

    try {
        $decodedTarget = [System.Uri]::UnescapeDataString($targetWithoutFragment)
        $targetPath = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($SourceDirectory, $decodedTarget)
        )
    } catch {
        return $false
    }

    return Test-Path -LiteralPath $targetPath
}

$repoRootPath = [System.IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath $repoRootPath -PathType Container)) {
    throw "Repository root '$repoRootPath' does not exist."
}

$unresolvedPairs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($relativeSourcePath in Get-TrackedMarkdownFiles -Root $repoRootPath) {
    $sourcePath = Join-Path $repoRootPath $relativeSourcePath
    $sourceDirectory = [System.IO.Path]::GetDirectoryName($sourcePath)
    $inFence = $false
    $fenceCharacter = [char]0
    $fenceLength = 0

    foreach ($line in Get-Content -LiteralPath $sourcePath) {
        $fence = [regex]::Match($line, '^\s*(?<marker>`{3,}|~{3,})')
        if ($fence.Success) {
            $marker = $fence.Groups['marker'].Value
            if (-not $inFence) {
                $inFence = $true
                $fenceCharacter = $marker[0]
                $fenceLength = $marker.Length
                continue
            }

            if ($marker[0] -eq $fenceCharacter -and $marker.Length -ge $fenceLength) {
                $inFence = $false
            }
            continue
        }

        if ($inFence) {
            continue
        }

        foreach ($contents in Get-MarkdownLinkContents -Line $line) {
            $literalTarget = Get-MarkdownLinkTarget -Contents $contents
            if ($null -eq $literalTarget) {
                continue
            }

            if (-not (Test-LocalMarkdownTarget -LiteralTarget $literalTarget -SourceDirectory $sourceDirectory)) {
                $normalizedSourcePath = $relativeSourcePath.Replace('\', '/')
                $null = $unresolvedPairs.Add("$normalizedSourcePath`t$literalTarget")
            }
        }
    }
}

$pairSet = [string[]]@($unresolvedPairs)
[System.Array]::Sort($pairSet, [System.StringComparer]::Ordinal)
foreach ($pair in $pairSet) {
    Write-Output $pair
}

if ($WriteBaseline) {
    if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
        throw '-WriteBaseline requires -BaselinePath.'
    }

    $baselineDirectory = [System.IO.Path]::GetDirectoryName($BaselinePath)
    if (-not [string]::IsNullOrWhiteSpace($baselineDirectory)) {
        New-Item -ItemType Directory -Path $baselineDirectory -Force | Out-Null
    }
    [System.IO.File]::WriteAllLines(
        [System.IO.Path]::GetFullPath($BaselinePath),
        [string[]]$pairSet,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if ($FailOnUnresolved) {
    $allowedPairs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if (-not [string]::IsNullOrWhiteSpace($BaselinePath) -and -not $WriteBaseline) {
        if (-not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
            throw "Baseline '$BaselinePath' does not exist."
        }

        foreach ($baselinePair in Get-Content -LiteralPath $BaselinePath) {
            if (-not [string]::IsNullOrWhiteSpace($baselinePair)) {
                $null = $allowedPairs.Add($baselinePair)
            }
        }
    }

    $newPairs = @($pairSet | Where-Object { -not $allowedPairs.Contains($_) })
    if ($newPairs.Count -gt 0) {
        exit 1
    }
}
