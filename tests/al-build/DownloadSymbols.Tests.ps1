#Requires -Version 7.2

BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts'
    $script:DownloadSymbolsPath = Resolve-Path (Join-Path $scriptsRoot 'download-symbols.ps1')
    $commonPath = Resolve-Path (Join-Path $scriptsRoot 'common.psm1')
    Import-Module $commonPath -DisableNameChecking -Force
    # Compare-Version moved to the feed module; download-symbols.ps1 reaches it there too.
    Import-Module (Join-Path $scriptsRoot 'symbol-feed.psm1') -DisableNameChecking -Force
    Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:DownloadSymbolsPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "download-symbols.ps1 has parse errors: $($parseErrors.Message -join '; ')"
    }

    $requiredFunctions = @(
        'Set-PackageMapMinimum'
        'Add-DependencyToPackageMap'
        'Add-LocalAppDependenciesToPackageMap'
        'Build-PackageMap'
    )

    foreach ($functionName in $requiredFunctions) {
        $functionAst = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        }, $true))
        if ($functionAst.Count -ne 1) {
            throw "$functionName was not found exactly once in download-symbols.ps1."
        }
        . ([scriptblock]::Create($functionAst[0].Extent.Text))
    }

    $script:FixtureRoot = Join-Path $TestDrive 'download-symbols-local-deps'
    New-Item -ItemType Directory -Path $script:FixtureRoot | Out-Null

    $script:MainAppDir = Join-Path $script:FixtureRoot 'app'
    $script:UnitTestDir = Join-Path $script:FixtureRoot 'unit-tests'
    New-Item -ItemType Directory -Path $script:MainAppDir, $script:UnitTestDir | Out-Null

    $script:MainAppId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    $script:LicenseAppId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    $script:UnitTestAppId = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    $script:SharedAppId = 'dddddddd-dddd-dddd-dddd-dddddddddddd'

    $mainAppJson = @{
        id          = $script:MainAppId
        name        = 'Main App'
        publisher   = 'Contoso'
        version     = '1.0.0.0'
        application = '24.0.0.0'
        dependencies = @(
            @{
                id        = $script:LicenseAppId
                name      = '9A Advanced Manufacturing - License'
                publisher = 'Dynalogic'
                version   = '2.1.0.0'
            }
            @{
                id        = $script:SharedAppId
                name      = 'Shared Library'
                publisher = 'Contoso'
                version   = '1.0.0.0'
            }
        )
    }
    $script:MainAppJsonPath = Join-Path $script:MainAppDir 'app.json'
    $mainAppJson | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:MainAppJsonPath -Encoding utf8

    $script:UnitTestAppJson = [pscustomobject]@{
        id          = $script:UnitTestAppId
        name        = 'Main App Unit Tests'
        publisher   = 'Contoso'
        version     = '1.0.0.0'
        application = '24.0.0.0'
        dependencies = @(
            [pscustomobject]@{
                id        = $script:MainAppId
                name      = 'Main App'
                publisher = 'Contoso'
                version   = '1.0.0.0'
            }
            [pscustomobject]@{
                id        = $script:SharedAppId
                name      = 'Shared Library'
                publisher = 'Contoso'
                version   = '1.2.0.0'
            }
        )
    }
}

