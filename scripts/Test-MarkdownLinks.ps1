#Requires -Version 7.2
<#
.SYNOPSIS
    Audits tracked Markdown links whose local targets do not exist.
.DESCRIPTION
    Reads the tracked Markdown corpus with git ls-files, ignores fenced code
    blocks, inline code spans (including spans that continue across lines
    within a paragraph), and non-local targets, and writes one sorted, unique
    source-file<TAB>literal-target pair for each unresolved target.

    Use -Path to audit named repository-root-relative source files instead of
    the tracked corpus; git is not consulted. A named file absent from the
    working tree is skipped, matching a tracked file deleted from it.

    Targets starting with a single '/' resolve from the repository root. Any
    local target that resolves outside the repository root — textually or
    through a symlink, junction, or other reparse point — is reported as
    unresolved without probing the outside path. Query strings and fragments
    are stripped before filesystem resolution; the reported pair keeps the
    literal target. Path case comparison follows the case sensitivity of the
    volume hosting the repository root.

    Use -BaselinePath with -FailOnUnresolved to fail only for unresolved pairs
    not already present in the baseline. Use -WriteBaseline to refresh it;
    combined with -FailOnUnresolved, the comparison runs against the baseline
    just written and therefore succeeds.
.EXAMPLE
    pwsh scripts/Test-MarkdownLinks.ps1
.EXAMPLE
    pwsh scripts/Test-MarkdownLinks.ps1 -Path README.md,docs/guide.md
.EXAMPLE
    pwsh scripts/Test-MarkdownLinks.ps1 -BaselinePath .link-baseline.txt -FailOnUnresolved
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),

    [string[]]$Path,

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

function Find-BacktickRun {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$StartIndex,

        [Parameter(Mandatory = $true)]
        [int]$RunLength
    )

    # Backslashes are not escapes inside code spans, so the closing run is
    # found by raw scanning for a backtick run of exactly the opening length.
    $search = $StartIndex
    while ($search -lt $Text.Length) {
        if ($Text[$search] -ne '`') {
            $search++
            continue
        }

        $candidateStart = $search
        while ($search -lt $Text.Length -and $Text[$search] -eq '`') {
            $search++
        }
        if (($search - $candidateStart) -eq $RunLength) {
            return $candidateStart
        }
    }

    return -1
}

function Remove-InlineCodeSpans {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    # Operates on a whole paragraph joined with "`n" so code spans opened on
    # one line and closed on a later line are removed, while backtick runs
    # with no matching closer in the paragraph stay literal text. Newlines
    # inside removed spans are preserved to keep line boundaries stable.
    $result = [System.Text.StringBuilder]::new()
    $index = 0
    while ($index -lt $Text.Length) {
        $character = $Text[$index]
        if ($character -eq '\') {
            # A backslash-escaped character (including a backtick) is literal
            # text and never opens a code span.
            $null = $result.Append($character)
            $index++
            if ($index -lt $Text.Length) {
                $null = $result.Append($Text[$index])
                $index++
            }
            continue
        }

        if ($character -ne '`') {
            $null = $result.Append($character)
            $index++
            continue
        }

        $runStart = $index
        while ($index -lt $Text.Length -and $Text[$index] -eq '`') {
            $index++
        }
        $runLength = $index - $runStart

        $closeStart = Find-BacktickRun -Text $Text -StartIndex $index -RunLength $runLength
        if ($closeStart -ge 0) {
            $null = $result.Append(' ')
            for ($scan = $runStart; $scan -lt $closeStart + $runLength; $scan++) {
                if ($Text[$scan] -eq "`n") {
                    $null = $result.Append("`n")
                }
            }
            $index = $closeStart + $runLength
        } else {
            $null = $result.Append($Text.Substring($runStart, $runLength))
        }
    }

    return $result.ToString()
}

