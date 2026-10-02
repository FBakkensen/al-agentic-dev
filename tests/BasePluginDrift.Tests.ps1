#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:DriftScript = Join-Path $script:RepoRoot 'scripts' 'Test-BasePluginDrift.ps1'
    $script:CiPath = Join-Path $script:RepoRoot '.github' 'workflows' 'ci.yml'
    . $script:DriftScript

    function Set-FixtureFile {
        param([string]$Path, [string]$Value)
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($Path)) -Force | Out-Null
        Set-Content -LiteralPath $Path -Value $Value -Encoding utf8
    }

    function New-ConsumerRepo {
        param(
            [string]$Name,
            [string]$SkillBody = 'Run the gate.',
            [string]$SessionStart = '# Delegation',
            [string[]]$Dependencies = @('mattpocock-skills@claude-plugins-official', 'bcquality@bcquality', 'al-language-server-go-windows@al-lsp-for-agents')
        )

        $root = Join-Path $TestDrive $Name 'repo'
        Set-FixtureFile (Join-Path $root '.claude-plugin' 'plugin.json') (
            [ordered]@{ name = 'al-agentic-dev'; version = '0.9.0'; dependencies = $Dependencies } | ConvertTo-Json
        )
        Set-FixtureFile (Join-Path $root '.claude-plugin' 'marketplace.json') ([ordered]@{
                name    = 'al-agentic-dev'
                owner   = @{ name = 'Owner' }
                plugins = @([ordered]@{ name = 'al-agentic-dev'; source = './' })
            } | ConvertTo-Json -Depth 5)
        Set-FixtureFile (Join-Path $root 'skills' 'al-build' 'SKILL.md') @"
---
name: al-build
description: Use when AL code changed.
---

$SkillBody
"@
        Set-FixtureFile (Join-Path $root 'hooks' 'session-start.md') $SessionStart
        return $root
    }

    function New-BasePlugins {
        param([string]$Name, [switch]$OmitBcQuality)

        $base = Join-Path $TestDrive $Name 'base'
        $matt = Join-Path $base 'mattpocock-skills'
        Set-FixtureFile (Join-Path $matt '.claude-plugin' 'plugin.json') @'
{
  "name": "mattpocock-skills",
  "skills": [ "./skills/engineering/tdd", "./skills/engineering/code-review", "./skills/productivity" ]
}
'@
        Set-FixtureFile (Join-Path $matt 'skills' 'engineering' 'tdd' 'SKILL.md') "---`nname: tdd`n---"
        Set-FixtureFile (Join-Path $matt 'skills' 'engineering' 'code-review' 'SKILL.md') "---`nname: code-review`n---"
        Set-FixtureFile (Join-Path $matt 'skills' 'productivity' 'grilling' 'SKILL.md') "---`nname: grilling`n---"
        Set-FixtureFile (Join-Path $matt 'skills' 'engineering' 'unlisted' 'SKILL.md') "---`nname: unlisted`n---"

        $bcq = Join-Path $base 'bcquality'
        Set-FixtureFile (Join-Path $bcq 'skills' 'al-code-review' 'SKILL.md') "---`nname: al-code-review`n---"
        Set-FixtureFile (Join-Path $bcq 'skills' 'entry.md') '# Entry protocol'

        $lsp = Join-Path $base 'al-language-server-go-windows'
        Set-FixtureFile (Join-Path $lsp '.claude-plugin' 'plugin.json') '{ "name": "al-language-server-go-windows" }'
        Set-FixtureFile (Join-Path $lsp '.lsp.json') '{}'

        $map = @{
            'mattpocock-skills'             = $matt
            'bcquality'                     = $bcq
            'al-language-server-go-windows' = $lsp
        }
        if ($OmitBcQuality) { $map.Remove('bcquality') }
        return $map
    }

    function Invoke-DriftCheck {
        param([string]$Root, [hashtable]$PluginRoot)

        $output = @(
            & {
                Invoke-BasePluginDriftCheck -RepoRoot $Root -PluginRoot $PluginRoot -ErrorAction Continue
            } *>&1
        )
        return [pscustomobject]@{
            ExitCode = [int]$output[-1]
            Text     = (@($output | Select-Object -SkipLast 1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
}

Describe 'Base plugin drift check' -Tag 'Unit' {
    It 'passes when every namespaced reference exists upstream' {
        $root = New-ConsumerRepo -Name 'all-exist' `
            -SkillBody 'Run `/mattpocock-skills:tdd`, then /bcquality:al-code-review and mattpocock-skills:grilling.' `
            -SessionStart 'Entry `/mattpocock-skills:code-review` adds al-review.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'all-exist')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'fails and names a reference to a missing upstream skill' {
        $root = New-ConsumerRepo -Name 'missing' -SkillBody "Line one.`nThen /mattpocock-skills:to-prd."

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'missing')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'SKILL\.md:7.*mattpocock-skills:to-prd'
    }

    It 'fails on a missing reference in the SessionStart text' {
        $root = New-ConsumerRepo -Name 'hook-missing' -SessionStart '| /mattpocock-skills:to-spec | /al-scope |'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'hook-missing')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'session-start\.md:1.*mattpocock-skills:to-spec'
    }

    It 'fails when a declared dependency has no plugin directory' {
        $root = New-ConsumerRepo -Name 'no-fixture'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'no-fixture' -OmitBcQuality)

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'bcquality'
    }

    It 'passes a declared dependency that ships no skills while nothing references it' {
        $root = New-ConsumerRepo -Name 'zero-skills' -SkillBody 'Symbols come from the AL language server.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'zero-skills')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'fails a reference into a dependency that ships no skills' {
        $root = New-ConsumerRepo -Name 'zero-skills-ref' -SkillBody 'Run /al-language-server-go-windows:hover.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'zero-skills-ref')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'al-language-server-go-windows:hover'
    }

    It 'leaves bare built-ins such as /simplify and /code-review unresolved' {
        $root = New-ConsumerRepo -Name 'built-ins' -SkillBody 'Run /simplify, then /code-review.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'built-ins')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'resolves the nested layout the upstream manifest lists' {
        $root = New-ConsumerRepo -Name 'nested' -SkillBody 'Use /mattpocock-skills:grilling.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'nested')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'does not count a skill folder the upstream manifest does not list' {
        $root = New-ConsumerRepo -Name 'unlisted' -SkillBody 'Use /mattpocock-skills:unlisted.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'unlisted')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'mattpocock-skills:unlisted'
    }

    It 'does not count a loose markdown file under skills/' {
        $root = New-ConsumerRepo -Name 'loose' -SkillBody 'Read /bcquality:entry first.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'loose')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'bcquality:entry'
    }

    It 'ignores undeclared file:line-shaped tokens' {
        $root = New-ConsumerRepo -Name 'file-line' -SkillBody 'See common:1143, host:port, and SKILL.md:42.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'file-line')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'fails and names a reference whose skill is not spelled in lowercase' {
        $root = New-ConsumerRepo -Name 'upper-skill' -SkillBody 'Use /mattpocock-skills:TDD and mattpocock-skills:code_review.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'upper-skill')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'mattpocock-skills:TDD'
        $result.Text | Should -Match 'mattpocock-skills:code_review'
    }

    It 'fails a declared namespace spelled in another case' {
        $root = New-ConsumerRepo -Name 'upper-ns' -SkillBody 'Use /Mattpocock-Skills:tdd.'

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'upper-ns')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Mattpocock-Skills:tdd spells the namespace mattpocock-skills'
    }

    It 'falls through to skills/*/SKILL.md when the manifest paths hold no skill' {
        $root = New-ConsumerRepo -Name 'fallthrough' -SkillBody 'Use /mattpocock-skills:flat.'
        $plugins = New-BasePlugins -Name 'fallthrough'
        $matt = $plugins['mattpocock-skills']
        Set-FixtureFile (Join-Path $matt '.claude-plugin' 'plugin.json') '{ "name": "mattpocock-skills", "skills": [ "./moved/" ] }'
        Set-FixtureFile (Join-Path $matt 'skills' 'flat' 'SKILL.md') "---`nname: flat`n---"

        $result = Invoke-DriftCheck -Root $root -PluginRoot $plugins

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'skips references inside fenced blocks' {
        $root = New-ConsumerRepo -Name 'fenced' -SkillBody "``````text`n/mattpocock-skills:gone`n``````"

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'fenced')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }
}

