#requires -Version 7.2

<#
.SYNOPSIS
    AL Namespace Map Module

.DESCRIPTION
    The text-and-symbols pass behind apply-namespace-map.ps1. Invoke-NamespaceMap
    is the one entry; it builds and checks the whole plan before the first write.
    NAMESPACE-MAP.md next to SKILL.md holds the contract.
#>

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'al-source.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'module-check.psm1') -DisableNameChecking

# AL object keyword -> HasId and the CodeCop file-name type, from the reader.
$script:ObjectTypes = Get-AlObjectType

# The object types other code names, which is what a using is for. Extensions are never named.
$script:ReferenceableTypes = @('table', 'page', 'codeunit', 'report', 'xmlport', 'query', 'enum', 'controladdin', 'profile', 'interface', 'permissionset')

# SymbolReference.json array -> object type.
$script:SymbolKinds = @{
    Tables = 'table'; Pages = 'page'; Codeunits = 'codeunit'; Reports = 'report'; XmlPorts = 'xmlport'; Queries = 'query'
    EnumTypes = 'enum'; ControlAddIns = 'controladdin'; Profiles = 'profile'; Interfaces = 'interface'; PermissionSets = 'permissionset'
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
        Source, Target, Namespace, and Usings (absolute paths).
    .PARAMETER MapPath
        The reviewed map: a JSON array of { type, id, name, namespace }.
    .PARAMETER AppDir
        The app folder.
    .PARAMETER RootNamespace
        The app's root namespace; every map namespace is the root or below it.
    .PARAMETER SymbolDir
        The folder of the app's downloaded dependency symbol packages (.app files).
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

        [Parameter(Mandatory)]
        [string]$SymbolDir,

        [string[]]$ExcludeDirs = @()
    )

    $plan = Get-NamespaceMapPlan -MapPath $MapPath -AppDir $AppDir -RootNamespace $RootNamespace -SymbolDir $SymbolDir -ExcludeDirs $ExcludeDirs
    if (@($plan.Errors).Count -gt 0) {
        throw "The namespace map was not applied; nothing was written. $(@($plan.Errors).Count) problem(s):`n- $(@($plan.Errors) -join "`n- ")"
    }

    try {
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
    } catch {
        throw "Writing the namespace map stopped partway: $($_.Exception.Message) Restore the tree with git restore and git clean, then run the pass again."
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
        [Parameter(Mandatory)][string]$SymbolDir,
        [string[]]$ExcludeDirs = @()
    )

    $appFull = [System.IO.Path]::GetFullPath($AppDir).TrimEnd('\', '/')
    $source = Get-AppSource -App ([pscustomobject]@{ Dir = $appFull }) `
        -Apps (@([pscustomobject]@{ Dir = $appFull }) + @($ExcludeDirs | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Dir = $_ } }))
    if (-not $source) { throw "The app folder $AppDir does not exist." }

    $dependencyObjects = Read-DependencyObject -SymbolDir $SymbolDir

    $errors = [System.Collections.Generic.List[string]]::new()
    if ($RootNamespace -notmatch $script:NamespacePattern) {
        $errors.Add("Root namespace '$RootNamespace' is not a dotted AL identifier. Pass the app's root namespace, such as Contoso.Sales.")
    }
    $entries = @(Read-NamespaceMap -MapPath $MapPath -RootNamespace $RootNamespace -Errors $errors)

    $files = [System.Collections.Generic.List[object]]::new()
    foreach ($alFile in $source.Files) {
        $file = Read-AlFile -Path $alFile.FullName -AppFull $appFull
        if ($file.Error) { $errors.Add($file.Error) } else { $files.Add($file) }
    }

    $entriesByKey = Select-MapObjectMatch -Entries $entries -Files $files -AppFull $appFull -Errors $errors
    $index = New-ReferenceIndex -Entries $entries -DependencyObjects $dependencyObjects

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $mapped = @($file.Objects | Where-Object { $entriesByKey.ContainsKey($_.Key) } | ForEach-Object { $entriesByKey[$_.Key] })
        if ($mapped.Count -ne @($file.Objects).Count) { continue }
        $namespaces = @($mapped | ForEach-Object { $_.Namespace } | Select-Object -Unique)
        if ($namespaces.Count -gt 1) {
            $errors.Add("$(Get-AppRelative $appFull $file.Path) holds objects the map sends to different namespaces ($($namespaces -join ', ')). A file has one namespace; give its objects the same one.")
            continue
        }
        $namespace = $namespaces[0]

        $usings = Resolve-FileUsing -File $file -Namespace $namespace -Index $index -AppFull $appFull -Errors $errors
        $target = Get-TargetPath -File $file -Namespace $namespace -RootNamespace $RootNamespace -SourceRoot $source.SourceRoot
        $items.Add([pscustomobject]@{
            Source = $file.Path; Target = $target; Namespace = $namespace; Usings = $usings
            NewBytes = Get-RewrittenBytes -File $file -Namespace $namespace -Usings $usings
        })
    }

    Find-PathCollision -Items $items -Files $files -AppFull $appFull -Errors $errors

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

        $key = Get-ObjectKey -Type $type -Id $id -Name $name
        $label = Get-ObjectLabel -Type $type -Id $id -Name $name
        if ($seen.ContainsKey($key)) {
            $Errors.Add("Map entry $label appears twice (entries $($seen[$key]) and $position). Keep one.")
            continue
        }
        $seen[$key] = $position
        $entries.Add([pscustomobject]@{ Key = $key; Label = $label; Type = $type; Id = [long]$id; Name = $name; Namespace = $namespace })
    }
    return @($entries)
}

