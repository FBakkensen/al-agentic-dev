#Requires -Version 7.2

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'build-operations.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'alrunner-cli.psm1') -Force -DisableNameChecking

    $script:OriginalHome = $env:HOME
    $script:OriginalUserProfile = $env:USERPROFILE

    # Builds a repo fixture: al-build.json (appDir 'app', testApps ['test']),
    # app/app.json and test/app.json with the given dependency arrays.
    function script:New-DependencyFixtureRepo {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)]$AppManifest,
            $TestManifest
        )

        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        [ordered]@{ appDir = 'app'; testApps = @('test') } |
            ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $Root 'al-build.json') -Encoding UTF8

        $appDir = Join-Path $Root 'app'
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null
        $AppManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $appDir 'app.json') -Encoding UTF8

        if ($TestManifest) {
            $testDir = Join-Path $Root 'test'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $TestManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $testDir 'app.json') -Encoding UTF8
        }
    }

    # Places fake .app files (and a minimal symbols.lock.json) into the
    # checkout symbol cache dir for the given bundle app.json, the way
    # download-symbols.ps1 would have left them.
    function script:Add-CacheFile {
        param(
            [Parameter(Mandatory)][string]$RepoRoot,
            [Parameter(Mandatory)]$BundleAppJson,
            [AllowEmptyCollection()]
            [string[]]$FileNames = @()
        )

        Push-Location -LiteralPath $RepoRoot
        try {
            $cacheRoot = Get-SymbolCacheRoot
            $publisherDir = Join-Path -Path $cacheRoot -ChildPath (ConvertTo-SafePathSegment -Value $BundleAppJson.publisher)
            $appDirPath = Join-Path -Path $publisherDir -ChildPath (ConvertTo-SafePathSegment -Value $BundleAppJson.name)
            $cacheDir = Join-Path -Path $appDirPath -ChildPath (ConvertTo-SafePathSegment -Value $BundleAppJson.id)
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            if (-not (Test-Path -LiteralPath (Join-Path $cacheDir 'symbols.lock.json'))) {
                '{}' | Set-Content -LiteralPath (Join-Path $cacheDir 'symbols.lock.json') -Encoding UTF8
            }
            foreach ($fileName in $FileNames) {
                Set-Content -LiteralPath (Join-Path $cacheDir $fileName) -Value $fileName -Encoding UTF8
            }
            return $cacheDir
        }
        finally {
            Pop-Location
        }
    }

    $script:MainAppId = '11111111-1111-1111-1111-111111111111'
    $script:TestAppId = '22222222-2222-2222-2222-222222222222'
    $script:ThirdPartyId = '33333333-3333-3333-3333-333333333333'

    function script:New-MainAppManifest {
        param([array]$Dependencies = @())
        [ordered]@{
            id           = $script:MainAppId
            name         = 'Main App'
            publisher    = 'Contoso'
            version      = '1.0.0.0'
            dependencies = $Dependencies
        }
    }

    function script:New-TestAppManifest {
        param([array]$Dependencies = @())
        [ordered]@{
            id           = $script:TestAppId
            name         = 'Main App Test'
            publisher    = 'Contoso'
            version      = '1.0.0.0'
            dependencies = $Dependencies
        }
    }
}

