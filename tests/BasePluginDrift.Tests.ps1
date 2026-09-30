#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:DriftScript = Join-Path $script:RepoRoot 'scripts' 'Test-BasePluginDrift.ps1'
    $script:IssueScript = Join-Path $script:RepoRoot 'scripts' 'Update-BasePluginDriftIssue.ps1'
    $script:WorkflowPath = Join-Path $script:RepoRoot '.github' 'workflows' 'base-plugin-drift.yml'
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
            [string]$SessionStart = '# Delegation'
        )

        $root = Join-Path $TestDrive $Name 'repo'
        Set-FixtureFile (Join-Path $root '.claude-plugin' 'plugin.json') @'
{
  "name": "al-agentic-dev",
  "version": "0.9.0",
  "dependencies": [
    "mattpocock-skills@claude-plugins-official",
    "bcquality",
    "al-language-server-go-windows"
  ]
}
'@
        Set-FixtureFile (Join-Path $root '.claude-plugin' 'marketplace.json') @'
{
  "name": "al-agentic-dev",
  "owner": { "name": "Owner" },
  "plugins": [
    { "name": "al-agentic-dev", "source": "./" },
    {
      "name": "bcquality",
      "source": { "source": "url", "url": "https://github.com/microsoft/BCQuality.git" },
      "skills": [ "./skills/" ]
    },
    {
      "name": "al-language-server-go-windows",
      "source": {
        "source": "git-subdir",
        "url": "https://github.com/SShadowS/al-lsp-for-agents.git",
        "path": "al-language-server-go-windows"
      }
    }
  ]
}
'@
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

        $map = [ordered]@{
            'mattpocock-skills'             = $matt
            'bcquality'                     = $bcq
            'al-language-server-go-windows' = $lsp
        }
        if ($OmitBcQuality) { $map.Remove('bcquality') }
        return @($map.Keys | ForEach-Object { "$_=$($map[$_])" })
    }

    function Invoke-DriftCheck {
        param([string]$Root, [string[]]$PluginRoot)

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

    It 'skips references inside fenced blocks' {
        $root = New-ConsumerRepo -Name 'fenced' -SkillBody "``````text`n/mattpocock-skills:gone`n``````"

        $result = Invoke-DriftCheck -Root $root -PluginRoot (New-BasePlugins -Name 'fenced')

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }
}

Describe 'Base plugin drift check process wrapper' -Tag 'Process' {
    It 'returns zero for resolved references and nonzero for a missing one' {
        $good = New-ConsumerRepo -Name 'process-good' -SkillBody 'Run /mattpocock-skills:tdd.'
        $bad = New-ConsumerRepo -Name 'process-bad' -SkillBody 'Run /mattpocock-skills:gone.'
        $goodPlugins = (New-BasePlugins -Name 'process-good' | ForEach-Object { "'$_'" }) -join ','
        $badPlugins = (New-BasePlugins -Name 'process-bad' | ForEach-Object { "'$_'" }) -join ','

        & pwsh -NoProfile -Command "& '$script:DriftScript' -RepoRoot '$good' -PluginRoot $goodPlugins; exit `$LASTEXITCODE" *> $null
        $LASTEXITCODE | Should -Be 0

        $output = & pwsh -NoProfile -Command "& '$script:DriftScript' -RepoRoot '$bad' -PluginRoot $badPlugins; exit `$LASTEXITCODE" 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'mattpocock-skills:gone'
    }
}

