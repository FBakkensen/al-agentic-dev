#Requires -Version 7.2

BeforeAll {
    $alBuildRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build')
    $script:HelperProject = Join-Path $alBuildRoot 'code-coverage-helper'
    $script:HelperManifestPath = Join-Path $script:HelperProject 'app.json'
    $script:HelperSourcePath = Join-Path $script:HelperProject 'src' 'RawCodeCoverage.XmlPort.al'
    $script:GoldenScriptPath = Join-Path $alBuildRoot 'scripts' 'new-bc-container.ps1'
    $script:GoldenModulePath = Join-Path $alBuildRoot 'scripts' 'coverage-helper-golden.psm1'

    Import-Module $script:GoldenModulePath -Force

    $script:Manifest = Get-CodeCoverageHelperManifest -ProjectFolder $script:HelperProject
    $script:HelperSource = Get-Content -Path $script:HelperSourcePath -Raw
    $script:GoldenScript = Get-Content -Path $script:GoldenScriptPath -Raw

    $tokens = $null
    $parseErrors = $null
    $script:GoldenModuleAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:GoldenModulePath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "coverage-helper-golden.psm1 has parse errors: $($parseErrors.Message -join '; ')"
    }

    $script:InstallFunction = @($script:GoldenModuleAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Install-CodeCoverageHelperInBcContainer'
    }, $true))[0]
}

Describe 'Bundled code coverage helper identity' {
    It 'keeps the stable app ID and version' {
        $script:Manifest.Id | Should -Be ([guid]'6a7912dd-91be-4a75-a9d3-8f3b5d4e7501')
        $script:Manifest.Version | Should -Be ([version]'1.0.0.0')
    }

    It 'accepts the exact installed identity' {
        $installed = [PSCustomObject]@{
            AppId = $script:Manifest.Id
            Version = $script:Manifest.Version
        }

        $actual = Assert-CodeCoverageHelperIdentity -Manifest $script:Manifest -InstalledApps @($installed)

        $actual | Should -Be $installed
    }

    It 'accepts the exact installed identity exposed through Id' {
        $installed = [PSCustomObject]@{
            Id = $script:Manifest.Id
            Version = $script:Manifest.Version
        }

        $actual = Assert-CodeCoverageHelperIdentity -Manifest $script:Manifest -InstalledApps @($installed)

        $actual | Should -Be $installed
    }

    It 'ignores unrelated objects without an app identifier' {
        $installed = [PSCustomObject]@{
            AppId = $script:Manifest.Id
            Version = $script:Manifest.Version
        }
        $unrelated = [PSCustomObject]@{
            Name = 'Unrelated App'
            Version = [version]'1.0.0.0'
        }

        $actual = Assert-CodeCoverageHelperIdentity `
            -Manifest $script:Manifest `
            -InstalledApps @($unrelated, $installed)

        $actual | Should -Be $installed
    }

    It 'fails when the helper is missing' {
        {
            Assert-CodeCoverageHelperIdentity -Manifest $script:Manifest -InstalledApps @()
        } | Should -Throw '*is not installed exactly once*'
    }

    It 'fails when the installed version is stale' {
        $installed = [PSCustomObject]@{
            AppId = $script:Manifest.Id
            Version = [version]'0.9.0.0'
        }

        {
            Assert-CodeCoverageHelperIdentity -Manifest $script:Manifest -InstalledApps @($installed)
        } | Should -Throw '*version mismatch*'
    }

    It 'reports a version mismatch when the installed version is absent' {
        $installed = [PSCustomObject]@{
            AppId = $script:Manifest.Id
        }

        {
            Assert-CodeCoverageHelperIdentity -Manifest $script:Manifest -InstalledApps @($installed)
        } | Should -Throw "Code coverage helper $($script:Manifest.Id) version mismatch. Expected $($script:Manifest.Version), installed ."
    }
}

