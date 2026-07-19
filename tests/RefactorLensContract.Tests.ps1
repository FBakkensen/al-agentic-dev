#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $agentsPath = Join-Path $repoRoot 'plugins\al-agentic-dev\agents'
    $script:BcAgent = Get-Content -LiteralPath (Join-Path $agentsPath 'al-review-refactor-bc.agent.md') -Raw
    $script:NamingAgent = Get-Content -LiteralPath (Join-Path $agentsPath 'al-review-refactor-naming.agent.md') -Raw
    $script:PerfAgent = Get-Content -LiteralPath (Join-Path $agentsPath 'al-review-refactor-perf.agent.md') -Raw
    $script:SimplifyAgent = Get-Content -LiteralPath (Join-Path $agentsPath 'al-review-refactor-simplify.agent.md') -Raw
    $script:StructuralAgent = Get-Content -LiteralPath (Join-Path $agentsPath 'al-review-refactor-structural.agent.md') -Raw
}

Describe 'Refactor lens Return sentinel contract' {
    It 'declares the BC lens sentinel' {
        $script:BcAgent | Should -Match 'Line 1: `BC RESHAPE FINDINGS`'
    }

    It 'declares the naming lens sentinel' {
        $script:NamingAgent | Should -Match 'Line 1: `NAMING RESHAPE FINDINGS`'
    }

    It 'declares the performance lens sentinel' {
        $script:PerfAgent | Should -Match 'Line 1: `PERFORMANCE RESHAPE FINDINGS`'
    }

    It 'declares the simplify lens sentinel' {
        $script:SimplifyAgent | Should -Match 'Line 1: `SIMPLIFY RESHAPE FINDINGS`'
    }

    It 'declares the structural lens sentinel' {
        $script:StructuralAgent | Should -Match 'Line 1: `STRUCTURAL RESHAPE FINDINGS`'
    }

    It 'gives every reshape lens a Boundary section restricting it to identification only' {
        foreach ($agent in @($script:BcAgent, $script:NamingAgent, $script:PerfAgent, $script:SimplifyAgent, $script:StructuralAgent)) {
            $agent | Should -Match 'Identify only\. Never edit, write, or apply a fix'
        }
    }
}

Describe 'Performance lens unavailable-MCP skip exception contract' {
    It 'names the skip line as the sole exception to the sentinel in Boundary' {
        $script:PerfAgent | Should -Match 'return exactly one line, `perf scan skipped: al-performance MCP not available`, in place of the `Line 1: PERFORMANCE RESHAPE FINDINGS` sentinel'
        $script:PerfAgent | Should -Match 'the sole exception to it'
    }

    It 'names the same exception in Return, never requiring both the sentinel and the skip line' {
        $script:PerfAgent | Should -Match 'Its one exception is the Boundary'
        $script:PerfAgent | Should -Match 'unavailable-MCP skip: return exactly the one line'
        $script:PerfAgent | Should -Match 'never this sentinel and never any other line'
    }

    It 'preserves the exact one-line skip text verbatim, once in Boundary and once in Return' {
        $skipLine = 'perf scan skipped: al-performance MCP not available'
        $matches = [regex]::Matches($script:PerfAgent, [regex]::Escape($skipLine))
        $matches.Count | Should -Be 2
    }

    It 'never presents the sentinel and the skip line as a simultaneous, additive requirement' {
        $script:PerfAgent | Should -Not -Match 'Line 1: `PERFORMANCE RESHAPE FINDINGS`\s*\r?\n\s*perf scan skipped'
    }
}

Describe 'Voice-contract Return-canon alignment (performance skip exception)' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $script:VoiceContract = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\references\voice-contract.md') -Raw
    }

    It 'documents the exact perf-agent skip payload as a Return-contract exception' {
        $skipLine = 'perf scan skipped: al-performance MCP not available'
        $script:VoiceContract | Should -Match ([regex]::Escape($skipLine))
    }

    It 'names al-review-refactor-perf as the owner of that exception, in the same bullet as the skip line' {
        $bulletMatch = [regex]::Match($script:VoiceContract, '- \*\*Bounded lede/purpose\.\*\*.*?(?=\r?\n- \*\*|\r?\n\r?\n)', 'Singleline')
        $bulletMatch.Success | Should -BeTrue
        $bulletMatch.Value | Should -Match 'al-review-refactor-perf'
        $bulletMatch.Value | Should -Match ([regex]::Escape('perf scan skipped: al-performance MCP not available'))
    }

    It 'keeps the skip payload byte-identical between the agent file and the voice-contract exception' {
        $skipLine = 'perf scan skipped: al-performance MCP not available'
        $agentHits = [regex]::Matches($script:PerfAgent, [regex]::Escape($skipLine))
        $voiceHits = [regex]::Matches($script:VoiceContract, [regex]::Escape($skipLine))
        $agentHits.Count | Should -Be 2
        $voiceHits.Count | Should -BeGreaterOrEqual 1
    }
}
