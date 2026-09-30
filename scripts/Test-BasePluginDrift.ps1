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
    dependency. Upstream skills are found through our marketplace entry's skills paths,
    else the upstream manifest's skills paths, else skills/*/SKILL.md; only folders holding
    a SKILL.md count. Every unresolved reference and every dependency that cannot be
    fetched is reported; any of them exits 1.
    -PluginRoot maps namespaces to local directories ('ns=path') and skips every fetch.
.EXAMPLE
    pwsh scripts/Test-BasePluginDrift.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),

    [string[]]$PluginRoot
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
        $pattern = '(?<![\w./:@-])/?(?<ns>[a-z0-9]+(?:-[a-z0-9]+)*):(?<skill>[a-z0-9]+(?:-[a-z0-9]+)*)(?![\w-])'
        foreach ($match in [regex]::Matches($line, $pattern)) {
            [pscustomobject]@{
                Namespace = $match.Groups['ns'].Value
                Skill     = $match.Groups['skill'].Value
                Line      = $lineNumber
            }
        }
    }
}

function Get-BasePluginDependency {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $manifest = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude-plugin' 'plugin.json') -Raw | ConvertFrom-Json
    foreach ($dependency in @($manifest.PSObject.Properties['dependencies'] ? $manifest.dependencies : @())) {
        $spec = if ($dependency -is [string]) { $dependency } else { [string]$dependency.name }
        $name, $marketplace = $spec -split '@', 2
        [pscustomobject]@{ Name = $name; Marketplace = $marketplace }
    }
}

function Invoke-Git {
    param([string[]]$Arguments)

    $output = @(& git @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join ' ')"
    }
    $output
}

