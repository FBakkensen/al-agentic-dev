#Requires -Version 7.2

BeforeAll {
    $script:ValidatorPath = Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Validate-PluginStructure.ps1')

    function New-PluginRepoFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,
            [Parameter(Mandatory = $true)]
            [string]$SkillBody
        )

        $marketplaceDir = Join-Path $Root '.github\plugin'
        $pluginDir = Join-Path $Root 'plugins\demo'
        $skillDir = Join-Path $pluginDir 'skills\demo'

        New-Item -ItemType Directory -Path $marketplaceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null

        'Fixture instructions.' | Set-Content -LiteralPath (Join-Path $Root '.github\copilot-instructions.md') -Encoding UTF8

        @'
{
  "plugins": [
    { "name": "demo" }
  ]
}
'@ | Set-Content -LiteralPath (Join-Path $marketplaceDir 'marketplace.json') -Encoding UTF8

        @'
{
  "name": "demo",
  "version": "1.0.0",
  "description": "fixture plugin"
}
'@ | Set-Content -LiteralPath (Join-Path $pluginDir 'plugin.json') -Encoding UTF8

        $SkillBody | Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Encoding UTF8
    }

    function New-ValidAgentContent {
        param(
            [string]$Name = 'demo-agent',
            [string]$Model = 'gpt-5.6-terra',
            [string]$Tools = '["read", "search"]',
            [string]$UserInvocable = 'false',
            [string]$AdditionalFrontmatter = '',
            [string]$Body = 'Fixture body.'
        )

        return @"
---
name: $Name
description: Fixture agent for validator tests.
tools: $Tools
model: $Model
user-invocable: $UserInvocable
$AdditionalFrontmatter
---

# $Name

$Body
"@
    }

    function New-PluginRepoFixtureWithAgents {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,
            [Parameter(Mandatory = $true)]
            [hashtable]$AgentFiles,
            [string]$PluginName = 'demo'
        )

        $marketplaceDir = Join-Path $Root '.github\plugin'
        $pluginDir = Join-Path $Root "plugins\$PluginName"
        $skillDir = Join-Path $pluginDir "skills\$PluginName"
        $agentsDir = Join-Path $pluginDir 'agents'

        New-Item -ItemType Directory -Path $marketplaceDir -Force | Out-Null
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

        'Fixture instructions.' | Set-Content -LiteralPath (Join-Path $Root '.github\copilot-instructions.md') -Encoding UTF8

        @"
{
  "plugins": [
    { "name": "$PluginName" }
  ]
}
"@ | Set-Content -LiteralPath (Join-Path $marketplaceDir 'marketplace.json') -Encoding UTF8

        @"
{
  "name": "$PluginName",
  "version": "1.0.0",
  "description": "fixture plugin"
}
"@ | Set-Content -LiteralPath (Join-Path $pluginDir 'plugin.json') -Encoding UTF8

        @"
---
name: $PluginName
description: "Fixture skill."
---

# $PluginName
"@ | Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Encoding UTF8

        foreach ($agentFileName in $AgentFiles.Keys) {
            $AgentFiles[$agentFileName] | Set-Content -LiteralPath (Join-Path $agentsDir "$agentFileName.agent.md") -Encoding UTF8
        }
    }

    $script:ExpectedAlAgenticDevFleet = [ordered]@{
        'al-design-option'              = 'claude-opus-5'
        'al-debug-logging'              = 'claude-opus-5'
        'al-gate-runner'                = 'claude-sonnet-5'
        'al-mutant-cycle'               = 'claude-sonnet-5'
        'al-red-green'                  = 'claude-opus-5'
        'al-researcher'                 = 'claude-opus-5'
        'al-review-cr-appsource'        = 'claude-opus-5'
        'al-review-cr-bc'               = 'claude-opus-5'
        'al-review-cr-bugscan'          = 'claude-opus-5'
        'al-review-cr-comments'         = 'claude-opus-5'
        'al-review-cr-compliance'       = 'claude-opus-5'
        'al-review-cr-perf'             = 'claude-opus-5'
        'al-review-judge'               = 'claude-opus-5'
        'al-review-refactor-bc'         = 'claude-opus-5'
        'al-review-refactor-naming'     = 'claude-opus-5'
        'al-review-refactor-perf'       = 'claude-opus-5'
        'al-review-refactor-simplify'   = 'claude-opus-5'
        'al-review-refactor-structural' = 'claude-opus-5'
    }

    function New-AlAgenticDevFleetAgentFiles {
        $agentFiles = @{}
        foreach ($entry in $script:ExpectedAlAgenticDevFleet.GetEnumerator()) {
            $agentFiles[$entry.Key] = New-ValidAgentContent -Name $entry.Key -Model $entry.Value
        }

        return $agentFiles
    }
}