Describe 'Base plugin resolution into a directory' -Tag 'Unit' {
    It 'writes each resolved Base plugin into the destination' {
        $root = New-ConsumerRepo -Name 'resolve-dest'
        $destination = Join-Path $TestDrive 'resolve-dest' 'plugins'

        $exitCode = Invoke-BasePluginResolution -RepoRoot $root -Destination $destination -PluginRoot (New-BasePlugins -Name 'resolve-dest') 6> $null

        $exitCode | Should -Be 0
        Join-Path $destination 'mattpocock-skills' 'skills' 'engineering' 'tdd' 'SKILL.md' | Should -Exist
        Join-Path $destination 'bcquality' 'skills' 'al-code-review' 'SKILL.md' | Should -Exist
        Join-Path $destination 'al-language-server-go-windows' '.lsp.json' | Should -Exist
    }

    It 'exits nonzero when a declared dependency cannot be resolved' {
        $root = New-ConsumerRepo -Name 'resolve-missing'

        $exitCode = Invoke-BasePluginResolution -RepoRoot $root -Destination (Join-Path $TestDrive 'resolve-missing' 'plugins') `
            -PluginRoot (New-BasePlugins -Name 'resolve-missing' -OmitBcQuality) 6> $null 2> $null

        $exitCode | Should -Be 1
    }
}

Describe 'Eval copies of the Base plugins' -Tag 'Unit' {
    BeforeAll {
        $script:EvalScript = Join-Path $script:RepoRoot 'scripts' 'Update-EvalBasePlugins.ps1'
        . $script:EvalScript

        function Invoke-EvalCopy {
            param([string]$Root, [string]$Destination, [hashtable]$PluginRoot)

            $output = @(
                & {
                    Update-EvalBasePlugin -RepoRoot $Root -Destination $Destination -PluginRoot $PluginRoot -ErrorAction Continue
                } *>&1
            )
            return [pscustomobject]@{
                ExitCode = [int]$output[-1]
                Text     = (@($output | Select-Object -SkipLast 1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
            }
        }
    }

    It 'writes every declared Base plugin, the one that ships no skill too, and nothing else' {
        $root = New-ConsumerRepo -Name 'eval-copy'
        $destination = Join-Path $TestDrive 'eval-copy' '.base-plugins'

        $result = Invoke-EvalCopy -Root $root -Destination $destination -PluginRoot (New-BasePlugins -Name 'eval-copy')

        $result.ExitCode | Should -Be 0 -Because $result.Text
        Join-Path $destination 'mattpocock-skills' 'skills' 'engineering' 'tdd' 'SKILL.md' | Should -Exist
        Join-Path $destination 'bcquality' 'skills' 'al-code-review' 'SKILL.md' | Should -Exist
        Join-Path $destination 'al-language-server-go-windows' '.lsp.json' | Should -Exist
        @(Get-ChildItem -LiteralPath $destination -Force).Name | Sort-Object |
            Should -Be @('al-language-server-go-windows', 'bcquality', 'mattpocock-skills')
    }

    It 'refreshes a copy on rerun, dropping files upstream no longer ships' {
        $root = New-ConsumerRepo -Name 'eval-refresh'
        $destination = Join-Path $TestDrive 'eval-refresh' '.base-plugins'
        Set-FixtureFile (Join-Path $destination 'mattpocock-skills' 'skills' 'retired' 'SKILL.md') "---`nname: retired`n---"

        $result = Invoke-EvalCopy -Root $root -Destination $destination -PluginRoot (New-BasePlugins -Name 'eval-refresh')

        $result.ExitCode | Should -Be 0 -Because $result.Text
        Join-Path $destination 'mattpocock-skills' 'skills' 'retired' | Should -Not -Exist
        Join-Path $destination 'mattpocock-skills' 'skills' 'engineering' 'tdd' 'SKILL.md' | Should -Exist
    }

    It 'exits nonzero, names the dependency, and keeps the existing copies when one cannot be fetched' {
        $root = New-ConsumerRepo -Name 'eval-missing'
        $destination = Join-Path $TestDrive 'eval-missing' '.base-plugins'
        $kept = Join-Path $destination 'mattpocock-skills' 'skills' 'kept' 'SKILL.md'
        Set-FixtureFile $kept "---`nname: kept`n---"

        $result = Invoke-EvalCopy -Root $root -Destination $destination -PluginRoot (New-BasePlugins -Name 'eval-missing' -OmitBcQuality)

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "dependency 'bcquality' could not be fetched"
        $kept | Should -Exist
        Join-Path $destination 'bcquality' | Should -Not -Exist
    }
}

Describe 'Eval copies process wrapper' -Tag 'Process' {
    It 'writes into .base-plugins by default and exits nonzero when an upstream is unreachable' {
        $script:EvalScript = Join-Path $script:RepoRoot 'scripts' 'Update-EvalBasePlugins.ps1'
        $good = New-ConsumerRepo -Name 'eval-process-good'
        $map = New-BasePlugins -Name 'eval-process-good'
        $pairs = ($map.Keys | ForEach-Object { "'$_=$($map[$_])'" }) -join ','

        & pwsh -NoProfile -Command "& '$script:EvalScript' -RepoRoot '$good' -PluginRoot $pairs; exit `$LASTEXITCODE" *> $null
        $LASTEXITCODE | Should -Be 0
        Join-Path $good '.base-plugins' 'bcquality' 'skills' 'al-code-review' 'SKILL.md' | Should -Exist

        $bad = New-ConsumerRepo -Name 'eval-process-bad' -Dependencies @('bcquality@no-such-marketplace')
        $output = & pwsh -NoProfile -Command "& '$script:EvalScript' -RepoRoot '$bad'; exit `$LASTEXITCODE" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match "dependency 'bcquality' could not be fetched"
        Join-Path $bad '.base-plugins' 'bcquality' | Should -Not -Exist
    }
}