function Save-GitSource {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Target,
        [string]$Sha,
        [string]$Ref,
        [string]$Path
    )

    $checkout = Join-Path ([System.IO.Path]::GetTempPath()) ("drift-" + [guid]::NewGuid().ToString('N'))
    try {
        if ($Sha) {
            $null = Invoke-Git @('init', '--quiet', $checkout)
            $null = Invoke-Git @('-C', $checkout, 'remote', 'add', 'origin', $Url)
            $null = Invoke-Git @('-C', $checkout, 'fetch', '--quiet', '--depth', '1', '--filter=blob:none', 'origin', $Sha)
        } else {
            $clone = @('clone', '--quiet', '--depth', '1', '--filter=blob:none', '--no-checkout')
            if ($Ref) { $clone += @('--branch', $Ref) }
            $null = Invoke-Git ($clone + @($Url, $checkout))
        }
        if ($Path) {
            $null = Invoke-Git @('-C', $checkout, 'sparse-checkout', 'set', '--no-cone', "/$($Path.Trim('/'))/")
        }
        $null = Invoke-Git @('-C', $checkout, 'checkout', '--quiet', $(if ($Sha) { 'FETCH_HEAD' } else { 'HEAD' }))

        $source = if ($Path) { Join-Path $checkout $Path } else { $checkout }
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "$Url has no directory '$Path'."
        }
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
        Get-ChildItem -LiteralPath $source -Force |
            Where-Object Name -NE '.git' |
            Copy-Item -Destination $Target -Recurse -Force
    } finally {
        Remove-Item -LiteralPath $checkout -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Save-PluginSource {
    param(
        [Parameter(Mandatory = $true)]$Source,
        [Parameter(Mandatory = $true)][string]$Target
    )

    if ($Source -is [string]) {
        throw "a relative source '$Source' outside our marketplace is not supported."
    }
    $parameters = @{
        Target = $Target
        Sha    = [string]$Source.PSObject.Properties['sha']?.Value
        Ref    = [string]$Source.PSObject.Properties['ref']?.Value
    }
    switch ($Source.source) {
        'url' { Save-GitSource @parameters -Url $Source.url }
        'github' { Save-GitSource @parameters -Url "https://github.com/$($Source.repo).git" }
        'git-subdir' { Save-GitSource @parameters -Url $Source.url -Path $Source.path }
        default { throw "source type '$($Source.source)' is not supported." }
    }
}

function Get-MarketplacePluginSource {
    param([Parameter(Mandatory = $true)][string]$Marketplace, [Parameter(Mandatory = $true)][string]$Name)

    $url = $script:KnownMarketplaces[$Marketplace]
    if (-not $url) {
        throw "marketplace '$Marketplace' has no known repository."
    }
    $checkout = Join-Path ([System.IO.Path]::GetTempPath()) ("drift-" + [guid]::NewGuid().ToString('N'))
    try {
        $null = Invoke-Git @('clone', '--quiet', '--depth', '1', '--filter=blob:none', '--no-checkout', $url, $checkout)
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
        -PluginRoot ('ns=path'), maps each dependency to its directory and fetches nothing.
        Emits one object per dependency: Name, Root, SkillPaths (our marketplace entry's
        skills paths), and Error when it cannot be resolved.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$Destination,
        [string[]]$PluginRoot
    )

    $marketplace = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude-plugin' 'marketplace.json') -Raw | ConvertFrom-Json
    $overrides = @{}
    foreach ($pair in @($PluginRoot)) {
        if (-not $pair) { continue }
        $namespace, $path = $pair -split '=', 2
        $overrides[$namespace] = $path
    }

    foreach ($dependency in @(Get-BasePluginDependency -RepoRoot $RepoRoot)) {
        $entry = @($marketplace.plugins | Where-Object name -EQ $dependency.Name) | Select-Object -First 1
        $skillPaths = if ($entry) { @($entry.PSObject.Properties['skills']?.Value | Where-Object { $_ }) } else { @() }
        $result = [pscustomobject]@{
            Name       = $dependency.Name
            Root       = $null
            SkillPaths = $skillPaths
            Error      = $null
        }
        try {
            if ($PluginRoot) {
                if (-not $overrides.ContainsKey($dependency.Name)) {
                    throw 'no plugin directory was supplied.'
                }
                if (-not (Test-Path -LiteralPath $overrides[$dependency.Name] -PathType Container)) {
                    throw "the plugin directory '$($overrides[$dependency.Name])' does not exist."
                }
                $result.Root = $overrides[$dependency.Name]
            } else {
                if (-not $Destination) {
                    throw 'a destination directory is required to fetch.'
                }
                $target = Join-Path $Destination $dependency.Name
                if ($dependency.Marketplace) {
                    $upstream = Get-MarketplacePluginSource -Marketplace $dependency.Marketplace -Name $dependency.Name
                    Save-PluginSource -Source $upstream -Target $target
                } elseif ($entry -and $entry.source -isnot [string]) {
                    Save-PluginSource -Source $entry.source -Target $target
                } else {
                    throw 'our marketplace lists no url or git-subdir source for it.'
                }
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

    $paths = @($SkillPaths | Where-Object { $_ })
    if ($paths.Count -eq 0) {
        foreach ($manifestPath in @((Join-Path $Root '.claude-plugin' 'plugin.json'), (Join-Path $Root 'plugin.json'))) {
            if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
                $paths = @($manifest.PSObject.Properties['skills']?.Value | Where-Object { $_ })
                break
            }
        }
    }
    if ($paths.Count -eq 0) {
        $paths = @('./skills/')
    }

    foreach ($relative in $paths) {
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
}

function Invoke-BasePluginDriftCheck {
    [CmdletBinding()]
    param(
        [string]$RepoRoot = (Join-Path $PSScriptRoot '..'),
        [string[]]$PluginRoot
    )

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
    $failures = [System.Collections.Generic.List[string]]::new()
    $destination = Join-Path ([System.IO.Path]::GetTempPath()) ("base-plugins-" + [guid]::NewGuid().ToString('N'))
    try {
        $skillsByNamespace = @{}
        foreach ($plugin in @(Resolve-BasePlugin -RepoRoot $RepoRoot -Destination $destination -PluginRoot $PluginRoot)) {
            if ($plugin.Error) {
                $failures.Add("FAIL: dependency '$($plugin.Name)' could not be resolved: $($plugin.Error)")
                continue
            }
            $skills = @(Get-BasePluginSkill -Root $plugin.Root -SkillPaths $plugin.SkillPaths)
            $skillsByNamespace[$plugin.Name] = [System.Collections.Generic.HashSet[string]]::new([string[]]$skills)
            Write-Host "OK: $($plugin.Name) ships $($skills.Count) skill(s)" -ForegroundColor Green
        }
        $declared = @(Get-BasePluginDependency -RepoRoot $RepoRoot | ForEach-Object Name)

        $files = @(
            Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'skills') -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }
            Get-Item -LiteralPath (Join-Path $RepoRoot 'hooks' 'session-start.md') -ErrorAction SilentlyContinue
        )
        foreach ($file in $files) {
            $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName).Replace('\', '/')
            $text = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($reference in @(Get-NamespacedSkillReference -Text ([string]$text))) {
                if ($declared -cnotcontains $reference.Namespace) { continue }
                $skills = $skillsByNamespace[$reference.Namespace]
                if ($null -eq $skills) { continue }
                if (-not $skills.Contains($reference.Skill)) {
                    $failures.Add("FAIL: ${relative}:$($reference.Line) - $($reference.Namespace):$($reference.Skill) names no skill that $($reference.Namespace) ships")
                }
            }
        }
    } finally {
        Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
        return 1
    }
    Write-Host "`nEvery Base plugin skill reference resolves." -ForegroundColor Cyan
    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-BasePluginDriftCheck -RepoRoot $RepoRoot -PluginRoot $PluginRoot)
}