Describe 'Validate-PluginStructure skill frontmatter checks' {
    It 'fails when a skill description is unquoted and contains colon-space' {
        $repoRoot = Join-Path $TestDrive 'bad-repo'
        $badSkill = @'
---
name: demo
description: Execute the `kind: provision` task at `status: ready`.
---

# Demo
'@
        New-PluginRepoFixture -Root $repoRoot -SkillBody $badSkill

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Unquoted description with colon-space'
    }

    It 'passes when a skill description is quoted' {
        $repoRoot = Join-Path $TestDrive 'good-repo'
        $goodSkill = @'
---
name: demo
description: "Execute the `kind: provision` task at `status: ready`."
---

# Demo
'@
        New-PluginRepoFixture -Root $repoRoot -SkillBody $goodSkill

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'All plugins have valid Copilot CLI marketplace structure'
    }
}

Describe 'Validate-PluginStructure agent frontmatter checks' {
    It 'passes when a custom agent has valid frontmatter' {
        $repoRoot = Join-Path $TestDrive 'agent-good'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{ 'demo-agent' = (New-ValidAgentContent) }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'All plugins have valid Copilot CLI marketplace structure'
    }

    It 'accepts agent-local MCP tools alongside the top-level tools list' {
        $repoRoot = Join-Path $TestDrive 'agent-local-mcp'
        $mcpFrontmatter = @'
mcp-servers:
  demo-mcp:
    type: stdio
    command: npx
    args: ["-y", "demo-mcp"]
    tools: ["*"]
'@
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -AdditionalFrontmatter $mcpFrontmatter)
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'All plugins have valid Copilot CLI marketplace structure'
    }

    It 'does not force unrelated plugin agents onto the al-agentic-dev model allow-list' {
        $repoRoot = Join-Path $TestDrive 'agent-independent-model'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{ 'demo-agent' = (New-ValidAgentContent -Model 'gpt-4o') }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'All plugins have valid Copilot CLI marketplace structure'
    }

    It 'fails when an agent is missing the tools declaration' {
        $repoRoot = Join-Path $TestDrive 'agent-no-tools'
        $noToolsAgent = @'
---
name: demo-agent
description: Fixture agent missing tools.
model: gpt-5.6-terra
user-invocable: false
---

# demo-agent
'@
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{ 'demo-agent' = $noToolsAgent }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Missing or malformed tools declaration'
    }

    It 'fails when tools is not a JSON array' {
        $repoRoot = Join-Path $TestDrive 'agent-scalar-tools'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '"read"')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Tools declaration must be a JSON array'
    }

    It 'fails when tools contains a non-string JSON entry' -TestCases @(
        @{ Tools = '[null]'; EntryType = 'null' }
        @{ Tools = '[1]'; EntryType = 'numeric' }
        @{ Tools = '[true]'; EntryType = 'boolean' }
        @{ Tools = '[{}]'; EntryType = 'object' }
        @{ Tools = '[["read"]]'; EntryType = 'array' }
    ) {
        param($Tools, $EntryType)

        $repoRoot = Join-Path $TestDrive "agent-$EntryType-tool"
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools $Tools)
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Tools declaration contains a non-string entry'
    }

    It 'fails when an agent declares edit without skill' {
        $repoRoot = Join-Path $TestDrive 'agent-edit-no-skill'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '["read", "edit", "execute"]')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "declares 'edit' but not 'skill'"
    }

    It 'accepts an agent declaring both edit and skill' {
        $repoRoot = Join-Path $TestDrive 'agent-edit-with-skill'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '["read", "edit", "skill"]')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Not -Match "declares 'edit' but not 'skill'"
    }

    It 'fails when an agent invokes a delegating gate skill without the agent tool' {
        $repoRoot = Join-Path $TestDrive 'agent-gate-without-agent'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '["read", "execute", "skill"]' -Body 'Run the gate by invoking /al-build with the supplied variant.')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "invokes a delegating gate skill but does not declare 'agent'"
    }

    It 'accepts an agent invoking a delegating gate skill with the agent tool' {
        $repoRoot = Join-Path $TestDrive 'agent-gate-with-agent'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '["read", "execute", "skill", "agent"]' -Body 'Run the gate by invoking /al-build with the supplied variant.')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Not -Match 'delegating gate skill'
    }

    It 'fails when tools contains an empty string' {
        $repoRoot = Join-Path $TestDrive 'agent-empty-tool'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '["read", ""]')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Tools declaration contains an empty or whitespace-only entry'
    }

    It 'fails when tools contains a whitespace-only string' {
        $repoRoot = Join-Path $TestDrive 'agent-whitespace-tool'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '["read", "  "]')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Tools declaration contains an empty or whitespace-only entry'
    }

    It 'accepts a non-empty tool after trimming whitespace' {
        $repoRoot = Join-Path $TestDrive 'agent-trimmed-tool'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -Tools '[" read "]')
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'All plugins have valid Copilot CLI marketplace structure'
    }

    It 'fails when an agent user-invocable is not false' {
        $repoRoot = Join-Path $TestDrive 'agent-invocable'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{ 'demo-agent' = (New-ValidAgentContent -UserInvocable 'true') }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "user-invocable must be 'false'"
    }

    It 'fails when an authoritative field is duplicated even when the first value is valid' -TestCases @(
        @{ Key = 'name'; AdditionalFrontmatter = 'name: invalid agent name' }
        @{ Key = 'tools'; AdditionalFrontmatter = 'tools: [not valid JSON]' }
        @{ Key = 'model'; AdditionalFrontmatter = 'model: invalid model value' }
        @{ Key = 'user-invocable'; AdditionalFrontmatter = 'user-invocable: true' }
    ) {
        param($Key, $AdditionalFrontmatter)

        $repoRoot = Join-Path $TestDrive "agent-duplicate-$Key"
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{
            'demo-agent' = (New-ValidAgentContent -AdditionalFrontmatter $AdditionalFrontmatter)
        }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "Duplicate $Key field in agent frontmatter"
    }

    It 'fails when two agents declare the same name' {
        $repoRoot = Join-Path $TestDrive 'agent-dupe-name'
        $agentA = New-ValidAgentContent -Name 'shared-name'
        $agentB = New-ValidAgentContent -Name 'shared-name'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{ 'agent-a' = $agentA; 'agent-b' = $agentB }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "Duplicate agent name 'shared-name'"
    }

    It 'fails when an agent name does not match its filename' {
        $repoRoot = Join-Path $TestDrive 'agent-name-mismatch'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -AgentFiles @{ 'demo-agent' = (New-ValidAgentContent -Name 'other-name') }

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "does not match filename stem 'demo-agent'"
    }

    It 'fails when al-agentic-dev is missing an expected fleet member' {
        $repoRoot = Join-Path $TestDrive 'al-agentic-dev-missing-agent'
        $agentFiles = New-AlAgenticDevFleetAgentFiles
        $agentFiles.Remove('al-red-green')
        New-PluginRepoFixtureWithAgents -Root $repoRoot -PluginName 'al-agentic-dev' -AgentFiles $agentFiles

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "Missing expected al-agentic-dev agent 'al-red-green'"
    }

    It 'fails when al-agentic-dev has an extra fleet member' {
        $repoRoot = Join-Path $TestDrive 'al-agentic-dev-extra-agent'
        $agentFiles = New-AlAgenticDevFleetAgentFiles
        $agentFiles['unapproved-agent'] = New-ValidAgentContent -Name 'unapproved-agent' -Model 'gpt-4o'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -PluginName 'al-agentic-dev' -AgentFiles $agentFiles

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "Unexpected al-agentic-dev agent 'unapproved-agent'"
    }

    It 'fails when an al-agentic-dev fleet member has the wrong model' {
        $repoRoot = Join-Path $TestDrive 'al-agentic-dev-wrong-model'
        $agentFiles = New-AlAgenticDevFleetAgentFiles
        $agentFiles['al-red-green'] = New-ValidAgentContent -Name 'al-red-green' -Model 'gpt-5.6-sol'
        New-PluginRepoFixtureWithAgents -Root $repoRoot -PluginName 'al-agentic-dev' -AgentFiles $agentFiles

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match "al-agentic-dev agent 'al-red-green' must use model 'claude-opus-5' \(found 'gpt-5.6-sol'\)"
    }
}

