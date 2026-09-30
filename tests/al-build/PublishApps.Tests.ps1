#Requires -Version 7.2

# publish-apps.ps1 runs under Set-StrictMode -Version Latest, so a reference to a
# config property Get-BuildConfig no longer exposes throws at runtime — and the
# script has no live-container test to catch it. These surface assertions pin
# the script to the current config model.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'publish-apps.ps1'
    $script:Content = Get-Content -LiteralPath $script:ScriptPath -Raw
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'build-operations.psm1') -Force -DisableNameChecking
}

Describe 'publish-apps.ps1 surface' {
    It 'references only properties Get-BuildConfig exposes' {
        $configProps = @('AppDir', 'TestApps', 'ContainerTestApps', 'ContainerName')
        $referenced = [regex]::Matches($script:Content, '\$config\.(\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $referenced | Should -Not -BeNullOrEmpty
        foreach ($prop in $referenced) {
            $prop | Should -BeIn $configProps
        }
    }

    It 'carries no retired unit-test-app vocabulary' {
        $script:Content | Should -Not -Match 'UnitTestApp|unitTestApp|UnitTestInitEvents|publish-unit-'
    }

    It 'derives the secondary publish set from Get-CompileTargets' {
        $script:Content | Should -Match 'Get-CompileTargets -Config \$config'
    }

    It 'parses under strict mode' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }
}
