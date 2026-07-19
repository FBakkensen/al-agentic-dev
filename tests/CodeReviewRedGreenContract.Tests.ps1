#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:CodeReview = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\skills\al-code-review\SKILL.md') -Raw
    $script:RedGreen = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\agents\al-red-green.agent.md') -Raw
}

Describe 'Code-review red-green contract' {
    It 'passes every required red-green input from a substantive --fix' {
        $script:CodeReview | Should -Match 'invoke `al-red-green` with the missing/adjusted AAA case \(Arrange/Act/Assert\), the originating task''s `New and Modified Objects` block, and task file path'
        $script:RedGreen | Should -Match 'one AAA case \(Arrange/Act/Assert text\), the task''s `New and Modified Objects` block, and the task file path'
    }

    It 'keeps the red-green outcome contract available to code-review fixes' {
        $script:RedGreen | Should -Match 'one of `GREEN`, `PUSH-UP`, `BLOCKED`'
        $script:CodeReview | Should -Match 'A substantive fix that cannot go green, or any needs-a-decision finding → escalate'
    }
}