Describe 'Validate-PluginStructure instruction format checks' {
    It 'fails when .github/copilot-instructions.md is missing' {
        $repoRoot = Join-Path $TestDrive 'instructions-missing'
        New-PluginRepoFixture -Root $repoRoot -SkillBody "---`nname: demo`ndescription: Fixture skill.`n---`n"
        Remove-Item -LiteralPath (Join-Path $repoRoot '.github\copilot-instructions.md') -Force

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'Missing \.github/copilot-instructions\.md'
    }

    It 'fails when an AGENTS.md survives anywhere in the repo' {
        $repoRoot = Join-Path $TestDrive 'instructions-stray-agents-md'
        New-PluginRepoFixture -Root $repoRoot -SkillBody "---`nname: demo`ndescription: Fixture skill.`n---`n"
        'Legacy context.' | Set-Content -LiteralPath (Join-Path $repoRoot 'plugins\demo\AGENTS.md') -Encoding UTF8

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join [Environment]::NewLine) | Should -Match 'AGENTS\.md is not the native Copilot instruction format'
    }

    It 'passes when instructions use the native Copilot format' {
        $repoRoot = Join-Path $TestDrive 'instructions-native'
        New-PluginRepoFixture -Root $repoRoot -SkillBody "---`nname: demo`ndescription: Fixture skill.`n---`n"

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repoRoot 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'no AGENTS\.md files'
    }
}