function Get-PathCaseComparison {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    if (-not $script:PathCaseComparisonCache) {
        $script:PathCaseComparisonCache = @{}
    }
    $key = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($RootPath))
    if ($script:PathCaseComparisonCache.ContainsKey($key)) {
        return $script:PathCaseComparisonCache[$key]
    }

    # Case sensitivity is a property of the volume hosting the repository, not
    # of the operating system, so probe the root directory itself.
    $comparison = $null
    if ([System.IO.Directory]::Exists($key)) {
        $probeName = '.markdown-link-case-probe-' + [guid]::NewGuid().ToString('n')
        $probePath = [System.IO.Path]::Combine($key, $probeName)
        try {
            [System.IO.File]::WriteAllText($probePath, '')
            $comparison = if ([System.IO.File]::Exists([System.IO.Path]::Combine($key, $probeName.ToUpperInvariant()))) {
                [System.StringComparison]::OrdinalIgnoreCase
            } else {
                [System.StringComparison]::Ordinal
            }
        } catch {
            $comparison = $null
        } finally {
            try {
                [System.IO.File]::Delete($probePath)
            } catch {
                Write-Verbose "Could not delete case probe '$probePath'."
            }
        }

        if ($null -eq $comparison) {
            # Read-only volume: flip the casing of the existing root leaf name.
            $leaf = [System.IO.Path]::GetFileName($key)
            $flippedLeaf = -join ($leaf.ToCharArray() | ForEach-Object {
                if ([char]::IsLower($_)) { [char]::ToUpperInvariant($_) }
                elseif ([char]::IsUpper($_)) { [char]::ToLowerInvariant($_) }
                else { $_ }
            })
            if ($flippedLeaf -and -not $flippedLeaf.Equals($leaf, [System.StringComparison]::Ordinal)) {
                $flippedPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($key), $flippedLeaf)
                $comparison = if ([System.IO.Directory]::Exists($flippedPath)) {
                    [System.StringComparison]::OrdinalIgnoreCase
                } else {
                    [System.StringComparison]::Ordinal
                }
            }
        }
    }

    if ($null -eq $comparison) {
        $comparison = if ([System.OperatingSystem]::IsLinux()) {
            [System.StringComparison]::Ordinal
        } else {
            [System.StringComparison]::OrdinalIgnoreCase
        }
    }

    $script:PathCaseComparisonCache[$key] = $comparison
    return $comparison
}

function Test-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $root = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($RootPath))
    $normalizedPath = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($Path))

    $relative = [System.IO.Path]::GetRelativePath($root, $normalizedPath)
    $escapesRoot = [System.IO.Path]::IsPathRooted($relative) -or
        $relative -eq '..' -or
        $relative.StartsWith('..' + [System.IO.Path]::DirectorySeparatorChar) -or
        $relative.StartsWith('..' + [System.IO.Path]::AltDirectorySeparatorChar)

    if (-not $escapesRoot) {
        $rejoined = [System.IO.Path]::TrimEndingDirectorySeparator(
            [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $relative))
        )
        if ($rejoined.Equals($normalizedPath, [System.StringComparison]::Ordinal)) {
            return $true
        }
        if (-not $rejoined.Equals($normalizedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
        # GetRelativePath matched with the platform default case rule while the
        # strings differ only in casing: the hosting volume decides.
        return (Get-PathCaseComparison -RootPath $root) -eq [System.StringComparison]::OrdinalIgnoreCase
    }

    $rootWithSeparator = if ($root.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or
        $root.EndsWith([System.IO.Path]::AltDirectorySeparatorChar)) {
        $root
    } else {
        $root + [System.IO.Path]::DirectorySeparatorChar
    }
    $matchesIgnoringCase = $normalizedPath.Equals($root, [System.StringComparison]::OrdinalIgnoreCase) -or
        $normalizedPath.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $matchesIgnoringCase) {
        return $false
    }
    # GetRelativePath rejected the prefix with the platform default case rule
    # while it matches ignoring case: the hosting volume decides.
    return (Get-PathCaseComparison -RootPath $root) -eq [System.StringComparison]::OrdinalIgnoreCase
}

function Get-PhysicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $full = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($Path))
    $pathRoot = [System.IO.Path]::GetPathRoot($full)
    $separators = [char[]]@(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $segments = $full.Substring($pathRoot.Length).Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries)

    $current = $pathRoot
    for ($index = 0; $index -lt $segments.Length; $index++) {
        $current = [System.IO.Path]::Combine($current, $segments[$index])
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            for ($rest = $index + 1; $rest -lt $segments.Length; $rest++) {
                $current = [System.IO.Path]::Combine($current, $segments[$rest])
            }
            break
        }
        if ($item.LinkType) {
            $target = $item.ResolveLinkTarget($true)
            if ($null -ne $target) {
                $current = [System.IO.Path]::TrimEndingDirectorySeparator(
                    [System.IO.Path]::GetFullPath($target.FullName)
                )
            }
        }
    }

    return $current
}