Describe 'Base plugin drift issue lifecycle' -Tag 'Unit' {
    BeforeAll {
        $script:IssueTitle = '[Drift] Base plugin skill references'

        function New-GhRecorder {
            param([object[]]$Issues = @())

            $calls = [System.Collections.Generic.List[object]]::new()
            $handler = {
                param([string[]]$Arguments)
                $calls.Add([string[]]$Arguments)
                if ($Arguments[0] -eq 'issue' -and $Arguments[1] -eq 'list') {
                    return @($Issues) | ConvertTo-Json -Compress -AsArray
                }
                ''
            }.GetNewClosure()

            [pscustomobject]@{ Calls = $calls; Handler = $handler }
        }

        function Invoke-IssueUpdate {
            param($Recorder, [string]$Conclusion, [string]$Failure)
            & $script:IssueScript `
                -Conclusion $Conclusion `
                -Failure $Failure `
                -WorkflowUrl 'https://github.example/runs/7' `
                -Repository 'owner/repo' `
                -GhCommand $Recorder.Handler
            @($Recorder.Calls | ForEach-Object { $_ -join ' ' })
        }
    }

    It 'opens one issue naming the unresolved reference and the run' {
        $recorder = New-GhRecorder

        $calls = Invoke-IssueUpdate $recorder Failure 'FAIL: skills/al-x/SKILL.md:3 - mattpocock-skills:gone'

        $create = @($recorder.Calls | Where-Object { $_[0] -eq 'issue' -and $_[1] -eq 'create' })
        $create | Should -HaveCount 1
        $create[0][[array]::IndexOf($create[0], '--title') + 1] | Should -Be $script:IssueTitle
        $body = $create[0][[array]::IndexOf($create[0], '--body') + 1]
        $body | Should -Match 'mattpocock-skills:gone'
        $body | Should -Match 'https://github\.example/runs/7'
        @($calls | Where-Object { $_ -match '^issue (close|comment) ' }) | Should -HaveCount 0
    }

    It 'comments on the open issue and closes duplicates instead of opening another' {
        $recorder = New-GhRecorder -Issues @(
            [pscustomobject]@{ number = 4; title = $script:IssueTitle; state = 'OPEN' }
            [pscustomobject]@{ number = 9; title = $script:IssueTitle; state = 'OPEN' }
            [pscustomobject]@{ number = 11; title = 'Unrelated'; state = 'OPEN' }
        )

        $calls = Invoke-IssueUpdate $recorder Failure 'FAIL: bcquality could not be fetched'

        @($calls | Where-Object { $_ -match '^issue comment 4 ' -and $_ -match 'could not be fetched' }) | Should -HaveCount 1
        $calls | Should -Contain 'issue close 9 --repo owner/repo --reason not planned'
        @($calls | Where-Object { $_ -match '^issue create ' -or $_ -match '^issue close 11 ' }) | Should -HaveCount 0
    }

    It 'reopens the closed issue when drift returns' {
        $recorder = New-GhRecorder -Issues @(
            [pscustomobject]@{ number = 4; title = $script:IssueTitle; state = 'CLOSED' }
        )

        $calls = Invoke-IssueUpdate $recorder Failure 'FAIL: again'

        $calls | Should -Contain 'issue reopen 4 --repo owner/repo'
        @($calls | Where-Object { $_ -match '^issue comment 4 ' }) | Should -HaveCount 1
        @($calls | Where-Object { $_ -match '^issue create ' }) | Should -HaveCount 0
    }

    It 'closes the open issue after a green run' {
        $recorder = New-GhRecorder -Issues @(
            [pscustomobject]@{ number = 4; title = $script:IssueTitle; state = 'OPEN' }
        )

        $calls = Invoke-IssueUpdate $recorder Success ''

        @($calls | Where-Object { $_ -match '^issue comment 4 ' }) | Should -HaveCount 1
        $calls | Should -Contain 'issue close 4 --repo owner/repo --reason completed'
    }

    It 'does nothing after a green run with no open issue' {
        $recorder = New-GhRecorder -Issues @(
            [pscustomobject]@{ number = 4; title = $script:IssueTitle; state = 'CLOSED' }
        )

        $calls = Invoke-IssueUpdate $recorder Success ''

        @($calls | Where-Object { $_ -notmatch '^issue list ' }) | Should -HaveCount 0
    }
}

Describe 'Base plugin drift workflows' -Tag 'Unit' {
    It 'runs daily and on demand with issue access, outside pull-request CI' {
        $workflow = Get-Content -LiteralPath $script:WorkflowPath -Raw

        $workflow | Should -Match "cron:\s*'[^']+ \* \* \*'"
        $workflow | Should -Match 'workflow_dispatch:'
        $workflow | Should -Match 'issues:\s*write'
        $workflow | Should -Not -Match 'pull_request'
        $workflow | Should -Match 'Test-BasePluginDrift\.ps1'
        $workflow | Should -Match 'continue-on-error:\s*true'
        $workflow | Should -Match 'Update-BasePluginDriftIssue\.ps1'
    }

    It 'runs the drift check as a CI step on every pull request' {
        $ci = Get-Content -LiteralPath $script:CiPath -Raw

        $ci | Should -Match 'pull_request:'
        $ci | Should -Match '\./scripts/Test-BasePluginDrift\.ps1'
    }
}
