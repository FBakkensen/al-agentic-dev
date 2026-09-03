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
        $implement | Should -Match 'rerun the gate green'
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
        $lookup | Should -Match 'A map hit writes nothing'
        $lookup | Should -Match 'A search with no sourced answer writes nothing'
        $lookup | Should -Match 'a dirty path stops the run before the map changes'
        $lookup | Should -Match 'ask /al-commit to commit the complete worktree'
        $lookup | Should -Match "remove only this run's row from the index and working tree"
        $lookup | Should -Match 'never ownership of a dirty map change'
        $lookup | Should -Not -Match "developer's next commit"
        @($mapContracts).Count | Should -Be 1
        $mapContracts[0] | Should -Be (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md')
    }

    It 'uses root User Stories and orders Acceptance Criteria for people before agents' {
        $scope = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-scope' 'SKILL.md') -Raw
        $testDesign = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-test-design' 'SKILL.md') -Raw
        $workItemSkills = @(
            'al-grill-adr',
            'al-event-model',
            'al-design',
            'al-scope',
            'al-test-design',
            'al-implement',
            'al-refactor',
            'al-review',
            'al-next',
            'al-orchestrate',
            'al-walkthrough'
        )

        $scope | Should -Match 'One user request creates one Original User Story'
        $scope | Should -Match 'not the top of the Azure DevOps hierarchy'
        $scope | Should -Match 'structural parents remain unchanged and out of scope'
        $scope | Should -Match 'Exactly one Vertical slice creates no child'
        $scope | Should -Match 'every slice gets one direct child User Story'
        $scope | Should -Match '`Problem`, `Expected outcome`, `Scope`, `Process contract`, `Business process`, `Runtime View`, `Building Block View`'
        $scope | Should -Match '`Behavior` precedes `Test specification` when both are present'
        $scope | Should -Match 'Either section may be omitted'
        $scope | Should -Match 'valid fenced Gherkin'
        $testDesign | Should -Match 'Acceptance Criteria, after `## Behavior` when both are present'

        foreach ($skill in $workItemSkills) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $content | Should -Not -Match '\bFeature\b' -Because "$skill must use the Original User Story contract"
        }
    }

    It 'owns commits and pull requests in dedicated skills' {
        $commit = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-commit' 'SKILL.md') -Raw
        $pullRequest = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' 'SKILL.md') -Raw

        $commit | Should -Match 'Treat every file in the worktree as in scope'
        $commit | Should -Match 'Stage all files by default'
        $commit | Should -Match 'maximum number of independently valid commits'
        $commit | Should -Match 'List only the work-item IDs served by that commit'
        $commit | Should -Match 'Co-authored-by: Copilot <223556219\+Copilot@users\.noreply\.github\.com>'

        $pullRequest | Should -Match 'Use `<area>: <imperative change>` for the title'
        $pullRequest | Should -Match 'List every work item represented by the branch'
        $pullRequest | Should -Match 'this skill runs no tests'
        $pullRequest | Should -Match 'Push unpublished commits'
        $pullRequest | Should -Match 'never creates or keeps a draft'
        $pullRequest | Should -Match 'Name /al-pr-shepherd as the next move'

        foreach ($skill in @('al-clone-bcapps', 'al-clone-bcquality', 'al-design', 'al-grill-adr', 'al-implement', 'al-lookup', 'al-pr-shepherd', 'al-refactor')) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $content | Should -Match '/al-commit' -Because "$skill writes repository files"
        }
    }
}
