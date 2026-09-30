#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    function Invoke-SessionStartHook {
        param([Parameter(Mandatory = $true)][string]$PluginRoot)

        $hooks = Get-Content -LiteralPath (Join-Path $PluginRoot 'hooks' 'hooks.json') -Raw | ConvertFrom-Json
        $handler = @($hooks.hooks.SessionStart)[0].hooks[0]
        $arguments = @($handler.args | ForEach-Object { $_.Replace('${CLAUDE_PLUGIN_ROOT}', $PluginRoot) })

        $previousEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        try {
            $output = '{}' | & $handler.command @arguments 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            [Console]::OutputEncoding = $previousEncoding
        }

        return [pscustomobject]@{
            ExitCode = $exitCode
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join "`n")
        }
    }
}

Describe 'SessionStart hook' -Tag 'Process' {
    It 'injects the delegation rules as SessionStart additionalContext' {
        $result = Invoke-SessionStartHook -PluginRoot $script:RepoRoot

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $payload = $result.Text | ConvertFrom-Json
        $payload.hookSpecificOutput.hookEventName | Should -BeExactly 'SessionStart'
        $context = $payload.hookSpecificOutput.additionalContext
        $context | Should -Not -BeNullOrEmpty
        $context | Should -Match ([regex]::Escape('▶ <model> · <brief> → <return>'))
        $context | Should -Match ([regex]::Escape('Spawn a child only for a sizeable, independent track of work whose result comes back compact. Work you can finish in a handful of tool calls, you do yourself. Keep spawn counts low. A skill''s `▶` line is already that judgement: run it as written.'))
    }

    It 'injects the entry → addition table with a row per landed AL addition' {
        $result = Invoke-SessionStartHook -PluginRoot $script:RepoRoot

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $context = ($result.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext
        $context | Should -Match '(?m)^## Entry skills and their AL additions\r?$'
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:setup-matt-pocock-skills` | `/al-setup-matt-pocock-skills` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:tdd` | `/al-tdd` |') + '\r?$')
    }

    It 'fails when the delegation text is missing' {
        $plugin = Join-Path $TestDrive 'plugin'
        New-Item -ItemType Directory -Path (Join-Path $plugin 'hooks') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'hooks.json') -Destination (Join-Path $plugin 'hooks')
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'Write-SessionStart.ps1') -Destination (Join-Path $plugin 'hooks')

        $result = Invoke-SessionStartHook -PluginRoot $plugin

        $result.ExitCode | Should -Not -Be 0
        $result.Text | Should -Match 'session-start\.md'
    }
}
