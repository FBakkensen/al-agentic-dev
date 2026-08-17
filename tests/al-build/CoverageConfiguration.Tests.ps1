#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    $script:DefaultConfigPath = Resolve-Path (
        Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'config' 'al-build.json'
    )

    function Set-CoverageConfig {
        param(
            [Parameter(Mandatory)]
            [string]$RepoRoot,

            [AllowNull()]
            [Nullable[bool]]$Enabled,

            [string[]]$TestApps = @('test')
        )

        $config = [ordered]@{
            appDir   = 'app'
            testApps = @($TestApps)
        }
        if ($null -ne $Enabled) {
            $config.coverage = @{ enabled = [bool]$Enabled }
        }
        $config | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $RepoRoot 'al-build.json')
    }

    function Get-CoverageConfig {
        param(
            [Nullable[bool]]$JsonEnabled,
            [AllowNull()]
            [object]$EnvironmentValue,
            [string[]]$TestApps = @('test'),
            [hashtable]$Overrides = @{}
        )

        Set-CoverageConfig -RepoRoot $global:CoverageConfigRepoRoot -Enabled $JsonEnabled `
            -TestApps $TestApps
        if ($null -eq $EnvironmentValue) {
            Remove-Item Env:\ALBT_COVERAGE_ENABLED -ErrorAction SilentlyContinue
        } else {
            $env:ALBT_COVERAGE_ENABLED = $EnvironmentValue
        }
        Get-BuildConfig -Overrides $Overrides
    }
}

Describe 'coverage configuration' {
    BeforeEach {
        $global:CoverageConfigRepoRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $global:CoverageConfigRepoRoot -Force | Out-Null
        Push-Location $global:CoverageConfigRepoRoot

        Mock git {
            $global:LASTEXITCODE = 0
            $global:CoverageConfigRepoRoot
        } -ModuleName common
        Mock Get-BCAgentContainerName { 'bctest' } -ModuleName build-operations
        Mock Write-BuildMessage {} -ModuleName build-operations
        Remove-Item Env:\ALBT_COVERAGE_ENABLED -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item Env:\ALBT_COVERAGE_ENABLED -ErrorAction SilentlyContinue
        Pop-Location
        Remove-Variable CoverageConfigRepoRoot -Scope Global -ErrorAction SilentlyContinue
    }

    It 'enables coverage in the new-project template' {
        $defaultConfig = Get-Content -LiteralPath $script:DefaultConfigPath -Raw | ConvertFrom-Json

        $defaultConfig.coverage.enabled | Should -BeTrue
    }

    It 'uses false when the repo JSON omits coverage and no higher layer exists' {
        (Get-CoverageConfig -JsonEnabled $null -EnvironmentValue $null).CoverageEnabled |
            Should -BeFalse
    }

    It 'uses the repo JSON value when no higher layer exists' {
        (Get-CoverageConfig -JsonEnabled $true -EnvironmentValue $null).CoverageEnabled |
            Should -BeTrue
    }

    It 'lets the environment override repo JSON' -TestCases @(
        @{ EnvironmentValue = 'true'; JsonEnabled = $false; Expected = $true }
        @{ EnvironmentValue = 'false'; JsonEnabled = $true; Expected = $false }
        @{ EnvironmentValue = '1'; JsonEnabled = $false; Expected = $true }
        @{ EnvironmentValue = '0'; JsonEnabled = $true; Expected = $false }
        @{ EnvironmentValue = 'TRUE'; JsonEnabled = $false; Expected = $true }
    ) {
        param($EnvironmentValue, $JsonEnabled, $Expected)

        (Get-CoverageConfig -JsonEnabled $JsonEnabled -EnvironmentValue $EnvironmentValue).CoverageEnabled |
            Should -Be $Expected
    }

    It 'rejects malformed environment boolean "<EnvironmentValue>" with the variable and value' -TestCases @(
        @{ EnvironmentValue = 'yes' }
        @{ EnvironmentValue = '' }
        @{ EnvironmentValue = ' true ' }
    ) {
        param($EnvironmentValue)

        {
            Get-CoverageConfig -JsonEnabled $false -EnvironmentValue $EnvironmentValue
        } | Should -Throw -ExpectedMessage (
            "Environment variable ALBT_COVERAGE_ENABLED must be one of: true, false, 1, 0. Received: '$EnvironmentValue'."
        )
    }

    It 'lets explicit coverage override configured false' {
        $config = Get-CoverageConfig -JsonEnabled $false -EnvironmentValue 'false'

        Resolve-CoverageEnabled -Config $config -Coverage | Should -BeTrue
    }

    It 'skips coverage from JSON, environment, and overrides when testApps is empty' -TestCases @(
        @{ JsonEnabled = $true; EnvironmentValue = $null; Overrides = @{} }
        @{ JsonEnabled = $false; EnvironmentValue = 'true'; Overrides = @{} }
        @{ JsonEnabled = $false; EnvironmentValue = 'false'; Overrides = @{ coverageEnabled = $true } }
    ) {
        param($JsonEnabled, $EnvironmentValue, $Overrides)

        $config = Get-CoverageConfig -JsonEnabled $JsonEnabled -EnvironmentValue $EnvironmentValue `
            -TestApps @() -Overrides $Overrides

        $config.CoverageEnabled | Should -BeFalse
        Resolve-CoverageEnabled -Config $config | Should -BeFalse
    }

    It 'does not parse environment coverage when testApps is empty' {
        $config = Get-CoverageConfig -JsonEnabled $true -EnvironmentValue 'invalid' -TestApps @()

        $config.CoverageEnabled | Should -BeFalse
    }

    It 'skips explicit coverage when testApps is empty' {
        $config = Get-CoverageConfig -JsonEnabled $false -EnvironmentValue $null -TestApps @()

        Resolve-CoverageEnabled -Config $config -Coverage | Should -BeFalse
    }

    It 'does not parse lower-precedence environment coverage when explicit coverage is present' {
        $config = Get-CoverageConfig -JsonEnabled $false -EnvironmentValue 'invalid' `
            -Overrides @{ coverageEnabled = $true }

        Resolve-CoverageEnabled -Config $config -Coverage | Should -BeTrue
    }

    It 'keeps the coverage override key separate from other nested enabled settings' {
        $config = Get-CoverageConfig -JsonEnabled $false -EnvironmentValue $null -Overrides @{
            enabled         = $true
            coverageEnabled = $false
        }

        $config.CoverageEnabled | Should -BeFalse
        $config.BreakingChangeEnabled | Should -BeTrue
    }

    It 'ignores configured coverage for a unit-only run' {
        $config = Get-CoverageConfig -JsonEnabled $true -EnvironmentValue 'true'

        $config.CoverageEnabled | Should -BeTrue
        Resolve-CoverageEnabled -Config $config -UnitTestOnly | Should -BeFalse
    }

    It 'does not parse configured environment coverage for a unit-only run' {
        $config = Get-CoverageConfig -JsonEnabled $true -EnvironmentValue 'invalid' `
            -Overrides @{ coverageEnabled = $false }

        Resolve-CoverageEnabled -Config $config -UnitTestOnly | Should -BeFalse
    }

    It 'rejects explicit coverage for a unit-only run' {
        $config = Get-CoverageConfig -JsonEnabled $false -EnvironmentValue $null

        {
            Resolve-CoverageEnabled -Config $config -Coverage -UnitTestOnly
        } | Should -Throw -ExpectedMessage '-Coverage cannot be combined with -UnitTestOnly.'
    }
}