Describe 'Base plugin fetch through marketplaces' -Tag 'Process' {
    BeforeAll {
        function New-GitRepo {
            param([string]$Path, [hashtable]$Files)
            foreach ($relative in $Files.Keys) { Set-FixtureFile (Join-Path $Path $relative) $Files[$relative] }
            $null = & git -C $Path init --quiet 2>&1
            $null = & git -C $Path add -A 2>&1
            $null = & git -C $Path -c user.name=fixture -c user.email=fixture@example.com commit --quiet -m fixture 2>&1
            ([uri](Resolve-Path -LiteralPath $Path).Path).AbsoluteUri
        }

        # The shapes the real upstream marketplaces use: a plugin at the repository root, and
        # one in a folder beside its sibling variant.
        $upstream = Join-Path $TestDrive 'upstream'
        $script:SavedMarketplaces = $script:KnownMarketplaces.Clone()
        $script:KnownMarketplaces['bcquality'] = New-GitRepo (Join-Path $upstream 'bcquality') @{
            '.claude-plugin/marketplace.json' = '{ "name": "bcquality", "plugins": [ { "name": "bcquality", "source": "./", "skills": [ "./skills/" ] } ] }'
            'skills/al-code-review/SKILL.md'  = "---`nname: al-code-review`n---"
            'skills/entry.md'                 = '# Entry'
        }
        $script:KnownMarketplaces['al-lsp-for-agents'] = New-GitRepo (Join-Path $upstream 'lsp') @{
            '.claude-plugin/marketplace.json'                          = '{ "name": "al-lsp-for-agents", "plugins": [ { "name": "al-language-server-go-windows", "source": "./al-language-server-go-windows" }, { "name": "al-language-server-go-linux", "source": "./al-language-server-go-linux" } ] }'
            'al-language-server-go-windows/.claude-plugin/plugin.json' = '{ "name": "al-language-server-go-windows" }'
            'al-language-server-go-linux/bin/server'                   = 'linux'
        }
        $script:BothDependencies = @('bcquality@bcquality', 'al-language-server-go-windows@al-lsp-for-agents')
    }

    AfterAll {
        $script:KnownMarketplaces.Clear()
        foreach ($key in $script:SavedMarketplaces.Keys) { $script:KnownMarketplaces[$key] = $script:SavedMarketplaces[$key] }
    }

    It 'fetches a plugin at the marketplace root and one in a marketplace folder into the destination' {
        $root = New-ConsumerRepo -Name 'fetch-dest' -Dependencies $script:BothDependencies
        $destination = Join-Path $TestDrive 'fetch-dest' 'plugins'

        $exitCode = Invoke-BasePluginResolution -RepoRoot $root -Destination $destination 6> $null

        $exitCode | Should -Be 0
        Join-Path $destination 'bcquality' 'skills' 'al-code-review' 'SKILL.md' | Should -Exist
        Join-Path $destination 'al-language-server-go-windows' '.claude-plugin' 'plugin.json' | Should -Exist
        Join-Path $destination 'al-language-server-go-windows' 'al-language-server-go-linux' | Should -Not -Exist
    }

    It 'resolves references against fetched plugins' {
        $good = New-ConsumerRepo -Name 'fetch-good' -Dependencies $script:BothDependencies -SkillBody 'Run /bcquality:al-code-review.'
        $bad = New-ConsumerRepo -Name 'fetch-bad' -Dependencies $script:BothDependencies -SkillBody 'Run /bcquality:entry.'

        $result = Invoke-DriftCheck -Root $good
        $result.ExitCode | Should -Be 0 -Because $result.Text
        $result = Invoke-DriftCheck -Root $bad
        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'bcquality:entry'
    }

    It 'fails and names a dependency whose marketplace does not list it' {
        $root = New-ConsumerRepo -Name 'fetch-unlisted' -Dependencies @('no-such-plugin@bcquality')

        $result = Invoke-DriftCheck -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "dependency 'no-such-plugin' could not be resolved.*does not list"
    }

    It 'fails and names a dependency whose marketplace is unknown' {
        $root = New-ConsumerRepo -Name 'fetch-unknown' -Dependencies @('bcquality@no-such-marketplace')

        $result = Invoke-DriftCheck -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "dependency 'bcquality' could not be resolved.*no known repository"
    }

    It 'fails and names a dependency written without a marketplace' {
        $root = New-ConsumerRepo -Name 'fetch-bare' -Dependencies @('bcquality')

        $result = Invoke-DriftCheck -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "dependency 'bcquality' could not be resolved.*names no marketplace"
    }
}

