#Requires -Version 7.2

# The module gate's switch and wiring: Get-BuildConfig's resolution of
# moduleGate.enabled (omitted -> off, ALBT_MODULE_GATE_ENABLED overrides the
# file) and moduleGate.rootNamespace, what init.ps1 writes, the moduleGate block
# in summary.json, and test.ps1 running the check before the first compile.
# The check itself is covered by ModuleCheck.Tests.ps1.

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    $script:savedModuleGateEnv = $env:ALBT_MODULE_GATE_ENABLED

    function Set-ModuleGateConfig {
        param(
            [Parameter(Mandatory)][string]$RepoRoot,
            [hashtable]$ModuleGate
        )

        $config = [ordered]@{ appDir = 'app'; testApps = @('test') }
        if ($ModuleGate) { $config.moduleGate = $ModuleGate }
        $config | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $RepoRoot 'al-build.json')
    }
}

AfterAll {
    if ($null -ne $script:savedModuleGateEnv) {
        $env:ALBT_MODULE_GATE_ENABLED = $script:savedModuleGateEnv
    }
    else {
        Remove-Item Env:\ALBT_MODULE_GATE_ENABLED -ErrorAction SilentlyContinue
    }
}

Describe 'module gate switch resolution' {
    BeforeEach {
        $global:ModuleGateRepoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $global:ModuleGateRepoRoot -Force | Out-Null
        Push-Location $global:ModuleGateRepoRoot

        Mock git {
            $global:LASTEXITCODE = 0
            $global:ModuleGateRepoRoot
        } -ModuleName common
        Mock Get-BCAgentContainerName { 'bctest' } -ModuleName build-operations
        Mock Write-BuildMessage {} -ModuleName build-operations
        Remove-Item Env:\ALBT_MODULE_GATE_ENABLED -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item Env:\ALBT_MODULE_GATE_ENABLED -ErrorAction SilentlyContinue
        Pop-Location
        Remove-Variable ModuleGateRepoRoot -Scope Global -ErrorAction SilentlyContinue
    }

    It 'resolves off when al-build.json has no moduleGate block' {
        Set-ModuleGateConfig -RepoRoot $global:ModuleGateRepoRoot

        $config = Get-BuildConfig

        $config.ModuleGateEnabled | Should -BeFalse
        $config.ModuleGateRootNamespace | Should -Be ''
    }

    It 'resolves off when moduleGate omits enabled' {
        Set-ModuleGateConfig -RepoRoot $global:ModuleGateRepoRoot -ModuleGate @{ rootNamespace = 'Contoso.Sales' }

        (Get-BuildConfig).ModuleGateEnabled | Should -BeFalse
    }

    It 'resolves on from moduleGate.enabled and reads the trimmed root namespace' {
        Set-ModuleGateConfig -RepoRoot $global:ModuleGateRepoRoot -ModuleGate @{ enabled = $true; rootNamespace = ' Contoso.Sales ' }

        $config = Get-BuildConfig

        $config.ModuleGateEnabled | Should -BeTrue
        $config.ModuleGateRootNamespace | Should -Be 'Contoso.Sales'
    }

    It 'lets ALBT_MODULE_GATE_ENABLED=false override a true al-build.json' {
        Set-ModuleGateConfig -RepoRoot $global:ModuleGateRepoRoot -ModuleGate @{ enabled = $true; rootNamespace = 'Contoso.Sales' }
        $env:ALBT_MODULE_GATE_ENABLED = 'false'

        (Get-BuildConfig).ModuleGateEnabled | Should -BeFalse
    }

    It 'lets ALBT_MODULE_GATE_ENABLED=true turn the gate on when the file omits the block' {
        Set-ModuleGateConfig -RepoRoot $global:ModuleGateRepoRoot
        $env:ALBT_MODULE_GATE_ENABLED = 'true'

        (Get-BuildConfig).ModuleGateEnabled | Should -BeTrue
    }

    It 'rejects an ALBT_MODULE_GATE_ENABLED value that is not a boolean' {
        Set-ModuleGateConfig -RepoRoot $global:ModuleGateRepoRoot
        $env:ALBT_MODULE_GATE_ENABLED = 'maybe'

        { Get-BuildConfig } | Should -Throw
    }
}

