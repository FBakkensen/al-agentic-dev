#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Hooks = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'hooks.json') -Raw | ConvertFrom-Json
    $script:Start = @($script:Hooks.hooks.sessionStart)[0]
    $script:DefaultsPath = Join-Path $script:RepoRoot 'skills' 'al-setup-models' 'models.default.json'
    $script:DefaultsCompact = (Get-Content -LiteralPath $script:DefaultsPath -Raw) -replace '\s', ''
    $script:Defaults = Get-Content -LiteralPath $script:DefaultsPath -Raw | ConvertFrom-Json

    # bash counts as available only when it sees the HOME this test sets (Git Bash and
    # Linux do; a WSL bash on PATH does not share the Windows environment).
    $script:BashUsable = $false
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        $probe = Join-Path ([System.IO.Path]::GetTempPath()) "home-probe-$([guid]::NewGuid())"
        $saved = $env:HOME
        try {
            $env:HOME = $probe
            $seen = (bash -c 'cygpath -m "$HOME" 2>/dev/null || printf %s "$HOME"' 2>$null) -join ''
            $windowsHome = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $seen = ($seen -replace '\\', '/').TrimEnd('/')
            $windowsHome = ($windowsHome -replace '\\', '/').TrimEnd('/')
            $script:BashUsable = $seen.Equals($windowsHome, [System.StringComparison]::OrdinalIgnoreCase)
        } finally { $env:HOME = $saved }
    }

    function Invoke-SessionStart {
        param(
            [Parameter(Mandatory = $true)][ValidateSet('powershell', 'bash')][string]$Shell,
            [Parameter(Mandatory = $true)][string]$HomeDir,
            [Parameter(Mandatory = $true)][string]$Cwd
        )

        $body = $script:Start.$Shell
        $stdin = @{ cwd = $Cwd } | ConvertTo-Json -Compress
        $savedHome = $env:HOME
        $savedProfile = $env:USERPROFILE
        try {
            $env:HOME = $HomeDir
            $env:USERPROFILE = $HomeDir
            if ($Shell -eq 'powershell') {
                $file = Join-Path $TestDrive "start-$([guid]::NewGuid()).ps1"
                Set-Content -LiteralPath $file -Value $body -Encoding utf8
                $out = $stdin | pwsh -NoProfile -File $file
            } else {
                $file = Join-Path $TestDrive "start-$([guid]::NewGuid()).sh"
                Set-Content -LiteralPath $file -Value $body -Encoding utf8
                $out = $stdin | bash $file
            }
        } finally {
            $env:HOME = $savedHome
            $env:USERPROFILE = $savedProfile
        }
        return (($out -join "`n") | ConvertFrom-Json).additionalContext
    }

    function New-HomeDir {
        param([string]$Name, [string]$ModelsJson)
        $dir = Join-Path $TestDrive "home-$Name"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        if ($null -ne $ModelsJson) {
            $folder = Join-Path $dir '.copilot' 'al-agentic-dev'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $folder 'models.json') -Value $ModelsJson -Encoding utf8
        }
        return $dir
    }

    function Get-DefaultRow {
        param([string]$Tier, [string]$For)
        return "| $Tier | $($script:Defaults.tiers.$Tier.model) | $($script:Defaults.tiers.$Tier.effort) | $For |"
    }
}

