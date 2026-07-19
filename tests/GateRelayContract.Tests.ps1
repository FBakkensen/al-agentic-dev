#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:GateRunnerAgent = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\agents\al-gate-runner.agent.md') -Raw
    $script:MutantCycleAgent = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\al-agentic-dev\agents\al-mutant-cycle.agent.md') -Raw

    function Get-OutputExcerptPatterns {
        param([string]$AgentText)

        $realFailure = [regex]::Match($AgentText, 'real failure signal, matching `(?<p>.+?)`\.')
        $zeroSummary = [regex]::Match($AgentText, 'zero-count fragment matching `(?<p>.+?)` \(e\.g\.')
        if (-not $realFailure.Success -or -not $zeroSummary.Success) {
            throw 'Could not extract the output excerpt selection regex from the agent file.'
        }
        [pscustomobject]@{
            RealFailure = $realFailure.Groups['p'].Value
            ZeroSummary = $zeroSummary.Groups['p'].Value
        }
    }

    function Select-FirstFailureLine {
        # Mirrors the agent contract's strip-then-test algorithm: remove any zero-count
        # fragment first, then test the remainder against the real-failure pattern. A pure
        # zero-count summary strips to nothing left to match; a mixed line (a nonzero count
        # alongside a zero-count fragment) keeps its nonzero portion and still qualifies.
        param([string[]]$Lines, [string]$RealFailurePattern, [string]$ZeroSummaryPattern)

        foreach ($line in $Lines) {
            $stripped = [regex]::Replace($line, $ZeroSummaryPattern, ' ')
            if ($stripped -match $RealFailurePattern) {
                return $line
            }
        }
        return $null
    }

    function Get-AppendedTimingLines {
        # Mirrors al-mutant-cycle.agent.md's snapshot contract: a line counted in the
        # pre-execution snapshot is never relayed; only lines appended beyond it are.
        param([string[]]$PreSnapshotLines, [string[]]$PostExecutionLines)

        $snapshotCount = $PreSnapshotLines.Count
        if ($PostExecutionLines.Count -le $snapshotCount) {
            return @()
        }
        return @($PostExecutionLines[$snapshotCount..($PostExecutionLines.Count - 1)])
    }
}