Describe 'Resolve-ALRunnerDependencySet / New-ALRunnerDependencyDirectory' -Tag 'Process' {
    BeforeEach {
        $script:FakeHome = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome
    }

    AfterEach {
        $env:HOME = $script:OriginalHome
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    It 'includes a third-party dependency found in the bundle symbol cache' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = $script:ThirdPartyId; publisher = '9altitudes'; name = '9A Advanced Manufacturing - License'; version = '27.0.30.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest
        Add-CacheFile -RepoRoot $repo -BundleAppJson $appManifest -FileNames @('9altitudes.9AAdvancedManufacturing-License.27.0.30.0.app') | Out-Null

        $result = New-ALRunnerDependencyDirectory -RepoRoot $repo

        $result.Packages.Count | Should -Be 1
        $result.Packages[0].Id | Should -Be $script:ThirdPartyId
        $result.Packages[0].Version | Should -Be '27.0.30.0'
        Test-Path -LiteralPath (Join-Path $result.OutputDirectory '9altitudes.9AAdvancedManufacturing-License.27.0.30.0.app') | Should -BeTrue
    }

    It 'excludes a Microsoft dependency' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = [Guid]::NewGuid().ToString(); publisher = 'Microsoft'; name = 'Base Application'; version = '28.0.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest

        $result = New-ALRunnerDependencyDirectory -RepoRoot $repo

        $result.Packages.Count | Should -Be 0
    }

    It 'excludes a dependency whose id is itself one of the bundles' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest
        $testManifest = New-TestAppManifest -Dependencies @(
            [ordered]@{ id = $script:MainAppId; publisher = 'Contoso'; name = 'Main App'; version = '1.0.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest -TestManifest $testManifest

        $result = New-ALRunnerDependencyDirectory -RepoRoot $repo

        $result.Packages.Count | Should -Be 0
    }

    It 'throws naming the publisher, name, version and cache dir searched when the package is missing' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = $script:ThirdPartyId; publisher = '9altitudes'; name = 'License'; version = '1.0.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest
        $cacheDir = Add-CacheFile -RepoRoot $repo -BundleAppJson $appManifest -FileNames @()

        { New-ALRunnerDependencyDirectory -RepoRoot $repo } | Should -Throw "*9altitudes*License*1.0.0.0*$cacheDir*"
    }

    It 'picks the highest cache version that satisfies the declared minimum' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = $script:ThirdPartyId; publisher = '9altitudes'; name = 'License'; version = '1.5.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest
        Add-CacheFile -RepoRoot $repo -BundleAppJson $appManifest -FileNames @(
            '9altitudes.License.1.0.0.0.app',
            '9altitudes.License.2.0.0.0.app'
        ) | Out-Null

        $result = New-ALRunnerDependencyDirectory -RepoRoot $repo

        $result.Packages.Count | Should -Be 1
        $result.Packages[0].Version | Should -Be '2.0.0.0'
    }

    It 'empties stale files from the output directory on each build' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = $script:ThirdPartyId; publisher = '9altitudes'; name = 'License'; version = '1.0.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest
        Add-CacheFile -RepoRoot $repo -BundleAppJson $appManifest -FileNames @('9altitudes.License.1.0.0.0.app') | Out-Null

        $outputDir = Join-Path $repo '.output' 'al-runner-deps'
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outputDir 'stale.app') -Value 'stale'

        $result = New-ALRunnerDependencyDirectory -RepoRoot $repo

        Test-Path -LiteralPath (Join-Path $outputDir 'stale.app') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $outputDir '9altitudes.License.1.0.0.0.app') | Should -BeTrue
        $result.OutputDirectory | Should -Be $outputDir
    }

    It 'refuses an output directory outside <RepoRoot>/.output and touches nothing' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = $script:ThirdPartyId; publisher = '9altitudes'; name = 'License'; version = '1.0.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest
        Add-CacheFile -RepoRoot $repo -BundleAppJson $appManifest -FileNames @('9altitudes.License.1.0.0.0.app') | Out-Null
        $sentinel = Join-Path $repo 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'

        { New-ALRunnerDependencyDirectory -RepoRoot $repo -OutputDirectory $repo } | Should -Throw '*must be inside*'
        { New-ALRunnerDependencyDirectory -RepoRoot $repo -OutputDirectory (Join-Path $repo '.output' '..' 'x') } | Should -Throw '*must be inside*'
        Test-Path -LiteralPath $sentinel | Should -BeTrue
    }

    It 'matches a package name that ConvertTo-SafePathSegment rewrote' {
        $repo = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        $appManifest = New-MainAppManifest -Dependencies @(
            [ordered]@{ id = $script:ThirdPartyId; publisher = '9altitudes'; name = 'Sales: Extras'; version = '1.0.0.0' }
        )
        New-DependencyFixtureRepo -Root $repo -AppManifest $appManifest
        $expected = (ConvertTo-SafePathSegment -Value '9altitudes.Sales:Extras') + '.1.0.0.0.app'
        Add-CacheFile -RepoRoot $repo -BundleAppJson $appManifest -FileNames @($expected) | Out-Null

        $result = New-ALRunnerDependencyDirectory -RepoRoot $repo
        @($result.Packages).Count | Should -Be 1
        Test-Path -LiteralPath (Join-Path $result.OutputDirectory $expected) | Should -BeTrue
    }
}