Describe 'Base plugin drift check process wrapper' -Tag 'Process' {
    It 'returns zero for resolved references and nonzero for a missing one' {
        $good = New-ConsumerRepo -Name 'process-good' -SkillBody 'Run /mattpocock-skills:tdd.'
        $bad = New-ConsumerRepo -Name 'process-bad' -SkillBody 'Run /mattpocock-skills:gone.'
        $goodMap = New-BasePlugins -Name 'process-good'
        $badMap = New-BasePlugins -Name 'process-bad'
        $goodPlugins = ($goodMap.Keys | ForEach-Object { "'$_=$($goodMap[$_])'" }) -join ','
        $badPlugins = ($badMap.Keys | ForEach-Object { "'$_=$($badMap[$_])'" }) -join ','

        & pwsh -NoProfile -Command "& '$script:DriftScript' -RepoRoot '$good' -PluginRoot $goodPlugins; exit `$LASTEXITCODE" *> $null
        $LASTEXITCODE | Should -Be 0

        $output = & pwsh -NoProfile -Command "& '$script:DriftScript' -RepoRoot '$bad' -PluginRoot $badPlugins; exit `$LASTEXITCODE" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'mattpocock-skills:gone'
    }
}

Describe 'Base plugin drift workflow' -Tag 'Unit' {
    It 'runs the drift check as a CI step on every pull request' {
        $ci = Get-Content -LiteralPath $script:CiPath -Raw

        $ci | Should -Match 'pull_request:'
        $ci | Should -Match '\./scripts/Test-BasePluginDrift\.ps1'
    }
}
