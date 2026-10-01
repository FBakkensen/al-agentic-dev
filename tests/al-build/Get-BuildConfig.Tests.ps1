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

Describe 'Get-BuildConfig config model' {
    BeforeEach {
        # Env beats al-build.json, and Set-BuildEnvironment writes ALBT_* into this process: snapshot the
        # environment, start with both breakingChange overrides unset, and restore it in AfterEach.
        $script:SavedEnvironment = [System.Environment]::GetEnvironmentVariables()
        Remove-Item Env:\ALBT_RELEASE_APP_DIR, Env:\ALBT_BASELINE_CACHE_PATH -ErrorAction SilentlyContinue
        $script:ProbeRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:ProbeRoot -Force | Out-Null
        Push-Location $script:ProbeRoot
        $configPath = Join-Path $script:ProbeRoot 'al-build.json'

        Mock git {
            $global:LASTEXITCODE = 128
        } -ModuleName common
        Mock Get-BCAgentContainerName { 'bctest' } -ModuleName build-operations
        Mock Write-BuildMessage {} -ModuleName build-operations
    }

    AfterEach {
        Pop-Location
        foreach ($name in @([System.Environment]::GetEnvironmentVariables().Keys)) {
            if (-not $script:SavedEnvironment.Contains($name)) { Remove-Item -LiteralPath "Env:\$name" }
        }
        foreach ($name in $script:SavedEnvironment.Keys) {
            if ([System.Environment]::GetEnvironmentVariable($name) -ne $script:SavedEnvironment[$name]) {
                Set-Item -LiteralPath "Env:\$name" -Value $script:SavedEnvironment[$name]
            }
        }
    }

    It 'resolves containerTestApps to absolute paths' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":["test"],"containerTestApps":["e2e"]}'
        $config = Get-BuildConfig
        @($config.ContainerTestApps).Count | Should -Be 1
        [System.IO.Path]::IsPathRooted($config.ContainerTestApps[0]) | Should -BeTrue
    }

    It 'defaults containerTestApps to empty' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":["test"]}'
        (Get-BuildConfig).ContainerTestApps | Should -HaveCount 0
    }

    It 'no longer exposes unitTestApp keys' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":["test"],"unitTestApp":"unit"}'
        $config = Get-BuildConfig
        $config.PSObject.Properties.Name | Should -Not -Contain 'UnitTestApp'
        $config.PSObject.Properties.Name | Should -Not -Contain 'UnitTestInitEvents'
    }

    It 'resolves breakingChange.releaseAppDir against the repo root' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":[],"breakingChange":{"releaseAppDir":"release/app"}}'
        (Get-BuildConfig).ReleaseAppDir | Should -Be (Join-Path $script:ProbeRoot 'release/app')
    }

    It 'keeps an absolute breakingChange.releaseAppDir as written' {
        $absolute = Join-Path $TestDrive 'elsewhere'
        @{ appDir = 'app'; testApps = @(); breakingChange = @{ releaseAppDir = $absolute } } |
            ConvertTo-Json | Set-Content -LiteralPath $configPath
        (Get-BuildConfig).ReleaseAppDir | Should -Be $absolute
    }

    It 'lets ALBT_RELEASE_APP_DIR override the al-build.json releaseAppDir' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":[],"breakingChange":{"releaseAppDir":"from-json"}}'
        $env:ALBT_RELEASE_APP_DIR = 'from-env'
        (Get-BuildConfig).ReleaseAppDir | Should -Be (Join-Path $script:ProbeRoot 'from-env')
    }

    It 'leaves ReleaseAppDir $null when al-build.json and the environment lack it' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":[],"breakingChange":{"enabled":true}}'
        $config = Get-BuildConfig
        $config.PSObject.Properties.Name | Should -Contain 'ReleaseAppDir'
        $config.ReleaseAppDir | Should -BeNullOrEmpty
    }

    It 'exports ALBT_RELEASE_APP_DIR only when the folder is set' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":[],"breakingChange":{"releaseAppDir":"release"}}'
        Set-BuildEnvironment -Config (Get-BuildConfig)
        $env:ALBT_RELEASE_APP_DIR | Should -Be (Join-Path $script:ProbeRoot 'release')

        Remove-Item Env:\ALBT_RELEASE_APP_DIR
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":[]}'
        Set-BuildEnvironment -Config (Get-BuildConfig)
        Test-Path Env:\ALBT_RELEASE_APP_DIR | Should -BeFalse
    }

    It 'no longer exposes a baseline cache path, though al-build.json and the environment still carry one' {
        Set-Content -LiteralPath $configPath -Value '{"appDir":"app","testApps":[],"breakingChange":{"baselinePackageCachePath":".old"}}'
        $env:ALBT_BASELINE_CACHE_PATH = '.older'
        $config = Get-BuildConfig
        $config.PSObject.Properties.Name | Should -Not -Contain 'BaselinePackageCachePath'

        Remove-Item Env:\ALBT_BASELINE_CACHE_PATH
        Set-BuildEnvironment -Config $config
        Test-Path Env:\ALBT_BASELINE_CACHE_PATH | Should -BeFalse
    }
}