function Select-MapObjectMatch {
    # Matches map entries to the app's objects by key; returns the entries by key.
    # Reports an entry with no object, an object with no entry, and an object declared twice.
    param([object[]]$Entries = @(), [Parameter(Mandatory)]$Files, [Parameter(Mandatory)][string]$AppFull, [Parameter(Mandatory)]$Errors)

    $objectsByKey = @{}
    foreach ($file in $Files) {
        foreach ($object in $file.Objects) {
            if ($objectsByKey.ContainsKey($object.Key)) {
                $Errors.Add("$($object.Label) is declared in $(Get-AppRelative $AppFull $objectsByKey[$object.Key].Path) and $(Get-AppRelative $AppFull $file.Path). Object names are unique per app; remove one.")
            } else {
                $objectsByKey[$object.Key] = $file
            }
        }
    }

    $entriesByKey = @{}
    foreach ($entry in $Entries) { $entriesByKey[$entry.Key] = $entry }

    foreach ($entry in $Entries | Where-Object { -not $objectsByKey.ContainsKey($_.Key) }) {
        $sameId = if ($script:ObjectTypes[$entry.Type].HasId) {
            $Files | ForEach-Object { $_.Objects } | Where-Object { $_.Type -eq $entry.Type -and $_.Id -eq $entry.Id } | Select-Object -First 1
        }
        $hint = if ($sameId) { " The app's $($entry.Type) $($entry.Id) is named $($sameId.Name); correct the name in the map." } else { ' Remove the entry, or correct its type, id, and name.' }
        $Errors.Add("Map entry $($entry.Label) names an object the app does not have.$hint")
    }
    foreach ($file in $Files) {
        foreach ($object in $file.Objects | Where-Object { -not $entriesByKey.ContainsKey($_.Key) }) {
            $Errors.Add("$($object.Label) in $(Get-AppRelative $AppFull $file.Path) is missing from the map. Add an entry with its namespace.")
        }
    }
    return $entriesByKey
}