Describe 'Output excerpt selection contract (al-gate-runner, al-mutant-cycle)' {

    It 'defines a real-failure regex and a zero-summary exclusion regex in al-gate-runner.agent.md' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:GateRunnerAgent
        $patterns.RealFailure | Should -Not -BeNullOrEmpty
        $patterns.ZeroSummary | Should -Match ([regex]::Escape('0\s+'))
    }

    It 'defines a real-failure regex and a zero-summary exclusion regex in al-mutant-cycle.agent.md' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:MutantCycleAgent
        $patterns.RealFailure | Should -Not -BeNullOrEmpty
        $patterns.ZeroSummary | Should -Match ([regex]::Escape('0\s+'))
    }

    It 'selects a later real error instead of an earlier zero-failed summary (al-gate-runner)' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:GateRunnerAgent
        $lines = @(
            'Publishing app to sandbox...',
            'Tests: 12 passed, 0 failed',
            'Compiling AL project...',
            'error AL0305: The dependency App1 could not be resolved',
            'Build stopped.'
        )
        $selected = Select-FirstFailureLine -Lines $lines -RealFailurePattern $patterns.RealFailure -ZeroSummaryPattern $patterns.ZeroSummary
        $selected | Should -Be 'error AL0305: The dependency App1 could not be resolved'
    }

    It 'selects a later real error instead of an earlier zero-failed summary (al-mutant-cycle)' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:MutantCycleAgent
        $lines = @(
            'Running test suite...',
            'Failed: 0, Passed: 42',
            'Container gate-container-01 reported container failed during publish',
            'Test run complete.'
        )
        $selected = Select-FirstFailureLine -Lines $lines -RealFailurePattern $patterns.RealFailure -ZeroSummaryPattern $patterns.ZeroSummary
        $selected | Should -Be 'Container gate-container-01 reported container failed during publish'
    }

    It 'treats common zero-failure summaries as non-matches on their own' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:GateRunnerAgent
        foreach ($zeroLine in @('0 failed', 'Tests: 12 passed, 0 failed', 'Failed: 0', 'Errors: 0')) {
            $selected = Select-FirstFailureLine -Lines @($zeroLine) -RealFailurePattern $patterns.RealFailure -ZeroSummaryPattern $patterns.ZeroSummary
            $selected | Should -BeNullOrEmpty -Because "'$zeroLine' is a zero-count summary, not a failure"
        }
    }

    It 'selects a mixed line carrying both a zero-count fragment and a nonzero failure/error count (al-gate-runner)' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:GateRunnerAgent
        foreach ($mixedLine in @('40 passed, 0 failed, 2 errors', 'Tests: 40 passed, 0 failed, Errors: 3')) {
            $selected = Select-FirstFailureLine -Lines @($mixedLine) -RealFailurePattern $patterns.RealFailure -ZeroSummaryPattern $patterns.ZeroSummary
            $selected | Should -Be $mixedLine -Because "'$mixedLine' carries a nonzero failure/error signal alongside the zero-count fragment"
        }
    }

    It 'selects a mixed line carrying both a zero-count fragment and a nonzero failure/error count (al-mutant-cycle)' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:MutantCycleAgent
        $mixedLine = '40 passed, 0 failed, 2 errors'
        $selected = Select-FirstFailureLine -Lines @($mixedLine) -RealFailurePattern $patterns.RealFailure -ZeroSummaryPattern $patterns.ZeroSummary
        $selected | Should -Be $mixedLine -Because "'$mixedLine' carries a nonzero failure/error signal alongside the zero-count fragment"
    }

    It 'selects the mixed-summary line over an earlier unrelated line and before a later real error (al-gate-runner)' {
        $patterns = Get-OutputExcerptPatterns -AgentText $script:GateRunnerAgent
        $lines = @(
            'Publishing app to sandbox...',
            'Tests: 40 passed, 0 failed, 2 errors',
            'error AL0305: The dependency App1 could not be resolved'
        )
        $selected = Select-FirstFailureLine -Lines $lines -RealFailurePattern $patterns.RealFailure -ZeroSummaryPattern $patterns.ZeroSummary
        $selected | Should -Be 'Tests: 40 passed, 0 failed, 2 errors'
    }
}

Describe 'Mutation gate timing snapshot contract (al-mutant-cycle)' {

    It 'documents a pre-execution snapshot of the timing log' {
        $script:MutantCycleAgent | Should -Match 'Before running the gate command, snapshot `\.output/logs/build-timing\.jsonl`'
        $script:MutantCycleAgent | Should -Match 'record whether the file exists and, when it does, its current byte length \(or line count\)'
    }

    It 'documents relaying only a line appended beyond the snapshot, never a pre-existing one' {
        $script:MutantCycleAgent | Should -Match 'identify only a line appended beyond it'
        $script:MutantCycleAgent | Should -Match 'never a pre-existing one'
        $script:MutantCycleAgent | Should -Match 'beyond the pre-execution snapshot, verbatim — never a line that already existed at snapshot time'
        $script:MutantCycleAgent | Should -Match 'Name it `missing` when no line was appended beyond the snapshot'
    }

    It 'never relays a pre-existing timing line when no new line is appended after execution' {
        $preSnapshot = @('{"outcome":"success","steps":"compile,publish,test","tests":"42 passed"}')
        $postExecution = $preSnapshot  # gate ran but appended nothing new
        $appended = @(Get-AppendedTimingLines -PreSnapshotLines $preSnapshot -PostExecutionLines $postExecution)
        $appended.Count | Should -Be 0
        $appended | Should -Not -Contain $preSnapshot[0]
    }

    It 'relays only the newly appended timing line when one exists beyond the snapshot' {
        $preSnapshot = @('{"outcome":"success","steps":"compile,publish,test","tests":"42 passed"}')
        $newLine = '{"outcome":"failed","steps":"compile","tests":"n/a"}'
        $postExecution = $preSnapshot + $newLine
        $appended = @(Get-AppendedTimingLines -PreSnapshotLines $preSnapshot -PostExecutionLines $postExecution)
        $appended.Count | Should -Be 1
        $appended[0] | Should -Be $newLine
    }
}
