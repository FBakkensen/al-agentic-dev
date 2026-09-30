#Requires -Version 7.2
<#
.SYNOPSIS
    Fails when a <ns>:<skill> reference names a Base plugin skill that upstream no longer ships.
.DESCRIPTION
    Reads the dependencies of .claude-plugin/plugin.json. A dependency's namespace is its
    plugin name, the part before '@'. mattpocock-skills@claude-plugins-official resolves at
    the commit claude-plugins-official's marketplace lists; a bare dependency resolves at its
    upstream default branch through its url or git-subdir entry in our marketplace.
    Every <ns>:<skill> token, with or without a leading '/', outside fenced blocks in
    skills/**/*.md and hooks/session-start.md is resolved when its namespace is a declared
    dependency in any casing. Upstream skills are found through our marketplace entry's
    skills paths, else the upstream manifest's skills paths, else skills/*/SKILL.md, taking
    the first step that yields a skill; only folders holding a SKILL.md count. Every
    unresolved reference and every dependency that cannot be fetched is reported; any of
    them exits 1.
    -PluginRoot maps namespaces to local directories ('ns=path') and skips every fetch.
    -Destination resolves every Base plugin into <Destination>/<name> and checks nothing.
.EXAMPLE
    pwsh scripts/Test-BasePluginDrift.ps1
.EXAMPLE
    pwsh scripts/Test-BasePluginDrift.ps1 -Destination .base-plugins
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),

    [string[]]$PluginRoot,

    [string]$Destination
)

$script:KnownMarketplaces = @{
    'claude-plugins-official' = 'https://github.com/anthropics/claude-plugins-official.git'
}

function Get-NamespacedSkillReference {
    <#
    .SYNOPSIS
        Emits every <ns>:<skill> candidate outside fenced blocks; the caller filters namespaces.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $pattern = '(?<![\w./:@-])/?(?<ns>[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*):(?<skill>[A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)*)(?![\w-])'
    $fenceChar = ''
    $fenceLength = 0
    $lineNumber = 0
    foreach ($line in ($Text -split '\r?\n')) {
        $lineNumber++
        $run = [regex]::Match($line, '^\s*(?<fence>`{3,}|~{3,})')
        if ($run.Success) {
            $fence = $run.Groups['fence'].Value
            if ($fenceLength -eq 0) {
                $fenceChar = $fence[0]
                $fenceLength = $fence.Length
                continue
            } elseif ($fence[0] -eq $fenceChar -and $fence.Length -ge $fenceLength) {
                $fenceLength = 0
                continue
            }
        }
        if ($fenceLength -gt 0) { continue }
        foreach ($match in [regex]::Matches($line, $pattern)) {
            [pscustomobject]@{
                Namespace = $match.Groups['ns'].Value
                Skill     = $match.Groups['skill'].Value
                Line      = $lineNumber
            }
        }
    }
}

function ConvertTo-PluginRootMap {
    <#
    .SYNOPSIS
        Turns 'ns=path' pairs, the form a process boundary can carry, into a map.
    #>
    param([string[]]$Pair)

    $pairs = @($Pair | Where-Object { $_ })
    if ($pairs.Count -eq 0) {
        return $null
    }
    $map = @{}
    foreach ($item in $pairs) {
        $namespace, $path = $item -split '=', 2
        $map[$namespace] = $path
    }
    $map
}

function New-TemporaryCheckoutPath {
    Join-Path ([System.IO.Path]::GetTempPath()) ('base-plugin-' + [guid]::NewGuid().ToString('N'))
}

function Invoke-Git {
    param([string[]]$Arguments)

    $output = @(& git @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join ' ')"
    }
    $output
}

function Invoke-GitClone {
    # Blobs arrive on checkout only, so a sparse or tree-only read stays small.
    param([string]$Url, [string]$Checkout)

    $null = Invoke-Git @('clone', '--quiet', '--depth', '1', '--filter=blob:none', '--no-checkout', $Url, $Checkout)
}

