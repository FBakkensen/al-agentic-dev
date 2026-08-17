#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    $script:BuildOperationsPath = Join-Path $scriptsDir 'build-operations.psm1'
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module $script:BuildOperationsPath -Force -DisableNameChecking
}

Describe 'Get-BuildConfig uses Get-GitRepoRoot' {
    It 'has no nested Get-GitRepoRoot' {
        $src = Get-Content -LiteralPath $script:BuildOperationsPath -Raw
        $src | Should -Not -Match 'function Get-GitRepoRoot'
        $src | Should -Match 'Get-GitRepoRoot'
    }

    Context 'when git cannot name the root' {
        BeforeEach {
            $script:ProbeRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $script:ProbeRoot -Force | Out-Null
            Push-Location $script:ProbeRoot

            Mock git {
                $global:LASTEXITCODE = 128
            } -ModuleName common
            Mock Get-BCAgentContainerName { 'bctest' } -ModuleName build-operations
            Mock Write-BuildMessage {} -ModuleName build-operations
        }

        AfterEach {
            Pop-Location
        }

        It 'loads al-build.json from the current directory' {
            @{
                appDir   = 'app'
                testApps = @('test')
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:ProbeRoot 'al-build.json')

            $cfg = Get-BuildConfig
            $cfg.AppDir | Should -Be (Join-Path $script:ProbeRoot 'app')
        }

        It 'fails with the path that was tried, not "not in git repo"' {
            $expected = Join-Path $script:ProbeRoot 'al-build.json'
            $err = { Get-BuildConfig } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike "*$expected*"
            $err.Exception.Message | Should -Not -BeLike '*not in git repo*'
        }
    }
}
