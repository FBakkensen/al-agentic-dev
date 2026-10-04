#requires -Version 7.2

<#
.SYNOPSIS
    AL Module Check Module

.DESCRIPTION
    The text-only module check the test gate runs before it compiles. It reads
    AL files and git, never the compiler. Invoke-ModuleCheck is the one entry;
    each rule is one function it calls.

.NOTES
    Rule 1: every AL file declares a namespace, and its folder path below the
    app's source root equals that namespace after the root namespace.

    Rule 3: new objects, new callable procedures, new event subscribers, and
    local procedures made callable stay out of open code; a new local
    procedure only warns.
#>

Set-StrictMode -Version Latest

# =============================================================================
# Entry
# =============================================================================

function Invoke-ModuleCheck {
    <#
    .SYNOPSIS
        Check a Consumer repository against the module rules.
    .DESCRIPTION
        Returns Violations (fail the gate), Warnings (reported only), and
        SkippedRules (rules that could not run). Each violation carries Rule,
        File (repo-relative, forward slashes), Line, and Message — the move to
        make.
    .PARAMETER RepoRoot
        The Consumer repository root.
    .PARAMETER BaseRef
        The git ref the change is compared with: the default branch. Rule 3
        needs it; without a base that resolves, rule 3 is reported in
        SkippedRules.
    .PARAMETER RootNamespace
        The app's root namespace (moduleGate.rootNamespace). Test apps use it
        plus .Test.
    .PARAMETER AppDir
        The main app folder.
    .PARAMETER TestAppDirs
        Every test app folder the gate compiles.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [string]$BaseRef = '',

        [AllowEmptyString()]
        [string]$RootNamespace = '',

        [Parameter(Mandatory)]
        [string]$AppDir,

        [string[]]$TestAppDirs = @()
    )

    $violations = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $skippedRules = [System.Collections.Generic.List[string]]::new()

    $apps = @([pscustomobject]@{ Dir = $AppDir; Namespace = $RootNamespace })
    $apps += @($TestAppDirs | Where-Object { $_ } | ForEach-Object {
        [pscustomobject]@{ Dir = $_; Namespace = "$RootNamespace.Test" }
    })

    if ([string]::IsNullOrWhiteSpace($RootNamespace)) {
        $violations.Add((Get-RootNamespaceViolation -RepoRoot $RepoRoot))
    } else {
        foreach ($violation in @(Get-NamespacePathViolation -RepoRoot $RepoRoot -Apps $apps)) {
            $violations.Add($violation)
        }
    }

    $openCode = Get-OpenCodeFinding -RepoRoot $RepoRoot -BaseRef $BaseRef -Apps $apps
    foreach ($violation in $openCode.Violations) { $violations.Add($violation) }
    foreach ($warning in $openCode.Warnings) { $warnings.Add($warning) }
    if ($openCode.SkippedReason) { $skippedRules.Add("Rule 3 skipped: $($openCode.SkippedReason)") }

    return [pscustomobject]@{
        Violations   = @($violations)
        Warnings     = @($warnings)
        SkippedRules = @($skippedRules)
    }
}

function ConvertTo-ModuleGateBlock {
    <#
    .SYNOPSIS
        Shape the module check result as summary.json's moduleGate block.
    .DESCRIPTION
        An off gate carries nothing beyond the flag.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled,

        $Result
    )

    if (-not $Enabled) {
        return [ordered]@{ enabled = $false }
    }

    $violations = if ($Result) { @($Result.Violations) } else { @() }
    $warnings = if ($Result) { @($Result.Warnings) } else { @() }
    $skippedRules = if ($Result) { @($Result.SkippedRules) } else { @() }
    $record = { [ordered]@{ rule = $_.Rule; file = $_.File; line = $_.Line; message = $_.Message } }
    return [ordered]@{
        enabled      = $true
        violations   = @($violations | ForEach-Object $record)
        warnings     = @($warnings | ForEach-Object $record)
        skippedRules = $skippedRules
    }
}

# =============================================================================
# Rule 1: namespace equals folder path
# =============================================================================

