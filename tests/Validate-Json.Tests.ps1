#Requires -Version 7.2

BeforeAll {
    $script:ValidatorPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Validate-Json.ps1')).Path

    function New-PluginRepo {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [hashtable]$Overrides = @{},

            [string[]]$Remove = @()
        )

        $files = @{
            'plugin.json'                     = @'
{
  "name": "al-agentic-dev",
  "description": "Agentic AL and Business Central development skills.",
  "version": "1.0.0",
  "skills": "skills/",
  "agents": "agents/",
  "mcpServers": ".mcp.json"
}
'@
            '.mcp.json'                       = @'
{
  "mcpServers": {
    "nab-al-tools": {
      "type": "stdio",
      "command": "npx",
      "tools": ["initialize", "refreshXlf"]
    }
  }
}
'@
            '.github/plugin/marketplace.json' = @'
{
  "name": "al-agentic-dev",
  "plugins": [
    { "name": "al-agentic-dev", "source": "./", "version": "1.0.0" }
  ]
}
'@
        }
        foreach ($key in $Overrides.Keys) { $files[$key] = $Overrides[$key] }
        foreach ($key in $Remove) { $files.Remove($key) }

        New-Item -ItemType Directory -Path (Join-Path $Root 'skills') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root 'agents') -Force | Out-Null
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

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $Root 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
}

Describe 'Validate-Json plugin surface' {
    It 'passes a well-formed plugin surface' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'good')

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'All JSON files validated successfully'
    }

    It 'fails when a plugin surface file is missing' -TestCases @(
        @{ Case = 'plugin'; Remove = 'plugin.json'; Expected = 'plugin\.json is missing' }
        @{ Case = 'mcp'; Remove = '.mcp.json'; Expected = '\.mcp\.json is missing' }
        @{ Case = 'marketplace'; Remove = '.github/plugin/marketplace.json'; Expected = 'marketplace\.json is missing' }
    ) {
        param($Case, $Remove, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "missing-$Case") -Remove @($Remove)

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails when a manifest path does not exist on disk' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'path-absent')
        Remove-Item (Join-Path $root 'agents') -Recurse -Force

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'agents path does not exist: agents/'
    }

    It 'fails when the manifest drops a required field' -TestCases @(
        @{ Case = 'name'; Json = '{ "version": "1.0.0", "skills": "skills/", "agents": "agents/", "mcpServers": ".mcp.json" }'; Expected = 'name must be non-empty' }
        @{ Case = 'version'; Json = '{ "name": "al-agentic-dev", "skills": "skills/", "agents": "agents/", "mcpServers": ".mcp.json" }'; Expected = 'version must be non-empty' }
        @{ Case = 'skills'; Json = '{ "name": "al-agentic-dev", "version": "1.0.0", "agents": "agents/", "mcpServers": ".mcp.json" }'; Expected = 'skills must name a path' }
    ) {
        param($Case, $Json, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "manifest-$Case") -Overrides @{ 'plugin.json' = $Json }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails an MCP server without a type or a tools allowlist' -TestCases @(
        @{ Case = 'no-type'; Json = '{ "mcpServers": { "svc": { "tools": ["a"] } } }'; Expected = "server 'svc' must carry a type" }
        @{ Case = 'no-tools'; Json = '{ "mcpServers": { "svc": { "type": "stdio" } } }'; Expected = "server 'svc' must carry a non-empty tools allowlist" }
        @{ Case = 'empty-tools'; Json = '{ "mcpServers": { "svc": { "type": "stdio", "tools": [] } } }'; Expected = "server 'svc' must carry a non-empty tools allowlist" }
        @{ Case = 'no-servers'; Json = '{ "mcpServers": {} }'; Expected = 'must carry at least one server' }
    ) {
        param($Case, $Json, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "mcp-$Case") -Overrides @{ '.mcp.json' = $Json }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails a marketplace entry whose source is absent or whose name mismatches' -TestCases @(
        @{ Case = 'source-absent'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "al-agentic-dev", "source": "./missing/" } ] }'; Expected = 'source does not exist: \./missing/' }
        @{ Case = 'name-mismatch'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "other-plugin", "source": "./" } ] }'; Expected = "does not match the manifest name 'al-agentic-dev'" }
        @{ Case = 'no-entries'; Json = '{ "name": "al-agentic-dev", "plugins": [] }'; Expected = 'plugins must carry at least one entry' }
        @{ Case = 'version-mismatch'; Json = '{ "name": "al-agentic-dev", "plugins": [ { "name": "al-agentic-dev", "source": "./", "version": "9.9.9" } ] }'; Expected = "version '9\.9\.9' does not match the manifest version '1\.0\.0'" }
        @{ Case = 'metadata-version-mismatch'; Json = '{ "name": "al-agentic-dev", "metadata": { "version": "8.8.8" }, "plugins": [ { "name": "al-agentic-dev", "source": "./", "version": "1.0.0" } ] }'; Expected = "metadata version '8\.8\.8' does not match the manifest version '1\.0\.0'" }
    ) {
        param($Case, $Json, $Expected)

        $root = New-PluginRepo -Root (Join-Path $TestDrive "market-$Case") -Overrides @{ '.github/plugin/marketplace.json' = $Json }

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match $Expected
    }

    It 'fails malformed JSON anywhere in the tree' {
        $root = New-PluginRepo -Root (Join-Path $TestDrive 'malformed')
        Set-Content -LiteralPath (Join-Path $root 'skills' 'broken.json') -Value '{ "unclosed": ' -Encoding utf8

        $result = Invoke-JsonValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'FAIL:.*broken\.json'
    }
}