Describe 'init.ps1 moduleGate block' -Tag 'Process' {
    BeforeAll {
        function Invoke-InitInRepo {
            param([Parameter(Mandatory)][hashtable]$AppJsonByDir)

            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            & git -C $root init --quiet 2>&1 | Out-Null
            foreach ($dir in $AppJsonByDir.Keys) {
                New-Item -ItemType Directory -Path (Join-Path $root $dir) -Force | Out-Null
                $AppJsonByDir[$dir] | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root $dir 'app.json')
            }
            Push-Location $root
            try { & pwsh -NoProfile -File (Join-Path $scriptsDir 'init.ps1') *> $null }
            finally { Pop-Location }
            return Get-Content -LiteralPath (Join-Path $root 'al-build.json') -Raw | ConvertFrom-Json
        }
    }

    It 'writes enabled true and the root namespace from the main app''s publisher and name' {
        $config = Invoke-InitInRepo @{
            'app'  = @{ publisher = 'Naveksa A/S'; name = 'Cad Connect 365'; dependencies = @() }
            'test' = @{ publisher = 'Naveksa A/S'; name = 'Cad Connect 365 Test'; dependencies = @() }
        }

        $config.moduleGate.enabled | Should -BeTrue
        $config.moduleGate.rootNamespace | Should -Be 'NaveksaAS.CadConnect365'
    }

    It 'writes enabled true with an empty root namespace when no app.json is found' {
        $config = Invoke-InitInRepo @{}

        $config.moduleGate.enabled | Should -BeTrue
        $config.moduleGate.rootNamespace | Should -Be ''
    }
}

Describe 'moduleGate block in summary.json' {
    It 'is written next to the coverage block' {
        $summaryPath = Join-Path $TestDrive 'summary.json'
        $moduleResult = [pscustomobject]@{
            Violations   = @([pscustomobject]@{ Rule = 1; File = 'app/src/A.al'; Line = 4; Message = 'Add a namespace.' })
            Warnings     = @()
            SkippedRules = @()
        }
        Import-Module (Join-Path $scriptsDir 'module-check.psm1') -Force -DisableNameChecking

        Write-TestSummary -Gate 'al-runner' -Results @() -CoverageBlock ([ordered]@{ enabled = $false }) `
            -ModuleGateBlock (ConvertTo-ModuleGateBlock -Enabled $true -Result $moduleResult) -Path $summaryPath

        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        $summary.coverage.enabled | Should -BeFalse
        $summary.moduleGate.enabled | Should -BeTrue
        $summary.moduleGate.violations[0].file | Should -Be 'app/src/A.al'
        $summary.moduleGate.violations[0].line | Should -Be 4
        $summary.moduleGate.warnings.Count | Should -Be 0
        $summary.moduleGate.skippedRules.Count | Should -Be 0
    }

    It 'is absent when the caller passes none, as the container gate does' {
        $summaryPath = Join-Path $TestDrive 'container-summary.json'

        Write-TestSummary -Gate 'container' -Results @() -CoverageBlock ([ordered]@{ enabled = $false }) -Path $summaryPath

        (Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json).PSObject.Properties.Name | Should -Not -Contain 'moduleGate'
    }
}

Describe 'test.ps1 module gate wiring' {
    BeforeAll {
        $script:gate = Get-Content (Join-Path $scriptsDir 'test.ps1') -Raw
    }

    It 'runs the module check, gated on the switch, before the first compile' {
        $script:gate | Should -Match 'Import-Module \(Join-Path \$PSScriptRoot ''module-check\.psm1''\)'
        $check = $script:gate.IndexOf('Invoke-ModuleCheck')
        $check | Should -BeGreaterThan 0
        $check | Should -BeLessThan $script:gate.IndexOf('Invoke-ALBuild')
        $script:gate | Should -Match '(?s)if \(\$config\.ModuleGateEnabled\) \{.*?Invoke-ModuleCheck'
    }

    It 'turns the gate red on a violation before anything compiles' {
        $script:gate | Should -Match '(?s)Violations\)\.Count -gt 0\) \{.*?\$gateOutcome = ''failed''\s+return\s+\}'
    }

    It 'passes every test app the gate compiles' {
        $script:gate | Should -Match 'TestAppDirs @\(\$config\.TestApps \+ \$config\.ContainerTestApps'
    }

    It 'hands the moduleGate block to the summary' {
        $script:gate | Should -Match 'ConvertTo-ModuleGateBlock'
        $script:gate | Should -Match '-ModuleGateBlock \$moduleGateBlock'
    }
}
