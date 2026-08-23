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
        $rendererRoot = Join-Path $script:SkillsRoot 'al-event-model' 'bpmn-renderer'
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
        $contract = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-event-model' 'BPMN.md') -Raw

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

    It 'maps every implementation before deciding whether Level 2 belongs on the Feature' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $arc42 = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'SKILL.md') -Raw
        $template = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'ARC42.md') -Raw
        $review = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-review' 'SKILL.md') -Raw

        $implement | Should -Match 'connected-object change map'
        $implement | Should -Match 'every changed production object'
        $implement | Should -Match 'simple module may need the implementation map but no Feature Level 2'
        $arc42 | Should -Match 'change overlay on the Building Block View'
        $arc42 | Should -Match 'Level 1 impact overview'
        $template | Should -Match 'executable-item receipt and comment keep the change overlay'
        $review | Should -Match 'implementation change map includes every changed production object'
    }

    It 'contains no shipped skill reference to al-visualize' {
        $references = Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse |
            Select-String -Pattern '/al-visualize'

        @($references).Count | Should -Be 0
    }
}
