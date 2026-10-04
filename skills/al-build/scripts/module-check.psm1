#requires -Version 7.2

<#
.SYNOPSIS
    AL Module Check Module

.DESCRIPTION
    The text-only module check the test gate runs before it compiles. It reads
    AL files and git, never the compiler. Invoke-ModuleCheck is the one entry;
    each rule has one entry function it calls.

.NOTES
    Rule 1: every AL file declares a namespace, and its folder path below the
    app's source root equals that namespace after the root namespace.
    Rule 2: a namespace X.Internal declared in the gate's apps belongs to module
    X; only files in X or in X.Internal and below may reference it.
    Rule 3: new objects, new callable procedures, new event subscribers, and
    local procedures made callable stay out of open code; a new local
    procedure only warns.
#>

Set-StrictMode -Version Latest

# What the AL readers below look for, defined once.
$script:AlIdObjectTypes = 'tableextension|table|pageextension|pagecustomization|page|codeunit|reportextension|report|xmlport|query|enumextension|enum|permissionsetextension|permissionset'
$script:AlNamedObjectTypes = 'interface|controladdin|profile|entitlement|dotnet'
$script:AlNamespaceStatement = '^[ \t]*namespace[ \t]+(?<ns>[^;\r\n]+?)[ \t]*;'

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
        foreach ($violation in @(Get-InternalReachViolation -RepoRoot $RepoRoot -Apps $apps)) {
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
        Base         = $openCode.Base
    }
}

