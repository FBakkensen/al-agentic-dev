#Requires -Version 7.2

BeforeAll {
    $script:PluginRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'plugins\al-agentic-dev'
    $script:GroundRulesPath = Join-Path $script:PluginRoot 'references\GROUND-RULES.md'
    $script:SkillsRoot = Join-Path $script:PluginRoot 'skills'
}

Describe 'Ground Rules ownership' {
    It 'homes chat and production AL thrift' {
        $content = Get-Content -LiteralPath $script:GroundRulesPath -Raw

        $content | Should -Match '(?m)^## Chat thrift\r?$'
        $content | Should -Match 'Lead with the verdict on line 1'
        $content | Should -Match 'Emit tool results, never tool-call narration'
        $content | Should -Match '(?m)^## Production-AL thrift\r?$'
        $content | Should -Match 'No abstraction for one caller'
        $content | Should -Match 'Name the ceiling'
    }

    It 'homes gate execution ownership' {
        $content = Get-Content -LiteralPath $script:GroundRulesPath -Raw

        $content | Should -Match '(?m)^## Gates\r?$'
        $content | Should -Match 'Gate execution belongs to the isolated `al-gate-runner`'
        $content | Should -Match 'delegates it through `/al-build`'
        $content | Should -Match '`/al-provision` and `/al-validate-breaking-changes`'
    }

    It 'is the compaction recovery read for every skill' {
        $expected = 'Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.'
        $skillFiles = Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'skills') -Recurse -File -Filter 'SKILL.md'

        foreach ($skillFile in $skillFiles) {
            Get-Content -LiteralPath $skillFile.FullName -Raw | Should -Match ([regex]::Escape($expected)) -Because $skillFile.Directory.Name
        }
    }

    It 'injects the same file at session start' {
        $hooks = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'hooks\hooks.json') -Raw
        $hooks | Should -Match 'GROUND-RULES\.md'
    }
}

Describe 'Gate delegation' {
    BeforeAll {
        $script:AlBuildSkillPath = Join-Path $script:SkillsRoot 'al-build\SKILL.md'
        $script:GateCallerFiles = @(
            Get-ChildItem -LiteralPath $script:SkillsRoot -Recurse -File -Filter 'SKILL.md'
            Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'agents') -File -Filter '*.agent.md'
        )
    }

    It 'keeps every caller on a delegation verb' {
        # An execution verb in front of /al-build reads as "run this command yourself"
        # and is what let a caller bypass al-gate-runner. Invoking the skill is the
        # correct move, and reverse-order prose such as "the host's own /al-build run"
        # stays legal.
        $executionVerb = '(?im)\b(?:run|re-?run|execute)\s+(?:the\s+)?(?:full\s+)?`?/al-build`?'

        foreach ($callerFile in $script:GateCallerFiles) {
            $content = Get-Content -LiteralPath $callerFile.FullName -Raw
            $content | Should -Not -Match $executionVerb -Because $callerFile.Name
        }
    }

    It 'pins the delegation verb at every caller site' {
        $callers = @{
            'al-code-review' = 2
            'al-implement'   = 1
            'al-mutate'      = 1
            'al-refactor'    = 2
            'al-sync-main'   = 2
        }

        foreach ($caller in $callers.GetEnumerator()) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot "$($caller.Key)\SKILL.md") -Raw
            $hits = @([regex]::Matches($content, '(?i)Delegate the (?:full )?(?:gate through )?`?/al-build`?'))
            $hits.Count | Should -BeGreaterOrEqual $caller.Value -Because $caller.Key
        }
    }

    It 'names the runner before the gate command in al-build' {
        $content = Get-Content -LiteralPath $script:AlBuildSkillPath -Raw
        $bodyStart = $content.IndexOf('---', 3) + 3

        $runnerIndex = $content.IndexOf('al-gate-runner', $bodyStart)
        $commandIndex = $content.IndexOf('pwsh "<skill-folder>/scripts/test.ps1"', $bodyStart)

        $runnerIndex | Should -BeGreaterThan -1
        $commandIndex | Should -BeGreaterThan -1
        $runnerIndex | Should -BeLessThan $commandIndex
    }

    It 'pre-approves the agent tool on al-build' {
        $content = Get-Content -LiteralPath $script:AlBuildSkillPath -Raw
        $match = [regex]::Match($content, '(?m)^allowed-tools:\s*(\[.+\])\s*$')

        $match.Success | Should -BeTrue
        @($match.Groups[1].Value | ConvertFrom-Json) | Should -Contain 'agent'
    }

    It 'keeps the gate script out of every other caller' {
        $offenders = @($script:GateCallerFiles |
                Where-Object { $_.Directory.Name -ne 'al-build' } |
                Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'scripts/test\.ps1' } |
                ForEach-Object { $_.Name })

        $offenders | Should -BeNullOrEmpty
    }

    It 'keeps /al-build out of the user-invocable command list' {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $manifest = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'plugin.json') -Raw | ConvertFrom-Json
        $marketplace = Get-Content -LiteralPath (Join-Path $repoRoot '.github\plugin\marketplace.json') -Raw | ConvertFrom-Json
        $entry = $marketplace.plugins | Where-Object name -eq 'al-agentic-dev'

        $manifest.description | Should -Not -Match 'Build/test: /al-build'
        $manifest.description | Should -Match 'the /al-build gate skill other skills invoke'
        $entry.description | Should -BeExactly $manifest.description
    }
}
