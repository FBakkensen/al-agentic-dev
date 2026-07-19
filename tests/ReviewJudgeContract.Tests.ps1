#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:ReviewJudge = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\agents\al-review-judge.agent.md') -Raw
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
