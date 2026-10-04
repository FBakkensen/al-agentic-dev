#requires -Version 7.2

<#
.SYNOPSIS
    AL Namespace Map Module

.DESCRIPTION
    Applies a reviewed map of an app's objects to namespaces in one deterministic
    pass: each file gets its namespace line and the using lines its references
    need, moves to the folder its namespace names below the source root, and takes
    the CodeCop file name. It reads and writes text only, never the compiler.
    Invoke-NamespaceMap is the one entry; it builds and checks the whole plan
    before the first write.

.NOTES
    The map format is documented in NAMESPACE-MAP.md next to SKILL.md.
#>

Set-StrictMode -Version Latest

# AL object keyword -> whether the object has an ID, and the CodeCop file-name
# type (Best practices for AL, "File naming"). reportextension follows the page's
# <FullTypeName>Ext notation; entitlement is not in the type map, so its file keeps its name.
$script:ObjectTypes = @{
    table                  = @{ HasId = $true;  FileType = 'Table' }
    tableextension         = @{ HasId = $true;  FileType = 'TableExt' }
    page                   = @{ HasId = $true;  FileType = 'Page' }
    pageextension          = @{ HasId = $true;  FileType = 'PageExt' }
    pagecustomization      = @{ HasId = $false; FileType = 'PageCust' }
    codeunit               = @{ HasId = $true;  FileType = 'Codeunit' }
    report                 = @{ HasId = $true;  FileType = 'Report' }
    reportextension        = @{ HasId = $true;  FileType = 'ReportExt' }
    xmlport                = @{ HasId = $true;  FileType = 'Xmlport' }
    query                  = @{ HasId = $true;  FileType = 'Query' }
    enum                   = @{ HasId = $true;  FileType = 'Enum' }
    enumextension          = @{ HasId = $true;  FileType = 'EnumExt' }
    controladdin           = @{ HasId = $false; FileType = 'ControlAddin' }
    profile                = @{ HasId = $false; FileType = 'Profile' }
    interface              = @{ HasId = $false; FileType = 'Interface' }
    permissionset          = @{ HasId = $true;  FileType = 'PermissionSet' }
    permissionsetextension = @{ HasId = $true;  FileType = 'PermissionSetExt' }
    entitlement            = @{ HasId = $false; FileType = $null }
}

$script:NamespacePattern = '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$'

# =============================================================================
# Entry
# =============================================================================