function ConvertTo-ModuleGateBlock {
    <#
    .SYNOPSIS
        Shape the module check result as summary.json's moduleGate block.
    .DESCRIPTION
        An off gate carries nothing beyond the flag. The base is the ref rule 3
        compared with and its merge base with HEAD, $null when rule 3 was skipped.
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
    $base = if ($Result -and $Result.PSObject.Properties['Base'] -and $Result.Base) {
        [ordered]@{ ref = $Result.Base.Ref; mergeBase = $Result.Base.MergeBase }
    } else {
        $null
    }
    $record = { [ordered]@{ rule = $_.Rule; file = $_.File; line = $_.Line; message = $_.Message } }
    return [ordered]@{
        enabled      = $true
        violations   = @($violations | ForEach-Object $record)
        warnings     = @($warnings | ForEach-Object $record)
        base         = $base
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

function Get-AppSource {
    <#
    .SYNOPSIS
        An app's source root and the AL files the gate reads in it.
    .DESCRIPTION
        The source root is src when the app has one, else the app folder. Hidden
        folders and test apps nested in the app folder are left out. Returns
        $null when the app folder is missing.
    #>
    param(
        [Parameter(Mandatory)][object]$App,
        [Parameter(Mandatory)][object[]]$Apps
    )

    $appFull = [System.IO.Path]::GetFullPath($App.Dir).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $appFull -PathType Container)) { return $null }

    $appDirs = @($Apps | ForEach-Object { [System.IO.Path]::GetFullPath($_.Dir).TrimEnd('\', '/') })
    $srcDir = Join-Path $appFull 'src'
    $sourceRoot = if (Test-Path -LiteralPath $srcDir -PathType Container) { $srcDir } else { $appFull }
    $nested = @($appDirs | Where-Object { $_ -ne $appFull -and $_.StartsWith($appFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) })

    $files = @(Get-ChildItem -LiteralPath $appFull -Filter '*.al' -Recurse -File |
        Where-Object {
            $fileFull = $_.FullName
            $belowApp = [System.IO.Path]::GetRelativePath($appFull, $fileFull)
            -not ($belowApp -split '[\\/]' | Where-Object { $_.StartsWith('.') }) -and
            -not ($nested | Where-Object { $fileFull.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) })
        } |
        Sort-Object FullName)

    return [pscustomobject]@{ SourceRoot = $sourceRoot; Files = $files }
}

function Get-NamespacePathViolation {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][object[]]$Apps
    )

    $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)

    foreach ($app in $Apps) {
        $source = Get-AppSource -App $app -Apps $Apps
        if (-not $source) { continue }
        $sourceRoot = $source.SourceRoot
        $files = $source.Files

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

# =============================================================================
# Rule 2: a module's .Internal is reached only from its own module
# =============================================================================

function Get-InternalReachViolation {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][object[]]$Apps
    )

    $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $ignoreCase = [System.StringComparison]::OrdinalIgnoreCase

    $entries = foreach ($app in $Apps) {
        $source = Get-AppSource -App $app -Apps $Apps
        if (-not $source) { continue }
        $sourceRootRelative = [System.IO.Path]::GetRelativePath($repoFull, $source.SourceRoot) -replace '\\', '/'
        foreach ($file in $source.Files) {
            [pscustomobject]@{
                File               = [System.IO.Path]::GetRelativePath($repoFull, $file.FullName) -replace '\\', '/'
                Namespace          = ConvertTo-CodeName -Name (Read-AlNamespaceDeclaration -Path $file.FullName).Namespace
                Code               = Get-AlCodeText -Path $file.FullName
                AppNamespace       = $app.Namespace
                SourceRootRelative = $sourceRootRelative
            }
        }
    }

    $modules = Get-InternalModuleMap -Entries @($entries)
    if ($modules.Count -eq 0) { return }

    foreach ($entry in $entries) {
        $lines = $entry.Code -split "`r?`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $reported = @{}
            foreach ($match in [regex]::Matches($lines[$i], '(?<![\w.])[A-Za-z_]\w*(?:\.\w+)+')) {
                $reach = Get-InternalReach -Name $match.Value
                if (-not $reach) { continue }
                $module = $reach.Module
                if (-not $modules.ContainsKey($module) -or $reported.ContainsKey($module)) { continue }

                $own = $entry.Namespace -and (
                    $entry.Namespace -ieq $module -or
                    $entry.Namespace -ieq "$module.Internal" -or
                    $entry.Namespace.StartsWith("$module.Internal.", $ignoreCase))
                if ($own) { continue }

                $reported[$module] = $true
                $interface = if ($modules[$module]) { "its interface folder $($modules[$module])" } else { "the folder of namespace $module" }
                New-ModuleViolation -Rule 2 -File $entry.File -Line ($i + 1) `
                    -Message "$($reach.Reached) is internal to module $module. Use the module's interface in $interface instead."
            }
        }
    }
}

function Get-InternalModuleMap {
    <#
    .SYNOPSIS
        Module name -> interface folder, for every module the entries declare.
    .DESCRIPTION
        A namespace X.Internal declared anywhere in the gate's apps makes X a
        module; its interface folder is the folder of namespace X, empty when X
        sits outside its app's root namespace.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Entries)

    $modules = @{}
    foreach ($entry in $Entries) {
        if (-not $entry.Namespace) { continue }
        $reach = Get-InternalReach -Name $entry.Namespace
        if (-not $reach -or $modules.ContainsKey($reach.Module)) { continue }
        $module = $reach.Module
        $modules[$module] = if ($module -ieq $entry.AppNamespace) {
            $entry.SourceRootRelative
        } elseif ($module.StartsWith($entry.AppNamespace + '.', [System.StringComparison]::OrdinalIgnoreCase)) {
            (@($entry.SourceRootRelative) + ($module.Substring($entry.AppNamespace.Length + 1) -split '\.') | Where-Object { $_ -ne '.' }) -join '/'
        } else {
            ''
        }
    }
    return $modules
}

function ConvertTo-CodeName {
    <#
    .SYNOPSIS
        A dotted name with each segment made one word, the form Get-AlCodeText
        gives quoted identifiers.
    #>
    param([AllowNull()][string]$Name)

    if (-not $Name) { return $Name }
    return (($Name -split '\.') | ForEach-Object { $_ -replace '\W', '_' }) -join '.'
}

function Get-InternalReach {
    <#
    .SYNOPSIS
        The module and the .Internal namespace a dotted name reaches, or $null.
    .DESCRIPTION
        The first Internal segment after the first one ends the module's name.
    #>
    param([Parameter(Mandatory)][string]$Name)

    $segments = $Name -split '\.'
    for ($i = 1; $i -lt $segments.Count; $i++) {
        if ($segments[$i] -ieq 'Internal') {
            return [pscustomobject]@{ Module = $segments[0..($i - 1)] -join '.'; Reached = $segments[0..$i] -join '.' }
        }
    }
    return $null
}

function Get-AlCodeText {
    <#
    .SYNOPSIS
        A file's code with comments, string literals, and the namespace
        statement blanked and quoted identifiers made single names.
    .DESCRIPTION
        Line numbers are kept. One left-to-right pass, so a // inside a string
        is not a comment and an apostrophe inside a comment is not a string. A
        file that never says Internal returns empty.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrEmpty($text) -or $text.IndexOf('Internal', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return '' }

    $tokens = '/\*.*?\*/|//[^\r\n]*|''(?:[^''\r\n]|'''')*''|"[^"\r\n]*"'
    $blank = { param($m) $m.Value -replace '[^\r\n]', ' ' }
    $code = [regex]::Replace($text, $tokens, {
        param($m)
        if ($m.Value.StartsWith('"')) { return $m.Value.Trim('"') -replace '\W', '_' }
        return & $blank $m
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return [regex]::Replace($code, '(?m)^[ \t]*namespace\s[^;\r\n]*;', $blank)
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

    $objectKeyword = "^\s*($script:AlIdObjectTypes|$script:AlNamedObjectTypes)\s+\S"
    $namespace = $null
    $namespaceLine = 1
    $objectLine = 1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $code = $lines[$i]
        if ($code -match $script:AlNamespaceStatement) {
            $namespace = $Matches['ns'] -replace '"', ''
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

$script:OpenCodeMove = 'place the new code in a module (a namespace with an .Internal child)'

function Get-DefaultBranchRef {
    <#
    .SYNOPSIS
        The Consumer repository's default branch as a ref, such as origin/main.
    .DESCRIPTION
        Reads refs/remotes/origin/HEAD. Returns an empty string when the
        repository has no remote default branch or is not a git repository.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)

    return Get-GitFirstLine -Result (Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('symbolic-ref', '--short', 'refs/remotes/origin/HEAD'))
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
        Returns Violations, Warnings, SkippedReason (empty when rule 3 ran),
        and Base (the ref and merge base compared, $null when skipped).
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyString()][string]$BaseRef,
        [Parameter(Mandatory)][object[]]$Apps
    )

    $base = Resolve-ModuleMergeBase -RepoRoot $RepoRoot -BaseRef $BaseRef
    if ($base.Reason) {
        return [pscustomobject]@{ Violations = @(); Warnings = @(); SkippedReason = $base.Reason; Base = $null }
    }

    $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $appRelatives = @($Apps | ForEach-Object { Get-RepoRelativePath -RepoRoot $repoFull -Path ([System.IO.Path]::GetFullPath($_.Dir).TrimEnd('\', '/')) } |
        Where-Object { $_ -ne '..' -and -not $_.StartsWith('../') } |
        Select-Object -Unique |
        Sort-Object { $_.Length } -Descending)

    $currentObjects = @(Get-CurrentAlObject -RepoRoot $repoFull -Apps $Apps)
    $baseProcedures = Get-BaseProcedureMap -RepoRoot $repoFull -Revision $base.Sha -AppRelatives $appRelatives
    $moduleRoots = Get-ModuleRootSet -Objects $currentObjects

    $violations = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
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
        Base          = [pscustomobject]@{ Ref = $BaseRef; MergeBase = $base.Sha }
    }
}

function Get-RepoRelativePath {
    # A path relative to the repository root, forward slashes; empty for the root itself.
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Path
    )

    $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $Path) -replace '\\', '/'
    if ($relative -eq '.') { return '' }
    return $relative
}

function Get-CurrentAlObject {
    <#
    .SYNOPSIS
        Every object in the apps' working-tree files, each file read once.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][object[]]$Apps
    )

    foreach ($app in $Apps) {
        $source = Get-AppSource -App $app -Apps $Apps
        if (-not $source) { continue }
        $appRelative = Get-RepoRelativePath -RepoRoot $RepoRoot -Path ([System.IO.Path]::GetFullPath($app.Dir).TrimEnd('\', '/'))
        foreach ($file in $source.Files) {
            Read-AlObjectModel -Text "$(Get-Content -LiteralPath $file.FullName -Raw)" `
                -File (Get-RepoRelativePath -RepoRoot $RepoRoot -Path $file.FullName) -App $appRelative
        }
    }
}

