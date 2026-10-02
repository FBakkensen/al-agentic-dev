#Requires -Version 7.2

BeforeAll {
    $script:ValidatorPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Validate-Json.ps1')).Path
    . $script:ValidatorPath

    function New-PluginRepo {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [hashtable]$Overrides = @{},

            [string[]]$Remove = @()
        )

        $files = @{
            '.claude-plugin/plugin.json'      = @'
{
  "name": "al-agentic-dev",
  "description": "Agentic AL and Business Central development skills.",
  "version": "1.0.0",
  "mcpServers": {
    "nab-al-tools": {
      "type": "stdio",
      "command": "npx"
    }
  }
}
'@
            '.claude-plugin/marketplace.json' = @'
{
  "name": "al-agentic-dev",
  "owner": { "name": "Owner" },
  "plugins": [
    { "name": "al-agentic-dev", "source": "./" }
  ]
}
'@
        }
        foreach ($key in $Overrides.Keys) { $files[$key] = $Overrides[$key] }
        foreach ($key in $Remove) { $files.Remove($key) }

        New-Item -ItemType Directory -Path (Join-Path $Root 'skills') -Force | Out-Null
        foreach ($relativePath in $files.Keys) {
            $path = Join-Path $Root $relativePath
            New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($path)) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $files[$relativePath] -Encoding utf8
        }

        return $Root
    }

    function Invoke-JsonValidator {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root
        )

        $output = @(
            & {
                Invoke-JsonValidation -RepoRoot $Root -ErrorAction Continue
            } *>&1
        )
        $exitCode = [int]$output[-1]
        $text = if ($output.Count -gt 1) {
            @($output[0..($output.Count - 2)] | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        } else {
            ''
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Text     = $text
        }
    }

    function Invoke-JsonValidatorProcess {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root
        )

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $Root 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
}