function Invoke-NamespaceMap {
    <#
    .SYNOPSIS
        Apply a reviewed namespace map to an app.
    .DESCRIPTION
        Builds the plan for every .al file of the app, checks all of it, and
        throws one error listing every problem when any check fails, with nothing
        written. Otherwise writes each file to its target and removes the folders
        the moves emptied. Returns Files, one record per written file with
        Source, Target, Namespace, and Usings (repo paths are absolute).
    .PARAMETER MapPath
        The reviewed map: a JSON array of { type, id, name, namespace }.
    .PARAMETER AppDir
        The app folder.
    .PARAMETER RootNamespace
        The app's root namespace; every map namespace is the root or below it.
    .PARAMETER ExcludeDirs
        App folders nested inside AppDir (test apps) that are not part of this app.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MapPath,

        [Parameter(Mandatory)]
        [string]$AppDir,

        [Parameter(Mandatory)]
        [string]$RootNamespace,

        [string[]]$ExcludeDirs = @()
    )

    $plan = Get-NamespaceMapPlan -MapPath $MapPath -AppDir $AppDir -RootNamespace $RootNamespace -ExcludeDirs $ExcludeDirs
    if (@($plan.Errors).Count -gt 0) {
        throw "The namespace map was not applied; nothing was written. $(@($plan.Errors).Count) problem(s):`n- $(@($plan.Errors) -join "`n- ")"
    }

    foreach ($item in $plan.Items) {
        New-Item -ItemType Directory -Path (Split-Path $item.Target -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllBytes($item.Target, $item.NewBytes)
    }

    $targets = @($plan.Items | ForEach-Object { $_.Target })
    foreach ($item in $plan.Items) {
        if (-not ($targets | Where-Object { $_ -ieq $item.Source })) {
            Remove-Item -LiteralPath $item.Source -Force -Confirm:$false
        }
    }
    foreach ($directory in @($plan.Items | ForEach-Object { Split-Path $_.Source -Parent } | Select-Object -Unique | Sort-Object -Descending { $_.Length })) {
        Remove-EmptyFolder -Path $directory -StopAt $plan.AppFull
    }

    return [pscustomobject]@{
        Files = @($plan.Items | ForEach-Object {
            [pscustomobject]@{ Source = $_.Source; Target = $_.Target; Namespace = $_.Namespace; Usings = @($_.Usings) }
        })
    }
}

# =============================================================================
# The plan: read, check, compute — no writes
# =============================================================================

function Get-NamespaceMapPlan {
    param(
        [Parameter(Mandatory)][string]$MapPath,
        [Parameter(Mandatory)][string]$AppDir,
        [Parameter(Mandatory)][string]$RootNamespace,
        [string[]]$ExcludeDirs = @()
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $appFull = [System.IO.Path]::GetFullPath($AppDir).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $appFull -PathType Container)) {
        throw "The app folder $AppDir does not exist."
    }

    if ($RootNamespace -notmatch $script:NamespacePattern) {
        $errors.Add("Root namespace '$RootNamespace' is not a dotted AL identifier. Pass the app's root namespace, such as Contoso.Sales.")
    }

    $entries = Read-NamespaceMap -MapPath $MapPath -RootNamespace $RootNamespace -Errors $errors

    $srcDir = Join-Path $appFull 'src'
    $sourceRoot = if (Test-Path -LiteralPath $srcDir -PathType Container) { $srcDir } else { $appFull }

    $files = Get-AppAlFile -AppFull $appFull -ExcludeDirs $ExcludeDirs
    $parsed = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $result = Read-AlFile -Path $file.FullName -AppFull $appFull
        if ($result.Error) { $errors.Add($result.Error); continue }
        $parsed.Add($result)
    }

    # Match the map to the app's objects.
    $objectsByKey = @{}
    foreach ($file in $parsed) {
        foreach ($object in $file.Objects) {
            if ($objectsByKey.ContainsKey($object.Key)) {
                $errors.Add("$($object.Label) is declared in $(Get-AppRelative $appFull $objectsByKey[$object.Key].Path) and $(Get-AppRelative $appFull $file.Path). Object names are unique per app; remove one.")
            } else {
                $objectsByKey[$object.Key] = $file
            }
        }
    }
    $entriesByKey = @{}
    foreach ($entry in $entries) { $entriesByKey[$entry.Key] = $entry }

    foreach ($entry in $entries) {
        if ($objectsByKey.ContainsKey($entry.Key)) { continue }
        $sameId = if ($script:ObjectTypes[$entry.Type].HasId) {
            $parsed | ForEach-Object { $_.Objects } | Where-Object { $_.Type -eq $entry.Type -and $_.Id -eq $entry.Id } | Select-Object -First 1
        }
        $hint = if ($sameId) { " The app's $($entry.Type) $($entry.Id) is named $($sameId.Name); correct the name in the map." } else { ' Remove the entry, or correct its type, id, and name.' }
        $errors.Add("Map entry $($entry.Label) names an object the app does not have.$hint")
    }
    foreach ($file in $parsed) {
        foreach ($object in $file.Objects | Where-Object { -not $entriesByKey.ContainsKey($_.Key) }) {
            $errors.Add("$($object.Label) in $(Get-AppRelative $appFull $file.Path) is missing from the map. Add an entry with its namespace.")
        }
    }

    # The name index drives the using lines: other objects' names -> their namespaces.
    $namespacesByName = @{}
    foreach ($entry in $entries) {
        if (-not $objectsByKey.ContainsKey($entry.Key)) { continue }
        $name = $entry.Name.ToLowerInvariant()
        if (-not $namespacesByName.ContainsKey($name)) { $namespacesByName[$name] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        [void]$namespacesByName[$name].Add($entry.Namespace)
    }

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $parsed) {
        $mapped = @($file.Objects | Where-Object { $entriesByKey.ContainsKey($_.Key) } | ForEach-Object { $entriesByKey[$_.Key] })
        if ($mapped.Count -ne @($file.Objects).Count) { continue }
        $namespaces = @($mapped | ForEach-Object { $_.Namespace } | Select-Object -Unique)
        if ($namespaces.Count -gt 1) {
            $errors.Add("$(Get-AppRelative $appFull $file.Path) holds objects the map sends to different namespaces ($($namespaces -join ', ')). A file has one namespace; give its objects the same one.")
            continue
        }
        $namespace = $namespaces[0]

        $usingSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($reference in $file.References) {
            if (-not $namespacesByName.ContainsKey($reference)) { continue }
            foreach ($candidate in $namespacesByName[$reference]) {
                if ($candidate -ine $namespace) { [void]$usingSet.Add($candidate) }
            }
        }
        [string[]]$usings = @($usingSet)
        [Array]::Sort($usings, [System.StringComparer]::OrdinalIgnoreCase)

        $segments = @(Get-NamespaceFolderSegment -Namespace $namespace -RootNamespace $RootNamespace)
        $folder = $sourceRoot
        foreach ($segment in $segments) { $folder = Join-Path $folder $segment }
        $fileName = Get-CodeCopFileName -File $file
        $target = Join-Path $folder $fileName

        $block = "namespace $namespace;$($file.NewLine)$($file.NewLine)"
        if ($usings.Count) { $block += (($usings | ForEach-Object { "using $_;" }) -join $file.NewLine) + $file.NewLine + $file.NewLine }
        $newText = $file.Text.Insert($file.InsertAt, $block)
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($newText)
        if ($file.HasBom) { $bytes = [byte[]]@(0xEF, 0xBB, 0xBF) + $bytes }

        $items.Add([pscustomobject]@{
            Source = $file.Path; Target = $target; Namespace = $namespace; Usings = $usings; NewBytes = $bytes
        })
    }

    # Two files sent to one path; a target held by a file the pass does not move.
    foreach ($group in ($items | Group-Object { $_.Target.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })) {
        $errors.Add("Files $((@($group.Group | ForEach-Object { Get-AppRelative $appFull $_.Source }) -join ', ')) all go to $(Get-AppRelative $appFull $group.Group[0].Target). Give the objects different names or namespaces.")
    }
    $sources = @($parsed | ForEach-Object { $_.Path })
    foreach ($item in $items) {
        if ((Test-Path -LiteralPath $item.Target) -and -not ($sources | Where-Object { $_ -ieq $item.Target })) {
            $errors.Add("$(Get-AppRelative $appFull $item.Target) already exists and is not one of the app's .al files; the move of $(Get-AppRelative $appFull $item.Source) would overwrite it.")
        }
    }

    return [pscustomobject]@{ Errors = @($errors); Items = @($items); AppFull = $appFull }
}

function Read-NamespaceMap {
    param(
        [Parameter(Mandatory)][string]$MapPath,
        [Parameter(Mandatory)][string]$RootNamespace,
        [Parameter(Mandatory)]$Errors
    )

    if (-not (Test-Path -LiteralPath $MapPath -PathType Leaf)) {
        throw "The map file $MapPath does not exist."
    }
    try {
        $json = Get-Content -LiteralPath $MapPath -Raw | ConvertFrom-Json -NoEnumerate
    } catch {
        throw "The map file $MapPath is not valid JSON: $($_.Exception.Message)"
    }
    if ($json -isnot [System.Array]) {
        throw "The map file $MapPath is not a JSON array of { type, id, name, namespace }."
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    $position = 0
    foreach ($raw in $json) {
        $position++
        $where = "Map entry $position"
        $type = Get-JsonProperty $raw 'type'
        $id = Get-JsonProperty $raw 'id'
        $name = Get-JsonProperty $raw 'name'
        $namespace = Get-JsonProperty $raw 'namespace'

        if ($type -isnot [string] -or -not $script:ObjectTypes.ContainsKey($type.ToLowerInvariant())) {
            $Errors.Add("$where has type '$type', which is not an AL object type. Use the object keyword, such as codeunit or tableextension.")
            continue
        }
        $type = $type.ToLowerInvariant()
        $hasId = $script:ObjectTypes[$type].HasId
        $idOk = ($id -is [int] -or $id -is [long]) -and (($hasId -and $id -ge 1) -or (-not $hasId -and $id -eq 0))
        if (-not $idOk) {
            $Errors.Add("$where ($type) has id '$id'. $(if ($hasId) { 'Use the object ID, a positive number.' } else { "A $type has no ID; use 0." })")
            continue
        }
        if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) {
            $Errors.Add("$where ($type $id) has no name. Use the object name without quotes.")
            continue
        }
        $underRoot = $namespace -is [string] -and $RootNamespace -match $script:NamespacePattern -and
            ($namespace -ieq $RootNamespace -or $namespace.StartsWith($RootNamespace + '.', [System.StringComparison]::OrdinalIgnoreCase))
        if ($namespace -isnot [string] -or $namespace -notmatch $script:NamespacePattern -or -not $underRoot) {
            $Errors.Add("$where ($type $id $name) has namespace '$namespace'. Use a dotted AL identifier that is $RootNamespace or starts with $RootNamespace.")
            continue
        }

        $key = if ($hasId) { "$type|$id|$($name.ToLowerInvariant())" } else { "$type|0|$($name.ToLowerInvariant())" }
        $label = if ($hasId) { "$type $id $name" } else { "$type $name" }
        if ($seen.ContainsKey($key)) {
            $Errors.Add("Map entry $label appears twice (entries $($seen[$key]) and $position). Keep one.")
            continue
        }
        $seen[$key] = $position
        $entries.Add([pscustomobject]@{ Key = $key; Label = $label; Type = $type; Id = [long]$id; Name = $name; Namespace = $namespace })
    }
    return @($entries)
}

function Get-JsonProperty {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

# =============================================================================
# Reading the app's AL files
# =============================================================================

function Get-AppAlFile {
    # The same files rule 1 of the module check reads: every .al below the app,
    # outside dot-folders and outside nested apps.
    param([Parameter(Mandatory)][string]$AppFull, [string[]]$ExcludeDirs = @())

    $nested = @($ExcludeDirs | Where-Object { $_ } | ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\', '/') } |
        Where-Object { $_ -ne $AppFull -and $_.StartsWith($AppFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) })

    return @(Get-ChildItem -LiteralPath $AppFull -Filter '*.al' -Recurse -File |
        Where-Object {
            $fileFull = $_.FullName
            $belowApp = [System.IO.Path]::GetRelativePath($AppFull, $fileFull)
            -not ($belowApp -split '[\\/]' | Where-Object { $_.StartsWith('.') }) -and
            -not ($nested | Where-Object { $fileFull.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) })
        } |
        Sort-Object FullName)
}

function Read-AlFile {
    <#
    .SYNOPSIS
        Read one file: its text, objects, name references, and the insertion point.
    .DESCRIPTION
        Returns an object with Error set when the file cannot be organized by the
        pass: not UTF-8, no object, a namespace or using already present.
    #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$AppFull)

    $relative = Get-AppRelative $AppFull $Path
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    try {
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes, $(if ($hasBom) { 3 } else { 0 }), $bytes.Length - $(if ($hasBom) { 3 } else { 0 }))
    } catch {
        return [pscustomobject]@{ Error = "$relative is not valid UTF-8. Save it as UTF-8, then run the pass again." }
    }

    $tokens = @(Get-AlToken -Text $text)
    $objects = [System.Collections.Generic.List[object]]::new()
    $declarationIndexes = [System.Collections.Generic.HashSet[int]]::new()
    $firstObjectIndex = -1
    $header = $null
    $depth = 0
    $previous = $null
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $token = $tokens[$i]
        if ($token.Kind -in 'comment', 'directive') { continue }
        if ($token.Text -eq '{') { $depth++ }
        elseif ($token.Text -eq '}') { $depth-- }
        elseif ($depth -eq 0 -and $token.Kind -eq 'ident' -and ($null -eq $previous -or $previous.Text -in '}', ';')) {
            $word = $token.Text.ToLowerInvariant()
            if ($word -in 'namespace', 'using') {
                $header = $word
            } elseif ($script:ObjectTypes.ContainsKey($word)) {
                $hasId = $script:ObjectTypes[$word].HasId
                $rest = if ($i + 1 -lt $tokens.Count) { @($tokens[($i + 1)..($tokens.Count - 1)] | Where-Object { $_.Kind -notin 'comment', 'directive' } | Select-Object -First 2) } else { @() }
                $id = 0
                $nameToken = $null
                if ($hasId) {
                    if ($rest.Count -ge 2 -and $rest[0].Kind -eq 'number' -and $rest[1].Kind -in 'ident', 'qident') { $id = [long]$rest[0].Text; $nameToken = $rest[1] }
                } elseif ($rest.Count -ge 1 -and $rest[0].Kind -in 'ident', 'qident') {
                    $nameToken = $rest[0]
                }
                if ($nameToken) {
                    [void]$declarationIndexes.Add($nameToken.Index)
                    if ($firstObjectIndex -lt 0) { $firstObjectIndex = $token.Index }
                    $label = if ($hasId) { "$word $id $($nameToken.Value)" } else { "$word $($nameToken.Value)" }
                    $objects.Add([pscustomobject]@{
                        Type = $word; Id = $id; Name = $nameToken.Value; Label = $label
                        Key = "$word|$id|$($nameToken.Value.ToLowerInvariant())"
                    })
                }
            }
        }
        $previous = $token
    }

    if ($header) {
        return [pscustomobject]@{ Error = "$relative already has a $header statement. The pass organizes files that have none; remove it, or leave the file out of the app folder." }
    }
    if ($objects.Count -eq 0) {
        return [pscustomobject]@{ Error = "$relative declares no AL object the pass recognizes. Remove the file or declare its object." }
    }

    # Names the file refers to: identifiers and quoted identifiers, except member
    # accesses after a dot and the declared object names themselves.
    $references = [System.Collections.Generic.HashSet[string]]::new()
    $before = $null
    foreach ($token in $tokens) {
        if ($token.Kind -in 'comment', 'directive') { continue }
        if ($token.Kind -in 'ident', 'qident' -and -not $declarationIndexes.Contains($token.Index) -and -not ($before -and $before.Text -eq '.')) {
            [void]$references.Add($token.Value.ToLowerInvariant())
        }
        $before = $token
    }

    $newLine = if ($text -match "\r\n") { "`r`n" } else { "`n" }
    $lineStart = if ($firstObjectIndex -gt 0) { $text.LastIndexOf("`n", $firstObjectIndex - 1) + 1 } else { 0 }

    return [pscustomobject]@{
        Error = $null; Path = $Path; Text = $text; HasBom = $hasBom; NewLine = $newLine
        InsertAt = $lineStart; Objects = @($objects); References = @($references)
    }
}

