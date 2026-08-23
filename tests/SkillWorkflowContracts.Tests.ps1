#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:SkillsRoot = Join-Path $script:RepoRoot 'skills'
}

Describe 'Skill workflow contracts' {
    It 'keeps refactor evaluation with al-refactor' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $refactor = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-refactor' 'SKILL.md') -Raw
        $orchestrate = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-orchestrate' 'SKILL.md') -Raw

        $implement | Should -Match 'Name /al-refactor as the next move'
        $implement | Should -Not -Match 'Tidy:'
        $orchestrate | Should -Match 'Launch a fresh /al-refactor child stacked on the implementation branch'
        $orchestrate | Should -Not -Match 'Tidy: none'
        $refactor | Should -Match '`Tidy: none` or the exact reshapes'
    }
}
