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
