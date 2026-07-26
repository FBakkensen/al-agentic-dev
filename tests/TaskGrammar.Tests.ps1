#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:PluginRoot = Join-Path $script:RepoRoot 'plugins\al-agentic-dev'
    $script:GrammarPath = Join-Path $script:PluginRoot 'references\task-grammar.md'
    $script:LifecyclePath = Join-Path $script:PluginRoot 'references\task-lifecycle.md'
    $script:IntegrityPath = Join-Path $script:PluginRoot 'references\doc-integrity.md'
    $script:GroundRulesPath = Join-Path $script:PluginRoot 'references\GROUND-RULES.md'
    $script:ExamplesPath = Join-Path $script:PluginRoot 'references\examples\tasks'
    $script:ParserPath = Join-Path $script:PluginRoot 'hooks\Test-TaskFileGrammar.ps1'

    function Invoke-GrammarCheck {
        param([string] $Target, [switch] $IncludeDone)
        $psArgs = @('-NoProfile', '-NoLogo', '-File', $script:ParserPath, '-Path', $Target)
        if ($IncludeDone) { $psArgs += '-IncludeDone' }
        $out = & pwsh @psArgs 2>&1
        return @{ Findings = @($out); ExitCode = $LASTEXITCODE }
    }

    # A body that satisfies every rule. Individual tests break exactly one thing.
    function New-TaskFile {
        param(
            [string] $Folder,
            [string] $Name = '010-T-001-valid.md',
            [string] $Kind = 'technical',
            [string] $Body
        )
        if (-not $Body) { $Body = $script:ValidTechnicalBody }
        $path = Join-Path $Folder $Name
        $text = @"
---
task: T-001
status: ready-for-implementation
slice: demo-slice
kind: $Kind
depends_on: []
---
# T-001 — Demo task

A one-line description of the demo task.

$Body
"@
        Set-Content -LiteralPath $path -Value $text -Encoding utf8
        return $path
    }

    $script:ValidTechnicalBody = @'
Test Specification:

## New and Modified Objects

- New: codeunit `Demo Policy`
  - `internal procedure IsBlocked(Customer: Record Customer): Boolean` — P

## Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Blocked Customer is rejected | RejectsBlockedCustomer |

## AAA Cases

### RejectsBlockedCustomer
Scope: Unit
Covers: B1
Arrange:
- Customer state is blocked.
Act:
- Evaluate the policy.
Assert:
- Policy returns blocked.
'@

    $script:ValidVerifyBody = @'
Verification Plan:

## Journey Examples

### V1 BlocksReleaseFromCard
Scope: E2E
Record: no
Role: Sales Processor
Action:
- Open the Sales Order for a blocked Customer.
Observable Checks:
- Blocked-customer error is visible.
'@
}

Describe 'task-grammar.md owns the shape' {
    It 'homes all ten shape rules' {
        $content = Get-Content -LiteralPath $script:GrammarPath -Raw

        $content | Should -Match '(?m)^## Shape rules\r?$'
        $content | Should -Match 'bare labeled line `Test Specification:` or `Verification Plan:`'
        $content | Should -Match 'holds entries another section or skill references by ID or by name'
        $content | Should -Match 'next column-0 line that is either a `## ` heading or a `<Label>:` line'
        $content | Should -Match 'Sections appear in the order'
        $content | Should -Match 'required, optional, or conditional is stated at that section'
        $content | Should -Match 'case header carries the handle other sections reference'
        $content | Should -Match 'No field restates its own header'
        $content | Should -Match '`Scope:` comes first'
        $content | Should -Match '`; ` separates multiple values'
        $content | Should -Match 'No inline comments'
    }

    It 'declares the section order and the table column contracts' {
        $content = Get-Content -LiteralPath $script:GrammarPath -Raw

        $content | Should -Match '(?m)^## Body sections\r?$'
        $content | Should -Match 'Columns are exactly `ID`, `Expected Behavior`, `Covered By`'
        $content | Should -Match 'First column `Case`, last column `Covered By`'
    }

    It 'covers both kinds from one rule set' {
        $content = Get-Content -LiteralPath $script:GrammarPath -Raw

        $content | Should -Match 'Both obey the same shape rules'
        $content | Should -Match '\| `Contract notes:` \| both \|'
        $content | Should -Match '\| `Closeout:` \| both \|'
    }
}