function Get-JsonProperty {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

function Get-ObjectKey {
    param([string]$Type, [long]$Id, [string]$Name)
    return "$($Type.ToLowerInvariant())|$Id|$($Name.ToLowerInvariant())"
}

function Get-ObjectLabel {
    param([string]$Type, [long]$Id, [string]$Name)
    return $(if ($script:ObjectTypes[$Type].HasId) { "$Type $Id $Name" } else { "$Type $Name" })
}

# =============================================================================
# Using lines: the namespaces of the objects a file names
# =============================================================================

function Read-DependencyObject {
    <#
    .SYNOPSIS
        Read the namespace of every named object in the dependency symbol packages.
    .DESCRIPTION
        A .app file is a NAVX header in front of a zip; SymbolReference.json inside
        holds a tree of namespaces, each with arrays of objects. Throws, naming
        provision.ps1, when the folder is missing or holds no .app file.
    #>
    param([Parameter(Mandatory)][string]$SymbolDir)

    $packages = @(if (Test-Path -LiteralPath $SymbolDir -PathType Container) { Get-ChildItem -LiteralPath $SymbolDir -Filter '*.app' -File | Sort-Object Name })
    if ($packages.Count -eq 0) {
        throw "No dependency symbols at $SymbolDir. The pass resolves using lines from the downloaded symbol packages; run provision.ps1 (it runs download-symbols.ps1), then run the pass again."
    }

    Add-Type -AssemblyName System.IO.Compression
    $objects = [System.Collections.Generic.List[object]]::new()
    foreach ($package in $packages) {
        $document = Open-SymbolReference -Path $package.FullName
        try {
            Add-SymbolNamespaceObject -Element $document.RootElement -Namespace '' -Objects $objects
        } finally {
            $document.Dispose()
        }
    }
    return @($objects)
}

function Open-SymbolReference {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $headerLength = if ($bytes.Length -ge 8) { [BitConverter]::ToInt32($bytes, 4) } else { 0 }
    $hasNavxHeader = $bytes.Length -ge 8 -and [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ceq 'NAVX' -and
        $headerLength -ge 8 -and $headerLength -lt $bytes.Length
    if (-not $hasNavxHeader) { throw "Symbol package $Path is not a .app file: no NAVX header. Run provision.ps1 to download it again." }

    $archive = [System.IO.Compression.ZipArchive]::new([System.IO.MemoryStream]::new($bytes, $headerLength, $bytes.Length - $headerLength, $false), [System.IO.Compression.ZipArchiveMode]::Read)
    try {
        $entry = $archive.GetEntry('SymbolReference.json')
        if (-not $entry) { throw "Symbol package $Path has no SymbolReference.json. Run provision.ps1 to download it again." }
        $buffer = [System.IO.MemoryStream]::new()
        $stream = $entry.Open()
        try { $stream.CopyTo($buffer) } finally { $stream.Dispose() }
    } finally {
        $archive.Dispose()
    }
    $json = $buffer.ToArray()
    $skip = if ($json.Length -ge 3 -and $json[0] -eq 0xEF -and $json[1] -eq 0xBB -and $json[2] -eq 0xBF) { 3 } else { 0 }
    return [System.Text.Json.JsonDocument]::Parse([ReadOnlyMemory[byte]]::new($json, $skip, $json.Length - $skip))
}

function Add-SymbolNamespaceObject {
    # Walks one namespace node: its object arrays by kind, then its child namespaces.
    param([Parameter(Mandatory)]$Element, [string]$Namespace, [Parameter(Mandatory)]$Objects)

    foreach ($property in $Element.EnumerateObject()) {
        if ($property.Value.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { continue }
        if ($property.Name -ceq 'Namespaces') {
            foreach ($child in $property.Value.EnumerateArray()) {
                $childName = ''
                foreach ($childProperty in $child.EnumerateObject()) { if ($childProperty.Name -ceq 'Name') { $childName = $childProperty.Value.GetString(); break } }
                Add-SymbolNamespaceObject -Element $child -Namespace $(if ($Namespace) { "$Namespace.$childName" } else { $childName }) -Objects $Objects
            }
        } elseif ($script:SymbolKinds.ContainsKey($property.Name)) {
            foreach ($object in $property.Value.EnumerateArray()) {
                foreach ($objectProperty in $object.EnumerateObject()) {
                    if ($objectProperty.Name -ceq 'Name') {
                        $Objects.Add([pscustomobject]@{ Type = $script:SymbolKinds[$property.Name]; Name = $objectProperty.Value.GetString(); Namespace = $Namespace })
                        break
                    }
                }
            }
        }
    }
}

function New-ReferenceIndex {
    # lower-case name -> the (type, namespace) pairs it can mean: the app's own objects and the dependencies'.
    param([object[]]$Entries = @(), [object[]]$DependencyObjects = @())

    $index = @{}
    foreach ($object in @($Entries) + @($DependencyObjects)) {
        if ($object.Type -notin $script:ReferenceableTypes) { continue }
        $key = $object.Name.ToLowerInvariant()
        if (-not $index.ContainsKey($key)) { $index[$key] = @{} }
        $index[$key]["$($object.Type)|$($object.Namespace)"] = [pscustomobject]@{ Type = $object.Type; Namespace = $object.Namespace }
    }
    return $index
}

function Resolve-FileUsing {
    <#
    .SYNOPSIS
        The using lines one file needs, sorted, each namespace once.
    .DESCRIPTION
        A reference whose object type its context fixes (Record X, Codeunit::X)
        resolves among that type's objects; two namespaces for it is an error
        unless the file's own namespace is one of them, which wins as the closest
        scope. A reference with no such context adds every namespace its name can
        mean; an unused using is a hidden diagnostic.
    #>
    param(
        [Parameter(Mandatory)]$File,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)]$Index,
        [Parameter(Mandatory)][string]$AppFull,
        [Parameter(Mandatory)]$Errors
    )

    $usings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($reference in $File.References) {
        if (-not $Index.ContainsKey($reference.Name)) { continue }
        $candidates = @($Index[$reference.Name].Values | Where-Object { -not $reference.Type -or $_.Type -eq $reference.Type })
        $namespaces = @($candidates | ForEach-Object { $_.Namespace } | Select-Object -Unique)
        if ($reference.Type) {
            if ($namespaces -contains $Namespace) { continue }
            if ($namespaces.Count -gt 1) {
                $listed = @($namespaces | Sort-Object { $_.ToLowerInvariant() } | ForEach-Object { if ($_) { $_ } else { '(no namespace)' } }) -join ', '
                $Errors.Add("$(Get-AppRelative $AppFull $File.Path) references $($reference.Type) $($reference.Display), which resolves to $listed. Rename one of the objects or qualify the reference by hand, then run the pass again.")
                continue
            }
        }
        foreach ($candidate in $namespaces) {
            if ($candidate -and $candidate -ine $Namespace) { [void]$usings.Add($candidate) }
        }
    }
    [string[]]$sorted = @($usings)
    [Array]::Sort($sorted, [System.StringComparer]::OrdinalIgnoreCase)
    return ,$sorted
}

# =============================================================================
# Reading the app's AL files
# =============================================================================

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
    $skip = if ($hasBom) { 3 } else { 0 }
    try {
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes, $skip, $bytes.Length - $skip)
    } catch {
        return [pscustomobject]@{ Error = "$relative is not valid UTF-8. Save it as UTF-8, then run the pass again." }
    }

    $source = Read-AlSource -Text $text
    if ($source.HeaderWord) {
        return [pscustomobject]@{ Error = "$relative already has a $($source.HeaderWord) statement. The pass organizes files that have none; restore the file with git, then run the pass again." }
    }
    if (@($source.Objects).Count -eq 0) {
        return [pscustomobject]@{ Error = "$relative declares no AL object the pass recognizes. Remove the file or declare its object." }
    }

    return [pscustomobject]@{
        Error = $null; Path = $Path; Text = $text; HasBom = $hasBom
        NewLine = $(if ($text -match "\r\n") { "`r`n" } else { "`n" })
        InsertAt = Get-InsertionOffset -Text $text -Index $source.Objects[0].StartIndex
        Objects = @($source.Objects | ForEach-Object {
            [pscustomobject]@{
                Type = $_.Type; Id = $_.Id; Name = $_.Name
                Label = Get-ObjectLabel -Type $_.Type -Id $_.Id -Name $_.Name
                Key = Get-ObjectKey -Type $_.Type -Id $_.Id -Name $_.Name
            }
        })
        References = @(Get-AlNameReference -Source $source -Text $text)
    }
}