Describe 'Build-PackageMap local test-gate dependencies' {
    BeforeEach {
        $script:localDependencySkips = New-Object System.Collections.Generic.List[object]
    }

    It 'skips the local main app but still maps its dependencies into the unit-test package map' {
        $copiedLocalAppIds = @{
            $script:MainAppId.ToLowerInvariant() = [pscustomobject]@{
                Name = 'Main App'
                Path = $script:MainAppJsonPath
            }
        }

        $packageMap = Build-PackageMap -AppJson $script:UnitTestAppJson -CopiedLocalAppIds $copiedLocalAppIds

        $mainPackageId = 'Contoso.MainApp.symbols.{0}' -f $script:MainAppId
        $licensePackageId = 'Dynalogic.9AAdvancedManufacturing-License.symbols.{0}' -f $script:LicenseAppId
        $sharedPackageId = 'Contoso.SharedLibrary.symbols.{0}' -f $script:SharedAppId

        $packageMap.Contains($mainPackageId) | Should -BeFalse
        $packageMap.Contains($licensePackageId) | Should -BeTrue
        $packageMap[$licensePackageId] | Should -Be '2.1.0.0'
        $packageMap.Contains($sharedPackageId) | Should -BeTrue
        # Unit-test already requires Shared at 1.2.0.0; keep the higher floor.
        $packageMap[$sharedPackageId] | Should -Be '1.2.0.0'
        $packageMap['Microsoft.Application.symbols'] | Should -Be '24.0.0.0'

        $script:localDependencySkips | Should -HaveCount 1
        $script:localDependencySkips[0].Id | Should -Be $script:MainAppId
        $script:localDependencySkips[0].Name | Should -Be 'Main App'
    }

    It 'does not map a local main app when building the main app itself' {
        $mainAppJson = Read-JsonFile -Path $script:MainAppJsonPath
        $packageMap = Build-PackageMap -AppJson $mainAppJson -CopiedLocalAppIds @{}

        $mainPackageId = 'Contoso.MainApp.symbols.{0}' -f $script:MainAppId
        $licensePackageId = 'Dynalogic.9AAdvancedManufacturing-License.symbols.{0}' -f $script:LicenseAppId

        $packageMap.Contains($mainPackageId) | Should -BeFalse
        $packageMap.Contains($licensePackageId) | Should -BeTrue
        $script:localDependencySkips | Should -HaveCount 0
    }

    It 'fails closed when a skipped local dependency manifest is missing' {
        $copiedLocalAppIds = @{
            $script:MainAppId.ToLowerInvariant() = [pscustomobject]@{
                Name = 'Main App'
                Path = (Join-Path $script:FixtureRoot 'missing-app.json')
            }
        }

        $packageMap = Build-PackageMap -AppJson $script:UnitTestAppJson -CopiedLocalAppIds $copiedLocalAppIds

        $mainPackageId = 'Contoso.MainApp.symbols.{0}' -f $script:MainAppId
        $licensePackageId = 'Dynalogic.9AAdvancedManufacturing-License.symbols.{0}' -f $script:LicenseAppId
        $sharedPackageId = 'Contoso.SharedLibrary.symbols.{0}' -f $script:SharedAppId

        $packageMap.Contains($mainPackageId) | Should -BeFalse
        $packageMap.Contains($licensePackageId) | Should -BeFalse
        $packageMap.Contains($sharedPackageId) | Should -BeTrue
        $packageMap[$sharedPackageId] | Should -Be '1.2.0.0'
        $script:localDependencySkips | Should -HaveCount 1
    }
}

