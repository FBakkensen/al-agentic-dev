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
    Rule 2: a namespace X.Internal declared in the gate's apps belongs to module
    X; only files in X or in X.Internal and below may reference it.
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
        The git ref the change is compared with. No rule reads it yet.
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
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    'Invoke-ModuleCheck'
    'ConvertTo-ModuleGateBlock'
)