# =============================================================================
# Targets and the rewritten file
# =============================================================================

function Get-InsertionOffset {
    # The start of the line the first object's leading attributes or keyword sit on, moved up over
    # the `///` documentation lines directly above it. Header comments stay above the namespace.
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][int]$Index)

    $lineStart = if ($Index -gt 0) { $Text.LastIndexOf("`n", $Index - 1) + 1 } else { 0 }
    while ($lineStart -gt 0) {
        $previousStart = if ($lineStart -ge 2) { $Text.LastIndexOf("`n", $lineStart - 2) + 1 } else { 0 }
        if (-not $Text.Substring($previousStart, $lineStart - $previousStart).TrimStart().StartsWith('///')) { break }
        $lineStart = $previousStart
    }
    return $lineStart
}

function Get-RewrittenBytes {
    param([Parameter(Mandatory)]$File, [Parameter(Mandatory)][string]$Namespace, [string[]]$Usings = @())

    $block = "namespace $Namespace;$($File.NewLine)$($File.NewLine)"
    if ($Usings.Count) { $block += (($Usings | ForEach-Object { "using $_;" }) -join $File.NewLine) + $File.NewLine + $File.NewLine }
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($File.Text.Insert($File.InsertAt, $block))
    if ($File.HasBom) { $bytes = [byte[]]@(0xEF, 0xBB, 0xBF) + $bytes }
    return $bytes
}