function Get-BaseProcedureMap {
    <#
    .SYNOPSIS
        Object key -> every procedure of that object across the base commit's files.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Revision,
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$AppRelatives
    )

    $owners = @{}
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($path in @(Get-GitTreePath -RepoRoot $RepoRoot -Revision $Revision)) {
        if ($path -notlike '*.al') { continue }
        $owner = Get-TreePathApp -RelativePath $path -AppRelatives $AppRelatives
        if ($null -eq $owner) { continue }
        $owners[$path] = $owner
        $paths.Add($path)
    }
    $texts = Get-GitBlobText -RepoRoot $RepoRoot -Revision $Revision -Paths $paths.ToArray()

    $map = @{}
    foreach ($path in $paths) {
        if (-not $texts.ContainsKey($path)) { continue }
        foreach ($object in @(Read-AlObjectModel -Text $texts[$path] -File $path -App $owners[$path])) {
            if (-not $map.ContainsKey($object.Key)) { $map[$object.Key] = [System.Collections.Generic.List[object]]::new() }
            foreach ($procedure in $object.Procedures) { $map[$object.Key].Add($procedure) }
        }
    }
    return $map
}

function Get-TreePathApp {
    <#
    .SYNOPSIS
        The app a committed file belongs to, or $null when the gate does not read it.
    .DESCRIPTION
        The deepest app folder holding the path, ignoring hidden folders below
        it: Get-AppSource's file filter, applied to a git tree path.
    #>
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$AppRelatives
    )

    foreach ($appRelative in $AppRelatives) {
        if ($appRelative -and -not $RelativePath.StartsWith($appRelative + '/', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $below = if ($appRelative) { $RelativePath.Substring($appRelative.Length + 1) } else { $RelativePath }
        if (@($below -split '/') | Where-Object { $_.StartsWith('.') }) { return $null }
        return $appRelative
    }
    return $null
}

function Get-ModuleRootSet {
    <#
    .SYNOPSIS
        Namespaces that have an .Internal, or one below it, declared by some object.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Objects)

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
    <#
    .SYNOPSIS
        Whether a namespace is open code: no module root, not inside an .Internal.
    .DESCRIPTION
        A file with no namespace is open code.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Namespace,
        [Parameter(Mandatory)]$ModuleRoots
    )

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
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Procedures,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$BaseProcedures
    )

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
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][hashtable]$BaseProcedures
    )

    if (-not $BaseProcedures.ContainsKey($Object.Key)) {
        New-OpenCodeFinding -Object $Object -Line $Object.Line -Subject "New $($Object.Display) sits" -Then "$script:OpenCodeMove, and put this object there"
        return
    }

    $procedures = @($Object.Procedures)
    $pairing = Get-ProcedurePairing -Procedures $procedures -BaseProcedures @($BaseProcedures[$Object.Key])
    for ($i = 0; $i -lt $procedures.Count; $i++) {
        $procedure = $procedures[$i]
        $baseProcedure = $pairing[$i]
        $label = "'$($procedure.Name)' on $($Object.Display)"
        if ($null -eq $baseProcedure) {
            if ($procedure.IsSubscriber) {
                New-OpenCodeFinding -Object $Object -Line $procedure.Line -Subject "New event subscriber $label sits" -Then "$script:OpenCodeMove, and put this subscriber there"
            } elseif ($procedure.Access -ne 'local') {
                New-OpenCodeFinding -Object $Object -Line $procedure.Line -Subject "New $($procedure.Access) procedure $label sits" -Then "$script:OpenCodeMove, and call it from here"
            } else {
                New-OpenCodeFinding -Object $Object -Line $procedure.Line -Subject "New local procedure $label sits" -Then "it only warns; $script:OpenCodeMove when it is more than a helper" -IsWarning
            }
        } elseif ($procedure.IsSubscriber -and -not $baseProcedure.IsSubscriber) {
            New-OpenCodeFinding -Object $Object -Line $procedure.Line -Subject "Procedure $label is now an event subscriber" -Then "$script:OpenCodeMove, and put this subscriber there"
        } elseif ($baseProcedure.Access -eq 'local' -and $procedure.Access -ne 'local') {
            New-OpenCodeFinding -Object $Object -Line $procedure.Line -Subject "Procedure $label was local at the base and is now $($procedure.Access)" -Then "make it local again, or $script:OpenCodeMove"
        }
    }
}