Describe 'no second home for the shape' {
    It 'task-lifecycle.md defers the body and keeps the shell' {
        $content = Get-Content -LiteralPath $script:LifecyclePath -Raw

        $content | Should -Not -Match "Shape per feature is the writing skill's call"
        $content | Should -Match 'task-grammar\.md'
        $content | Should -Match 'YAML frontmatter tops every per-task file'
    }

    It 'doc-integrity.md points at the grammar rather than restating it' {
        $content = Get-Content -LiteralPath $script:IntegrityPath -Raw

        $content | Should -Match 'departs from the shape rules in \[`task-grammar\.md`\]'
        $content | Should -Not -Match '(?m)^\d+\. A section is a `##` heading'
    }

    It 'GROUND-RULES.md routes every task-file write through the check' {
        $content = Get-Content -LiteralPath $script:GroundRulesPath -Raw

        $content | Should -Match 'A write to a per-task file under `tasks/` is followed by'
        $content | Should -Match 'a one-field `status:` flip as much as a regenerated body'
    }

    It 'retires Procedure: everywhere' {
        $offenders = Get-ChildItem -LiteralPath $script:PluginRoot -Recurse -File -Filter '*.md' |
            Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^Procedure: ' }

        $offenders | Should -BeNullOrEmpty -Because 'the AAA case header is the procedure name'
    }

    It 'retires the #### Partial-run record heading' {
        $offenders = Get-ChildItem -LiteralPath $script:PluginRoot -Recurse -File -Filter '*.md' |
            Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '#### Partial-run record' }

        $offenders | Should -BeNullOrEmpty
    }

    It 'leaves the content lenses judging content only' {
        $assertions = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'agents\al-review-assertions.agent.md') -Raw
        $coverage = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'agents\al-review-coverage.agent.md') -Raw

        $assertions | Should -Not -Match 'Assert` block absent altogether'
        $coverage | Should -Not -Match 'naming a procedure no `AAA Cases` entry defines'
        $coverage | Should -Match 'is the document-integrity check'
    }
}

Describe 'the shipped examples conform' {
    It 'reports no finding across every example task file' {
        $result = Invoke-GrammarCheck -Target $script:ExamplesPath -IncludeDone

        $result.Findings | Should -BeNullOrEmpty
        $result.ExitCode | Should -Be 0
    }

    It 'checks every example that carries a body' {
        $withBody = Get-ChildItem -LiteralPath $script:ExamplesPath -Filter '*.md' |
            Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^(Test Specification|Verification Plan):' }

        $withBody.Count | Should -BeGreaterThan 4 -Because 'a green run over zero files proves nothing'
    }
}