function Get-RootNamespaceViolation {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $line = 1
    $configPath = Join-Path $RepoRoot 'al-build.json'
    if (Test-Path -LiteralPath $configPath) {
        $match = Select-String -LiteralPath $configPath -Pattern '"rootNamespace"' | Select-Object -First 1
        if (-not $match) { $match = Select-String -LiteralPath $configPath -Pattern '"moduleGate"' | Select-Object -First 1 }
        if ($match) { $line = $match.LineNumber }
    }
    return New-ModuleViolation -Rule 1 -File 'al-build.json' -Line $line `
        -Message 'The module gate is on and moduleGate.rootNamespace is empty. Set moduleGate.rootNamespace in al-build.json to the app''s root namespace.'
}

function Get-NamespacePathViolation {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][object[]]$Apps
    )

    $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $appDirs = @($Apps | ForEach-Object { [System.IO.Path]::GetFullPath($_.Dir).TrimEnd('\', '/') })

    foreach ($app in $Apps) {
        $appFull = [System.IO.Path]::GetFullPath($app.Dir).TrimEnd('\', '/')
        if (-not (Test-Path -LiteralPath $appFull -PathType Container)) { continue }

        $srcDir = Join-Path $appFull 'src'
        $sourceRoot = if (Test-Path -LiteralPath $srcDir -PathType Container) { $srcDir } else { $appFull }
        $nested = @($appDirs | Where-Object { $_ -ne $appFull -and $_.StartsWith($appFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) })

        $files = Get-ChildItem -LiteralPath $appFull -Filter '*.al' -Recurse -File |
            Where-Object {
                $fileFull = $_.FullName
                $belowApp = [System.IO.Path]::GetRelativePath($appFull, $fileFull)
                -not ($belowApp -split '[\\/]' | Where-Object { $_.StartsWith('.') }) -and
                -not ($nested | Where-Object { $fileFull.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) })
            } |
            Sort-Object FullName

        $sourceRootRelative = [System.IO.Path]::GetRelativePath($repoFull, $sourceRoot) -replace '\\', '/'
        foreach ($file in $files) {
            $repoRelative = [System.IO.Path]::GetRelativePath($repoFull, $file.FullName) -replace '\\', '/'
            $folder = [System.IO.Path]::GetRelativePath($sourceRoot, $file.DirectoryName)
            $declaration = Read-AlNamespaceDeclaration -Path $file.FullName

            if ($folder -eq '..' -or $folder.StartsWith('..' + [System.IO.Path]::DirectorySeparatorChar)) {
                New-ModuleViolation -Rule 1 -File $repoRelative -Line 1 `
                    -Message "The file sits outside the source root $sourceRootRelative. Move it under $sourceRootRelative, in the folder its namespace names."
                continue
            }

            $segments = @(if ($folder -ne '.') { $folder -split '[\\/]' })
            $badSegment = $segments | Where-Object { $_ -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' } | Select-Object -First 1
            if ($badSegment) {
                New-ModuleViolation -Rule 1 -File $repoRelative -Line 1 `
                    -Message "Folder '$badSegment' is not a single AL identifier, so no namespace can equal the path. Rename it to letters, digits, and underscores, starting with a letter or underscore."
                continue
            }

            $expected = (@($app.Namespace) + $segments) -join '.'
            $expectedFolder = (@($sourceRootRelative) + $segments | Where-Object { $_ -ne '.' }) -join '/'

            if (-not $declaration.Namespace) {
                New-ModuleViolation -Rule 1 -File $repoRelative -Line $declaration.ObjectLine `
                    -Message "The file declares no namespace, so it sees every namespace without a using. Add 'namespace $expected;' above line $($declaration.ObjectLine)."
                continue
            }

            if ($declaration.Namespace -ine $expected) {
                $prefix = $app.Namespace + '.'
                $moveTo = if ($declaration.Namespace.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $below = $declaration.Namespace.Substring($prefix.Length) -replace '\.', '/'
                    ", or move the file to $((@($sourceRootRelative, $below) | Where-Object { $_ -ne '.' }) -join '/')"
                } else {
                    ", or move the file under a namespace that starts with $($app.Namespace)"
                }
                New-ModuleViolation -Rule 1 -File $repoRelative -Line $declaration.NamespaceLine `
                    -Message "Namespace $($declaration.Namespace) does not match folder $expectedFolder. Change it to 'namespace $expected;'$moveTo."
            }
        }
    }
}

function Read-AlNamespaceDeclaration {
    <#
    .SYNOPSIS
        Read a file's namespace statement and the line of its first object.
    .DESCRIPTION
        Comments are blanked, line numbers kept. The namespace statement
        precedes every object, so the scan stops at the first object keyword.
        Quotes around identifiers are dropped.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $text) { $text = '' }
    # One left-to-right pass: whichever comment opens first wins, so a // before a /* ends the line.
    $blanked = [regex]::Replace($text, '/\*.*?\*/|//[^\r\n]*', { param($m) $m.Value -replace '[^\r\n]', ' ' }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $lines = $blanked -split "`r?`n"

    $objectKeyword = '^\s*(table|tableextension|page|pageextension|pagecustomization|codeunit|report|reportextension|xmlport|query|enum|enumextension|interface|permissionset|permissionsetextension|entitlement|controladdin|profile|dotnet)\s+\S'
    $namespace = $null
    $namespaceLine = 1
    $objectLine = 1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $code = $lines[$i]
        if ($code -match '^\s*namespace\s+(.+?)\s*;') {
            $namespace = $Matches[1] -replace '"', ''
            $namespaceLine = $i + 1
            break
        }
        if ($code -match $objectKeyword) {
            $objectLine = $i + 1
            break
        }
    }

    return [pscustomobject]@{ Namespace = $namespace; NamespaceLine = $namespaceLine; ObjectLine = $objectLine }
}

function New-ModuleViolation {
    param(
        [Parameter(Mandatory)][int]$Rule,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][int]$Line,
        [Parameter(Mandatory)][string]$Message
    )
    return [pscustomobject]@{ Rule = $Rule; File = $File; Line = $Line; Message = $Message }
}

# =============================================================================
# Rule 3: new code stays out of open code
# =============================================================================

function Get-DefaultBranchRef {
    <#
    .SYNOPSIS
        The Consumer repository's default branch as a ref, such as origin/main.
    .DESCRIPTION
        Reads refs/remotes/origin/HEAD. Returns an empty string when the
        repository has no remote default branch or is not a git repository.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    $result = Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('symbolic-ref', '--short', 'refs/remotes/origin/HEAD')
    if ($result.Succeeded -and $result.Output.Count -gt 0) { return ([string]$result.Output[0]).Trim() }
    return ''
}

function Get-OpenCodeFinding {
    <#
    .SYNOPSIS
        Compare the apps with the merge base of HEAD and the base ref.
    .DESCRIPTION
        Open code is any namespace that is neither a module root (a namespace
        some file declares an .Internal below) nor inside an .Internal. Identity
        decides what is new: objects by app, type, and ID (interfaces and other
        ID-less objects by name); procedures by object and name, counted. The
        current side is the working tree, the base side the merge base's
        committed files; the working tree is never written.
        Returns Violations, Warnings, and SkippedReason (empty when rule 3 ran).
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$BaseRef,
        [Parameter(Mandatory)][object[]]$Apps
    )

    $violations = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $base = Resolve-ModuleMergeBase -RepoRoot $RepoRoot -BaseRef $BaseRef
    if ($base.Reason) {
        return [pscustomobject]@{ Violations = @(); Warnings = @(); SkippedReason = $base.Reason }
    }

    $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $appRels = @($Apps | ForEach-Object {
        $rel = [System.IO.Path]::GetRelativePath($repoFull, [System.IO.Path]::GetFullPath($_.Dir)) -replace '\\', '/'
        if ($rel -eq '.') { '' } elseif ($rel -eq '..' -or $rel.StartsWith('../')) { $null } else { $rel.TrimEnd('/') }
    } | Where-Object { $null -ne $_ } | Select-Object -Unique | Sort-Object { $_.Length } -Descending)

    $currentObjects = @(Get-CurrentAlObject -RepoRoot $repoFull -AppRels $appRels)
    $baseProcedures = Get-BaseProcedureMap -RepoRoot $RepoRoot -Revision $base.Sha -AppRels $appRels
    $moduleRoots = Get-ModuleRootSet -Objects $currentObjects

    foreach ($object in $currentObjects) {
        if (-not (Test-OpenCodeNamespace -Namespace $object.Namespace -ModuleRoots $moduleRoots)) { continue }
        foreach ($finding in @(Compare-OpenCodeObject -Object $object -BaseProcedures $baseProcedures)) {
            if ($finding.IsWarning) { $warnings.Add($finding.Result) } else { $violations.Add($finding.Result) }
        }
    }

    return [pscustomobject]@{
        Violations    = @($violations | Sort-Object File, Line)
        Warnings      = @($warnings | Sort-Object File, Line)
        SkippedReason = ''
    }
}

function Get-CurrentAlObject {
    # Every object in the apps' working-tree files, each file read once, owned by its deepest app.
    param([string]$RepoRoot, [string[]]$AppRels)

    foreach ($appRel in $AppRels) {
        $appFull = if ($appRel) { Join-Path $RepoRoot $appRel } else { $RepoRoot }
        if (-not (Test-Path -LiteralPath $appFull -PathType Container)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $appFull -Filter '*.al' -Recurse -File) {
            $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
            if ((Get-AlFileAppDir -RelativePath $relative -AppRels $AppRels) -ne $appRel) { continue }
            if (Test-HiddenBelowApp -RelativePath $relative -AppRel $appRel) { continue }
            Read-AlObjectModel -Text "$(Get-Content -LiteralPath $file.FullName -Raw)" -File $relative -App $appRel
        }
    }
}

function Get-BaseProcedureMap {
    # Object key -> every procedure of that object across the base commit's files.
    param([string]$RepoRoot, [string]$Revision, [string[]]$AppRels)

    $paths = @()
    foreach ($path in @(Get-GitTreePath -RepoRoot $RepoRoot -Revision $Revision)) {
        $owner = Get-AlFileAppDir -RelativePath $path -AppRels $AppRels
        if ($path -like '*.al' -and $null -ne $owner -and -not (Test-HiddenBelowApp -RelativePath $path -AppRel $owner)) {
            $paths += $path
        }
    }
    $texts = Get-GitBlobText -RepoRoot $RepoRoot -Revision $Revision -Paths $paths

    $map = @{}
    foreach ($path in $paths) {
        if (-not $texts.ContainsKey($path)) { continue }
        $owner = Get-AlFileAppDir -RelativePath $path -AppRels $AppRels
        foreach ($object in @(Read-AlObjectModel -Text $texts[$path] -File $path -App $owner)) {
            if (-not $map.ContainsKey($object.Key)) { $map[$object.Key] = [System.Collections.Generic.List[object]]::new() }
            foreach ($procedure in $object.Procedures) { $map[$object.Key].Add($procedure) }
        }
    }
    return $map
}

function Get-ModuleRootSet {
    # Namespaces that have an .Internal (or one below it) declared by some object.
    param([object[]]$Objects)

    $roots = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($object in $Objects) {
        $segments = @($object.Namespace -split '\.')
        for ($i = 1; $i -lt $segments.Count; $i++) {
            if ($segments[$i] -ieq 'Internal') { [void]$roots.Add(($segments[0..($i - 1)] -join '.')) }
        }
    }
    return , $roots
}

function Test-OpenCodeNamespace {
    # Open code is neither a module root nor inside an .Internal; a file with no namespace is open code.
    param([string]$Namespace, $ModuleRoots)

    return -not ($ModuleRoots.Contains($Namespace) -or (@($Namespace -split '\.') -contains 'Internal'))
}

function Get-ProcedurePairing {
    <#
    .SYNOPSIS
        Pair each current procedure with its base procedure by name, or $null.
    .DESCRIPTION
        Procedures with the same name and parameter list pair first, so an
        added overload is the one left unpaired; the rest pair in order, so a
        changed parameter list is not new. Returns one entry per current
        procedure, in order.
    #>
    param([object[]]$Procedures, [object[]]$BaseProcedures)

    $paired = [object[]]::new($Procedures.Count)
    $used = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($exactSignature in $true, $false) {
        for ($i = 0; $i -lt $Procedures.Count; $i++) {
            if ($null -ne $paired[$i]) { continue }
            for ($j = 0; $j -lt $BaseProcedures.Count; $j++) {
                $candidate = $BaseProcedures[$j]
                if ($used.Contains($j) -or $candidate.Name -ine $Procedures[$i].Name) { continue }
                if ($exactSignature -and $candidate.Signature -ne $Procedures[$i].Signature) { continue }
                [void]$used.Add($j)
                $paired[$i] = $candidate
                break
            }
        }
    }
    return , $paired
}

function Compare-OpenCodeObject {
    <#
    .SYNOPSIS
        The rule 3 findings for one object in open code.
    .DESCRIPTION
        An object the base lacks is one violation. Otherwise each procedure is
        compared with its base procedure: new callable procedures, new event
        subscribers, and local procedures made callable are violations; a new
        local procedure is a warning. Edits inside a procedure are not seen.
    #>
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][hashtable]$BaseProcedures)

    $where = if ($Object.Namespace) { "namespace $($Object.Namespace)" } else { 'a file with no namespace' }
    $move = 'place the new code in a module (a namespace with an .Internal child)'
    $finding = {
        param([bool]$IsWarning, [int]$Line, [string]$Message)
        [pscustomobject]@{ IsWarning = $IsWarning; Result = New-ModuleViolation -Rule 3 -File $Object.File -Line $Line -Message $Message }
    }

    if (-not $BaseProcedures.ContainsKey($Object.Key)) {
        & $finding $false $Object.Line "New $($Object.Display) sits in open code ($where); $move, and put this object there."
        return
    }

    $procedures = @($Object.Procedures)
    $pairing = Get-ProcedurePairing -Procedures $procedures -BaseProcedures @($BaseProcedures[$Object.Key])
    for ($i = 0; $i -lt $procedures.Count; $i++) {
        $procedure = $procedures[$i]
        $before = $pairing[$i]
        $on = "'$($procedure.Name)' on $($Object.Display)"
        if ($null -eq $before) {
            if ($procedure.IsSubscriber) {
                & $finding $false $procedure.Line "New event subscriber $on sits in open code ($where); $move, and put this subscriber there."
            } elseif ($procedure.Access -ne 'local') {
                & $finding $false $procedure.Line "New $($procedure.Access) procedure $on sits in open code ($where); $move, and call it from here."
            } else {
                & $finding $true $procedure.Line "New local procedure $on sits in open code ($where). It only warns; $move when it is more than a helper."
            }
        } elseif ($procedure.IsSubscriber -and -not $before.IsSubscriber) {
            & $finding $false $procedure.Line "Procedure $on is now an event subscriber in open code ($where); $move, and put this subscriber there."
        } elseif ($before.Access -eq 'local' -and $procedure.Access -ne 'local') {
            & $finding $false $procedure.Line "Procedure $on was local at the base and is now $($procedure.Access) in open code ($where). Make it local again, or $move."
        }
    }
}

function Resolve-ModuleMergeBase {
    <#
    .SYNOPSIS
        The merge base of HEAD and the base ref, or the reason none resolves.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$BaseRef
    )

    if ([string]::IsNullOrWhiteSpace($BaseRef)) {
        return [pscustomobject]@{ Sha = ''; Reason = 'no default branch was resolved (refs/remotes/origin/HEAD is not set). Run git remote set-head origin --auto, then rerun the gate.' }
    }
    if (-not (Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('rev-parse', '--verify', '--quiet', 'HEAD^{commit}')).Succeeded) {
        return [pscustomobject]@{ Sha = ''; Reason = 'HEAD has no commit to compare.' }
    }
    if (-not (Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('rev-parse', '--verify', '--quiet', "$BaseRef^{commit}")).Succeeded) {
        return [pscustomobject]@{ Sha = ''; Reason = "the base ref $BaseRef does not resolve. Fetch the default branch (git fetch origin), then rerun the gate." }
    }
    $mergeBase = Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('merge-base', 'HEAD', $BaseRef)
    if ($mergeBase.Succeeded -and $mergeBase.Output.Count -gt 0 -and "$($mergeBase.Output[0])".Trim()) {
        return [pscustomobject]@{ Sha = "$($mergeBase.Output[0])".Trim(); Reason = '' }
    }
    $shallow = Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('rev-parse', '--is-shallow-repository')
    $why = if ($shallow.Succeeded -and "$($shallow.Output[0])".Trim() -eq 'true') {
        'The clone is shallow; fetch more history (git fetch --unshallow), then rerun the gate.'
    } else {
        'HEAD and the base ref share no history.'
    }
    return [pscustomobject]@{ Sha = ''; Reason = "no merge base between HEAD and $BaseRef. $why" }
}

function Get-AlFileAppDir {
    # The deepest app folder (repo-relative) containing the file; $null when none does.
    param([string]$RelativePath, [string[]]$AppRels)

    foreach ($appRel in $AppRels) {
        if ($appRel -eq '') { return '' }
        if ($RelativePath.StartsWith($appRel + '/', [System.StringComparison]::OrdinalIgnoreCase)) { return $appRel }
    }
    return $null
}

function Test-HiddenBelowApp {
    param([string]$RelativePath, [string]$AppRel)

    $below = if ($AppRel) { $RelativePath.Substring($AppRel.Length + 1) } else { $RelativePath }
    return [bool](@($below -split '/') | Where-Object { $_.StartsWith('.') })
}

function Get-AlCodeText {
    <#
    .SYNOPSIS
        Blank comments and the inside of string literals, keeping every offset and line.
    #>
    param([string]$Text)

    $pattern = '''(?:[^''\r\n]|'''')*''|"[^"\r\n]*"|/\*.*?\*/|//[^\r\n]*'
    return [regex]::Replace($Text, $pattern, {
        param($m)
        $value = $m.Value
        if ($value.StartsWith('"')) { return $value }
        if ($value.StartsWith("'")) { return "'" + ($value.Substring(1, $value.Length - 2) -replace '[^\r\n]', ' ') + "'" }
        return $value -replace '[^\r\n]', ' '
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
}

function Read-AlObjectModel {
    <#
    .SYNOPSIS
        Read a file's objects: identity, namespace, line, and procedures.
    .DESCRIPTION
        An object is keyed by app, type, and ID; interfaces, control add-ins,
        profiles, and entitlements have no ID and are keyed by name. A
        procedure carries its name, access (local, internal, protected, or
        public), parameter list, line, and whether it is an event subscriber.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][AllowEmptyString()][string]$App
    )

    $code = Get-AlCodeText -Text ($Text.TrimStart([char]0xFEFF))
    $newlines = [int[]]@([regex]::Matches($code, "`n") | ForEach-Object { $_.Index })
    $lineOf = {
        param($index)
        $position = [array]::BinarySearch($newlines, [int]$index)
        if ($position -lt 0) { $position = -bnot $position }
        return $position + 1
    }

    $options = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Multiline'
    $name = '(?<name>"[^"\r\n]*"|[A-Za-z_]\w*)'
    $headers = [System.Collections.Generic.List[object]]::new()
    $withId = "^[ \t]*(?<type>tableextension|table|pageextension|pagecustomization|page|codeunit|reportextension|report|xmlport|query|enumextension|enum|permissionsetextension|permissionset)[ \t]+(?<id>\d+)[ \t]+$name"
    $withoutId = "^[ \t]*(?<type>interface|controladdin|profile|entitlement)[ \t]+$name"
    foreach ($m in [regex]::Matches($code, $withId, $options)) {
        $headers.Add([pscustomobject]@{
            Index   = $m.Index
            Key     = "$App|$($m.Groups['type'].Value.ToLowerInvariant())|$($m.Groups['id'].Value)"
            Display = "$($m.Groups['type'].Value) $($m.Groups['id'].Value) $($m.Groups['name'].Value)"
            Line    = & $lineOf ($m.Index + $m.Value.Length - $m.Value.TrimStart().Length)
        })
    }
    foreach ($m in [regex]::Matches($code, $withoutId, $options)) {
        $headers.Add([pscustomobject]@{
            Index   = $m.Index
            Key     = "$App|$($m.Groups['type'].Value.ToLowerInvariant())|$($m.Groups['name'].Value.Trim('"').ToLowerInvariant())"
            Display = "$($m.Groups['type'].Value) $($m.Groups['name'].Value)"
            Line    = & $lineOf ($m.Index + $m.Value.Length - $m.Value.TrimStart().Length)
        })
    }
    $headers = @($headers | Sort-Object Index)
    if ($headers.Count -eq 0) { return @() }

    $namespace = ''
    $namespaceMatch = [regex]::Match($code, '^[ \t]*namespace[ \t]+(?<ns>[^;\r\n]+?)[ \t]*;', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($namespaceMatch.Success -and $namespaceMatch.Index -lt $headers[0].Index) {
        $namespace = $namespaceMatch.Groups['ns'].Value -replace '"', ''
    }

    $objects = @(foreach ($header in $headers) {
        [pscustomobject]@{
            Key        = $header.Key
            Display    = $header.Display -replace '\s+', ' '
            Line       = $header.Line
            File       = $File
            Namespace  = $namespace
            Procedures = [System.Collections.Generic.List[object]]::new()
        }
    })

    $procedurePattern = '(?<attrs>(?:\[[^\]]*\][ \t\r\n]*)*)(?:(?<![\w])(?<access>local|internal|protected)[ \t]+)?(?<![\w])(?<keyword>procedure)[ \t]+(?<name>"[^"\r\n]*"|[A-Za-z_]\w*)[ \t]*\((?<params>[^)]*)\)'
    foreach ($m in [regex]::Matches($code, $procedurePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $owner = -1
        for ($i = 0; $i -lt $headers.Count; $i++) {
            if ($headers[$i].Index -le $m.Groups['keyword'].Index) { $owner = $i }
        }
        if ($owner -lt 0) { continue }
        $access = if ($m.Groups['access'].Success) { $m.Groups['access'].Value.ToLowerInvariant() } else { 'public' }
        $objects[$owner].Procedures.Add([pscustomobject]@{
            Name         = $m.Groups['name'].Value.Trim('"')
            Access       = $access
            Signature    = ($m.Groups['params'].Value -replace '\s+', ' ').Trim().ToLowerInvariant()
            Line         = & $lineOf $m.Groups['keyword'].Index
            IsSubscriber = $m.Groups['attrs'].Value -match '(?i)(?<!\w)EventSubscriber\s*\('
        })
    }
    return @($objects)
}

function Invoke-ModuleGit {
    # Runs git in the repository; Succeeded is the exit code, Output the stdout lines.
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string[]]$Arguments)

    try {
        $output = @(& git -C $RepoRoot @Arguments 2>$null)
        return [pscustomobject]@{ Succeeded = ($LASTEXITCODE -eq 0); Output = $output }
    } catch {
        return [pscustomobject]@{ Succeeded = $false; Output = @() }
    }
}

function Start-ModuleGitProcess {
    param([string]$RepoRoot, [string[]]$Arguments, [switch]$RedirectInput)

    $info = [System.Diagnostics.ProcessStartInfo]::new('git')
    foreach ($argument in (@('-C', $RepoRoot) + $Arguments)) { $info.ArgumentList.Add($argument) }
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    if ($RedirectInput) {
        $info.RedirectStandardInput = $true
        $info.StandardInputEncoding = [System.Text.UTF8Encoding]::new($false)
    }
    return [System.Diagnostics.Process]::Start($info)
}

function Get-GitTreePath {
    # Every file path in a commit's tree, read as UTF-8 from git's NUL-separated list.
    param([string]$RepoRoot, [string]$Revision)

    $process = Start-ModuleGitProcess -RepoRoot $RepoRoot -Arguments @('ls-tree', '-r', '-z', '--name-only', $Revision)
    try {
        $text = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "git ls-tree $Revision failed with exit code $($process.ExitCode)." }
    } finally {
        $process.Dispose()
    }
    return @($text -split "`0" | Where-Object { $_ })
}