Describe 'Validate-Json plugin surface' -Tag 'Unit' {
    It 'passes a well-formed plugin surface' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'good')

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $result.Text | Should -Match 'All JSON files validated successfully'
    }

    It 'accepts an npm lockfile with an empty root package key' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'npm-lock')
        Set-Content -LiteralPath (Join-Path $root 'package-lock.json') -Encoding utf8 -Value @'
{
  "name": "fixture",
  "lockfileVersion": 3,
  "packages": {
    "": {
      "name": "fixture"
    }
  }

}
'@

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $result.Text | Should -Match 'All JSON files validated successfully'
    }

    It 'fails when a plugin surface file is missing' -TestCases @(
        @{ Case = 'plugin'; Remove = '.claude-plugin/plugin.json'; Expected = '\.claude-plugin/plugin\.json is missing' }
        @{ Case = 'marketplace'; Remove = '.claude-plugin/marketplace.json'; Expected = '\.claude-plugin/marketplace\.json is missing' }
    ) {
        param($Case, $Remove, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "missing-$Case") -Remove @($Remove)

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails when the manifest drops a required field' -TestCases @(
        @{ Case = 'name'; Json = '{ "version": "1.0.0" }'; Expected = 'name must be non-empty' }
        @{ Case = 'version'; Json = '{ "name": "al-agentic-dev" }'; Expected = 'version must be non-empty' }
    ) {
        param($Case, $Json, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "manifest-$Case") -Overrides @{ '.claude-plugin/plugin.json' = $Json }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails an MCP server without a type, or one that carries a tools allowlist' -TestCases @(
        @{ Case = 'no-type'; Servers = '{ "svc": { "command": "npx" } }'; Expected = "server 'svc' must carry a type" }
        @{ Case = 'tools'; Servers = '{ "svc": { "type": "stdio", "tools": ["a"] } }'; Expected = "server 'svc' carries a tools allowlist" }
        @{ Case = 'empty-tools'; Servers = '{ "svc": { "type": "stdio", "tools": [] } }'; Expected = "server 'svc' carries a tools allowlist" }
        @{ Case = 'no-servers'; Servers = '{}'; Expected = 'mcpServers must carry at least one server' }
        @{ Case = 'absent'; Servers = $null; Expected = 'mcpServers must carry at least one server' }
    ) {
        param($Case, $Servers, $Expected)

        $manifest = if ($null -eq $Servers) { '{ "name": "al-agentic-dev", "version": "1.0.0" }' } else { "{ ""name"": ""al-agentic-dev"", ""version"": ""1.0.0"", ""mcpServers"": $Servers }" }
        $root = New-PluginRepo -Root (Join-Path $TestDrive "mcp-$Case") -Overrides @{ '.claude-plugin/plugin.json' = $manifest }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails a root .mcp.json, which Claude Code also loads as the repository''s project MCP servers' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'root-mcp') -Overrides @{ '.mcp.json' = '{ "mcpServers": { "svc": { "type": "stdio", "command": "npx" } } }' }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match '\.mcp\.json at the repository root loads as project MCP servers'
    }

    It 'fails a marketplace whose local entry does not resolve to the plugin manifest' -TestCases @(
        @{ Case = 'source-absent'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "al-agentic-dev", "source": "./missing/" } ] }'; Expected = "source does not resolve to a plugin manifest: \./missing/" }
        @{ Case = 'no-manifest'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "al-agentic-dev", "source": "./skills/" } ] }'; Expected = "source does not resolve to a plugin manifest: \./skills/" }
        @{ Case = 'name-mismatch'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "other-plugin", "source": "./" } ] }'; Expected = "does not match the manifest name 'al-agentic-dev'" }
        @{ Case = 'unnamed'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "source": "./" } ] }'; Expected = 'every plugins entry must name a plugin' }
        @{ Case = 'no-source'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "al-agentic-dev" } ] }'; Expected = "plugin 'al-agentic-dev' must carry a source" }
        @{ Case = 'no-entries'; Json = '{ "name": "al-agentic-dev", "plugins": [] }'; Expected = 'plugins must carry at least one entry' }
    ) {
        param($Case, $Json, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "market-$Case") -Overrides @{ '.claude-plugin/marketplace.json' = $Json }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails a re-listed object source that Claude Code cannot install' -TestCases @(
        @{ Case = 'github-type'; Source = '{ "source": "github", "repo": "microsoft/BCQuality" }'; Expected = "plugin 'relisted' source type must be url or git-subdir" }
        @{ Case = 'url-missing'; Source = '{ "source": "url" }'; Expected = "plugin 'relisted' source must carry an https url" }
        @{ Case = 'url-ssh'; Source = '{ "source": "url", "url": "git@github.com:microsoft/BCQuality.git" }'; Expected = "plugin 'relisted' source must carry an https url" }
        @{ Case = 'url-hostless'; Source = '{ "source": "url", "url": "https://" }'; Expected = "plugin 'relisted' source must carry an https url" }
        @{ Case = 'url-relative'; Source = '{ "source": "url", "url": "https-not/a/uri" }'; Expected = "plugin 'relisted' source must carry an https url" }
        @{ Case = 'subdir-no-path'; Source = '{ "source": "git-subdir", "url": "https://github.com/SShadowS/al-lsp-for-agents.git" }'; Expected = "plugin 'relisted' git-subdir source must carry a path" }
        @{ Case = 'subdir-array-path'; Source = '{ "source": "git-subdir", "url": "https://github.com/SShadowS/al-lsp-for-agents.git", "path": ["tools/formatter"] }'; Expected = "plugin 'relisted' git-subdir source must carry a path" }
        @{ Case = 'subdir-blank-path'; Source = '{ "source": "git-subdir", "url": "https://github.com/SShadowS/al-lsp-for-agents.git", "path": "  " }'; Expected = "plugin 'relisted' git-subdir source must carry a path" }
    ) {
        param($Case, $Source, $Expected)

        $json = "{ `"name`": `"al-agentic-dev`", `"plugins`": [ { `"name`": `"al-agentic-dev`", `"source`": `"./`" }, { `"name`": `"relisted`", `"source`": $Source } ] }"
        $root = New-PluginRepo -Root (Join-Path $TestDrive "market-object-$Case") -Overrides @{ '.claude-plugin/marketplace.json' = $json }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape($Expected))
    }

    It 'passes re-listed url and git-subdir object sources without a path check' {
        $marketplace = @'
{
  "name": "al-agentic-dev",
  "owner": { "name": "Owner" },
  "allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"],
  "plugins": [
    { "name": "al-agentic-dev", "source": "./" },
    { "name": "bcquality", "source": { "source": "url", "url": "HTTPS://GitHub.com/microsoft/BCQuality.git" }, "skills": ["./skills/"] },
    { "name": "al-language-server-go-windows", "source": { "source": "git-subdir", "url": "https://github.com/SShadowS/al-lsp-for-agents.git", "path": "al-language-server-go-windows" } }
  ]
}
'@
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'market-object-sources') -Overrides @{ '.claude-plugin/marketplace.json' = $marketplace }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'fails a dependency whose marketplace Claude Code would not install it from' -TestCases @(
        @{ Case = 'not-allowed'; Dependencies = '"bcquality@bcquality"'; Allowed = '["claude-plugins-official"]'; Expected = "dependency 'bcquality@bcquality' needs 'bcquality' in marketplace.json allowCrossMarketplaceDependenciesOn" }
        @{ Case = 'no-allowlist'; Dependencies = '"bcquality@bcquality"'; Allowed = $null; Expected = "dependency 'bcquality@bcquality' needs 'bcquality'" }
        @{ Case = 'bare-unlisted'; Dependencies = '"bcquality"'; Allowed = '["bcquality"]'; Expected = "dependency 'bcquality' names no marketplace and marketplace.json does not list it" }
    ) {
        param($Case, $Dependencies, $Allowed, $Expected)

        $manifest = "{ `"name`": `"al-agentic-dev`", `"version`": `"1.0.0`", `"mcpServers`": { `"svc`": { `"type`": `"stdio`" } }, `"dependencies`": [ $Dependencies ] }"
        $allowList = if ($Allowed) { "`"allowCrossMarketplaceDependenciesOn`": $Allowed," }
        $marketplace = "{ `"name`": `"al-agentic-dev`", $allowList `"plugins`": [ { `"name`": `"al-agentic-dev`", `"source`": `"./`" } ] }"
        $root = New-PluginRepo -Root (Join-Path $TestDrive "dependency-$Case") -Overrides @{
            '.claude-plugin/plugin.json'      = $manifest
            '.claude-plugin/marketplace.json' = $marketplace
        }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape($Expected))
    }

    It 'passes dependencies from our marketplace, an allowed marketplace, or a plugin it lists' {
        $manifest = '{ "name": "al-agentic-dev", "version": "1.0.0", "mcpServers": { "svc": { "type": "stdio" } }, "dependencies": [ "mattpocock-skills@claude-plugins-official", "bcquality@bcquality", "helper", "al-agentic-dev@al-agentic-dev" ] }'
        $marketplace = '{ "name": "al-agentic-dev", "allowCrossMarketplaceDependenciesOn": ["claude-plugins-official", "bcquality"], "plugins": [ { "name": "al-agentic-dev", "source": "./" }, { "name": "helper", "source": { "source": "url", "url": "https://github.com/example/helper.git" } } ] }'
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'dependency-ok') -Overrides @{
            '.claude-plugin/plugin.json'      = $manifest
            '.claude-plugin/marketplace.json' = $marketplace
        }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Text
    }

    It 'fails malformed JSON anywhere in the tree' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'malformed')
        Set-Content -LiteralPath (Join-Path $root 'skills' 'broken.json') -Value '{ "unclosed": ' -Encoding utf8

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'FAIL:.*broken\.json'
    }

    It 'skips the eval copies of the Base plugins and the eval results, but not the eval cases' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'eval-skip')
        foreach ($relative in @('.base-plugins/bcquality/broken.json', 'evals/results/run/broken.json')) {
            $path = Join-Path $root $relative
            New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($path)) -Force | Out-Null
            Set-Content -LiteralPath $path -Value '{ "unclosed": ' -Encoding utf8
        }

        $result = Invoke-JsonValidator -Root $root
        $result.ExitCode | Should -Be 0 -Because $result.Text
        $result.Text | Should -Not -Match 'broken\.json'

        New-Item -ItemType Directory -Path (Join-Path $root 'evals' 'al-build') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'evals' 'al-build' 'case.json') -Value '{ "unclosed": ' -Encoding utf8

        $result = Invoke-JsonValidator -Root $root
        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'FAIL:.*case\.json'
    }
}

Describe 'Validate-Json process wrapper' -Tag 'Process' {
    It 'returns zero for a valid plugin surface' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'process-good')

        (Invoke-JsonValidatorProcess -Root $root).ExitCode | Should -Be 0
    }

    It 'returns nonzero for an invalid plugin surface' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'process-bad') -Remove @('.claude-plugin/plugin.json')

        (Invoke-JsonValidatorProcess -Root $root).ExitCode | Should -Be 1
    }
}
