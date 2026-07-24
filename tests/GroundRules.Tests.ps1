#Requires -Version 7.2

BeforeAll {
    $script:PluginRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'plugins\al-agentic-dev'
    $script:GroundRulesPath = Join-Path $script:PluginRoot 'references\GROUND-RULES.md'
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