function Test-PhysicalPathWithinRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [int]$Depth = 0
    )

    if ($Depth -gt 40) {
        # Guard against link cycles; treat an unresolvable chain as outside.
        return $false
    }

    if (-not $script:PhysicalRootCache) {
        $script:PhysicalRootCache = @{}
    }
    $root = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($RootPath))
    if (-not $script:PhysicalRootCache.ContainsKey($root)) {
        $script:PhysicalRootCache[$root] = Get-PhysicalPath -Path $root
    }
    $physicalRoot = $script:PhysicalRootCache[$root]

    $normalizedPath = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($Path))
    $relative = [System.IO.Path]::GetRelativePath($root, $normalizedPath)
    if ($relative -eq '.') {
        return $true
    }
    if ([System.IO.Path]::IsPathRooted($relative)) {
        return $false
    }

    # Only components below the repository root can smuggle an escape: walk
    # them, and when one is a link, decide containment from the resolved
    # target path text alone so outside paths are never probed.
    $separators = [char[]]@(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $segments = $relative.Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries)
    $current = $physicalRoot
    for ($index = 0; $index -lt $segments.Length; $index++) {
        $current = [System.IO.Path]::Combine($current, $segments[$index])
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            break
        }
        if ($item.LinkType) {
            $target = $item.ResolveLinkTarget($true)
            if ($null -eq $target) {
                continue
            }
            $targetPath = [System.IO.Path]::TrimEndingDirectorySeparator(
                [System.IO.Path]::GetFullPath($target.FullName)
            )
            $withinPhysical = Test-PathWithinRoot -Path $targetPath -RootPath $physicalRoot
            if (-not $withinPhysical -and -not (Test-PathWithinRoot -Path $targetPath -RootPath $root)) {
                return $false
            }
            if (-not $withinPhysical) {
                # Inside the logical root only (e.g. the root itself sits
                # behind a link): re-express the target below the physical root.
                $targetPath = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($physicalRoot, [System.IO.Path]::GetRelativePath($root, $targetPath))
                ))
            }

            # Re-walk the in-root target plus the remaining segments so links
            # nested inside the target path are checked the same way.
            $rewalkPath = $targetPath
            for ($rest = $index + 1; $rest -lt $segments.Length; $rest++) {
                $rewalkPath = [System.IO.Path]::Combine($rewalkPath, $segments[$rest])
            }
            return Test-PhysicalPathWithinRoot -Path $rewalkPath -RootPath $physicalRoot -Depth ($Depth + 1)
        }
    }

    return $true
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

    return @($files -split "`0")
}

function Get-MarkdownSourceFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [AllowEmptyCollection()]
        [string[]]$ExplicitPaths,

        [switch]$UseExplicitPaths
    )

    $candidates = if ($UseExplicitPaths) {
        # pwsh -File hands a script one literal string per argument, so a
        # multi-path -Path arrives comma-joined and is split here. Ceiling: a
        # source file whose name contains a comma cannot be named with -Path.
        @($ExplicitPaths | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    } else {
        Get-TrackedMarkdownFiles -Root $Root
    }

    # A tracked path can be absent from the working tree, and a caller-supplied
    # path can name a file that was never written or one that escapes the
    # repository root; none of those is a source.
    return @($candidates | Where-Object {
            if ([string]::IsNullOrWhiteSpace($_)) {
                return $false
            }

            $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $Root $_))
            (Test-PathWithinRoot -Path $candidatePath -RootPath $Root) -and
            (Test-Path -LiteralPath $candidatePath -PathType Leaf)
        })
}

