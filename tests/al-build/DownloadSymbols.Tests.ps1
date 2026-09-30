#Requires -Version 7.2

BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts'
    $script:DownloadSymbolsPath = Resolve-Path (Join-Path $scriptsRoot 'download-symbols.ps1')
    $commonPath = Resolve-Path (Join-Path $scriptsRoot 'common.psm1')
    Import-Module $commonPath -DisableNameChecking -Force

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
        'Compare-Version'
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