Describe 'Raw code coverage XML contract' {
    It 'versions the raw XML independently from the app version' {
        $script:HelperSource | Should -Match "RawXmlSchemaVersionLbl:\s+Label '1'"
        $script:Manifest.Version.ToString() | Should -Not -Be '1'
    }

    It 'uses the UTF-16 encoding expected by Test Runner blob text transport' {
        $script:HelperSource | Should -Match 'Encoding\s*=\s*UTF16;'
    }

    It 'resets only the supplied XMLport record filters' {
        $script:HelperSource | Should -Match 'trigger OnPreXmlItem\(\)'
        $script:HelperSource | Should -Match 'CoverageLine\.Reset\(\);'
        $script:HelperSource | Should -Not -Match 'CodeCoverageRefresh|CodeCoverageLog|Find(Set|First|Last)?\('
    }

    It 'exports every required raw field' {
        foreach ($field in @(
            'ObjectTypeCode',
            'ObjectTypeName',
            'ObjectId',
            'LineNumber',
            'LineTypeCode',
            'LineTypeName',
            'CoverageStatusCode',
            'CoverageStatusName',
            'HitCount',
            'SourceLine'
        )) {
            $script:HelperSource | Should -Match ([regex]::Escape($field))
        }
    }

    It 'converts each BC 28.3 option to an integer before formatting its code' {
        $script:HelperSource | Should -Match 'ObjectTypeOrdinal:\s+Integer;'
        $script:HelperSource | Should -Match 'ObjectTypeOrdinal := CoverageLine\."Object Type";'
        $script:HelperSource | Should -Match 'ObjectTypeCode := Format\(ObjectTypeOrdinal, 0, 9\);'
        $script:HelperSource | Should -Match 'LineTypeOrdinal:\s+Integer;'
        $script:HelperSource | Should -Match 'LineTypeOrdinal := CoverageLine\."Line Type";'
        $script:HelperSource | Should -Match 'LineTypeCode := Format\(LineTypeOrdinal, 0, 9\);'
        $script:HelperSource | Should -Match 'CoverageStatusOrdinal:\s+Integer;'
        $script:HelperSource | Should -Match 'CoverageStatusOrdinal := CoverageLine\."Code Coverage Status";'
        $script:HelperSource | Should -Match 'CoverageStatusCode := Format\(CoverageStatusOrdinal, 0, 9\);'
        $script:HelperSource | Should -Not -Match '\w+Code := Format\(CoverageLine\.'
    }

    It 'retains diagnostic option names separately from numeric codes' {
        $script:HelperSource | Should -Match 'ObjectTypeName := Format\(CoverageLine\."Object Type"\);'
        $script:HelperSource | Should -Match 'LineTypeName := Format\(CoverageLine\."Line Type"\);'
        $script:HelperSource | Should -Match 'CoverageStatusName := Format\(CoverageLine\."Code Coverage Status"\);'
    }

    It 'contains no normalization filtering or reporting behavior' {
        $script:HelperSource |
            Should -Not -Match 'SetRange|SetFilter|Skip\(|Delete|Modify|Insert|Report'
    }
}

Describe 'Golden helper installation ordering' {
    BeforeAll {
        $script:InstallCommands = @($script:InstallFunction.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true))
    }

    It 'compiles, publishes, syncs, installs, then reads installed identity' {
        $orderedNames = @(
            'Compile-AppInBcContainer',
            'Publish-BcContainerApp',
            'Sync-BcContainerApp',
            'Install-BcContainerApp',
            'Get-BcContainerAppInfo',
            'Assert-CodeCoverageHelperIdentity'
        )
        $positions = foreach ($name in $orderedNames) {
            @($script:InstallCommands | Where-Object { $_.GetCommandName() -eq $name })[0].Extent.StartOffset
        }

        $positions | Should -Be ($positions | Sort-Object)
    }

    It 'stages source and build output in a container-shared folder' {
        $commandNames = @($script:InstallCommands | ForEach-Object { $_.GetCommandName() })

        $commandNames | Should -Contain 'Get-BcContainerSharedFolders'
        $commandNames | Should -Contain 'Copy-Item'
        $script:InstallFunction.Extent.Text | Should -Match '-appProjectFolder \$stagedProjectFolder'
        $script:InstallFunction.Extent.Text | Should -Match '-appOutputFolder \$outputFolder'
        $script:InstallFunction.Extent.Text | Should -Match '-appSymbolsFolder \$symbolsFolder'
    }

    It 'does not swallow compile publish sync install or verification failures' {
        $tryStatements = @($script:InstallFunction.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TryStatementAst]
        }, $true))

        $tryStatements | Should -HaveCount 1
        $tryStatements[0].CatchClauses | Should -BeNullOrEmpty
        $tryStatements[0].Finally | Should -Not -BeNullOrEmpty
    }

    It 'installs and verifies before snapshot preparation and container stop' {
        $containerPosition = $script:GoldenScript.IndexOf('New-BcContainer @containerParams')
        $installPosition = $script:GoldenScript.IndexOf('Install-CodeCoverageHelperInBcContainer')
        $preparePosition = $script:GoldenScript.IndexOf("Write-BuildHeader 'Preparing Container For Commit'")
        $stopPosition = $script:GoldenScript.IndexOf('Stop-BcContainer -containerName')

        $script:GoldenScript | Should -Match 'includeTestToolkit\s*=\s*\$true'
        $containerPosition | Should -BeGreaterThan -1
        $installPosition | Should -BeGreaterThan -1
        $containerPosition | Should -BeLessThan $installPosition
        $installPosition | Should -BeLessThan $preparePosition
        $installPosition | Should -BeLessThan $stopPosition
    }
}
