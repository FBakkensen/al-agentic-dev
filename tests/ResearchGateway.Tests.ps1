#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:PluginRoot = Join-Path $script:RepoRoot 'plugins\al-agentic-dev'
    $script:AgentsRoot = Join-Path $script:PluginRoot 'agents'
    $script:SkillsRoot = Join-Path $script:PluginRoot 'skills'
    $script:ResearcherPath = Join-Path $script:AgentsRoot 'al-researcher.agent.md'

    function Get-AgentTools {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        $content = Get-Content -LiteralPath $Path -Raw
        $match = [regex]::Match($content, '(?m)^tools:\s*(\[.+\])\s*$')
        if (-not $match.Success) {
            throw "Missing tools declaration: $Path"
        }

        return @($match.Groups[1].Value | ConvertFrom-Json)
    }
}

Describe 'al-researcher gateway ownership' {
    It 'removes the public research skill and shared dispatch reference' {
        Test-Path (Join-Path $script:SkillsRoot 'al-research\SKILL.md') | Should -BeFalse
        Test-Path (Join-Path $script:PluginRoot 'references\bc-code-intelligence-dispatch.md') | Should -BeFalse
    }

    It 'pins the shipped plugin release version' {
        $manifest = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'plugin.json') -Raw | ConvertFrom-Json
        $manifest.version | Should -Be '5.3.0'
    }

    It 'contains no shipped slash-command references to al-research' {
        $shippedFiles = @(
            Get-Item -LiteralPath (Join-Path $script:PluginRoot 'plugin.json')
            Get-ChildItem -LiteralPath $script:AgentsRoot -File -Filter '*.agent.md'
            Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'references') -Recurse -File -Filter '*.md'
            Get-ChildItem -LiteralPath $script:SkillsRoot -Recurse -File -Include '*.md', '*.json'
        )

        $matches = @($shippedFiles | Select-String -Pattern '/al-research' -SimpleMatch)
        $matches | Should -BeNullOrEmpty
    }

    It 'configures bc-code-intelligence only on al-researcher' {
        $agentFiles = @(Get-ChildItem -LiteralPath $script:AgentsRoot -File -Filter '*.agent.md')
        $owners = @($agentFiles | Where-Object {
                (Get-Content -LiteralPath $_.FullName -Raw) -match 'bc-code-intelligence'
            } | ForEach-Object Name)

        ($owners -join ',') | Should -Be 'al-researcher.agent.md'

        $content = Get-Content -LiteralPath $script:ResearcherPath -Raw
        $content | Should -Match '(?m)^mcp-servers:\s*$'
        $content | Should -Match '(?m)^  bc-code-intelligence-mcp:\s*$'
        $content | Should -Match '(?m)^    command:\s*npx\s*$'
        $content | Should -Match '(?m)^    args:\s*\["-y", "bc-code-intelligence-mcp"\]\s*$'
        (Get-AgentTools -Path $script:ResearcherPath) | Should -Contain 'bc-code-intelligence-mcp/*'
    }

    It 'keeps Microsoft Learn tools on the gateway only' {
        $agentFiles = @(Get-ChildItem -LiteralPath $script:AgentsRoot -File -Filter '*.agent.md')
        $owners = @($agentFiles | Where-Object {
                (Get-AgentTools -Path $_.FullName) -contains 'microsoft_learn/*'
            } | ForEach-Object Name | Sort-Object)

        ($owners -join ',') | Should -Be 'al-researcher.agent.md'
    }

    It 'gives every research-capable caller agent access and gateway instructions' {
        $researchCallers = @(
            'al-debug-logging',
            'al-design-option',
            'al-red-green',
            'al-review-appsource',
            'al-review-assertions',
            'al-review-bc',
            'al-review-bugscan',
            'al-review-comments',
            'al-review-compliance',
            'al-review-coverage',
            'al-review-judge',
            'al-review-objects',
            'al-review-perf',
            'al-review-simplify',
            'al-review-structural'
        )

        foreach ($agentName in $researchCallers) {
            $path = Join-Path $script:AgentsRoot "$agentName.agent.md"
            $tools = Get-AgentTools -Path $path
            $content = Get-Content -LiteralPath $path -Raw

            $tools | Should -Contain 'agent' -Because "$agentName must invoke al-researcher"
            $tools | Should -Not -Contain 'microsoft_learn/*'
            $tools | Should -Not -Contain 'bc-code-intelligence/*'
            $tools | Should -Not -Contain 'bc-code-intelligence-mcp/*'
            $content | Should -Match 'al-researcher'
        }
    }

    It 'keeps execution-only agents outside the research route' {
        foreach ($agentName in @('al-gate-runner', 'al-mutant-cycle')) {
            $path = Join-Path $script:AgentsRoot "$agentName.agent.md"
            $tools = Get-AgentTools -Path $path

            Get-Content -LiteralPath $path -Raw | Should -Not -Match 'al-researcher' -Because "$agentName must not reach the research route"
            $tools | Should -Not -Contain 'microsoft_learn/*'
            $tools | Should -Not -Contain 'bc-code-intelligence/*'
            $tools | Should -Not -Contain 'bc-code-intelligence-mcp/*'
            $tools | Should -Not -Contain 'web'
        }

        # al-gate-runner spawns nothing; al-mutant-cycle needs the grant so its
        # /al-build call can reach al-gate-runner.
        Get-AgentTools -Path (Join-Path $script:AgentsRoot 'al-gate-runner.agent.md') | Should -Not -Contain 'agent'
    }

    It 'routes research-capable skills through al-researcher' {
        $researchSkills = @(
            'al-design',
            'al-event-model',
            'al-grill-adr',
            'al-implement',
            'al-mutate',
            'al-page-script',
            'al-refactor',
            'al-refine',
            'al-scope',
            'al-steer',
            'al-user-verification'
        )

        foreach ($skillName in $researchSkills) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot "$skillName\SKILL.md") -Raw
            $content | Should -Match 'al-researcher'
        }
    }

    It 'keeps canonical BCApps lookup inside al-researcher' {
        $shippedFiles = @(
            Get-ChildItem -LiteralPath $script:AgentsRoot -File -Filter '*.agent.md'
            Get-ChildItem -LiteralPath $script:SkillsRoot -Recurse -File -Filter 'SKILL.md'
            Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'references') -Recurse -File -Filter '*.md'
        )

        $matches = @($shippedFiles | Select-String -Pattern 'bc-standard-reference' -SimpleMatch)
        $matches | Should -BeNullOrEmpty

        $content = Get-Content -LiteralPath $script:ResearcherPath -Raw
        (Get-AgentTools -Path $script:ResearcherPath) | Should -Contain 'execute'
        $content | Should -Match 'microsoft/BCApps'
        $content | Should -Match 'GH_HOST=github\.com'
        $content | Should -Match "quote .main. and state that the evidence is not the consumer.s version"
    }

    It 'keeps the shared invocation and evidence contract in Ground Rules' {
        $content = Get-Content -LiteralPath (Join-Path $script:PluginRoot 'references\GROUND-RULES.md') -Raw

        $content | Should -Match 'Question:'
        $content | Should -Match 'Use:'
        $content | Should -Match 'Context:'
        $content | Should -Match 'SINGLE-SOURCE'
        $content | Should -Match 'VERIFIED'
        $content | Should -Match 'CONFLICT'
        $content | Should -Match 'UNRESOLVED'
        $content | Should -Match 'Never continue through another agent, MCP, web, or shell source\.'
    }
}
