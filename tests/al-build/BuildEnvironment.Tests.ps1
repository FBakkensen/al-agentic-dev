#Requires -Version 7.2

# Regression guard: container-test.ps1 loaded al-build.json with
# Get-BuildConfig but never applied it with Set-BuildEnvironment, so
# $env:RULESET_PATH stayed empty, Invoke-ALBuild omitted /ruleset:, and the
# consumer's suppressed rules fired under warnAsError before the container was
# touched. Every script that loads the config applies it.

BeforeAll {
    $script:ScriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')

    function Get-CommandNames {
        param([Parameter(Mandatory)][string]$Path)
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty
        @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) |
            ForEach-Object { $_.GetCommandName() })
    }

    $script:ConfigLoaders = @(Get-ChildItem -Path $script:ScriptsDir -Filter '*.ps1' | Where-Object {
        (Get-CommandNames -Path $_.FullName) -contains 'Get-BuildConfig'
    })
}

Describe 'Scripts that load al-build.json apply it to the build environment' {
    It 'finds container-test.ps1 among the Get-BuildConfig callers' {
        $script:ConfigLoaders.Name | Should -Contain 'container-test.ps1'
    }

    It 'calls Set-BuildEnvironment in every script that calls Get-BuildConfig' {
        $missing = @($script:ConfigLoaders | Where-Object {
            (Get-CommandNames -Path $_.FullName) -notcontains 'Set-BuildEnvironment'
        } | ForEach-Object Name)

        $missing | Should -BeNullOrEmpty -Because "Get-BuildConfig without Set-BuildEnvironment leaves RULESET_PATH and ALBT_* empty: $($missing -join ', ')"
    }
}
