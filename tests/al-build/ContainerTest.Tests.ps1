#Requires -Version 7.2

# Unit tests for container-test.ps1 — the explicit-only container test
# surface. These run without a BC container and without BcContainerHelper
# installed: only the two failure paths that must resolve before any
# container work starts (empty containerTestApps, missing compiled .app) are
# in scope, plus the parameter surface. A live container run is out of scope
# for this suite — this machine's golden container may not exist.

BeforeAll {
    $script:ScriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    $script:ContainerTestScript = Join-Path $script:ScriptsDir 'container-test.ps1'
    $script:Pwsh = Join-Path $PSHOME 'pwsh.exe'

    Import-Module (Join-Path $script:ScriptsDir 'common.psm1') -Force -DisableNameChecking

    function New-ContainerTestFixture {
        <#
        .SYNOPSIS
            Build a minimal consumer repo fixture: al-build.json, a main app
            dir, and one container test app dir, each with app.json.
        .PARAMETER MainAppCompiled
            When set, drop a compiled .app (Get-OutputPath's naming
            convention) into the main app dir.
        .PARAMETER ContainerTestAppCompiled
            When set, drop a compiled .app into the container test app dir.
        .PARAMETER ContainerTestApps
            containerTestApps entries to write into al-build.json. Empty
            reproduces the unconfigured-gate failure path.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [string[]]$ContainerTestApps = @('containertest'),
            [switch]$MainAppCompiled,
            [switch]$ContainerTestAppCompiled
        )

        New-Item -ItemType Directory -Path $Root -Force | Out-Null

        $appDir = Join-Path $Root 'app'
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null
        [ordered]@{
            id        = '11111111-1111-1111-1111-111111111111'
            name      = 'MainApp'
            publisher = 'Test'
            version   = '1.0.0.0'
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'app.json') -Encoding UTF8
        if ($MainAppCompiled) {
            $mainAppFile = Get-OutputPath $appDir
            Set-Content -LiteralPath $mainAppFile -Value 'fake' -Encoding UTF8
        }

        foreach ($dirName in $ContainerTestApps) {
            $ctDir = Join-Path $Root $dirName
            New-Item -ItemType Directory -Path $ctDir -Force | Out-Null
            [ordered]@{
                id        = '22222222-2222-2222-2222-222222222222'
                name      = 'ContainerTestApp'
                publisher = 'Test'
                version   = '1.0.0.0'
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ctDir 'app.json') -Encoding UTF8
            if ($ContainerTestAppCompiled) {
                $ctAppFile = Get-OutputPath $ctDir
                Set-Content -LiteralPath $ctAppFile -Value 'fake' -Encoding UTF8
            }
        }

        [ordered]@{
            appDir            = 'app'
            testApps          = @()
            containerTestApps = @($ContainerTestApps)
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'al-build.json') -Encoding UTF8
    }

    function Invoke-ContainerTestProcess {
        <#
        .SYNOPSIS
            Run container-test.ps1 as a fresh pwsh.exe process rooted at
            $Root, so Get-GitRepoRoot's cwd fallback resolves al-build.json
            from the fixture and never this repo's own config.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [switch]$Force
        )
        $forceArg = if ($Force) { ' -Force' } else { '' }
        $command = "Set-Location -LiteralPath '$Root'; & '$script:ContainerTestScript'$forceArg"
        $output = & $script:Pwsh -NoProfile -Command $command 2>&1
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = @($output | ForEach-Object { "$_" })
        }
    }
}

Describe 'container-test.ps1 parameter surface' {
    It 'exposes only Force beyond common parameters' {
        $cmd = Get-Command $script:ContainerTestScript
        $cmd.Parameters.Keys | Should -Contain 'Force'
        foreach ($gone in 'Coverage', 'Test') {
            $cmd.Parameters.Keys | Should -Not -Contain $gone
        }
    }
}

Describe 'container-test.ps1 explicit-only failure paths' {
    It 'fails before any BcContainerHelper import when containerTestApps is empty' {
        $root = Join-Path $TestDrive 'empty-config'
        New-ContainerTestFixture -Root $root -ContainerTestApps @() -MainAppCompiled

        $result = Invoke-ContainerTestProcess -Root $root

        $result.ExitCode | Should -Be 1
        ($result.Output -join "`n") | Should -Match 'containerTestApps'
        ($result.Output -join "`n") | Should -Not -Match 'BcContainerHelper'
    }

    It 'fails naming the app and pointing at test.ps1 when a container test app has no compiled .app' {
        $root = Join-Path $TestDrive 'missing-artifact'
        New-ContainerTestFixture -Root $root -ContainerTestApps @('containertest') `
            -MainAppCompiled -ContainerTestAppCompiled:$false

        $result = Invoke-ContainerTestProcess -Root $root

        $result.ExitCode | Should -Be 1
        ($result.Output -join "`n") | Should -Match 'containertest'
        ($result.Output -join "`n") | Should -Match 'test\.ps1'
        ($result.Output -join "`n") | Should -Not -Match 'BcContainerHelper'
    }

    It 'fails naming the main app when the main app itself has no compiled .app' {
        $root = Join-Path $TestDrive 'missing-main-artifact'
        New-ContainerTestFixture -Root $root -ContainerTestApps @('containertest') `
            -MainAppCompiled:$false -ContainerTestAppCompiled

        $result = Invoke-ContainerTestProcess -Root $root

        $result.ExitCode | Should -Be 1
        ($result.Output -join "`n") | Should -Match "'app'"
        ($result.Output -join "`n") | Should -Match 'test\.ps1'
        ($result.Output -join "`n") | Should -Not -Match 'BcContainerHelper'
    }
}