function Get-AlToken {
    <#
    .SYNOPSIS
        Split AL text into tokens, setting comments, strings, and directives apart.
    .DESCRIPTION
        One left-to-right pass, so a quote inside a comment or a preprocessor line
        never opens a string. Kinds: comment, directive, string, qident, number,
        ident, punct. Value is the identifier without its quotes.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $pattern = '(?m)^[ \t]*#[^\r\n]*|//[^\r\n]*|/\*.*?\*/|@?''(?:[^''\r\n]|'''')*''|"[^"\r\n]*"|\d+|[A-Za-z_][A-Za-z0-9_]*|::|[{};.]'
    foreach ($match in [regex]::Matches($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        $value = $match.Value
        $trimmed = $value.TrimStart()
        $kind = if ($trimmed.StartsWith('#')) { 'directive' }
        elseif ($trimmed.StartsWith('//') -or $trimmed.StartsWith('/*')) { 'comment' }
        elseif ($trimmed.StartsWith("'") -or $trimmed.StartsWith("@'")) { 'string' }
        elseif ($trimmed.StartsWith('"')) { 'qident' }
        elseif ($trimmed -match '^\d') { 'number' }
        elseif ($trimmed -match '^[A-Za-z_]') { 'ident' }
        else { 'punct' }
        $inner = if ($kind -eq 'qident') { $value.Substring(1, $value.Length - 2) } else { $value }
        [pscustomobject]@{ Kind = $kind; Text = $value; Value = $inner; Index = $match.Index + ($value.Length - $trimmed.Length) }
    }
}

# =============================================================================
# Paths and names
# =============================================================================

function Get-NamespaceFolderSegment {
    param([Parameter(Mandatory)][string]$Namespace, [Parameter(Mandatory)][string]$RootNamespace)
    if ($Namespace -ieq $RootNamespace) { return @() }
    return @($Namespace.Substring($RootNamespace.Length + 1) -split '\.')
}

function Get-CodeCopFileName {
    # <ObjectName, A-Z a-z 0-9 only>.<Type>.al; a file with several objects, an
    # entitlement, or a name with no such character keeps its file name.
    param([Parameter(Mandatory)]$File)

    $current = [System.IO.Path]::GetFileName($File.Path)
    if (@($File.Objects).Count -ne 1) { return $current }
    $object = $File.Objects[0]
    $fileType = $script:ObjectTypes[$object.Type].FileType
    $stem = $object.Name -replace '[^A-Za-z0-9]', ''
    if (-not $fileType -or -not $stem) { return $current }
    return "$stem.$fileType.al"
}

function Get-AppRelative {
    param([string]$AppFull, [string]$Path)
    return ([System.IO.Path]::GetRelativePath($AppFull, $Path)) -replace '\\', '/'
}

function Remove-EmptyFolder {
    # Remove Path and its parents while they are empty, stopping above StopAt's source content.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$StopAt)

    $current = $Path.TrimEnd('\', '/')
    while ($current -ine $StopAt -and $current.StartsWith($StopAt + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (-not (Test-Path -LiteralPath $current -PathType Container)) { break }
        if (@(Get-ChildItem -LiteralPath $current -Force).Count -gt 0) { break }
        Remove-Item -LiteralPath $current -Force -Confirm:$false
        $current = Split-Path $current -Parent
    }
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    'Invoke-NamespaceMap'
)