function Save-PluginSource {
    <#
    .SYNOPSIS
        Copies a url or git-subdir source, at its sha or the default branch, into Target.
    #>
    param(
        [Parameter(Mandatory = $true)]$Source,
        [Parameter(Mandatory = $true)][string]$Target
    )

    if ($Source -is [string] -or $Source.source -notin @('url', 'git-subdir')) {
        throw "source '$($Source.source ?? $Source)' is not a url or git-subdir source."
    }
    $sha = [string]$Source.PSObject.Properties['sha']?.Value
    $path = if ($Source.source -eq 'git-subdir') { ([string]$Source.path).Trim('/') } else { '' }

    $checkout = New-TemporaryCheckoutPath
    try {
        if ($sha) {
            $null = Invoke-Git @('init', '--quiet', $checkout)
            $null = Invoke-Git @('-C', $checkout, 'remote', 'add', 'origin', $Source.url)
            $null = Invoke-Git @('-C', $checkout, 'fetch', '--quiet', '--depth', '1', '--filter=blob:none', 'origin', $sha)
        } else {
            Invoke-GitClone -Url $Source.url -Checkout $checkout
        }
        if ($path) {
            $null = Invoke-Git @('-C', $checkout, 'sparse-checkout', 'set', '--no-cone', "/$path/")
        }
        $null = Invoke-Git @('-C', $checkout, 'checkout', '--quiet', $(if ($sha) { 'FETCH_HEAD' } else { 'HEAD' }))

        $pluginFolder = if ($path) { Join-Path $checkout $path } else { $checkout }
        if (-not (Test-Path -LiteralPath $pluginFolder -PathType Container)) {
            throw "$($Source.url) has no directory '$path'."
        }
        Copy-PluginFolder -From $pluginFolder -Target $Target
    } finally {
        Remove-Item -LiteralPath $checkout -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Copy-PluginFolder {
    param([string]$From, [string]$Target)

    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    Get-ChildItem -LiteralPath $From -Force |
        Where-Object Name -NE '.git' |
        Copy-Item -Destination $Target -Recurse -Force
}

function Get-MarketplacePluginSource {
    param([Parameter(Mandatory = $true)][string]$Marketplace, [Parameter(Mandatory = $true)][string]$Name)

    $url = $script:KnownMarketplaces[$Marketplace]
    if (-not $url) {
        throw "marketplace '$Marketplace' has no known repository."
    }
    $checkout = New-TemporaryCheckoutPath
    try {
        Invoke-GitClone -Url $url -Checkout $checkout
        $json = Invoke-Git @('-C', $checkout, 'show', 'HEAD:.claude-plugin/marketplace.json') | Out-String
    } finally {
        Remove-Item -LiteralPath $checkout -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Other entries carry keys that differ only by case, which only a hashtable parse accepts.
    $entry = @(($json | ConvertFrom-Json -AsHashtable).plugins | Where-Object { $_['name'] -ceq $Name }) | Select-Object -First 1
    if (-not $entry) {
        throw "marketplace '$Marketplace' does not list '$Name'."
    }
    $source = $entry['source']
    if ($source -is [System.Collections.IDictionary]) { [pscustomobject]$source } else { $source }
}

function Resolve-BasePlugin {
    <#
    .SYNOPSIS
        Resolves each declared Base plugin to a local directory.
    .DESCRIPTION
        Without -PluginRoot, fetches every dependency into <Destination>/<name>. With
        -PluginRoot (namespace -> directory), fetches nothing and uses each directory in
        place, or copies it into <Destination>/<name> when -Destination is given. Emits one
        object per declared dependency: Name, Root, SkillPaths (our marketplace entry's
        skills paths), and Error when it cannot be resolved.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$Destination,
        [hashtable]$PluginRoot
    )

    $manifest = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude-plugin' 'plugin.json') -Raw | ConvertFrom-Json
    $marketplace = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude-plugin' 'marketplace.json') -Raw | ConvertFrom-Json

    foreach ($dependency in @($manifest.PSObject.Properties['dependencies']?.Value)) {
        if (-not $dependency) { continue }
        $name, $dependencyMarketplace = ($dependency -is [string] ? $dependency : [string]$dependency.name) -split '@', 2
        $entry = @($marketplace.plugins | Where-Object name -EQ $name) | Select-Object -First 1
        $result = [pscustomobject]@{
            Name       = $name
            Root       = $null
            SkillPaths = @(if ($entry) { $entry.PSObject.Properties['skills']?.Value | Where-Object { $_ } })
            Error      = $null
        }
        try {
            $target = if ($Destination) { Join-Path $Destination $name }
            if ($PluginRoot) {
                $local = $PluginRoot[$name]
                if (-not $local) {
                    throw 'no plugin directory was supplied.'
                }
                if (-not (Test-Path -LiteralPath $local -PathType Container)) {
                    throw "the plugin directory '$local' does not exist."
                }
                $result.Root = $local
                if ($target) {
                    Copy-PluginFolder -From $local -Target $target
                    $result.Root = $target
                }
            } else {
                if (-not $target) {
                    throw 'a destination directory is required to fetch.'
                }
                $source = if ($dependencyMarketplace) {
                    Get-MarketplacePluginSource -Marketplace $dependencyMarketplace -Name $name
                } elseif ($entry) {
                    $entry.source
                } else {
                    throw 'our marketplace does not list it.'
                }
                Save-PluginSource -Source $source -Target $target
                $result.Root = $target
            }
        } catch {
            $result.Error = $_.Exception.Message
        }
        $result
    }
}

function Get-BasePluginSkill {
    <#
    .SYNOPSIS
        Names the skills a resolved Base plugin ships.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string[]]$SkillPaths
    )

    $manifestPath = Join-Path $Root '.claude-plugin' 'plugin.json'
    $manifestPaths = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).PSObject.Properties['skills']?.Value
    }

    foreach ($paths in @($SkillPaths), @($manifestPaths), @('./skills/')) {
        $skills = @(
            foreach ($relative in @($paths | Where-Object { $_ })) {
                $folder = Join-Path $Root $relative
                if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
                if (Test-Path -LiteralPath (Join-Path $folder 'SKILL.md') -PathType Leaf) {
                    (Get-Item -LiteralPath $folder).Name
                    continue
                }
                Get-ChildItem -LiteralPath $folder -Directory |
                    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
                    ForEach-Object Name
            }
        )
        if ($skills.Count -gt 0) {
            return $skills
        }
    }
}

