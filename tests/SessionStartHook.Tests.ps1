#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    $script:PathRule = @(
        'In an AL repository whose `al-build.json` has `moduleGate.enabled` true, the path of code says how to treat it:'
        '- A folder named `Internal` holds a module''s internals: call them only from inside that module.'
        '- A folder with an `Internal` child is a module''s interface: call the module from anywhere, through that folder.'
        '- Any other folder is open code: a fix inside an existing procedure stays there; a new object, callable procedure, or event subscriber goes into a module, carved as a child namespace with its own `Internal`.'
    )

    function Invoke-SessionStartHook {
        param(
            [Parameter(Mandatory = $true)][string]$PluginRoot,
            [ValidateSet('SessionStart', 'SubagentStart')][string]$Event = 'SessionStart'
        )

        $hooks = Get-Content -LiteralPath (Join-Path $PluginRoot 'hooks' 'hooks.json') -Raw | ConvertFrom-Json
        $handler = @($hooks.hooks.$Event)[0].hooks[0]
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
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:grill-with-docs` | `/al-grill-with-docs` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:to-spec` | `/al-to-spec` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:to-tickets` | `/al-to-tickets` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:implement` | `/al-implement` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:tdd` | `/al-tdd` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:codebase-design` | `/al-codebase-design` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:code-review` | `/al-review` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/simplify` | `/al-simplify` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:improve-codebase-architecture` | `/al-improve-codebase-architecture` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:diagnosing-bugs` | `/al-diagnosing-bugs` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:wayfinder` | `/al-wayfinder` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:prototype` | `/al-prototype` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:research` | `/al-research` |') + '\r?$')
    }

    It 'injects the path rule, scoped to a repository whose module gate is on, as SessionStart additionalContext' {
        $result = Invoke-SessionStartHook -PluginRoot $script:RepoRoot

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $context = ($result.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext
        $context | Should -Match '(?m)^## Reading an AL path\r?$'
        foreach ($line in $script:PathRule) {
            $context | Should -Match ('(?m)^' + [regex]::Escape($line) + '\r?$') -Because "SessionStart carries: $line"
        }
    }

    It 'gives a subagent the entry → addition table, the path rule, and none of the delegation rules' {
        $result = Invoke-SessionStartHook -PluginRoot $script:RepoRoot -Event SubagentStart

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $payload = $result.Text | ConvertFrom-Json
        $payload.hookSpecificOutput.hookEventName | Should -BeExactly 'SubagentStart'
        $context = $payload.hookSpecificOutput.additionalContext
        $context | Should -Match '(?m)^## Reading an AL path\r?$'
        foreach ($line in $script:PathRule) {
            $context | Should -Match ('(?m)^' + [regex]::Escape($line) + '\r?$') -Because "SubagentStart carries: $line"
        }
        $context | Should -Match '(?m)^## Entry skills and their AL additions\r?$'
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:wayfinder` | `/al-wayfinder` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:research` | `/al-research` |') + '\r?$')
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:prototype` | `/al-prototype` |') + '\r?$')
        $rows = @(Get-Content -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'session-start.md') | Where-Object { $_ -match '^\| `/' })
        $rows.Count | Should -BeGreaterThan 10
        foreach ($row in $rows) {
            $context | Should -Match ('(?m)^' + [regex]::Escape($row) + '\r?$') -Because "the subagent gets $row"
        }
        $context | Should -Not -Match ([regex]::Escape('▶ <model> · <brief> → <return>'))
        $context | Should -Not -Match '(?m)^## Delegation'
    }

    It 'ends the subagent section at the next level-2 heading' {
        $plugin = Join-Path $TestDrive 'section-plugin'
        New-Item -ItemType Directory -Path (Join-Path $plugin 'hooks') -Force | Out-Null
        foreach ($name in 'hooks.json', 'Write-SessionStart.ps1') {
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'hooks' $name) -Destination (Join-Path $plugin 'hooks')
        }
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'session-start.md') -Raw
        Set-Content -LiteralPath (Join-Path $plugin 'hooks' 'session-start.md') -Value ($text.TrimEnd() + "`n`n## Later section`n`nLater text.`n") -NoNewline

        $result = Invoke-SessionStartHook -PluginRoot $plugin -Event SubagentStart

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $context = ($result.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext
        $context | Should -Match ('(?m)^' + [regex]::Escape('| `/mattpocock-skills:research` | `/al-research` |') + '\r?$')
        $context | Should -Not -Match 'Later'
    }

    It 'prints the path rule to both hooks from the one section of session-start.md' {
        $source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'session-start.md') -Raw
        $section = [regex]::Match($source, '(?ms)^## Reading an AL path\r?\n.*?(?=^## |\z)').Value.Trim().Replace("`r`n", "`n")
        $section | Should -Not -BeNullOrEmpty

        foreach ($event in 'SessionStart', 'SubagentStart') {
            $result = Invoke-SessionStartHook -PluginRoot $script:RepoRoot -Event $event
            $result.ExitCode | Should -Be 0 -Because $result.Text
            $context = ($result.Text | ConvertFrom-Json).hookSpecificOutput.additionalContext
            $context.Replace("`r`n", "`n").Contains($section) | Should -BeTrue -Because "$event prints the section as written"
        }
    }

    It 'fails a subagent start when the "<Heading>" section is missing' -ForEach @(
        @{ Heading = 'Reading an AL path' }
        @{ Heading = 'Entry skills and their AL additions' }
    ) {
        $plugin = Join-Path $TestDrive 'missing-section-plugin'
        New-Item -ItemType Directory -Path (Join-Path $plugin 'hooks') -Force | Out-Null
        foreach ($name in 'hooks.json', 'Write-SessionStart.ps1') {
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'hooks' $name) -Destination (Join-Path $plugin 'hooks')
        }
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'session-start.md') -Raw
        $text = [regex]::Replace($text, '(?ms)^## ' + [regex]::Escape($Heading) + '\r?\n.*?(?=^## |\z)', '')
        Set-Content -LiteralPath (Join-Path $plugin 'hooks' 'session-start.md') -Value $text -NoNewline

        $result = Invoke-SessionStartHook -PluginRoot $plugin -Event SubagentStart

        $result.ExitCode | Should -Not -Be 0
        $result.Text | Should -Match ([regex]::Escape($Heading))
    }
    It 'fails a subagent start when the text is missing' {
        $plugin = Join-Path $TestDrive 'subagent-plugin'
        New-Item -ItemType Directory -Path (Join-Path $plugin 'hooks') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'hooks.json') -Destination (Join-Path $plugin 'hooks')
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'hooks' 'Write-SessionStart.ps1') -Destination (Join-Path $plugin 'hooks')

        $result = Invoke-SessionStartHook -PluginRoot $plugin -Event SubagentStart

        $result.ExitCode | Should -Not -Be 0
        $result.Text | Should -Match 'session-start\.md'
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
