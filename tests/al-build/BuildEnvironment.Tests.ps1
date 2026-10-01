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

Describe 'Release pin check stays out of the offline gate' {
    It 'test.ps1 calls neither the pin check nor download-baseline.ps1' {
        $path = Join-Path $script:ScriptsDir 'test.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
        $commandNames = @(Get-CommandNames -Path $path)
        $commandNames | Should -Not -Contain 'Test-ReleasePin'
        $commandNames | Should -Not -Contain 'Find-PackageInFeed'
        $commandNames | Should -Not -Contain 'Get-PackageFeedMetadata'

        $strings = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) |
            ForEach-Object { $_.Value })
        @($strings | Where-Object { $_ -match 'download-baseline|symbol-feed' }) | Should -HaveCount 0
    }
}

Describe 'No GitHub CLI command under skills/al-build' {
    It 'invokes no gh command from a script or module' {
        $files = @(Get-ChildItem -Path (Join-Path $script:ScriptsDir '..') -Recurse -File |
            Where-Object { $_.Extension -in '.ps1', '.psm1' })
        $files | Should -Not -BeNullOrEmpty

        $hits = @(foreach ($file in $files) {
            @(Get-CommandNames -Path $file.FullName) | Where-Object { $_ -in 'gh', 'gh.exe' } | ForEach-Object { $file.Name }
        })
        @($hits) | Should -HaveCount 0 -Because "gh calls remain in: $(@($hits) -join ', ')"
    }

    It 'sees a gh call when one is there' {
        $probe = Join-Path $TestDrive 'probe.ps1'
        Set-Content -LiteralPath $probe -Value '$info = gh release view --json tagName; & gh auth status'
        @(Get-CommandNames -Path $probe | Where-Object { $_ -eq 'gh' }) | Should -HaveCount 2
    }
}