function Invoke-BasePluginDriftCheck {
    [CmdletBinding()]
    param(
        [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),
        [hashtable]$PluginRoot
    )

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
    $failures = [System.Collections.Generic.List[string]]::new()
    $destination = if (-not $PluginRoot) { New-TemporaryCheckoutPath }
    try {
        $plugins = @(Resolve-BasePlugin -RepoRoot $RepoRoot -Destination $destination -PluginRoot $PluginRoot)
        $skillsByNamespace = @{}
        foreach ($plugin in $plugins) {
            if ($plugin.Error) {
                $failures.Add("FAIL: dependency '$($plugin.Name)' could not be resolved: $($plugin.Error)")
                continue
            }
            $skills = @(Get-BasePluginSkill -Root $plugin.Root -SkillPaths $plugin.SkillPaths)
            $skillsByNamespace[$plugin.Name] = [System.Collections.Generic.HashSet[string]]::new([string[]]$skills)
            Write-Host "OK: $($plugin.Name) ships $($skills.Count) skill(s)" -ForegroundColor Green
        }

        $files = @(
            Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'skills') -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }
            Get-Item -LiteralPath (Join-Path $RepoRoot 'hooks' 'session-start.md') -ErrorAction SilentlyContinue
        )
        foreach ($file in $files) {
            $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName).Replace('\', '/')
            $text = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($reference in @(Get-NamespacedSkillReference -Text ([string]$text))) {
                $namespace = @($plugins.Name | Where-Object { $_ -ieq $reference.Namespace }) | Select-Object -First 1
                if (-not $namespace) { continue }
                $token = "$($reference.Namespace):$($reference.Skill)"
                if ($namespace -cne $reference.Namespace) {
                    $failures.Add("FAIL: ${relative}:$($reference.Line) - $token spells the namespace $namespace")
                    continue
                }
                $skills = $skillsByNamespace[$namespace]
                if ($skills -and -not $skills.Contains($reference.Skill)) {
                    $failures.Add("FAIL: ${relative}:$($reference.Line) - $token names no skill that $namespace ships")
                }
            }
        }
    } finally {
        if ($destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
        return 1
    }
    Write-Host "`nEvery Base plugin skill reference resolves." -ForegroundColor Cyan
    return 0
}

function Invoke-BasePluginResolution {
    <#
    .SYNOPSIS
        Writes every resolved Base plugin into Destination; exits 1 when any cannot be resolved.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Destination,
        [hashtable]$PluginRoot
    )

    $failed = $false
    foreach ($plugin in @(Resolve-BasePlugin -RepoRoot $RepoRoot -Destination $Destination -PluginRoot $PluginRoot)) {
        if ($plugin.Error) {
            Write-Error "FAIL: dependency '$($plugin.Name)' could not be resolved: $($plugin.Error)" -ErrorAction Continue
            $failed = $true
        } else {
            Write-Host "OK: $($plugin.Name) -> $($plugin.Root)" -ForegroundColor Green
        }
    }
    return [int]$failed
}

if ($MyInvocation.InvocationName -ne '.') {
    $map = ConvertTo-PluginRootMap -Pair $PluginRoot
    if ($Destination) {
        exit (Invoke-BasePluginResolution -RepoRoot $RepoRoot -Destination $Destination -PluginRoot $map)
    }
    exit (Invoke-BasePluginDriftCheck -RepoRoot $RepoRoot -PluginRoot $map)
}
