#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:PluginRoot = Join-Path $script:RepoRoot 'plugins\al-agentic-dev'
    $script:AgentsRoot = Join-Path $script:PluginRoot 'agents'
    $script:SkillsRoot = Join-Path $script:PluginRoot 'skills'

    $script:ReviewRedPath = Join-Path $script:AgentsRoot 'al-review-red.agent.md'
    $script:RedGreenPath = Join-Path $script:AgentsRoot 'al-red-green.agent.md'
    $script:TddPath = Join-Path $script:PluginRoot 'references\testing\tdd.md'
    $script:OverviewPath = Join-Path $script:PluginRoot 'references\overview.md'
    $script:LensReferencePath = Join-Path $script:PluginRoot 'references\review-lenses.md'

    $script:TrueRed = 'TRUE-RED'
    $script:FalseRed = 'FALSE-RED'
    $script:InvocationErrorLine = 'RED REVIEW INVOCATION ERROR: incomplete evidence'
}

Describe 'al-review-red return contract' {
    BeforeAll {
        $script:ReviewRedBody = Get-Content -LiteralPath $script:ReviewRedPath -Raw
    }

    It 'ships as a custom agent file' {
        Test-Path -LiteralPath $script:ReviewRedPath | Should -BeTrue
    }

    It 'carries both verdict words' {
        $script:ReviewRedBody | Should -Match ([regex]::Escape($script:TrueRed))
        $script:ReviewRedBody | Should -Match ([regex]::Escape($script:FalseRed))
    }

    It 'fails closed on incomplete evidence rather than on a verdict' {
        $script:ReviewRedBody | Should -Match ([regex]::Escape($script:InvocationErrorLine))
        $script:ReviewRedBody | Should -Match 'Never a verdict'
    }

    It 'reports every blocking reason rather than only the first' {
        $script:ReviewRedBody | Should -Match 'independently blocking reason'
    }

    It 'rules only, never edits' {
        $frontmatter = [regex]::Match($script:ReviewRedBody, '(?s)^---(.*?)---').Groups[1].Value
        $tools = @(([regex]::Match($frontmatter, '(?m)^tools:\s*(\[.+\])\s*$').Groups[1].Value | ConvertFrom-Json))

        $tools | Should -Not -Contain 'edit'
        $tools | Should -Not -Contain 'execute'
    }
}

Describe 'al-review-red is not a review lens' {
    It 'stays out of the lens reference entirely' {
        Get-Content -LiteralPath $script:LensReferencePath -Raw | Should -Not -Match 'al-review-red'
    }

    It 'takes no mode and carries no lens sentinel' {
        $body = Get-Content -LiteralPath $script:ReviewRedPath -Raw

        $body | Should -Not -Match 'LENS INVOCATION ERROR'
        $body | Should -Not -Match '(?m)^Mode:'
        $body | Should -Not -Match 'al-review-judge'
    }

    It 'is named as the family exception in the overview' {
        Get-Content -LiteralPath $script:OverviewPath -Raw | Should -Match '(?m)^\| `al-review-red` \|'
    }
}

Describe 'The blind RED gate inside al-red-green' {
    BeforeAll {
        $script:RedGreenBody = Get-Content -LiteralPath $script:RedGreenPath -Raw
    }

    It 'spawns the reviewer fresh at every red' {
        $script:RedGreenBody | Should -Match 'Spawn `al-review-red`.*fresh'
    }

    It 'accepts nothing but an exact TRUE-RED as a pass' {
        $script:RedGreenBody | Should -Match ([regex]::Escape($script:InvocationErrorLine))
        $script:RedGreenBody | Should -Match 'not exactly `TRUE-RED` or `FALSE-RED`'
    }

    It 'caps the beat at two review rounds' {
        $script:RedGreenBody | Should -Match 'Two review rounds per case, at most'
    }

    It 'takes the characterization declaration from the caller only' {
        $script:RedGreenBody | Should -Match 'characterization case only when the caller says so'
        Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement\SKILL.md') -Raw |
            Should -Match 'characterization case'
    }

    It 'keeps the gate off its own line-1 verdict' {
        $script:RedGreenBody | Should -Match 'never this agent''s line-1 verdict'
    }
}

Describe 'The GREEN test-surface freeze' {
    BeforeAll {
        $script:RedGreenBody = Get-Content -LiteralPath $script:RedGreenPath -Raw
    }

    It 'hashes the surface before the review, not after' {
        $script:RedGreenBody | Should -Match 'Get-FileHash'
        $script:RedGreenBody | Should -Match 'before the review, not after'
    }

    It 'covers both test apps rather than the one test file' {
        $script:RedGreenBody | Should -Match 'every `\.al` file in both test apps'
    }

    It 'blocks on a mismatch and names the suspects' {
        $script:RedGreenBody | Should -Match 'Recompute the manifest before accepting GREEN'
        $script:RedGreenBody | Should -Match 'three suspects'
    }

    It 'keeps the hash read inside the never-alter-git-state boundary' {
        $script:RedGreenBody | Should -Match 'Hashing file content reads only'
    }
}

Describe 'TDD reference carries both halves' {
    BeforeAll {
        $script:TddBody = Get-Content -LiteralPath $script:TddPath -Raw
    }

    It 'puts the blind verdict in the Red phase exit criterion' {
        $script:TddBody | Should -Match '\| \*\*Red\*\* \|.*`TRUE-RED`'
    }

    It 'states the asymmetry rather than a flat freeze' {
        $script:TddBody | Should -Match '(?m)^## The two halves are frozen differently\r?$'
        $script:TddBody | Should -Match 'A flat freeze over both halves would contradict compile-fix-first'
    }

    It 'sits the verdict pair beside the existing false-pass vocabulary' {
        $script:TddBody | Should -Match '`TRUE-RED` / `FALSE-RED`'
        $script:TddBody | Should -Match 'false-pass'
    }
}

Describe 'Both spawning skills route the new blocks' {
    It 'names the missing agent as a block in al-implement' {
        $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement\SKILL.md') -Raw

        $body | Should -Match '`al-red-green` or `al-review-red` unavailable'
        $body | Should -Match 'two `FALSE-RED` rounds, or on the frozen test surface'
        $body | Should -Match 'Next: /al-refine T-NNN'
    }

    It 'escalates both blocks from al-code-review rework' {
        $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-code-review\SKILL.md') -Raw

        $body | Should -Match 'graded blind by `al-review-red`'
        $body | Should -Match 'escalates to `/al-steer`'
    }
}