function New-OpenCodeFinding {
    # One finding: "<subject> in open code (<where>); <then>."
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][int]$Line,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Then,
        [switch]$IsWarning
    )

    $where = if ($Object.Namespace) { "namespace $($Object.Namespace)" } else { 'a file with no namespace' }
    return [pscustomobject]@{
        IsWarning = [bool]$IsWarning
        Result    = New-ModuleViolation -Rule 3 -File $Object.File -Line $Line -Message "$Subject in open code ($where); $Then."
    }
}

function Resolve-ModuleMergeBase {
    <#
    .SYNOPSIS
        The merge base of HEAD and the base ref, or the reason none resolves.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyString()][string]$BaseRef
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
    $mergeBase = Get-GitFirstLine -Result (Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('merge-base', 'HEAD', $BaseRef))
    if ($mergeBase) {
        return [pscustomobject]@{ Sha = $mergeBase; Reason = '' }
    }
    $shallow = Get-GitFirstLine -Result (Invoke-ModuleGit -RepoRoot $RepoRoot -Arguments @('rev-parse', '--is-shallow-repository'))
    $why = if ($shallow -eq 'true') {
        'The clone is shallow; fetch more history (git fetch --unshallow), then rerun the gate.'
    } else {
        'HEAD and the base ref share no history.'
    }
    return [pscustomobject]@{ Sha = ''; Reason = "no merge base between HEAD and $BaseRef. $why" }
}