Describe 'sessionStart hook model tiers' -Tag 'Process' {
    $script:Cases = @(
        @{ Shell = 'powershell' }
        @{ Shell = 'bash' }
    )
    $script:ParityCases = @(
        @{ Name = 'absent'; ModelsJson = $null }
        @{ Name = 'valid'; ModelsJson = '{"version":1,"tiers":{"frontier":{"model":"user-f","effort":"low"},"execution":{"model":"user-e","effort":"medium"},"mechanical":{"model":"user-m","effort":"high"}}}' }
        @{ Name = 'unparseable'; ModelsJson = '{ not json' }
        @{ Name = 'partial'; ModelsJson = '{"version":1,"tiers":{"frontier":{"model":"user-f","effort":"low"}}}' }
        @{ Name = 'unsafe'; ModelsJson = '{"version":1,"tiers":{"frontier":{"model":"bad\"model","effort":"low"},"execution":{"model":"user-e","effort":"medium"},"mechanical":{"model":"user-m","effort":"high"}}}' }
        @{ Name = 'all-broken'; ModelsJson = '{"version":1,"tiers":{"frontier":{"model":"bad\"model","effort":"low"},"execution":{"model":"user-e","effort":"bad effort"},"mechanical":{}}}' }
    )
    BeforeAll {
        $script:UserMap = '{"version":1,"tiers":{"frontier":{"model":"user-f","effort":"low"},"execution":{"model":"user-e","effort":"medium"},"mechanical":{"model":"user-m","effort":"high"}}}'
        $script:PartialMap = '{"version":1,"tiers":{"frontier":{"model":"user-f","effort":"low"}}}'
        $script:UnsafeMap = '{"version":1,"tiers":{"frontier":{"model":"bad\"model","effort":"low"},"execution":{"model":"user-e","effort":"medium"},"mechanical":{"model":"user-m","effort":"high"}}}'
        $script:AllBrokenMap = '{"version":1,"tiers":{"frontier":{"model":"bad\"model","effort":"low"},"execution":{"model":"user-e","effort":"bad effort"},"mechanical":{}}}'
    }

    It 'injects the shipped defaults with the Defaults line when the file is absent (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "absent-$Shell") -Cwd $TestDrive

        $context | Should -Match '# Model tiers'
        $context | Should -Match '\| Tier \| Model \| Effort \| For \|'
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'frontier' -For 'design, judgment, verdicts, uncertain work')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'execution' -For 'writing code and tests from a brief')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'mechanical' -For 'running gates, commits, renders, lookups, review lenses')))
        $context | Should -Match 'Defaults in use — run /al-setup-models to set your models\.'
        $context | Should -Match 'A `▶ <tier> · <vehicle> · <brief> → <return>` line dispatches now'
        $context | Should -Match 'Delegation is down only'
        $context | Should -Match ([regex]::Escape('Every dispatch prompt carries the brief, the return contract, the unattended line — `You run unattended; the user cannot answer mid-task. Proceed on every reversible step the User Story already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.` — and the plain-text question rule; a child that writes or judges AL also carries the Speak BC paragraph and the grounding rule.'))
    }

    It 'injects the user map without the Defaults line when the file is valid (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "valid-$Shell" -ModelsJson $script:UserMap) -Cwd $TestDrive

        $context | Should -Match '\| frontier \| user-f \| low \|'
        $context | Should -Match '\| execution \| user-e \| medium \|'
        $context | Should -Match '\| mechanical \| user-m \| high \|'
        $context | Should -Not -Match 'Defaults in use'
    }

    It 'falls back to the shipped defaults with the Defaults line when the file is broken (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "broken-$Shell" -ModelsJson '{not json') -Cwd $TestDrive

        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'frontier' -For 'design, judgment, verdicts, uncertain work')))
        $context | Should -Match 'Defaults in use — run /al-setup-models to set your models\.'
    }

    It 'falls back per tier and names the fallen tiers when some are missing (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "partial-$Shell" -ModelsJson $script:PartialMap) -Cwd $TestDrive

        $context | Should -Match '\| frontier \| user-f \| low \|'
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'execution' -For 'writing code and tests from a brief')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'mechanical' -For 'running gates, commits, renders, lookups, review lenses')))
        $context | Should -Match 'Defaults in use for execution, mechanical — run /al-setup-models to set your models\.'
    }

    It 'falls back only the tier whose model has a non-matching value (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "unsafe-$Shell" -ModelsJson $script:UnsafeMap) -Cwd $TestDrive

        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'frontier' -For 'design, judgment, verdicts, uncertain work')))
        $context | Should -Match '\| execution \| user-e \| medium \|'
        $context | Should -Match '\| mechanical \| user-m \| high \|'
        $context | Should -Match 'Defaults in use for frontier — run /al-setup-models to set your models\.'
        $context | Should -Not -Match 'bad"model'
    }

    It 'uses the full Defaults line when all three tiers are broken (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "all-broken-$Shell" -ModelsJson $script:AllBrokenMap) -Cwd $TestDrive

        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'frontier' -For 'design, judgment, verdicts, uncertain work')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'execution' -For 'writing code and tests from a brief')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'mechanical' -For 'running gates, commits, renders, lookups, review lenses')))
        $context | Should -Match '(?m)^Defaults in use — run /al-setup-models to set your models\.$'
        $context | Should -Not -Match 'Defaults in use for'
    }

    It 'produces identical context from both bodies for the <Name> map' -TestCases $script:ParityCases {
        param($Name, $ModelsJson)
        if (-not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $powershellContext = Invoke-SessionStart -Shell 'powershell' -HomeDir (New-HomeDir -Name "parity-$Name-powershell" -ModelsJson $ModelsJson) -Cwd $TestDrive
        $bashContext = Invoke-SessionStart -Shell 'bash' -HomeDir (New-HomeDir -Name "parity-$Name-bash" -ModelsJson $ModelsJson) -Cwd $TestDrive

        $bashContext | Should -BeExactly $powershellContext
    }

    It 'places the block after Reply shape and before Speak BC in an AL repo (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }
        $alDir = Join-Path $TestDrive "al-$Shell"
        New-Item -ItemType Directory -Path $alDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $alDir 'app.json') -Value '{"id":"00000000-0000-0000-0000-000000000000"}' -Encoding utf8

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "order-$Shell") -Cwd $alDir

        $reply = $context.IndexOf('# Reply shape')
        $tiers = $context.IndexOf('# Model tiers')
        $voice = $context.IndexOf('# Speak BC')
        $reply | Should -BeGreaterOrEqual 0
        $tiers | Should -BeGreaterThan $reply
        $voice | Should -BeGreaterThan $tiers
    }
}

Describe 'Model tier defaults are single-sourced' -Tag 'Unit' {
    It 'keeps the PowerShell hook inline defaults equal to models.default.json' {
        $literal = [regex]::Match($script:Start.powershell, "(?m)^\`$d = '(\{.*?\})'\s*$").Groups[1].Value
        $literal | Should -Not -BeNullOrEmpty
        $literal | Should -Be $script:DefaultsCompact
    }

    It 'keeps the bash hook inline defaults equal to models.default.json' {
        $literal = [regex]::Match($script:Start.bash, "(?m)^D='(\{.*?\})'\s*$").Groups[1].Value
        $literal | Should -Not -BeNullOrEmpty
        $literal | Should -Be $script:DefaultsCompact
    }
}

Describe 'Agent pins follow the model tiers' -Tag 'Unit' {
    It 'pins <Agent> to the <Tier> default model' -TestCases @(
        @{ Agent = 'al-review-lens'; Tier = 'execution' }
        @{ Agent = 'al-knowledge-leaf'; Tier = 'mechanical' }
    ) {
        param($Agent, $Tier)

        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'agents' "$Agent.agent.md") -Raw
        $pin = [regex]::Match($text, '(?m)^model\s*:\s*(.+?)\s*$').Groups[1].Value.Trim("'", '"')

        $pin | Should -Be $script:Defaults.tiers.$Tier.model
    }
}