Describe 'download-symbols.ps1 against fixture feeds' -Tag 'Process' {
    BeforeAll {
        $script:Pwsh = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $script:EnvNames = @('HOME', 'USERPROFILE', 'ALBT_MSSYMBOLS_FEED', 'ALBT_APPSOURCESYMBOLS_FEED', 'ALBT_APP_DIR')
        $script:SavedEnv = @{}
        foreach ($name in $script:EnvNames) {
            $script:SavedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
        }

        # The checkout symbol cache sits under HOME, or USERPROFILE: keep it out of the real one.
        $script:FakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Path $script:FakeHome | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome
        $env:ALBT_APP_DIR = $null

        $script:LibId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        $script:LibPackageId = "Contoso.Lib.symbols.$($script:LibId)"
        $script:MissingPackageId = 'Contoso.Missing.symbols.cccccccc-cccc-cccc-cccc-cccccccccccc'
        $script:ApplicationPackageId = 'Microsoft.Application.symbols'

        # A project whose app.json names Contoso Lib, in a folder that is no git repo, so the
        # checkout fingerprint falls back to this folder.
        function script:New-FixtureProject {
            param([Parameter(Mandatory)][string]$Name)
            $project = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path (Join-Path $project 'app') -Force | Out-Null
            [ordered]@{
                id           = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                name         = 'Fixture App'
                publisher    = 'Contoso'
                version      = '1.0.0.0'
                dependencies = @(
                    [ordered]@{ id = $script:LibId; name = 'Lib'; publisher = 'Contoso'; version = '1.0.0.0' }
                )
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $project 'app' 'app.json') -Encoding UTF8
            return $project
        }

        # Contoso Lib depends on a second package, one level down.
        function script:Add-LibPackage {
            param([Parameter(Mandatory)][string]$FeedRoot, [string]$DependsOn = $script:ApplicationPackageId)
            New-FixtureFeedPackage -FeedRoot $FeedRoot -PackageId $script:LibPackageId -NuGetVersion '1.2.3' `
                -App @{ Id = $script:LibId; Name = 'Lib'; Publisher = 'Contoso'; Version = '1.2.3.0' } `
                -Dependencies @(@{ Id = $DependsOn; Version = '26.0.0.0' }) | Out-Null
        }

        function script:Add-ApplicationPackage {
            param([Parameter(Mandatory)][string]$FeedRoot)
            foreach ($version in '26.0.1', '26.1.9') {
                New-FixtureFeedPackage -FeedRoot $FeedRoot -PackageId $script:ApplicationPackageId -NuGetVersion $version `
                    -App @{ Id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'; Name = 'Application'; Publisher = 'Microsoft'; Version = "$version.0" } | Out-Null
            }
        }

        # Starts the script with the call operator in a fresh pwsh, the way provision.ps1 does.
        function script:Invoke-DownloadSymbols {
            param(
                [Parameter(Mandatory)][string]$Project,
                [Parameter(Mandatory)][string]$MsRoot,
                [Parameter(Mandatory)][string]$AppSourceRoot
            )
            $env:ALBT_MSSYMBOLS_FEED = $MsRoot
            $env:ALBT_APPSOURCESYMBOLS_FEED = $AppSourceRoot
            $command = "Set-Location -LiteralPath '$Project'; & '$($script:DownloadSymbolsPath)'"
            $output = & $script:Pwsh -NoProfile -Command $command 2>&1
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output   = (@($output | ForEach-Object { "$_" }) -join "`n")
            }
        }

        function script:Get-SymbolCacheFiles {
            $lock = @(Get-ChildItem -LiteralPath (Join-Path $script:FakeHome '.bc-symbol-cache') -Recurse -Filter 'symbols.lock.json')
            $lock | Should -HaveCount 1
            [pscustomobject]@{
                Lock = Get-Content -LiteralPath $lock[0].FullName -Raw | ConvertFrom-Json
                Apps = @(Get-ChildItem -LiteralPath $lock[0].DirectoryName -Filter '*.app' | Sort-Object Name | ForEach-Object Name)
                Dir  = $lock[0].DirectoryName
            }
        }
    }

    AfterAll {
        foreach ($name in $script:EnvNames) {
            [Environment]::SetEnvironmentVariable($name, $script:SavedEnv[$name])
        }
    }

    BeforeEach {
        # One run per cache: each case starts from an empty symbol cache.
        Get-ChildItem -LiteralPath $script:FakeHome -Force | Remove-Item -Recurse -Force
    }

    It 'resolves a two-level graph across the two fixture roots, MSSymbols first' {
        $project = New-FixtureProject -Name 'two-roots'
        $msRoot = Join-Path $TestDrive 'two-roots-ms'
        $appSourceRoot = Join-Path $TestDrive 'two-roots-appsource'
        Add-LibPackage -FeedRoot $appSourceRoot
        Add-ApplicationPackage -FeedRoot $msRoot

        $run = Invoke-DownloadSymbols -Project $project -MsRoot $msRoot -AppSourceRoot $appSourceRoot

        $run.ExitCode | Should -Be 0 -Because $run.Output
        $cache = Get-SymbolCacheFiles
        $cache.Apps | Should -Be @('Contoso.Lib.1.2.3.app', 'Microsoft.Application.26.1.9.app')
        $cache.Lock.packages.$($script:LibPackageId) | Should -Be '1.2.3'
        $cache.Lock.packages.$($script:ApplicationPackageId) | Should -Be '26.1.9'
        @($cache.Lock.feeds) | Should -Be @($msRoot, $appSourceRoot)
        (Read-AppManifest -Path (Join-Path $cache.Dir 'Microsoft.Application.26.1.9.app')).Version | Should -Be '26.1.9.0'
    }

    It 'warns and moves on when a feed root directory does not exist' {
        $project = New-FixtureProject -Name 'unreadable-root'
        $appSourceRoot = Join-Path $TestDrive 'unreadable-root-appsource'
        Add-LibPackage -FeedRoot $appSourceRoot
        Add-ApplicationPackage -FeedRoot $appSourceRoot
        $absentRoot = Join-Path $TestDrive 'unreadable-root-absent'

        $run = Invoke-DownloadSymbols -Project $project -MsRoot $absentRoot -AppSourceRoot $appSourceRoot

        $run.ExitCode | Should -Be 0 -Because $run.Output
        $run.Output | Should -Match 'does not exist'
    }

    It 'fails and names a dependency that neither fixture root holds' {
        $project = New-FixtureProject -Name 'missing-dependency'
        $msRoot = Join-Path $TestDrive 'missing-dependency-ms'
        $appSourceRoot = Join-Path $TestDrive 'missing-dependency-appsource'
        Add-LibPackage -FeedRoot $appSourceRoot -DependsOn $script:MissingPackageId
        New-Item -ItemType Directory -Path $msRoot | Out-Null

        $run = Invoke-DownloadSymbols -Project $project -MsRoot $msRoot -AppSourceRoot $appSourceRoot

        $run.ExitCode | Should -Not -Be 0
        $run.Output | Should -Match ([regex]::Escape($script:MissingPackageId))
    }
}
