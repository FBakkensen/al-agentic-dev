#Requires -Version 7.2

# Covers the still-live coverage-enabled resolution surface: Get-BuildConfig's
# three-tier CoverageEnabled resolution (al-build.json coverage.enabled,
# ALBT_COVERAGE_ENABLED override, empty-testApps floor) and the parts of
# Resolve-CoverageEnabled not already asserted by TestModes.Tests.ps1 (which
# covers test.ps1's surface).

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    $script:savedCoverageEnv = $env:ALBT_COVERAGE_ENABLED

    function Set-CoverageConfig {
        param(
            [Parameter(Mandatory)]
            [string]$RepoRoot,

            [Parameter(Mandatory)]
            [bool]$Enabled,

            [string[]]$TestApps = @('test')
        )

        $config = [ordered]@{
            appDir   = 'app'
            testApps = @($TestApps)
            coverage = @{ enabled = $Enabled }
        }
        $config | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $RepoRoot 'al-build.json')
    }
}

AfterAll {
    if ($null -ne $script:savedCoverageEnv) {
        $env:ALBT_COVERAGE_ENABLED = $script:savedCoverageEnv
    }
    else {
        Remove-Item Env:\ALBT_COVERAGE_ENABLED -ErrorAction SilentlyContinue
    }
}

Describe 'coverage-enabled resolution' {
    BeforeEach {
        $global:CoverageResolutionRepoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $global:CoverageResolutionRepoRoot -Force | Out-Null
        Push-Location $global:CoverageResolutionRepoRoot

        Mock git {
            $global:LASTEXITCODE = 0
            $global:CoverageResolutionRepoRoot
        } -ModuleName common
        Mock Get-BCAgentContainerName { 'bctest' } -ModuleName build-operations
        Mock Write-BuildMessage {} -ModuleName build-operations
        Remove-Item Env:\ALBT_COVERAGE_ENABLED -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item Env:\ALBT_COVERAGE_ENABLED -ErrorAction SilentlyContinue
        Pop-Location
        Remove-Variable CoverageResolutionRepoRoot -Scope Global -ErrorAction SilentlyContinue
    }

    It 'resolves CoverageEnabled true from al-build.json coverage.enabled' {
        Set-CoverageConfig -RepoRoot $global:CoverageResolutionRepoRoot -Enabled $true

        (Get-BuildConfig).CoverageEnabled | Should -BeTrue
    }

    It 'lets ALBT_COVERAGE_ENABLED=false override a true al-build.json config' {
        Set-CoverageConfig -RepoRoot $global:CoverageResolutionRepoRoot -Enabled $true
        $env:ALBT_COVERAGE_ENABLED = 'false'

        (Get-BuildConfig).CoverageEnabled | Should -BeFalse
    }

    It 'forces CoverageEnabled false when testApps is empty regardless of JSON or environment' {
        Set-CoverageConfig -RepoRoot $global:CoverageResolutionRepoRoot -Enabled $true -TestApps @()
        $env:ALBT_COVERAGE_ENABLED = 'true'

        (Get-BuildConfig).CoverageEnabled | Should -BeFalse
    }

    It 'lets explicit -Coverage win over a configured false' {
        Set-CoverageConfig -RepoRoot $global:CoverageResolutionRepoRoot -Enabled $false
        $config = Get-BuildConfig

        Resolve-CoverageEnabled -Config $config -Coverage | Should -BeTrue
    }
}
