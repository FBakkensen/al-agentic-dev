#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:ReviewJudge = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\agents\al-review-judge.agent.md') -Raw
}

Describe 'Review judge model-role canonical alignment' {
    BeforeAll {
        $script:PluginAgentsMd = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\AGENTS.md') -Raw
        $script:Delegation = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\references\delegation.md') -Raw
        $script:JudgeModel = ([regex]::Match($script:ReviewJudge, '(?m)^model:\s*(\S+)')).Groups[1].Value
    }

    It 'pins al-review-judge to the Fable smart-role model in its own frontmatter' {
        $script:JudgeModel | Should -Be 'claude-fable-5'
    }

    It 'describes al-review-judge as smart (Fable) in the plugin AGENTS.md layout comment, never arbiter (Sol)' {
        $script:PluginAgentsMd | Should -Match 'al-review-judge\.agent\.md[^\r\n]*smart \(Fable\)'
        $script:PluginAgentsMd | Should -Not -Match 'al-review-judge\.agent\.md[^\r\n]*arbiter \(Sol\)'
    }

    It 'lists al-review-judge as smart, fixed in delegation.md''s Where-each-worker-lands table, never arbiter' {
        $script:Delegation | Should -Match '\| `al-review-judge` custom agent[^\r\n]*\|\s*smart, fixed'
        $script:Delegation | Should -Not -Match '\| `al-review-judge` custom agent[^\r\n]*\|\s*arbiter, fixed'
    }
}

Describe 'Review judge performance severity contract' {
    It 'defaults substantiated HIGH code-review performance findings to MUST-FIX' {
        $script:ReviewJudge | Should -Match 'a substantiated `HIGH`-severity scanner finding from `al-review-cr-perf` defaults to `MUST-FIX`'
        $script:ReviewJudge | Should -Match 'normal scoped-evidence test still applies'
    }

    It 'does not carry the code-review performance default into refactor findings' {
        $script:ReviewJudge | Should -Match 'al-review-cr-perf` `HIGH`-severity default above apply only'
        $script:ReviewJudge | Should -Match 'or because `al-review-refactor-perf` reports `HIGH`'
    }
}