function Get-GitBlobText {
    <#
    .SYNOPSIS
        Read files from a commit through one git cat-file process.
    .DESCRIPTION
        Returns a hashtable of path to text. The working tree is not touched; a
        path the commit lacks is absent from the result.
    #>
    param([string]$RepoRoot, [string]$Revision, [string[]]$Paths)

    $texts = @{}
    if ($Paths.Count -eq 0) { return $texts }

    $process = Start-ModuleGitProcess -RepoRoot $RepoRoot -Arguments @('cat-file', '--batch') -RedirectInput
    try {
        $stream = $process.StandardOutput.BaseStream
        foreach ($path in $Paths) {
            $process.StandardInput.Write("${Revision}:$path`n")
            $process.StandardInput.Flush()

            $header = [System.Collections.Generic.List[byte]]::new()
            while (($byte = $stream.ReadByte()) -ge 0 -and $byte -ne 10) { $header.Add([byte]$byte) }
            $headerText = [System.Text.Encoding]::UTF8.GetString($header.ToArray())
            if ($headerText -notmatch '^[0-9a-f]{40,64} blob (?<size>\d+)$') { continue }

            $size = [int]$Matches['size']
            $buffer = [byte[]]::new($size)
            for ($read = 0; $read -lt $size;) {
                $count = $stream.Read($buffer, $read, $size - $read)
                if ($count -le 0) { throw "git cat-file ended before $path was read." }
                $read += $count
            }
            [void]$stream.ReadByte()
            $texts[$path] = [System.Text.Encoding]::UTF8.GetString($buffer)
        }
        $process.StandardInput.Close()
        $process.WaitForExit()
    } finally {
        if (-not $process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
    return $texts
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    'Invoke-ModuleCheck'
    'ConvertTo-ModuleGateBlock'
    'Get-DefaultBranchRef'
)