function Get-TargetPath {
    param([Parameter(Mandatory)]$File, [Parameter(Mandatory)][string]$Namespace, [Parameter(Mandatory)][string]$RootNamespace, [Parameter(Mandatory)][string]$SourceRoot)

    $folder = $SourceRoot
    if ($Namespace -ine $RootNamespace) {
        foreach ($segment in ($Namespace.Substring($RootNamespace.Length + 1) -split '\.')) { $folder = Join-Path $folder $segment }
    }
    return Join-Path $folder (Get-CodeCopFileName -File $File)
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

function Find-PathCollision {
    # Two files sent to one path; a target held by a file the pass does not move.
    param([Parameter(Mandatory)]$Items, [Parameter(Mandatory)]$Files, [Parameter(Mandatory)][string]$AppFull, [Parameter(Mandatory)]$Errors)

    foreach ($group in ($Items | Group-Object { $_.Target.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })) {
        $Errors.Add("Files $((@($group.Group | ForEach-Object { Get-AppRelative $AppFull $_.Source }) -join ', ')) all go to $(Get-AppRelative $AppFull $group.Group[0].Target). Give the objects different names or namespaces.")
    }
    $sources = @($Files | ForEach-Object { $_.Path })
    foreach ($item in $Items) {
        if ((Test-Path -LiteralPath $item.Target) -and -not ($sources | Where-Object { $_ -ieq $item.Target })) {
            $Errors.Add("$(Get-AppRelative $AppFull $item.Target) already exists and is not one of the app's .al files; the move of $(Get-AppRelative $AppFull $item.Source) would overwrite it.")
        }
    }
}

function Get-AppRelative {
    param([string]$AppFull, [string]$Path)
    return ([System.IO.Path]::GetRelativePath($AppFull, $Path)) -replace '\\', '/'
}

function Remove-EmptyFolder {
    # Remove Path and its parents while they are empty, stopping at StopAt.
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
