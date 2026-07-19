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

    It 'permits only al-build as the red-green nested skill for the required gate' {
        $script:RedGreen | Should -Match ([regex]::Escape('Never invoke `/al-research`, any other skill, or any agent; invoke only `/al-build` for the required RED/GREEN gate.'))
        $script:RedGreen | Should -Match ([regex]::Escape('For every build — confirming RED, confirming GREEN — invoke `/al-build`:'))
    }

    It 'limits --fix writes to scoped code or test edits and preserved planning-artifact exceptions' {
        $script:CodeReview | Should -Match ([regex]::Escape('This skill writes no durable planning artifacts except clean-gate state and, under `--fix`, reconciled originating tasks.'))
        $script:CodeReview | Should -Match ([regex]::Escape('Under `--fix`, it may make only the scoped code/test edits required by eligible fix-queue findings and their required fix commits;'))
        $script:CodeReview | Should -Match ([regex]::Escape('never `architecture.md`, `event-model.md`, ADRs, `CONTEXT.md`, or `.out-of-scope/`.'))
    }
}
