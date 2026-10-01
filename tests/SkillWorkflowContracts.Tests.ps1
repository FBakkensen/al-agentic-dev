#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:SkillsRoot = Join-Path $script:RepoRoot 'skills'
}

Describe 'Skill workflow contracts' {
    It 'reports evidence when no answer can be verified' {
        $lookup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md') -Raw
        $review = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-review' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $improve = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-improve-codebase-architecture' 'SKILL.md') -Raw

        $lookup | Should -Match 'name the unresolved question and each source searched'
        $lookup | Should -Match 'unresolved: <question> — searched: <source locations>'
        $lookup | Should -Match 'Hand the corresponding `verified:`, `assumed:`, or `unresolved:` ledger line'
        $implement | Should -Match '`verified:` / `assumed:` / `unresolved:` ledger entries'
        $improve | Should -Match '`verified:` / `assumed:` / `unresolved:` entries'
        $review | Should -Match 'receipt''s `verified:` / `assumed:` / `unresolved:` entries'
        $review | Should -Match 'Blocking before Non-Blocking'
        $review | Should -Match 'show the failing case or reproducible path when possible'
    }

    It 'keeps refactor evaluation with al-simplify and its entry skills' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $simplify = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-simplify' 'SKILL.md') -Raw

        $implement | Should -Match 'Name `/simplify` and `/mattpocock-skills:improve-codebase-architecture` as the next move'
        $implement | Should -Not -Match 'Tidy:'
        $simplify | Should -Match '`Tidy: none` or the exact cleanups'
    }

    It 'designs one coherent proof set and preserves existing proof while reshaping it' {
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $improve = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-improve-codebase-architecture' 'SKILL.md') -Raw
        $simplify = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-simplify' 'SKILL.md') -Raw

        $tdd | Should -Match 'search the repository for existing proof'
        $tdd | Should -Match 'Current-to-final proof map'
        $tdd | Should -Match 'keep`, `reshape`, `combine`, `split`, `replace`, or `add'
        $tdd | Should -Match 'Every new or materially reshaped automated proof earns a red'
        $tdd | Should -Match 'inject one compiling fault'
        $tdd | Should -Match 'proof-preserving reshapes before new expectations or production changes'
        $tdd | Should -Match 'rerun the gate green'
        $tdd | Should -Match 'A compile error or a failure before the assertion is not a red'
        $implement | Should -Match 'require its current scope green'
        $implement | Should -Match 'run /mattpocock-skills:tdd with al-tdd'
        $improve | Should -Match 'Read the diff, the receipt, and the `Current-to-final proof map`'
        $simplify | Should -Match 'require its current scope green'
        $simplify | Should -Match 'Every new or materially reshaped proof born green takes mutation as its red'
    }

    It 'serializes fault injection across parallel scenario workers' {
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw

        $tdd | Should -Match 'ends its turn with that proof''s fault site and test scope'
        $tdd | Should -Match 'only when its lead resumes it with the fault turn'
        $implement | Should -Match 'scenarios that name the same production site go to one worker'
        $implement | Should -Match 'fault turn from the lead through `SendMessage`, one worker at a time, the next only after that worker''s green returns'
        $implement | Should -Not -Match 'only when its lead resumes it'
        $tdd | Should -Not -Match 'one worker at a time'
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

    It 'pins the spec structure under the entry skill''s seven headings' {
        $toSpec = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-to-spec' 'SKILL.md') -Raw

        $headings = 'Problem Statement', 'Solution', 'User Stories', 'Implementation Decisions', 'Testing Decisions', 'Out of Scope', 'Further Notes'
        $toSpec | Should -Match ([regex]::Escape($headings -join ', '))
        $toSpec | Should -Match '`Process contract` \(Trigger, Success guarantee, Minimal guarantee\), then `Business process`, nest under Solution'
        $toSpec | Should -Match '`Building Block View` Level 1 nests here, and a `Runtime View` after it'
        $toSpec | Should -Match 'Description on a Feature or PBI, and in Repro Steps on a Bug'
        $toSpec | Should -Not -Match 'User Story'
    }

    It 'slices the Original work item into child PBIs and orders Acceptance Criteria for people before agents' {
        $toTickets = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-to-tickets' 'SKILL.md') -Raw
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw

        $toTickets | Should -Match '`Original` names a role in this workflow, not the top of the Azure DevOps hierarchy'
        $toTickets | Should -Match 'Every existing item stays where it is, including the Original''s own structural parent'
        $toTickets | Should -Match 'One slice creates no child'
        $toTickets | Should -Match 'Several slices each get one direct child PBI under the Original work item'
        $toTickets | Should -Match '`Behavior` precedes `Test specification` when both are present'
        $toTickets | Should -Match 'Either section may be omitted'
        $toTickets | Should -Match 'valid fenced Gherkin'
        $toTickets | Should -Not -Match 'User Story'
        $tdd | Should -Match 'Acceptance Criteria, after `## Behavior` when both are present'
    }

    It 'owns commits and pull requests in dedicated skills' {
        $commit = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-commit' 'SKILL.md') -Raw
        $pullRequest = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' 'SKILL.md') -Raw

        $commit | Should -Match 'Treat every file in the worktree as in scope'
        $commit | Should -Match 'Stage all files by default'
        $commit | Should -Match 'maximum number of independently valid commits'
        $commit | Should -Match 'List only the work-item IDs served by that commit'
        $commit | Should -MatchExactly 'Co-Authored-By: Claude <noreply@anthropic\.com>'

        $pullRequest | Should -Match 'Use `<area>: <imperative change>` for the title'
        $pullRequest | Should -Match 'List every work item represented by the branch'
        $pullRequest | Should -Match 'this skill runs no tests'
        $pullRequest | Should -Match 'Push unpublished commits'
        $pullRequest | Should -Match 'never creates or keeps a draft'
        $pullRequest | Should -Match 'Name /al-pr-shepherd as the next move'

        foreach ($skill in @('al-clone-bcapps', 'al-design', 'al-grill-with-docs', 'al-implement', 'al-lookup', 'al-pr-shepherd', 'al-improve-codebase-architecture', 'al-simplify')) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $content | Should -Match '/al-commit' -Because "$skill writes repository files"
        }
    }
}