function Test-LocalMarkdownTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralTarget,

        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    if ([string]::IsNullOrWhiteSpace($LiteralTarget) -or
        $LiteralTarget.StartsWith('#') -or
        $LiteralTarget.StartsWith('//') -or
        $LiteralTarget -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
        return $true
    }

    $targetWithoutFragment = $LiteralTarget.Split('#', 2)[0]
    $targetWithoutQuery = $targetWithoutFragment.Split('?', 2)[0]
    if ([string]::IsNullOrWhiteSpace($targetWithoutQuery)) {
        return $true
    }

    try {
        $decodedTarget = [System.Uri]::UnescapeDataString($targetWithoutQuery)
        if ($decodedTarget.StartsWith('/') -or $decodedTarget.StartsWith('\')) {
            $baseDirectory = $RepoRootPath
            $decodedTarget = $decodedTarget.TrimStart('/', '\')
        } else {
            $baseDirectory = $SourceDirectory
        }

        $targetPath = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($baseDirectory, $decodedTarget)
        )
    } catch {
        return $false
    }

    if (-not (Test-PathWithinRoot -Path $targetPath -RootPath $RepoRootPath)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $targetPath)) {
        return $false
    }

    # An existing target can still be a symlink, junction, or other reparse
    # point whose final target lies outside the repository root.
    return Test-PhysicalPathWithinRoot -Path $targetPath -RootPath $RepoRootPath
}

$repoRootPath = [System.IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath $repoRootPath -PathType Container)) {
    throw "Repository root '$repoRootPath' does not exist."
}

function Add-UnresolvedParagraphPairs {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$ParagraphLines,

        [Parameter(Mandatory = $true)]
        [string]$RelativeSourcePath,

        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$UnresolvedPairs
    )

    if ($ParagraphLines.Count -eq 0) {
        return
    }

    $paragraphWithoutCodeSpans = Remove-InlineCodeSpans -Text ($ParagraphLines -join "`n")
    foreach ($lineWithoutCodeSpans in $paragraphWithoutCodeSpans -split "`n") {
        foreach ($contents in Get-MarkdownLinkContents -Line $lineWithoutCodeSpans) {
            $literalTarget = Get-MarkdownLinkTarget -Contents $contents
            if ($null -eq $literalTarget) {
                continue
            }

            $isResolved = Test-LocalMarkdownTarget `
                -LiteralTarget $literalTarget `
                -SourceDirectory $SourceDirectory `
                -RepoRootPath $RepoRootPath
            if (-not $isResolved) {
                $normalizedSourcePath = $RelativeSourcePath.Replace('\', '/')
                $null = $UnresolvedPairs.Add("$normalizedSourcePath`t$literalTarget")
            }
        }
    }
}

$unresolvedPairs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($relativeSourcePath in Get-MarkdownSourceFiles -Root $repoRootPath -ExplicitPaths $Path `
        -UseExplicitPaths:$PSBoundParameters.ContainsKey('Path')) {
    $sourcePath = Join-Path $repoRootPath $relativeSourcePath
    $sourceDirectory = [System.IO.Path]::GetDirectoryName($sourcePath)
    $inFence = $false
    $fenceCharacter = [char]0
    $fenceLength = 0
    $paragraphLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in Get-Content -LiteralPath $sourcePath) {
        $fence = [regex]::Match($line, '^\s*(?<marker>`{3,}|~{3,})')
        if ($fence.Success) {
            $marker = $fence.Groups['marker'].Value
            if (-not $inFence) {
                Add-UnresolvedParagraphPairs -ParagraphLines $paragraphLines `
                    -RelativeSourcePath $relativeSourcePath -SourceDirectory $sourceDirectory `
                    -RepoRootPath $repoRootPath -UnresolvedPairs $unresolvedPairs
                $paragraphLines.Clear()
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

        if ([string]::IsNullOrWhiteSpace($line)) {
            # A blank line ends the paragraph; inline code spans cannot cross it.
            Add-UnresolvedParagraphPairs -ParagraphLines $paragraphLines `
                -RelativeSourcePath $relativeSourcePath -SourceDirectory $sourceDirectory `
                -RepoRootPath $repoRootPath -UnresolvedPairs $unresolvedPairs
            $paragraphLines.Clear()
            continue
        }

        $paragraphLines.Add($line)
    }

    Add-UnresolvedParagraphPairs -ParagraphLines $paragraphLines `
        -RelativeSourcePath $relativeSourcePath -SourceDirectory $sourceDirectory `
        -RepoRootPath $repoRootPath -UnresolvedPairs $unresolvedPairs
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
    if ($WriteBaseline) {
        # The baseline was just written from the current pair set, so the
        # comparison runs against that same set.
        foreach ($pair in $pairSet) {
            $null = $allowedPairs.Add($pair)
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($BaselinePath)) {
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