Describe 'the parser detects each departure' {
    BeforeEach {
        $script:Scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Scratch | Out-Null
    }

    It 'accepts the valid baseline' {
        New-TaskFile -Folder $script:Scratch | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).ExitCode | Should -Be 0
    }

    It 'catches a section at the wrong heading level' {
        $body = $script:ValidTechnicalBody -replace '## AAA Cases', '### AAA Cases'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-1'
    }

    It 'catches a heading section written as a labeled line' {
        $body = $script:ValidTechnicalBody -replace '## Expected Behaviors', 'Expected Behaviors:'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-2'
    }

    It 'accepts the New and Modified Objects: none labeled form' {
        $body = $script:ValidTechnicalBody -replace '(?s)## New and Modified Objects.*?(?=## Expected)', "New and Modified Objects: none`r`n`r`n"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).ExitCode | Should -Be 0
    }

    It 'catches sections out of the declared order' {
        $body = $script:ValidTechnicalBody -replace '(?s)(## New and Modified Objects.*?)(## Expected Behaviors)', '$2PLACEHOLDER$1'
        $body = $body -replace 'PLACEHOLDER', "`r`n"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-4'
    }

    It 'catches a missing required section' {
        $body = $script:ValidTechnicalBody -replace '(?s)## New and Modified Objects.*?(?=## Expected)', ''
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'New and Modified Objects'
    }

    It 'catches a verify-only section on a technical task' {
        $body = $script:ValidTechnicalBody + "`r`n`r`nPartial-run record:`r`n- V1 — pass`r`n"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'does not belong on a'
    }

    It 'catches an AAA case header that is not a procedure name' {
        $body = $script:ValidTechnicalBody -replace '### RejectsBlockedCustomer', '### B1 Rejects blocked customer'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-6'
    }

    It 'catches a Procedure: field restating its header' {
        $body = $script:ValidTechnicalBody -replace '(### RejectsBlockedCustomer)', "`$1`r`nProcedure: ``RejectsBlockedCustomer``"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-7'
    }

    It 'catches case fields out of order' {
        $body = $script:ValidTechnicalBody -replace "Scope: Unit`r?`nCovers: B1", "Covers: B1`r`nScope: Unit"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-8'
    }

    It 'catches a comma where the separator is a semicolon' {
        $body = $script:ValidTechnicalBody -replace 'Covers: B1', 'Covers: B1, B2'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-9'
    }

    It 'catches an inline comment' {
        $body = $script:ValidTechnicalBody -replace 'Scope: Unit', 'Scope: Unit  # the decision is pure'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-10'
    }

    It 'catches an absent Assert block' {
        $body = $script:ValidTechnicalBody -replace "(?s)Assert:.*", ''
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'has no `Assert`'
    }

    It 'catches an Assert block with no bullets' {
        $body = $script:ValidTechnicalBody -replace "(?s)Assert:.*", "Assert:`r`n"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'has no bullets'
    }

    It 'catches a coverage row naming a procedure no case defines' {
        $body = $script:ValidTechnicalBody -replace '\| RejectsBlockedCustomer \|', '| RejectsSomethingElse |'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'which no `AAA Cases` header defines'
    }

    It 'catches a Covers: naming no row' {
        $body = $script:ValidTechnicalBody -replace 'Covers: B1', 'Covers: B7'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'names no row in the coverage table'
    }

    It 'catches a duplicate coverage id' {
        $body = $script:ValidTechnicalBody -replace '(\| B1 \| Blocked Customer is rejected \| RejectsBlockedCustomer \|)', "`$1`r`n| B1 | Something else | RejectsBlockedCustomer |"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'is used by more than one row'
    }

    It 'catches two cases sharing one handle' {
        $body = $script:ValidTechnicalBody + @'

### RejectsBlockedCustomer
Scope: Unit
Covers: B1
Arrange:
- A second case reuses the handle.
Act:
- Evaluate the policy.
Assert:
- Policy returns blocked.
'@
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'a handle names one case'
    }

    It 'catches wrong Expected Behaviors columns' {
        $body = $script:ValidTechnicalBody -replace '\| ID \| Expected Behavior \| Covered By \|', '| ID | Behaviour | Covered By |'
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'columns are exactly'
    }

    It 'accepts a valid verify plan' {
        New-TaskFile -Folder $script:Scratch -Kind 'verify' -Body $script:ValidVerifyBody | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).ExitCode | Should -Be 0
    }

    It 'catches a missing Record: flag on an E2E example' {
        $body = $script:ValidVerifyBody -replace "Record: no`r?`n", ''
        New-TaskFile -Folder $script:Scratch -Kind 'verify' -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'has no `Record`'
    }

    It 'catches a verify example header missing its id' {
        $body = $script:ValidVerifyBody -replace '### V1 BlocksReleaseFromCard', '### BlocksReleaseFromCard'
        New-TaskFile -Folder $script:Scratch -Kind 'verify' -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'rule-6'
    }

    It 'catches an empty New and Modified Objects heading' {
        $body = $script:ValidTechnicalBody -replace '(?s)(## New and Modified Objects\r?\n).*?(?=## Expected)', "`$1`r`n"
        New-TaskFile -Folder $script:Scratch -Body $body | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).Findings -join "`n" | Should -Match 'neither entries nor the `: none` line'
    }

    It 'skips an ops task, which carries a description only' {
        # The body is a populated, deliberately off-grammar Verification Plan, so only the
        # kind guard can produce a clean run. A bodyless fixture would pass vacuously.
        $offGrammar = $script:ValidVerifyBody -replace "Record: no\r?\n", ''
        New-TaskFile -Folder $script:Scratch -Kind 'provision' -Body $offGrammar | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).ExitCode | Should -Be 0
    }

    It 'proves that same fixture is off-grammar for a verify task' {
        $offGrammar = $script:ValidVerifyBody -replace "Record: no\r?\n", ''
        New-TaskFile -Folder $script:Scratch -Kind 'verify' -Body $offGrammar | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).ExitCode | Should -Be 1
    }

    It 'skips a task that is not yet refined' {
        New-TaskFile -Folder $script:Scratch -Body 'Not refined yet.' | Out-Null
        (Invoke-GrammarCheck -Target $script:Scratch).ExitCode | Should -Be 0
    }
}

