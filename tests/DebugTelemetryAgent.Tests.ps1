#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:PluginRoot = Join-Path $script:RepoRoot 'plugins\al-agentic-dev'
    $script:AgentPath = Join-Path $script:PluginRoot 'agents\al-debug-logging.agent.md'
}

Describe 'al-debug-logging agent contract' {
    It 'replaces the public skill with a non-user-invocable agent' {
        Test-Path (Join-Path $script:PluginRoot 'skills\al-debug-logging') | Should -BeFalse
        Test-Path $script:AgentPath | Should -BeTrue

        $content = Get-Content -LiteralPath $script:AgentPath -Raw
        $content | Should -Match '(?m)^user-invocable:\s*false\s*$'
    }

    It 'owns Telemetry Buddy and direct Session.LogMessage probes' {
        $content = Get-Content -LiteralPath $script:AgentPath -Raw
        $agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'agents') -File -Filter '*.agent.md')
        $owners = @($agentFiles | Where-Object {
                (Get-Content -LiteralPath $_.FullName -Raw) -match 'bc-telemetry-buddy'
            } | ForEach-Object Name)

        ($owners -join ',') | Should -Be 'al-debug-logging.agent.md'
        $content | Should -Match '(?m)^  bc-telemetry-buddy:\s*$'
        $content | Should -Match '(?m)^    command:\s*npx\s*$'
        $content | Should -Match '(?m)^    args:\s*\["-y", "bc-telemetry-buddy-mcp", "start"\]\s*$'
        $content | Should -Match 'bc-telemetry-buddy/\*'
        $content | Should -Match 'Session\.LogMessage'
        $content | Should -Not -Match 'FeatureTelemetry\.LogUsage'
        $content | Should -Not -Match 'telemetry\.jsonl'
    }

    It 'removes the slash-skill surface from shipped files' {
        $shippedFiles = @(
            Get-Item -LiteralPath (Join-Path $script:PluginRoot 'plugin.json')
            Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'agents') -File -Filter '*.agent.md'
            Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'references') -Recurse -File -Filter '*.md'
            Get-ChildItem -LiteralPath (Join-Path $script:PluginRoot 'skills') -Recurse -File -Include '*.md', '*.json'
        )

        @($shippedFiles | Select-String -Pattern '/al-debug-logging' -SimpleMatch) | Should -BeNullOrEmpty
    }

    It 'keeps the agreed correlation polling and cleanup gates' {
        $content = Get-Content -LiteralPath $script:AgentPath -Raw
        $content | Should -Match 'InvestigationId'
        $content | Should -Match 'every 60 seconds'
        $content | Should -Match 'five minutes'
        $content | Should -Match 'rg "DEBUG-" -g "\*\.al"'
    }

    It 'requires a committed Azure CLI workspace profile without secrets' {
        $content = Get-Content -LiteralPath $script:AgentPath -Raw

        Test-Path (Join-Path $script:RepoRoot '.bctb-config.json') | Should -BeFalse
        $content | Should -Match 'committed `\.bctb-config\.json`'
        $content | Should -Match '`azure_cli` authentication'
        $content | Should -Match 'no secrets'
    }
}
