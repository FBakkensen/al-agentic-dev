#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:MutationSkill = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\skills\al-mutate\SKILL.md') -Raw
    $script:MutantCycleAgent = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\agents\al-mutant-cycle.agent.md') -Raw
}

Describe 'Mutation classification contract' {
    It 'makes the worker relay gate evidence without classifying it' {
        $script:MutantCycleAgent | Should -Match 'Return evidence only'
        $script:MutantCycleAgent | Should -Match 'Gate timing:'
        $script:MutantCycleAgent | Should -Match 'outcome`, `steps`, and `tests`'
        $script:MutantCycleAgent | Should -Match 'Output excerpt:'
        $script:MutantCycleAgent | Should -Match 'Do not invoke skills, custom agents, or other subagents'
        $script:MutantCycleAgent | Should -Match 'No classification, diagnosis, retry recommendation'
    }

    It 'relays only caller-marked mutation artifacts mechanically, without asserting freshness the gate does not guarantee' {
        $script:MutationSkill | Should -Match 'name the summary path: `.output/TestResults/summary.json`'
        $script:MutationSkill | Should -Match 'expand: resultFile where passed=false'
        $script:MutationSkill | Should -Match 'telemetryFile where passed=false.*only when the host will use telemetry for classification'
        $script:MutationSkill | Should -Match 'the worker never searches for, globs, or substitutes another file'
        $script:MutantCycleAgent | Should -Match 'Read the supplied `summary.json` only after that gate command'
        $script:MutantCycleAgent | Should -Match 'caller-marked literal field\(s\) and condition'
        $script:MutantCycleAgent | Should -Match 'Do not infer another field, condition, or artifact'
        $script:MutantCycleAgent | Should -Match 'mechanically `missing`'
    }

    It 'declares the mutation-cycle spawn in the composition table' {
        $script:MutationSkill | Should -Match '\| \*\*Spawns\*\*\s+\| `al-mutant-cycle` custom agent'
    }

    It 'requires mutation-tied compiler or parser evidence for a stillborn' {
        $script:MutationSkill | Should -Match 'Classify `invalid_stillborn` only when'
        $script:MutationSkill | Should -Match 'compiler/parser diagnostic that identifies the mutated file and line or construct'
        $script:MutationSkill | Should -Not -Match 'outcome:"error"` → `invalid_stillborn'
    }

    It 'routes non-compiler error outcomes through blocked infrastructure handling' {
        $script:MutationSkill | Should -Match 'publish, container, infrastructure, missing-artifact, or otherwise ambiguous `outcome:"error"` follows the infra recovery/blocked path'
        $script:MutationSkill | Should -Match 'blocked_infra_unknown'
        $script:MutationSkill | Should -Match 'never `invalid_stillborn`, never killed'
    }

    It 'never requests the timing log''s "newest" line — only the line appended beyond the pre-mutation snapshot' {
        $script:MutationSkill | Should -Not -Match 'verbatim newest `\.output/logs/build-timing\.jsonl` line'
        $script:MutationSkill | Should -Match 'only the `\.output/logs/build-timing\.jsonl` line appended beyond the pre-mutation snapshot'
        $script:MutationSkill | Should -Match 'never a pre-existing line, never simply the file''s newest line'
    }

    It 'requires the worker to snapshot the timing log before applying the mutant' {
        $script:MutationSkill | Should -Match 'before applying the mutant, snapshot `\.output/logs/build-timing\.jsonl`'
    }

    It 'requires the worker to verify HEAD exactly matches the host-provided baseline SHA before applying the mutant' {
        $script:MutationSkill | Should -Match 'git rev-parse HEAD` exactly equal to the host-provided baseline SHA'
        $script:MutationSkill | Should -Match 'Any mismatch — a dirty tree, or `HEAD` not exactly that baseline SHA — stops before applying the mutant'
    }
}
