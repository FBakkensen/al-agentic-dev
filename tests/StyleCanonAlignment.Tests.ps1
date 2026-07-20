#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $agentsPath = Join-Path $repoRoot 'plugins\al-agentic-dev\agents'
    $script:PluginAgentsMd = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\AGENTS.md') -Raw
    $script:VoiceContract = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\references\voice-contract.md') -Raw

    $script:CanonicalFive = @{
        'al-design-option' = @{
            File      = Get-Content -LiteralPath (Join-Path $agentsPath 'al-design-option.agent.md') -Raw
            StyleLine = 'Concise — cut filler, keep grammar. Opinionated — make one coherent candidate. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.'
            Model     = 'claude-fable-5'
        }
        'al-gate-runner' = @{
            File      = Get-Content -LiteralPath (Join-Path $agentsPath 'al-gate-runner.agent.md') -Raw
            StyleLine = 'Concise — cut filler, keep grammar. Exact — relay artifacts verbatim. Technical terms exact, commands and errors quoted verbatim.'
            Model     = 'gpt-5.6-luna'
        }
        'al-mutant-cycle' = @{
            File      = Get-Content -LiteralPath (Join-Path $agentsPath 'al-mutant-cycle.agent.md') -Raw
            StyleLine = 'Concise — cut filler, keep grammar. Exact — distinguish observation from judgment. Arrows (→) for the fixed cycle. Technical terms exact, code and errors quoted verbatim.'
            Model     = 'claude-sonnet-5'
        }
        'al-researcher' = @{
            File      = Get-Content -LiteralPath (Join-Path $agentsPath 'al-researcher.agent.md') -Raw
            StyleLine = 'Concise — cut filler, keep grammar. Exact — conclusions follow quoted evidence. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.'
            Model     = 'claude-opus-4.8'
        }
        'al-review-judge' = @{
            File      = Get-Content -LiteralPath (Join-Path $agentsPath 'al-review-judge.agent.md') -Raw
            StyleLine = 'Concise — cut filler, keep grammar. Opinionated — classify each finding. Arrows (→) for cause and effect. Technical terms exact, code and errors quoted verbatim.'
            Model     = 'claude-opus-4.8'
        }
    }

    # Kept for the earlier, narrower al-researcher-only assertions below.
    $script:ResearcherAgent = $script:CanonicalFive['al-researcher'].File
}

Describe 'No stale review-judge smart-role language anywhere in the plugin AGENTS.md' {
    It 'never pairs review-judge with the smart role, in any table cell or paragraph' {
        $script:PluginAgentsMd | Should -Not -Match '(?i)review-judge[^\r\n]{0,80}smart \(Fable\)'
        $script:PluginAgentsMd | Should -Not -Match '(?i)smart \(Fable\)[^\r\n]{0,80}review-judge'
    }
}

Describe 'Style canon derives from payload job, not model tier' {
    It 'states the job-based derivation rule in voice-contract.md, not a role-based one' {
        $script:VoiceContract | Should -Match 'derived from job not model tier'
        $script:VoiceContract | Should -Not -Match "follows the agent's role in ``references/delegation\.md``"
    }

    It 'names al-researcher in voice-contract.md as the frozen exemplar breaking a naive role-to-Style inference' {
        $script:VoiceContract | Should -Match 'Frozen exemplar proving the point'
        $script:VoiceContract | Should -Match 'al-researcher'
        $script:VoiceContract | Should -Match ([regex]::Escape('Exact — conclusions follow quoted evidence'))
    }

    It 'repeats the same job-based derivation and exemplar in the plugin AGENTS.md' {
        $script:PluginAgentsMd | Should -Match ([regex]::Escape('Style class tracks payload job, not `model:` role'))
        $script:PluginAgentsMd | Should -Match ([regex]::Escape('breaks a naive role→Style inference'))
        $script:PluginAgentsMd | Should -Match ([regex]::Escape('Exact — conclusions follow quoted evidence'))
    }
}

Describe 'Shared Style clauses are required concepts, not verbatim text' {
    It 'no longer claims the shared clauses must appear verbatim' {
        $script:VoiceContract | Should -Not -Match 'keeps the shared clauses verbatim'
    }

    It 'states the concepts-not-clauses rule, naming omission and artifact-native rewording as permitted' {
        $script:VoiceContract | Should -Match 'required intent, not verbatim clauses to copy'
        $script:VoiceContract | Should -Match 'omit the arrow clause entirely when the job is a single bounded relay with no causal shape to mark'
        $script:VoiceContract | Should -Match "worded to the agent's actual evidence domain"
    }
}

Describe 'Voice-contract documents every frozen Style-line variant and accepts each without edits' {
    It "lists every one of the five canonical agents' exact shipped Style lines" {
        foreach ($name in $script:CanonicalFive.Keys) {
            $script:VoiceContract | Should -Match ([regex]::Escape($script:CanonicalFive[$name].StyleLine))
        }
    }

    It 'names all five agents by filename alongside their Style-line rationale' {
        foreach ($name in $script:CanonicalFive.Keys) {
            $script:VoiceContract | Should -Match ([regex]::Escape($name))
        }
    }
}

Describe 'The corrected canon permits the frozen exemplars without touching any of the five canonical agents'' rubric surface' {
    It "leaves every one of the five canonical agents' frozen Style line exactly as PR #17 shipped it" {
        foreach ($name in $script:CanonicalFive.Keys) {
            $expected = "**Style:** $($script:CanonicalFive[$name].StyleLine)"
            $script:CanonicalFive[$name].File | Should -Match ([regex]::Escape($expected))
        }
    }

    It "pins every one of the five canonical agents' model frontmatter to the current approved fleet assignment" {
        foreach ($name in $script:CanonicalFive.Keys) {
            $expectedModel = [regex]::Escape($script:CanonicalFive[$name].Model)
            $script:CanonicalFive[$name].File | Should -Match "(?m)^model:\s*$expectedModel\s*`$"
        }
    }
}
