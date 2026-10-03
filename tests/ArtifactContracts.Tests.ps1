#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:SkillsRoot = Join-Path $script:RepoRoot 'skills'
}

Describe 'Architecture artifact contracts' {
    It 'replaces the generic visualization skill with arc42' {
        Test-Path -LiteralPath (Join-Path $script:SkillsRoot 'al-visualize') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'SKILL.md') | Should -BeTrue
    }

    It 'pins the BPMN renderer dependencies' {
        $rendererRoot = Join-Path $script:SkillsRoot 'al-to-spec' 'bpmn-renderer'
        $package = Get-Content -LiteralPath (Join-Path $rendererRoot 'package.json') -Raw | ConvertFrom-Json
        $lock = Get-Content -LiteralPath (Join-Path $rendererRoot 'package-lock.json') -Raw | ConvertFrom-Json -AsHashtable

        $package.dependencies.'bpmn-to-image' | Should -Be '0.10.0'
        $package.dependencies.'bpmn-js' | Should -Be '18.25.1'
        $package.dependencies.puppeteer | Should -Be '24.34.0'
        $lock.packages.'node_modules/bpmn-to-image'.version | Should -Be '0.10.0'
        $lock.packages.'node_modules/bpmn-js'.version | Should -Be '18.25.1'
        $lock.packages.'node_modules/puppeteer'.version | Should -Be '24.34.0'
    }

    It 'keeps BPMN source authoritative and requires local HTML review' {
        $contract = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-to-spec' 'BPMN.md') -Raw

        $contract | Should -Match '\.bpmn.*only editable process source'
        $contract | Should -Match 'bpmn-to-image'
        $contract | Should -Match 'process\.html'
        $contract | Should -Match 'process\.bpmn;process\.svg,process\.png'
        $contract | Should -Match '\$env:PUPPETEER_EXECUTABLE_PATH.+npm exec'
        $contract | Should -Match 'never pass `--no-footer`'
    }

    It 'ships the attributed arc42 v9 template subset' {
        $template = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'ARC42.md') -Raw

        $template | Should -Match 'arc42 Template Version 9\.0-EN, July 2025'
        $template | Should -Match 'Creative Commons Attribution-ShareAlike 4\.0'
        $template | Should -Match 'Whitebox Overall System'
        $template | Should -Match 'Purpose/Responsibility'
        $template | Should -Match 'Important Interfaces'
        $template | Should -Match 'Runtime View'
    }

    It 'maps every implementation before deciding whether Level 2 belongs on the Original work item' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $arc42 = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'SKILL.md') -Raw
        $template = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'ARC42.md') -Raw
        $review = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-review' 'SKILL.md') -Raw

        $implement | Should -Match 'connected-object change map'
        $implement | Should -Match 'every changed production object'
        $implement | Should -Match 'simple module may need the implementation map but no Original work item Level 2'
        $arc42 | Should -Match 'change overlay on the Building Block View'
        $arc42 | Should -Match 'Level 1 impact overview'
        $template | Should -Match 'executable-item receipt and comment keep the change overlay'
        $review | Should -Match 'implementation change map includes every changed production object'
    }

    It 'owns Azure DevOps attachment upload in one skill' {
        $attachmentSkill = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-azure-devops-attachments' 'SKILL.md') -Raw

        $attachmentSkill | Should -Match 'az account get-access-token'
        $attachmentSkill | Should -Match '--tenant 7f33d80b-fe48-47f4-a90d-4cae5c190f47'
        $attachmentSkill | Should -Match 'az login --tenant 7f33d80b-fe48-47f4-a90d-4cae5c190f47'
        $attachmentSkill | Should -Match '--allow-no-subscriptions'
        $attachmentSkill | Should -Match 'application/octet-stream'
        $attachmentSkill | Should -Match "relation-type 'Attached File'"
        $attachmentSkill | Should -Match 'removing spaces'
        $attachmentSkill | Should -Match 'CLI name `Attached File` and the WIT name `AttachedFile` both match'
        $attachmentSkill | Should -Match 'apply the same relation-type normalization'
        $attachmentSkill | Should -Match 'WIT JSON Patch with `test /rev`'
        $attachmentSkill | Should -Match 'remove matching `/relations/<index>` paths in descending order'
        $attachmentSkill | Should -Match 'work-item show --expand relations'
        $attachmentSkill | Should -Match 'Authentication failure never becomes a manual-upload handoff'

        foreach ($caller in @('al-to-spec', 'al-implement', 'al-improve-codebase-architecture', 'al-simplify')) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $caller 'SKILL.md') -Raw
            $content | Should -Match '▶ haiku · attach .* as the Tracker doc in docs/agents/issue-tracker\.md says → verified attachment URLs'
            $content | Should -Not -Match 'manual attach'
        }
    }

    It 'runs Pester once with compact mode-aware output' {
        $runner = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'scripts' 'Invoke-Tests.ps1') -Raw
        $instructions = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'CLAUDE.md') -Raw

        ([regex]::Matches($runner, '(?m)^\s*Invoke-Pester -Configuration ')).Count | Should -Be 1
        $runner | Should -Match '\$config\.Output\.Verbosity = ''None'''
        $runner | Should -Match '\$config\.Filter\.ExcludeTag = @\(''Process'', ''LiveFixture''\)'
        $runner | Should -Match '''Process''\s*\{\s*\$config\.Filter\.Tag = @\(''Process''\)'
        $runner | Should -Match '''LiveFixture''\s*\{\s*\$config\.Filter\.Tag = @\(''LiveFixture''\)'
        $instructions | Should -Match 'one `haiku` `Agent`'
        $instructions | Should -Match 'runs `scripts/Invoke-Tests\.ps1` once'
    }

    It 'contains no shipped skill reference to al-visualize' {
        $references = Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse |
            Select-String -Pattern '/al-visualize'

        @($references).Count | Should -Be 0
    }
}