function Get-AlObjectCodeText {
    <#
    .SYNOPSIS
        Blank comments and the inside of string literals, keeping every offset and line.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $tokens = '''(?:[^''\r\n]|'''')*''|"[^"\r\n]*"|/\*.*?\*/|//[^\r\n]*'
    return [regex]::Replace($Text, $tokens, {
        param($token)
        if ($token.Value.StartsWith('"')) { return $token.Value }
        if ($token.Value.StartsWith("'")) { return "'" + ($token.Value.Substring(1, $token.Value.Length - 2) -replace '[^\r\n]', ' ') + "'" }
        return $token.Value -replace '[^\r\n]', ' '
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

    $code = Get-AlObjectCodeText -Text ($Text.TrimStart([char]0xFEFF))
    $newlines = [int[]]@([regex]::Matches($code, "`n") | ForEach-Object { $_.Index })
    $getLineNumber = {
        param($index)
        $position = [array]::BinarySearch($newlines, [int]$index)
        if ($position -lt 0) { $position = -bnot $position }
        return $position + 1
    }

    $options = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Multiline'
    $name = '(?<name>"[^"\r\n]*"|[A-Za-z_]\w*)'
    $headers = [System.Collections.Generic.List[object]]::new()
    foreach ($header in [regex]::Matches($code, "^[ \t]*(?<type>$script:AlIdObjectTypes)[ \t]+(?<id>\d+)[ \t]+$name", $options)) {
        $headers.Add([pscustomobject]@{
            Index   = $header.Index
            Key     = "$App|$($header.Groups['type'].Value.ToLowerInvariant())|$($header.Groups['id'].Value)"
            Display = "$($header.Groups['type'].Value) $($header.Groups['id'].Value) $($header.Groups['name'].Value)"
            Line    = & $getLineNumber ($header.Index + $header.Value.Length - $header.Value.TrimStart().Length)
        })
    }
    foreach ($header in [regex]::Matches($code, "^[ \t]*(?<type>$script:AlNamedObjectTypes)[ \t]+$name", $options)) {
        $headers.Add([pscustomobject]@{
            Index   = $header.Index
            Key     = "$App|$($header.Groups['type'].Value.ToLowerInvariant())|$($header.Groups['name'].Value.Trim('"').ToLowerInvariant())"
            Display = "$($header.Groups['type'].Value) $($header.Groups['name'].Value)"
            Line    = & $getLineNumber ($header.Index + $header.Value.Length - $header.Value.TrimStart().Length)
        })
    }
    $headers = @($headers | Sort-Object Index)
    if ($headers.Count -eq 0) { return @() }

    $namespace = ''
    $namespaceMatch = [regex]::Match($code, $script:AlNamespaceStatement, [System.Text.RegularExpressions.RegexOptions]::Multiline)
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
    foreach ($procedure in [regex]::Matches($code, $procedurePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $owner = -1
        for ($i = 0; $i -lt $headers.Count; $i++) {
            if ($headers[$i].Index -le $procedure.Groups['keyword'].Index) { $owner = $i }
        }
        if ($owner -lt 0) { continue }
        $access = if ($procedure.Groups['access'].Success) { $procedure.Groups['access'].Value.ToLowerInvariant() } else { 'public' }
        $objects[$owner].Procedures.Add([pscustomobject]@{
            Name         = $procedure.Groups['name'].Value.Trim('"')
            Access       = $access
            Signature    = ($procedure.Groups['params'].Value -replace '\s+', ' ').Trim().ToLowerInvariant()
            Line         = & $getLineNumber $procedure.Groups['keyword'].Index
            IsSubscriber = $procedure.Groups['attrs'].Value -match '(?i)(?<!\w)EventSubscriber\s*\('
        })
    }
    return @($objects)
}

function Invoke-ModuleGit {
    <#
    .SYNOPSIS
        Run git in the repository; Succeeded is the exit code, Output the stdout lines.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    try {
        $output = @(& git -C $RepoRoot @Arguments 2>$null)
        return [pscustomobject]@{ Succeeded = ($LASTEXITCODE -eq 0); Output = $output }
    } catch {
        return [pscustomobject]@{ Succeeded = $false; Output = @() }
    }
}

function Get-GitFirstLine {
    # The trimmed first output line of a successful git run; empty otherwise.
    param([Parameter(Mandatory)]$Result)

    if ($Result.Succeeded -and $Result.Output.Count -gt 0) { return "$($Result.Output[0])".Trim() }
    return ''
}

function Start-ModuleGitProcess {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$RedirectInput
    )

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
    <#
    .SYNOPSIS
        Every file path in a commit's tree below the repository root folder,
        relative to it, read as UTF-8 from git's NUL-separated list.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Revision
    )

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
        Paths are relative to the repository root folder, as Get-GitTreePath
        returns them. Returns a hashtable of path to text. The working tree is
        not touched; a path the commit lacks is absent from the result.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Revision,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Paths
    )

    $texts = @{}
    if ($Paths.Count -eq 0) { return $texts }

    $process = Start-ModuleGitProcess -RepoRoot $RepoRoot -Arguments @('cat-file', '--batch') -RedirectInput
    try {
        $stream = $process.StandardOutput.BaseStream
        foreach ($path in $Paths) {
            $process.StandardInput.Write("${Revision}:./$path`n")
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