Describe 'the agentStop hook' {
    BeforeAll {
        $script:HookPath = Join-Path $script:PluginRoot 'hooks\Invoke-TaskGrammarHook.ps1'

        function Invoke-Hook {
            param([string] $Project, [string] $Transcript, [string] $SessionId)
            $payload = @{
                sessionId      = $SessionId
                cwd            = $Project
                transcriptPath = $Transcript
                stopReason     = 'end_turn'
            } | ConvertTo-Json -Compress

            $prior = $env:COPILOT_PROJECT_DIR
            $env:COPILOT_PROJECT_DIR = $Project
            try { $out = $payload | & pwsh -NoProfile -NoLogo -File $script:HookPath 2>&1 }
            finally { $env:COPILOT_PROJECT_DIR = $prior }
            return ($out -join '')
        }

        function New-HookProject {
            param([string] $Body, [switch] $WrittenBeforeSession)
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $tasks = Join-Path $root 'specs\010-demo\tasks'
            New-Item -ItemType Directory -Path $tasks -Force | Out-Null
            $transcript = Join-Path $root 'transcript.jsonl'

            if ($WrittenBeforeSession) {
                New-TaskFile -Folder $tasks -Body $Body | Out-Null
                Start-Sleep -Milliseconds 1200
                New-Item -ItemType File -Path $transcript | Out-Null
            }
            else {
                New-Item -ItemType File -Path $transcript | Out-Null
                Start-Sleep -Milliseconds 1200
                New-TaskFile -Folder $tasks -Body $Body | Out-Null
            }
            return @{ Project = $root; Transcript = $transcript }
        }

        $script:BrokenBody = $script:ValidTechnicalBody -replace '(?s)Assert:.*', ''
    }

    It 'stays silent when the session wrote nothing off-grammar' {
        $p = New-HookProject -Body $script:ValidTechnicalBody
        Invoke-Hook -Project $p.Project -Transcript $p.Transcript -SessionId (New-Guid) | Should -BeNullOrEmpty
    }

    It 'stays silent on a task file that predates the session' {
        $p = New-HookProject -Body $script:BrokenBody -WrittenBeforeSession
        Invoke-Hook -Project $p.Project -Transcript $p.Transcript -SessionId (New-Guid) | Should -BeNullOrEmpty
    }

    It 'blocks with the findings as the reason' {
        $p = New-HookProject -Body $script:BrokenBody
        $out = Invoke-Hook -Project $p.Project -Transcript $p.Transcript -SessionId (New-Guid)

        $out | Should -Not -BeNullOrEmpty
        $parsed = $out | ConvertFrom-Json
        $parsed.decision | Should -Be 'block'
        $parsed.reason | Should -Match 'off-grammar'
        $parsed.reason | Should -Match 'has no `Assert`'
        $parsed.reason | Should -Match 'task-grammar\.md'
    }

    It 'stops blocking after two turns so it cannot loop the session' {
        $p = New-HookProject -Body $script:BrokenBody
        $session = New-Guid

        Invoke-Hook -Project $p.Project -Transcript $p.Transcript -SessionId $session | Should -Not -BeNullOrEmpty
        Invoke-Hook -Project $p.Project -Transcript $p.Transcript -SessionId $session | Should -Not -BeNullOrEmpty
        Invoke-Hook -Project $p.Project -Transcript $p.Transcript -SessionId $session | Should -BeNullOrEmpty
    }

    It 'fails open when the project has no specs folder' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root | Out-Null
        $transcript = Join-Path $root 'transcript.jsonl'
        New-Item -ItemType File -Path $transcript | Out-Null

        Invoke-Hook -Project $root -Transcript $transcript -SessionId (New-Guid) | Should -BeNullOrEmpty
    }

    It 'stays silent when the payload carries no usable transcript' {
        # Without a baseline the hook cannot tell this session's writes from the repo's
        # history, so it must stop rather than block on files nobody touched.
        $p = New-HookProject -Body $script:BrokenBody
        Invoke-Hook -Project $p.Project -Transcript (Join-Path $p.Project 'no-such-transcript.jsonl') -SessionId (New-Guid) |
            Should -BeNullOrEmpty
    }

    It 'is registered on agentStop and carries no bash twin' {
        $hooks = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'hooks\hooks.json') -Raw
        $parsed = $hooks | ConvertFrom-Json

        $parsed.hooks.agentStop | Should -Not -BeNullOrEmpty
        $parsed.hooks.agentStop[0].powershell | Should -Match 'Invoke-TaskGrammarHook\.ps1'
        $hooks | Should -Not -Match '"bash"'
    }
}
