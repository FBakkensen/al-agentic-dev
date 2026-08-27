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

    It 'designs one coherent proof set and preserves existing proof while reshaping it' {
        $testDesign = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-test-design' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $refactor = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-refactor' 'SKILL.md') -Raw

        $testDesign | Should -Match 'search the repository for existing proof'
        $testDesign | Should -Match 'Current-to-final proof map'
        $testDesign | Should -Match 'keep`, `reshape`, `combine`, `split`, `replace`, or `add'
        $implement | Should -Match 'proof-preserving reshapes before new expectations or production changes'
        $implement | Should -Match 'require its current scope green'
        $implement | Should -Match 'rerun the same mode green'
        $implement | Should -Match 'Every new or materially reshaped automated proof earns a red'
        $implement | Should -Match 'inject one compiling fault'
        $refactor | Should -Match 'Compare the landed tests with the accepted proof map'
        $refactor | Should -Match 'require its current scope green'
        $refactor | Should -Match 'Every new or materially reshaped proof born green takes mutation as its red'
    }

    It 'keeps precedent map ownership with al-lookup' {
        $lookup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md') -Raw
        $mapContracts = @(Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse |
            Select-String -SimpleMatch 'docs/precedent-map.md' |
            Select-Object -ExpandProperty Path -Unique)

        $lookup | Should -Match 'Whether /al-lookup runs standalone or inside another skill'
        $lookup | Should -Match 'A map hit writes and commits nothing'
        $lookup | Should -Match 'A search with no sourced answer writes and commits nothing'
        $lookup | Should -Match 'a dirty path stops the run before the map changes'
        $lookup | Should -Match 'git commit --only -m "Record AL precedent" -- docs/precedent-map\.md'
        $lookup | Should -Match "remove this run's map change from both the index and working tree"
        $lookup | Should -Match 'never ownership of a dirty map change'
        $lookup | Should -Not -Match "developer's next commit"
        @($mapContracts).Count | Should -Be 1
        $mapContracts[0] | Should -Be (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md')
    }
}
