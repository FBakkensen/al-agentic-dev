#Requires -Version 7.2

BeforeAll {
    $base = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts'
    Import-Module (Resolve-Path (Join-Path $base 'common.psm1')) -Force -DisableNameChecking
    Import-Module (Resolve-Path (Join-Path $base 'build-operations.psm1')) -Force -DisableNameChecking
}

Describe 'Get-AppSourceCopSettings' {
    BeforeAll {
        function Write-AppSourceCop {
            param([string]$AppDir, [string]$Json)
            New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $AppDir 'AppSourceCop.json') -Value $Json -Encoding UTF8
        }
    }

    It 'returns $null when AppSourceCop.json is absent, with or without the app folder' {
        Get-AppSourceCopSettings -AppDir (Join-Path $TestDrive 'no-such-app') | Should -BeNullOrEmpty
        $appDir = Join-Path $TestDrive 'bare-app'
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null
        Get-AppSourceCopSettings -AppDir $appDir | Should -BeNullOrEmpty
    }

    It 'returns the path, and $null for a version and a cache path the file lacks' {
        $appDir = Join-Path $TestDrive 'no-version'
        Write-AppSourceCop -AppDir $appDir -Json '{ "mandatoryAffixes": ["NALICF"] }'

        $settings = Get-AppSourceCopSettings -AppDir $appDir

        $settings.Path | Should -Be (Join-Path $appDir 'AppSourceCop.json')
        $settings.Version | Should -BeNullOrEmpty
        $settings.BaselinePackageCachePath | Should -BeNullOrEmpty
    }

    It 'returns the version exactly as written' {
        $appDir = Join-Path $TestDrive 'with-version'
        Write-AppSourceCop -AppDir $appDir -Json '{ "version": "26.1.9.0" }'
        (Get-AppSourceCopSettings -AppDir $appDir).Version | Should -Be '26.1.9.0'
    }

    It 'resolves a relative baselinePackageCachePath against the app folder' {
        $appDir = Join-Path $TestDrive 'relative-cache'
        Write-AppSourceCop -AppDir $appDir -Json '{ "version": "1.0.0.0", "baselinePackageCachePath": "../.baseline" }'
        (Get-AppSourceCopSettings -AppDir $appDir).BaselinePackageCachePath | Should -Be (Join-Path $appDir '../.baseline')
    }

    It 'keeps an absolute baselinePackageCachePath' {
        $appDir = Join-Path $TestDrive 'absolute-cache'
        $absolute = Join-Path $TestDrive 'elsewhere'
        $json = [ordered]@{ version = '1.0.0.0'; baselinePackageCachePath = $absolute } | ConvertTo-Json
        Write-AppSourceCop -AppDir $appDir -Json $json
        (Get-AppSourceCopSettings -AppDir $appDir).BaselinePackageCachePath | Should -Be $absolute
    }

    It 'throws, naming the file, when AppSourceCop.json is not JSON' {
        $appDir = Join-Path $TestDrive 'broken'
        Write-AppSourceCop -AppDir $appDir -Json '{ not json'
        { Get-AppSourceCopSettings -AppDir $appDir } | Should -Throw '*AppSourceCop.json*'
    }
}

Describe 'Get-AlValidationVerdict' {
    It 'passes on an empty result' {
        $r = Get-AlValidationVerdict -ValidationResult @()
        $r.Verdict | Should -Be 'Passed'
        $r.Findings | Should -BeNullOrEmpty
        $r.EnvironmentErrors | Should -BeNullOrEmpty
    }

    It 'passes when nothing was returned at all' {
        $r = Get-AlValidationVerdict
        $r.Verdict | Should -Be 'Passed'
    }

    It 'classifies environment-only errors as EnvironmentError, not a breaking change' {
        $lines = @(
            'Unexpected error while validating app. Error is: hcs::CreateComputeSystem bcserver: The request is not supported.'
        )
        $r = Get-AlValidationVerdict -ValidationResult $lines
        $r.Verdict | Should -Be 'EnvironmentError'
        $r.EnvironmentErrors.Count | Should -Be 1
        $r.Findings | Should -BeNullOrEmpty
    }

    It 'classifies AppSourceCop findings as BreakingChange' {
        $lines = @(
            '2 errors found in MyApp.app on https://bcartifacts.azureedge.net/sandbox/24.0/dk:'
            'error AS0023: Procedure ''PostSalesOrder'' has been removed.'
        )
        $r = Get-AlValidationVerdict -ValidationResult $lines
        $r.Verdict | Should -Be 'BreakingChange'
        $r.Findings.Count | Should -Be 2
    }

    It 'lets a finding outrank an environment error in a mixed result' {
        $lines = @(
            'error AS0023: Procedure ''PostSalesOrder'' has been removed.'
            'Unexpected error while validating app. Error is: docker pull timed out'
        )
        $r = Get-AlValidationVerdict -ValidationResult $lines
        $r.Verdict | Should -Be 'BreakingChange'
        $r.Findings.Count | Should -Be 1
        $r.EnvironmentErrors.Count | Should -Be 1
    }

    It 'ignores blank separator lines (Run-AlCops appends them between blocks)' {
        $r = Get-AlValidationVerdict -ValidationResult @('', '   ', '')
        $r.Verdict | Should -Be 'Passed'
    }
}

Describe 'validate-breaking-changes.ps1 Run-AlValidation contract' {
    It 'passes skipVerification (local and AL-Go CI builds are unsigned; without it every run classifies NotSigned as a finding)' {
        $scriptPath = Join-Path $base 'validate-breaking-changes.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $pair = $ast.FindAll({ param($node)
                $node -is [System.Management.Automation.Language.HashtableAst]
            }, $true) |
            ForEach-Object { $_.KeyValuePairs } |
            Where-Object { $_.Item1.Extent.Text -eq 'skipVerification' }
        $pair | Should -Not -BeNullOrEmpty
        $pair.Item2.Extent.Text | Should -Be '$true'
    }
}

Describe 'validate-breaking-changes.ps1 splat and pin check wiring' {
    BeforeAll {
        $script:ValidatePath = Join-Path $base 'validate-breaking-changes.ps1'
        $script:ValidateAst = [System.Management.Automation.Language.Parser]::ParseFile($script:ValidatePath, [ref]$null, [ref]$null)
    }

    It 'hands Run-AlValidation the matched Release .app as previousApps and no installApps' {
        $splat = @($script:ValidateAst.FindAll({ param($node)
                $node -is [System.Management.Automation.Language.HashtableAst] -and
                @($node.KeyValuePairs | Where-Object { $_.Item1.Extent.Text -eq 'skipVerification' }).Count -gt 0
            }, $true))
        $splat | Should -HaveCount 1
        $keys = @($splat[0].KeyValuePairs | ForEach-Object { $_.Item1.Extent.Text })
        $keys | Should -Contain 'previousApps'
        $keys | Should -Not -Contain 'installApps'
    }

    It 'repeats the pin check through Test-ReleasePin and never runs download-baseline.ps1' {
        $commands = @($script:ValidateAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) |
            ForEach-Object { $_.GetCommandName() })
        $commands | Should -Contain 'Test-ReleasePin'

        $strings = @($script:ValidateAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) |
            ForEach-Object { $_.Value })
        @($strings | Where-Object { $_ -match 'download-baseline' }) | Should -HaveCount 0
    }

    It 'runs every prerequisite check before Invoke-ALBuild and Import-BCContainerHelper' {
        $offset = {
            param([string]$Name)
            $call = $script:ValidateAst.Find({ param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq $Name
                }, $true)
            $call.Extent.StartOffset
        }
        $build = & $offset 'Invoke-ALBuild'
        $import = & $offset 'Import-BCContainerHelper'
        foreach ($name in 'Test-ReleasePin', 'Get-BaselineFolderConflict', 'Find-ReleaseApp', 'Test-SymbolOnlyApp') {
            (& $offset $name) | Should -BeLessThan $build
        }
        $build | Should -BeLessThan $import
    }
}

Describe 'Release app helpers' {
    BeforeAll {
        Import-Module (Join-Path $base 'symbol-feed.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot 'ReleaseAppFixture.psm1') -Force

        $script:AppId = '3ac22135-0000-4000-8000-000000000001'
        function New-ReleaseFolder {
            param([string]$Name, [hashtable]$Files)
            $folder = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            foreach ($fileName in $Files.Keys) {
                $file = $Files[$fileName]
                New-FixtureAppFile -Path (Join-Path $folder $fileName) -Id $file.Id -Name 'NAVEKSA ShopFloor365 MES' -Publisher 'NAVEKSA' -Version $file.Version | Out-Null
            }
            $folder
        }
    }

    BeforeEach {
        Mock -ModuleName build-operations Write-BuildMessage {}
        Mock -ModuleName symbol-feed Write-BuildMessage {}
    }

    Context 'Test-BaselineFoldersDistinct' {
        It 'reports one folder spelled two ways as not distinct' {
            $folder = Join-Path $TestDrive 'Release'
            Test-BaselineFoldersDistinct -ReleaseAppDir $folder -BaselinePackageCachePath $folder | Should -BeFalse
            Test-BaselineFoldersDistinct -ReleaseAppDir $folder -BaselinePackageCachePath ($folder + [System.IO.Path]::DirectorySeparatorChar) | Should -BeFalse
            Test-BaselineFoldersDistinct -ReleaseAppDir $folder -BaselinePackageCachePath ($folder.ToUpperInvariant()) | Should -BeFalse
            Test-BaselineFoldersDistinct -ReleaseAppDir $folder -BaselinePackageCachePath (Join-Path $TestDrive 'app' '..' 'Release') | Should -BeFalse
        }

        It 'reports two folders, including a folder and its child, as distinct' {
            $folder = Join-Path $TestDrive 'Release'
            Test-BaselineFoldersDistinct -ReleaseAppDir $folder -BaselinePackageCachePath (Join-Path $TestDrive 'baseline') | Should -BeTrue
            Test-BaselineFoldersDistinct -ReleaseAppDir $folder -BaselinePackageCachePath (Join-Path $folder 'baseline') | Should -BeTrue
        }
    }

    Context 'Get-BaselineFolderConflict' {
        It 'returns a message naming both keys when the two resolve to one folder' {
            $release = Join-Path $TestDrive 'shared'
            $settings = [pscustomobject]@{ Path = 'AppSourceCop.json'; Version = '1.0.0.0'; BaselinePackageCachePath = (Join-Path $TestDrive 'app' '..' 'shared') }
            $message = Get-BaselineFolderConflict -ReleaseAppDir $release -AppSourceCop $settings
            $message | Should -Match 'breakingChange\.releaseAppDir'
            $message | Should -Match 'baselinePackageCachePath'
        }

        It 'returns $null for two folders, an unset folder, no AppSourceCop.json, or no baseline folder' {
            $settings = [pscustomobject]@{ Path = 'AppSourceCop.json'; Version = '1.0.0.0'; BaselinePackageCachePath = (Join-Path $TestDrive 'baseline') }
            Get-BaselineFolderConflict -ReleaseAppDir (Join-Path $TestDrive 'release') -AppSourceCop $settings | Should -BeNullOrEmpty
            Get-BaselineFolderConflict -ReleaseAppDir $null -AppSourceCop $settings | Should -BeNullOrEmpty
            Get-BaselineFolderConflict -ReleaseAppDir (Join-Path $TestDrive 'release') -AppSourceCop $null | Should -BeNullOrEmpty
            $noFolder = [pscustomobject]@{ Path = 'AppSourceCop.json'; Version = '1.0.0.0'; BaselinePackageCachePath = $null }
            Get-BaselineFolderConflict -ReleaseAppDir (Join-Path $TestDrive 'release') -AppSourceCop $noFolder | Should -BeNullOrEmpty
        }
    }

    Context 'Find-ReleaseApp' {
        It 'selects a feed-style name with the spaces stripped and a compiler-style name with spaces' {
            $folder = New-ReleaseFolder -Name 'names' -Files @{
                'NAVEKSA_NAVEKSAShopFloor365MES_26.1.9.0.app'       = @{ Id = $script:AppId; Version = '26.1.9.0' }
                'NAVEKSA_NAVEKSA ShopFloor365 MES_26.1.9.0 (2).app' = @{ Id = $script:AppId; Version = '26.1.9.0' }
            }
            $found = @(Find-ReleaseApp -Folder $folder -AppId $script:AppId -Version '26.1.9.0')
            $found.Name | Should -Contain 'NAVEKSA_NAVEKSAShopFloor365MES_26.1.9.0.app'
            $found.Name | Should -Contain 'NAVEKSA_NAVEKSA ShopFloor365 MES_26.1.9.0 (2).app'
        }

        It 'selects by manifest, whatever the file name says' {
            $folder = New-ReleaseFolder -Name 'renamed' -Files @{
                'something-else.app' = @{ Id = $script:AppId; Version = '26.1.9.0' }
            }
            @(Find-ReleaseApp -Folder $folder -AppId $script:AppId -Version '26.1.9.0').Name | Should -Be 'something-else.app'
        }

        It 'leaves out a .app whose manifest version or id differs, whatever its file name says' {
            $folder = New-ReleaseFolder -Name 'mismatch' -Files @{
                'NAVEKSA_NAVEKSAShopFloor365MES_26.1.9.0.app' = @{ Id = $script:AppId; Version = '26.1.4.0' }
                'other-app_26.1.9.0.app'                      = @{ Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Version = '26.1.9.0' }
            }
            @(Find-ReleaseApp -Folder $folder -AppId $script:AppId -Version '26.1.9.0') | Should -HaveCount 0
        }

        It 'returns nothing for a missing folder and skips a file that is no .app' {
            @(Find-ReleaseApp -Folder (Join-Path $TestDrive 'no-such-folder') -AppId $script:AppId -Version '26.1.9.0') | Should -HaveCount 0

            $folder = New-ReleaseFolder -Name 'garbage' -Files @{ 'real.app' = @{ Id = $script:AppId; Version = '26.1.9.0' } }
            Set-Content -LiteralPath (Join-Path $folder 'broken.app') -Value 'not an app'
            @(Find-ReleaseApp -Folder $folder -AppId $script:AppId -Version '26.1.9.0').Name | Should -Be 'real.app'
        }
    }

    Context 'Test-SymbolOnlyApp' {
        BeforeEach {
            $script:SavedToolCache = $env:ALBT_TOOL_CACHE_ROOT
        }
        AfterEach {
            if ($null -ne $script:SavedToolCache) { $env:ALBT_TOOL_CACHE_ROOT = $script:SavedToolCache }
            else { Remove-Item Env:\ALBT_TOOL_CACHE_ROOT -ErrorAction SilentlyContinue }
        }

        It 'reads the answer from the `al IsSymbolOnly` output, with exit 0 for both answers' {
            $env:ALBT_TOOL_CACHE_ROOT = New-FixtureToolCache -Root (Join-Path $TestDrive 'tc-answers') -SymbolOnly @('symbols.app')
            Test-SymbolOnlyApp -Path (Join-Path $TestDrive 'folder' 'symbols.app') | Should -BeTrue
            Test-SymbolOnlyApp -Path (Join-Path $TestDrive 'folder' 'full.app') | Should -BeFalse
        }

        It 'throws when the command exits non-zero' {
            $env:ALBT_TOOL_CACHE_ROOT = New-FixtureToolCache -Root (Join-Path $TestDrive 'tc-fail') -Output 'The specified input package file does not exist.' -ExitCode 1
            { Test-SymbolOnlyApp -Path (Join-Path $TestDrive 'gone.app') } | Should -Throw '*exit 1*does not exist*'
        }

        It 'throws when the output holds no answer' {
            $env:ALBT_TOOL_CACHE_ROOT = New-FixtureToolCache -Root (Join-Path $TestDrive 'tc-garbage') -Output 'something unexpected'
            { Test-SymbolOnlyApp -Path (Join-Path $TestDrive 'x.app') } | Should -Throw '*no answer*something unexpected*'
        }

        It 'throws when no compiler is provisioned' {
            $env:ALBT_TOOL_CACHE_ROOT = Join-Path $TestDrive 'tc-empty'
            { Test-SymbolOnlyApp -Path (Join-Path $TestDrive 'x.app') } | Should -Throw '*provision*'
        }
    }
}

# validate-breaking-changes.ps1 runs as a fresh pwsh process rooted at a fixture Consumer repository
# under TestDrive. ALBT_APPSOURCESYMBOLS_FEED points at a local flat2 feed and ALBT_TOOL_CACHE_ROOT at
# a fixture tool cache whose `al` stub answers IsSymbolOnly, so nothing reaches the network, a compiler,
# or a container. A run that passes every prerequisite goes on to Invoke-ALBuild, where the stub
# compiler fails, so the selection cases assert the chosen file from the script's output.
Describe 'validate-breaking-changes.ps1 prerequisites' -Tag 'Process' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot 'ReleaseAppFixture.psm1') -Force

        $script:ValidateScript = Join-Path $base 'validate-breaking-changes.ps1'
        $script:Pwsh = Join-Path $PSHOME 'pwsh.exe'
        $script:AppId = '3ac22135-0000-4000-8000-000000000001'
        $script:PackageId = "NAVEKSA.NAVEKSAShopFloor365MES.symbols.$($script:AppId)"
        $script:AppIdentity = @{ Id = $script:AppId; Name = 'NAVEKSA ShopFloor365 MES'; Publisher = 'NAVEKSA' }
        $script:Pin = '26.1.9.0'
        $script:FeedStyleName = 'NAVEKSA_NAVEKSAShopFloor365MES_26.1.9.0.app'
        $script:CompilerStyleName = 'NAVEKSA_NAVEKSA ShopFloor365 MES_26.1.9.0.app'

        function New-ValidateFixture {
            param(
                [Parameter(Mandatory)][string]$Root,
                [string]$Pin,
                [switch]$Enabled,
                [string]$ReleaseAppDir,
                [string]$BaselinePackageCachePath,
                [switch]$NoAffixes
            )
            $appDir = Join-Path $Root 'app'
            New-Item -ItemType Directory -Path $appDir -Force | Out-Null
            [ordered]@{
                id = $script:AppId; name = 'NAVEKSA ShopFloor365 MES'; publisher = 'NAVEKSA'; version = '1.0.0.0'
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'app.json') -Encoding UTF8
            $breakingChange = [ordered]@{ enabled = [bool]$Enabled }
            if ($ReleaseAppDir) { $breakingChange['releaseAppDir'] = $ReleaseAppDir }
            [ordered]@{ appDir = 'app'; testApps = @(); breakingChange = $breakingChange } |
                ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'al-build.json') -Encoding UTF8
            $asc = [ordered]@{ supportedCountries = @('dk') }
            if (-not $NoAffixes) { $asc['mandatoryAffixes'] = @('NALICF') }
            if ($Pin) { $asc['version'] = $Pin }
            if ($BaselinePackageCachePath) { $asc['baselinePackageCachePath'] = $BaselinePackageCachePath }
            $asc | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'AppSourceCop.json') -Encoding UTF8
        }

        function New-ValidateFeed {
            param([Parameter(Mandatory)][string]$Root, [hashtable]$Releases = @{ '26.1.9' = '26.1.9.0' })
            New-FixtureReleaseFeed -FeedRoot $Root -PackageId $script:PackageId -App $script:AppIdentity -Releases $Releases | Out-Null
        }

        function New-ReleaseAppFile {
            param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][string]$Name, [string]$Version = $script:Pin)
            New-FixtureAppFile -Path (Join-Path $Folder $Name) -Id $script:AppId -Name 'NAVEKSA ShopFloor365 MES' -Publisher 'NAVEKSA' -Version $Version | Out-Null
        }

        function Invoke-Validate {
            param(
                [Parameter(Mandatory)][string]$Root,
                [Parameter(Mandatory)][string]$Feed,
                [string[]]$SymbolOnly = @(),
                [switch]$NoCompiler
            )
            $toolCache = Join-Path $Root '.tool-cache'
            New-Item -ItemType Directory -Path $toolCache -Force | Out-Null
            if (-not $NoCompiler) { New-FixtureToolCache -Root $toolCache -SymbolOnly $SymbolOnly | Out-Null }
            # Paths travel as environment variables, so no quote in one can break the command. The
            # child's own ALBT_* variables are cleared first: they outrank the fixture's al-build.json.
            $env:VALTEST_ROOT = $Root
            $env:VALTEST_FEED = $Feed
            $env:VALTEST_TOOLCACHE = $toolCache
            $env:VALTEST_SCRIPT = $script:ValidateScript
            # A fake BcContainerHelper, newest on PSModulePath, writes a marker file when imported.
            $fakeModules = Join-Path $Root '.fake-modules'
            $fakeModule = Join-Path $fakeModules 'BcContainerHelper' '999.0.0'
            New-Item -ItemType Directory -Path $fakeModule -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $fakeModule 'BcContainerHelper.psm1') -Encoding UTF8 `
                -Value 'Set-Content -LiteralPath $env:VALTEST_BCH_MARKER -Value imported'
            New-ModuleManifest -Path (Join-Path $fakeModule 'BcContainerHelper.psd1') -RootModule 'BcContainerHelper.psm1' -ModuleVersion '999.0.0'
            $marker = Join-Path $Root '.bch-imported'
            Remove-Item -LiteralPath $marker -ErrorAction SilentlyContinue
            $env:VALTEST_BCH_MARKER = $marker
            $env:VALTEST_MODULES = $fakeModules
            try {
                $command = 'Get-ChildItem Env:ALBT_* | Remove-Item; $env:ALBT_APPSOURCESYMBOLS_FEED = $env:VALTEST_FEED; ' +
                    '$env:ALBT_TOOL_CACHE_ROOT = $env:VALTEST_TOOLCACHE; ' +
                    '$env:PSModulePath = $env:VALTEST_MODULES + [System.IO.Path]::PathSeparator + $env:PSModulePath; ' +
                    'Set-Location -LiteralPath $env:VALTEST_ROOT; & $env:VALTEST_SCRIPT; exit $LASTEXITCODE'
                $output = & $script:Pwsh -NoProfile -Command $command 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                Remove-Item Env:VALTEST_ROOT, Env:VALTEST_FEED, Env:VALTEST_TOOLCACHE, Env:VALTEST_SCRIPT, Env:VALTEST_BCH_MARKER, Env:VALTEST_MODULES -ErrorAction SilentlyContinue
            }
            [pscustomobject]@{
                ExitCode                = $exitCode
                Output                  = (@($output | ForEach-Object { "$_" }) -join "`n")
                BcContainerHelperLoaded = (Test-Path -LiteralPath $marker)
            }
        }

        # A prerequisite failure ends before the build and before BcContainerHelper loads.
        function Assert-StoppedBeforeBuild {
            param($Result)
            $Result.Output | Should -Not -Match 'Building current app|AL Project Compilation|Running Validation|Running AL validation'
            $Result.BcContainerHelperLoaded | Should -BeFalse -Because 'the fake BcContainerHelper on PSModulePath writes a marker when imported'
        }

        # A fixture with a current pin, enabled, and a release folder under the repo root.
        function New-ReadyFixture {
            param([Parameter(Mandatory)][string]$Name, [switch]$NoVersion)
            $root = Join-Path $TestDrive $Name
            $feed = Join-Path $TestDrive "$Name-feed"
            New-ValidateFixture -Root $root -Pin $(if (-not $NoVersion) { $script:Pin }) -Enabled -ReleaseAppDir 'release' -BaselinePackageCachePath '../.baseline'
            New-ValidateFeed -Root $feed
            New-Item -ItemType Directory -Path (Join-Path $root 'release') -Force | Out-Null
            [pscustomobject]@{ Root = $root; Feed = $feed; Release = (Join-Path $root 'release') }
        }
    }

    It 'stops with exit 4 and names the latest Release when the pin is stale, with enabled false' {
        $root = Join-Path $TestDrive 'stale'
        $feed = Join-Path $TestDrive 'stale-feed'
        New-ValidateFixture -Root $root -Pin '26.1.4.0'
        New-ValidateFeed -Root $feed

        $result = Invoke-Validate -Root $root -Feed $feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match '26\.1\.9\.0'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 1 and names the feed when the pin cannot be checked' {
        $root = Join-Path $TestDrive 'unreachable'
        $missingFeed = Join-Path $TestDrive 'unreachable-no-such-feed'
        New-ValidateFixture -Root $root -Pin $script:Pin

        $result = Invoke-Validate -Root $root -Feed $missingFeed

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match ([regex]::Escape($missingFeed))
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 for a version with no Release on the feed' {
        $root = Join-Path $TestDrive 'no-release'
        $feed = Join-Path $TestDrive 'no-release-feed'
        New-ValidateFixture -Root $root -Pin $script:Pin -Enabled -ReleaseAppDir 'release'
        New-FixtureFeedPackage -FeedRoot $feed -PackageId 'Contoso.Other.symbols.bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' -NuGetVersion '1.0.0' `
            -App @{ Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Name = 'Other'; Publisher = 'Contoso'; Version = '1.0.0.0' } | Out-Null

        $result = Invoke-Validate -Root $root -Feed $feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match ([regex]::Escape($script:PackageId))
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 0 with no build and no BcContainerHelper when the pin is current and enabled is false' {
        $root = Join-Path $TestDrive 'current-disabled'
        $feed = Join-Path $TestDrive 'current-disabled-feed'
        New-ValidateFixture -Root $root -Pin $script:Pin
        New-ValidateFeed -Root $feed

        $result = Invoke-Validate -Root $root -Feed $feed

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Not -Match 'releaseAppDir'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 0 and reads no feed when AppSourceCop.json carries no version and enabled is false' {
        $root = Join-Path $TestDrive 'no-version-disabled'
        New-ValidateFixture -Root $root

        $result = Invoke-Validate -Root $root -Feed (Join-Path $TestDrive 'no-version-disabled-missing-feed')

        $result.ExitCode | Should -Be 0
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4, naming the file, when AppSourceCop.json is not valid JSON' {
        $root = Join-Path $TestDrive 'broken-asc'
        New-ValidateFixture -Root $root -Enabled
        Set-Content -LiteralPath (Join-Path $root 'app' 'AppSourceCop.json') -Value '{ not json' -Encoding UTF8

        $result = Invoke-Validate -Root $root -Feed (Join-Path $TestDrive 'broken-asc-feed')

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match 'AppSourceCop\.json.*not valid JSON'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 and names breakingChange.releaseAppDir when enabled is true and the key is absent' {
        $root = Join-Path $TestDrive 'no-key'
        $feed = Join-Path $TestDrive 'no-key-feed'
        New-ValidateFixture -Root $root -Pin $script:Pin -Enabled
        New-ValidateFeed -Root $feed

        $result = Invoke-Validate -Root $root -Feed $feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match 'breakingChange\.releaseAppDir'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 and names version when enabled is true and AppSourceCop.json pins none' {
        $fixture = New-ReadyFixture -Name 'no-pin' -NoVersion

        $result = Invoke-Validate -Root $fixture.Root -Feed (Join-Path $TestDrive 'no-pin-missing-feed')

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match 'pins no version'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 and names both keys when releaseAppDir and baselinePackageCachePath, each from its own base, name one folder' {
        $root = Join-Path $TestDrive 'same-folder'
        $feed = Join-Path $TestDrive 'same-folder-feed'
        # releaseAppDir resolves from the repo root, baselinePackageCachePath from the app folder.
        New-ValidateFixture -Root $root -Pin $script:Pin -Enabled -ReleaseAppDir 'shared' -BaselinePackageCachePath '../shared/'
        New-ValidateFeed -Root $feed
        New-ReleaseAppFile -Folder (Join-Path $root 'shared') -Name $script:FeedStyleName

        $result = Invoke-Validate -Root $root -Feed $feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match 'breakingChange\.releaseAppDir'
        $result.Output | Should -Match 'baselinePackageCachePath'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 and names the pinned version and the folder when the folder holds no matching .app' {
        $fixture = New-ReadyFixture -Name 'no-match'
        # A real .app of the wrong version, under the right file name.
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:FeedStyleName -Version '26.1.4.0'

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match '26\.1\.9\.0'
        $result.Output | Should -Match ([regex]::Escape($fixture.Release))
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 when the releaseAppDir folder does not exist' {
        $fixture = New-ReadyFixture -Name 'no-folder'
        Remove-Item -LiteralPath $fixture.Release -Recurse -Force

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match ([regex]::Escape($fixture.Release))
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 when a matched .app is symbols-only' {
        $fixture = New-ReadyFixture -Name 'symbols-only'
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:FeedStyleName

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed -SymbolOnly @($script:FeedStyleName)

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match ([regex]::Escape($script:FeedStyleName))
        $result.Output | Should -Match 'symbols-only'
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 naming the symbols-only file when the folder holds it beside the real Release .app' {
        $fixture = New-ReadyFixture -Name 'both'
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:FeedStyleName
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:CompilerStyleName

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed -SymbolOnly @($script:FeedStyleName)

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match ([regex]::Escape($script:FeedStyleName) + ' is a symbols-only')
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 naming both files when the folder holds two real .app files of the pinned version' {
        $fixture = New-ReadyFixture -Name 'two-real'
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:FeedStyleName
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:CompilerStyleName

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match ([regex]::Escape($script:FeedStyleName))
        $result.Output | Should -Match ([regex]::Escape($script:CompilerStyleName))
        Assert-StoppedBeforeBuild $result
    }

    It 'exits 4 and names provision.ps1 when no compiler is provisioned' {
        $fixture = New-ReadyFixture -Name 'no-compiler'
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:FeedStyleName

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed -NoCompiler

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match 'provision\.ps1'
        Assert-StoppedBeforeBuild $result
    }

    It 'selects a real .app under a feed-style name and goes on to the build' {
        $fixture = New-ReadyFixture -Name 'feed-name'
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:FeedStyleName

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed

        $result.Output | Should -Match ('Release app: ' + [regex]::Escape($script:FeedStyleName))
        $result.Output | Should -Match 'Building current app'
        $result.ExitCode | Should -Not -Be 0
    }

    It 'selects a real .app under a compiler-style name with spaces and goes on to the build' {
        $fixture = New-ReadyFixture -Name 'compiler-name'
        New-ReleaseAppFile -Folder $fixture.Release -Name $script:CompilerStyleName

        $result = Invoke-Validate -Root $fixture.Root -Feed $fixture.Feed

        $result.Output | Should -Match ('Release app: ' + [regex]::Escape($script:CompilerStyleName))
        $result.Output | Should -Match 'Building current app'
        $result.ExitCode | Should -Not -Be 0
    }
}

# download-baseline.ps1 checks the Release pin, then fills the compile baseline folder. Each case runs
# it as a fresh pwsh process rooted at a fixture Consumer repository under TestDrive, with both symbol
# feeds pointed at local flat2 directories, so Get-BuildConfig reads the fixture's al-build.json and
# nothing reaches the network.
Describe 'download-baseline.ps1' -Tag 'Process' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force
        Import-Module (Resolve-Path (Join-Path $base 'symbol-feed.psm1')) -Force -DisableNameChecking

        $script:DownloadBaselineScript = Join-Path $base 'download-baseline.ps1'
        $script:Pwsh = Join-Path $PSHOME 'pwsh.exe'
        $script:FolderName = '.appSourceCopPackages'
        $script:StaleName = 'Stale.Release.1.0.0.0.app'
        $script:AppId = '3ac22135-0000-4000-8000-000000000001'
        $script:PackageId = "NAVEKSA.NAVEKSAShopFloor365MES.symbols.$($script:AppId)"
        $script:AppIdentity = @{ Id = $script:AppId; Name = 'NAVEKSA ShopFloor365 MES'; Publisher = 'NAVEKSA' }
        $script:EmptyFeed = Join-Path $TestDrive 'empty-mssymbols'
        New-Item -ItemType Directory -Path $script:EmptyFeed -Force | Out-Null

        # A Consumer repository: app.json, al-build.json, and an AppSourceCop.json that names its
        # baseline folder unless -NoCachePath is set. -Baseline adds the baseline folder with a
        # committed README.md and .gitignore (ignoring *.app) and one stale .app, and commits every
        # file to a fresh git repository; -TrackedApp commits the stale .app too.
        function New-ConsumerFixture {
            param(
                [Parameter(Mandatory)][string]$Root,
                [string]$Pin,
                [switch]$NoAppSourceCop,
                [switch]$NoCachePath,
                [switch]$BreakingChangeEnabled,
                [switch]$Baseline,
                [switch]$TrackedApp
            )
            $appDir = Join-Path $Root 'app'
            $folder = Join-Path $appDir $script:FolderName
            New-Item -ItemType Directory -Path $appDir -Force | Out-Null
            [ordered]@{
                id = $script:AppId; name = 'NAVEKSA ShopFloor365 MES'; publisher = 'NAVEKSA'; version = '1.0.0.0'
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'app.json') -Encoding UTF8
            [ordered]@{
                appDir         = 'app'
                testApps       = @()
                breakingChange = [ordered]@{ enabled = [bool]$BreakingChangeEnabled }
            } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'al-build.json') -Encoding UTF8
            if (-not $NoAppSourceCop) {
                $cop = [ordered]@{ mandatoryAffixes = @('NALICF'); supportedCountries = @('dk') }
                if ($Pin) { $cop['version'] = $Pin }
                if (-not $NoCachePath) { $cop['baselinePackageCachePath'] = "./$($script:FolderName)" }
                $cop | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'AppSourceCop.json') -Encoding UTF8
            }
            if (-not $Baseline) { return }

            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $folder 'README.md') -Value 'Baseline folder.' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $folder '.gitignore') -Value '*.app' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $folder $script:StaleName) -Value 'stale' -Encoding UTF8
            git -C $Root init -q
            git -C $Root config user.email 'test@example.invalid'
            git -C $Root config user.name 'test'
            git -C $Root config commit.gpgsign false
            git -C $Root add -A
            if ($TrackedApp) { git -C $Root add -f -- (Join-Path $folder $script:StaleName) }
            git -C $Root commit -q -m 'fixture'
        }

        function New-PinFeed {
            param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][hashtable]$Releases)
            New-FixtureReleaseFeed -FeedRoot $Root -PackageId $script:PackageId -App $script:AppIdentity -Releases $Releases | Out-Null
        }

        function Invoke-DownloadBaseline {
            param(
                [Parameter(Mandatory)][string]$Root,
                [Parameter(Mandatory)][string]$Feed,
                [string]$MsFeed = $script:EmptyFeed
            )
            # Paths travel as environment variables, so no quote in one can break the command. The
            # child's own ALBT_* variables are cleared first: they outrank the fixture's al-build.json.
            $env:PINTEST_ROOT = $Root
            $env:PINTEST_FEED = $Feed
            $env:PINTEST_MSFEED = $MsFeed
            $env:PINTEST_SCRIPT = $script:DownloadBaselineScript
            try {
                $command = 'Get-ChildItem Env:ALBT_* | Remove-Item; $env:ALBT_APPSOURCESYMBOLS_FEED = $env:PINTEST_FEED; ' +
                    '$env:ALBT_MSSYMBOLS_FEED = $env:PINTEST_MSFEED; ' +
                    'Set-Location -LiteralPath $env:PINTEST_ROOT; & $env:PINTEST_SCRIPT; exit $LASTEXITCODE'
                $output = & $script:Pwsh -NoProfile -Command $command 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                Remove-Item Env:PINTEST_ROOT, Env:PINTEST_FEED, Env:PINTEST_MSFEED, Env:PINTEST_SCRIPT -ErrorAction SilentlyContinue
            }
            [pscustomobject]@{
                ExitCode = $exitCode
                Output   = (@($output | ForEach-Object { "$_" }) -join "`n")
            }
        }

        function Get-AscBase64 {
            param([string]$Root)
            $path = Join-Path $Root 'app' 'AppSourceCop.json'
            if (Test-Path -LiteralPath $path) { return [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path)) }
            return $null
        }

        # The committed file is byte-identical and the retired cache folder was never created.
        function Assert-Untouched {
            param([string]$Root, $Before)
            Get-AscBase64 -Root $Root | Should -Be $Before
            (Join-Path $Root '.output' 'baseline-cache') | Should -Not -Exist
        }

        function Get-BaselineApps {
            param([string]$Root)
            $folder = Join-Path $Root 'app' $script:FolderName
            @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object Extension -eq '.app')
        }

        # Every file in the baseline folder with its content hash, to compare before and after a run.
        function Get-FolderSnapshot {
            param([string]$Root)
            @(Get-ChildItem -LiteralPath (Join-Path $Root 'app' $script:FolderName) -File -Force | Sort-Object Name |
                ForEach-Object { '{0}:{1}' -f $_.Name, (Get-FileHash -LiteralPath $_.FullName).Hash })
        }
    }

    Context 'Release pin check' {
        It 'passes with exit 0 and fills the baseline folder when the pin equals the latest Release' {
            $root = Join-Path $TestDrive 'equal'
            $feed = Join-Path $TestDrive 'equal-feed'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1'
            New-PinFeed -Root $feed -Releases @{ '26.1.4' = '26.1.4.0'; '26.1.9.1' = '26.1.9.1' }
            $before = Get-AscBase64 -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $feed

            $result.ExitCode | Should -Be 0 -Because $result.Output
            Assert-Untouched -Root $root -Before $before
            $apps = Get-BaselineApps -Root $root
            $apps.Count | Should -Be 1
            (Read-AppManifest -Path $apps[0].FullName).Version | Should -Be '26.1.9.1'
        }

        It 'stops with exit 4 and names the latest Release when the pin is stale' {
            $root = Join-Path $TestDrive 'stale'
            $feed = Join-Path $TestDrive 'stale-feed'
            New-ConsumerFixture -Root $root -Pin '26.1.9.0'
            New-PinFeed -Root $feed -Releases @{ '26.1.4' = '26.1.4.0'; '26.1.9.1' = '26.1.9.1' }
            $before = Get-AscBase64 -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $feed

            $result.ExitCode | Should -Be 4
            $result.Output | Should -Match '26\.1\.9\.1'
            Assert-Untouched -Root $root -Before $before
        }

        It 'compares the pin with the manifest version, not the trimmed NuGet version' {
            $feed = Join-Path $TestDrive 'trimmed-feed'
            New-PinFeed -Root $feed -Releases @{ '26.1.9' = '26.1.9.0' }

            $current = Join-Path $TestDrive 'trimmed-current'
            New-ConsumerFixture -Root $current -Pin '26.1.9.0'
            $currentBefore = Get-AscBase64 -Root $current
            (Invoke-DownloadBaseline -Root $current -Feed $feed).ExitCode | Should -Be 0
            Assert-Untouched -Root $current -Before $currentBefore

            $older = Join-Path $TestDrive 'trimmed-older'
            New-ConsumerFixture -Root $older -Pin '26.1.4.0'
            $olderBefore = Get-AscBase64 -Root $older
            $olderResult = Invoke-DownloadBaseline -Root $older -Feed $feed
            $olderResult.ExitCode | Should -Be 4
            $olderResult.Output | Should -Match '26\.1\.9\.0'
            Assert-Untouched -Root $older -Before $olderBefore
        }

        It 'checks the pin whatever breakingChange.enabled and al.codeAnalyzers say' {
            $feed = Join-Path $TestDrive 'enabled-feed'
            New-PinFeed -Root $feed -Releases @{ '26.1.9' = '26.1.9.0' }

            $disabled = Join-Path $TestDrive 'disabled'
            New-ConsumerFixture -Root $disabled -Pin '26.1.4.0'
            (Get-Content -LiteralPath (Join-Path $disabled 'al-build.json') -Raw | ConvertFrom-Json).breakingChange.enabled | Should -BeFalse
            (Join-Path $disabled '.vscode' 'settings.json') | Should -Not -Exist
            (Join-Path $disabled 'app' '.vscode' 'settings.json') | Should -Not -Exist
            $before = Get-AscBase64 -Root $disabled
            (Invoke-DownloadBaseline -Root $disabled -Feed $feed).ExitCode | Should -Be 4
            Assert-Untouched -Root $disabled -Before $before

            $enabled = Join-Path $TestDrive 'enabled'
            New-ConsumerFixture -Root $enabled -Pin '26.1.4.0' -BreakingChangeEnabled
            (Invoke-DownloadBaseline -Root $enabled -Feed $feed).ExitCode | Should -Be 4
        }

        It 'exits 0 and reads no feed when AppSourceCop.json is absent' {
            $root = Join-Path $TestDrive 'no-asc'
            New-ConsumerFixture -Root $root -NoAppSourceCop
            $unreachable = Join-Path $TestDrive 'no-asc-missing-feed'

            $result = Invoke-DownloadBaseline -Root $root -Feed $unreachable

            $result.ExitCode | Should -Be 0
            Assert-Untouched -Root $root -Before $null
        }

        It 'exits 0 and reads no feed when AppSourceCop.json carries no version' {
            $root = Join-Path $TestDrive 'no-version'
            New-ConsumerFixture -Root $root
            $unreachable = Join-Path $TestDrive 'no-version-missing-feed'
            $before = Get-AscBase64 -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $unreachable

            $result.ExitCode | Should -Be 0
            Assert-Untouched -Root $root -Before $before
        }

        It 'stops with exit 4, naming the file, when AppSourceCop.json is not valid JSON' {
            $root = Join-Path $TestDrive 'broken-asc'
            New-ConsumerFixture -Root $root -NoAppSourceCop
            Set-Content -LiteralPath (Join-Path $root 'app' 'AppSourceCop.json') -Value '{ not json' -Encoding UTF8
            $before = Get-AscBase64 -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed (Join-Path $TestDrive 'broken-asc-feed')

            $result.ExitCode | Should -Be 4
            $result.Output | Should -Match 'AppSourceCop\.json.*not valid JSON'
            Assert-Untouched -Root $root -Before $before
        }

        It 'exits 0 without an app folder, which holds no AppSourceCop.json' {
            $root = Join-Path $TestDrive 'no-app-folder'
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [ordered]@{ appDir = 'app'; testApps = @() } | ConvertTo-Json |
                Set-Content -LiteralPath (Join-Path $root 'al-build.json') -Encoding UTF8

            (Invoke-DownloadBaseline -Root $root -Feed (Join-Path $TestDrive 'no-app-folder-feed')).ExitCode | Should -Be 0
        }

        It 'stops with exit 4 when the app has no Release on the feed' {
            $root = Join-Path $TestDrive 'no-release'
            $feed = Join-Path $TestDrive 'no-release-feed'
            New-ConsumerFixture -Root $root -Pin '26.1.9.0'
            New-FixtureFeedPackage -FeedRoot $feed -PackageId 'Contoso.Other.symbols.bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' -NuGetVersion '1.0.0' `
                -App @{ Id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; Name = 'Other'; Publisher = 'Contoso'; Version = '1.0.0.0' } | Out-Null
            $before = Get-AscBase64 -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $feed

            $result.ExitCode | Should -Be 4
            $result.Output | Should -Match ([regex]::Escape($script:PackageId))
            Assert-Untouched -Root $root -Before $before
        }

        It 'stops with exit 1 and names the feed when it cannot be reached' {
            $root = Join-Path $TestDrive 'unreachable'
            $missingFeed = Join-Path $TestDrive 'unreachable-no-such-feed'
            New-ConsumerFixture -Root $root -Pin '26.1.9.0'
            $before = Get-AscBase64 -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $missingFeed

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match ([regex]::Escape($missingFeed))
            Assert-Untouched -Root $root -Before $before
        }
    }

    Context 'baseline fill' {
        BeforeAll {
            $script:LibraryId = '3ac22135-0000-4000-8000-000000000002'
            $script:MsApplicationId = '3ac22135-0000-4000-8000-000000000003'
            $script:MsSystemId = '3ac22135-0000-4000-8000-000000000004'
            $script:LibraryPackageId = "Contoso.ContosoLib.symbols.$($script:LibraryId)"
            $script:ApplicationPackageId = 'Microsoft.Application.symbols'
            $script:SystemPackageId = 'Microsoft.System.symbols'
            $script:GhostPackageId = 'Contoso.Ghost.symbols.aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

            # Release -> Contoso Lib (AppSourceSymbols) -> Application (MSSymbols), plus System
            # (MSSymbols) directly. Each package sits in exactly one feed, so its .app in the folder
            # names the feed that served it; Contoso Lib lists two versions at or above its minimum. With -MissingDependency the Release's direct dependency
            # is on neither feed.
            function New-FillFeeds {
                param([Parameter(Mandatory)][string]$Root, [switch]$MissingDependency)
                $ms = Join-Path $Root 'mssymbols'
                $appSource = Join-Path $Root 'appsourcesymbols'
                New-FixtureFeedPackage -FeedRoot $ms -PackageId $script:ApplicationPackageId -NuGetVersion '26.0.0' `
                    -App @{ Id = $script:MsApplicationId; Name = 'Application'; Publisher = 'Microsoft'; Version = '26.0.0.0' } | Out-Null
                New-FixtureFeedPackage -FeedRoot $ms -PackageId $script:SystemPackageId -NuGetVersion '26.0.0' `
                    -App @{ Id = $script:MsSystemId; Name = 'System'; Publisher = 'Microsoft'; Version = '26.0.0.0' } | Out-Null
                foreach ($libraryVersion in '2.0.0', '2.1.0') {
                    New-FixtureFeedPackage -FeedRoot $appSource -PackageId $script:LibraryPackageId -NuGetVersion $libraryVersion `
                        -App @{ Id = $script:LibraryId; Name = 'Contoso Lib'; Publisher = 'Contoso'; Version = "$libraryVersion.0" } `
                        -Dependencies @(@{ Id = $script:ApplicationPackageId; Version = '26.0.0' }) | Out-Null
                }
                $directId = if ($MissingDependency) { $script:GhostPackageId } else { $script:SystemPackageId }
                foreach ($release in @{ '26.1.4' = '26.1.4.0'; '26.1.9.1' = '26.1.9.1' }.GetEnumerator()) {
                    $app = $script:AppIdentity.Clone()
                    $app.Version = $release.Value
                    New-FixtureFeedPackage -FeedRoot $appSource -PackageId $script:PackageId -NuGetVersion $release.Key -App $app `
                        -Dependencies @(@{ Id = $script:LibraryPackageId; Version = '1.0.0' }, @{ Id = $directId; Version = '26.0.0' }) | Out-Null
                }
                [pscustomobject]@{ Ms = $ms; AppSource = $appSource }
            }

            $script:Feeds = New-FillFeeds -Root (Join-Path $TestDrive 'fill-feeds')
            $script:GhostFeeds = New-FillFeeds -Root (Join-Path $TestDrive 'fill-feeds-ghost') -MissingDependency
        }

        Context 'with a current pin' {
            BeforeAll {
                $script:FilledRoot = Join-Path $TestDrive 'filled'
                New-ConsumerFixture -Root $script:FilledRoot -Pin '26.1.9.1' -Baseline
                $script:CopBefore = [System.IO.File]::ReadAllBytes((Join-Path $script:FilledRoot 'app' 'AppSourceCop.json'))
                $script:ReadmeBefore = (Get-FileHash -LiteralPath (Join-Path $script:FilledRoot 'app' $script:FolderName 'README.md')).Hash
                $script:FilledResult = Invoke-DownloadBaseline -Root $script:FilledRoot -Feed $script:Feeds.AppSource -MsFeed $script:Feeds.Ms
            }

            It 'writes the Release and its dependencies from both feeds, transitively' {
                $script:FilledResult.ExitCode | Should -Be 0 -Because $script:FilledResult.Output

                $apps = Get-BaselineApps -Root $script:FilledRoot
                $manifests = @($apps | ForEach-Object { Read-AppManifest -Path $_.FullName })
                $apps.Count | Should -Be 4
                ($manifests.Id | Sort-Object) | Should -Be (@($script:AppId, $script:LibraryId, $script:MsApplicationId, $script:MsSystemId) | Sort-Object)
                ($manifests | Where-Object Id -eq $script:AppId).Version | Should -Be '26.1.9.1'
            }

            It 'takes the highest version a feed lists at or above a dependency minimum' {
                $library = Get-BaselineApps -Root $script:FilledRoot | ForEach-Object { Read-AppManifest -Path $_.FullName } | Where-Object Id -eq $script:LibraryId
                @($library).Count | Should -Be 1
                $library.Version | Should -Be '2.1.0.0'
            }

            It 'changes no committed file and removes only the stale .app' {
                git -C $script:FilledRoot status --porcelain | Should -BeNullOrEmpty
                [System.IO.File]::ReadAllBytes((Join-Path $script:FilledRoot 'app' 'AppSourceCop.json')) | Should -Be $script:CopBefore
                (Get-FileHash -LiteralPath (Join-Path $script:FilledRoot 'app' $script:FolderName 'README.md')).Hash | Should -Be $script:ReadmeBefore
                (Join-Path $script:FilledRoot 'app' $script:FolderName $script:StaleName) | Should -Not -Exist
                (Get-BaselineApps -Root $script:FilledRoot).Count | Should -Be 4
            }
        }

        It 'stops with exit 4 naming baselinePackageCachePath and writes nothing when the key is missing' {
            $root = Join-Path $TestDrive 'no-key'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -NoCachePath -Baseline
            $before = Get-FolderSnapshot -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $script:Feeds.AppSource -MsFeed $script:Feeds.Ms

            $result.ExitCode | Should -Be 4
            $result.Output | Should -Match 'baselinePackageCachePath'
            Get-FolderSnapshot -Root $root | Should -Be $before
            @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.app').Count | Should -Be 1
        }

        It 'leaves every file in the folder as it was when the pin is stale' {
            $root = Join-Path $TestDrive 'stale-pin'
            New-ConsumerFixture -Root $root -Pin '26.1.4.0' -Baseline
            $before = Get-FolderSnapshot -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $script:Feeds.AppSource -MsFeed $script:Feeds.Ms

            $result.ExitCode | Should -Be 4
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'leaves every file in the folder as it was when AppSourceCop.json has no version' {
            $root = Join-Path $TestDrive 'no-pin'
            New-ConsumerFixture -Root $root -Baseline
            $before = Get-FolderSnapshot -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $script:Feeds.AppSource -MsFeed $script:Feeds.Ms

            $result.ExitCode | Should -Be 0
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'stops with exit 1 naming the package, and leaves the folder as it was, when a dependency is on neither feed' {
            $root = Join-Path $TestDrive 'ghost'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -Baseline
            $before = Get-FolderSnapshot -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $script:GhostFeeds.AppSource -MsFeed $script:GhostFeeds.Ms

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match ([regex]::Escape($script:GhostPackageId))
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'stops with exit 1 naming the package, and leaves the folder as it was, when a feed fails mid-fill' {
            $root = Join-Path $TestDrive 'mid-fill'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -Baseline
            $before = Get-FolderSnapshot -Root $root
            $feeds = New-FillFeeds -Root (Join-Path $TestDrive 'mid-fill-feeds')
            Remove-Item -LiteralPath (Join-Path $feeds.Ms 'flat2' $script:ApplicationPackageId.ToLowerInvariant() '26.0.0') -Recurse -Force

            $result = Invoke-DownloadBaseline -Root $root -Feed $feeds.AppSource -MsFeed $feeds.Ms

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match ([regex]::Escape($script:ApplicationPackageId))
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'stops with exit 1 naming the feed, and leaves the folder as it was, when a feed cannot be read' {
            $root = Join-Path $TestDrive 'unreadable-ms'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -Baseline
            $before = Get-FolderSnapshot -Root $root
            $missingMs = Join-Path $TestDrive 'unreadable-ms-no-such-feed'

            $result = Invoke-DownloadBaseline -Root $root -Feed $script:Feeds.AppSource -MsFeed $missingMs

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match ([regex]::Escape($missingMs))
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'restores the old .app files and exits 1 when a file cannot be moved' {
            $root = Join-Path $TestDrive 'swap-fails'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -Baseline
            $locked = Join-Path $root 'app' $script:FolderName 'Zz.Locked.1.0.0.0.app'
            Set-Content -LiteralPath $locked -Value 'locked' -Encoding UTF8
            $before = Get-FolderSnapshot -Root $root

            # Stale.Release moves to the backup first; the open handle then stops Zz.Locked from moving.
            $handle = [System.IO.File]::Open($locked, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            try {
                $result = Invoke-DownloadBaseline -Root $root -Feed $script:Feeds.AppSource -MsFeed $script:Feeds.Ms
            } finally {
                $handle.Dispose()
            }

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'old \*\.app files are restored'
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'stops with exit 4 and leaves the folder as it was when the latest Release is not the version asked for' {
            $root = Join-Path $TestDrive 'manifest-differs'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -Baseline
            $before = Get-FolderSnapshot -Root $root
            $appJson = Get-Content -LiteralPath (Join-Path $root 'app' 'app.json') -Raw | ConvertFrom-Json
            $env:ALBT_MSSYMBOLS_FEED = $script:Feeds.Ms
            $env:ALBT_APPSOURCESYMBOLS_FEED = $script:Feeds.AppSource
            try {
                $result = Save-ReleaseBaseline -AppJson $appJson -Version '26.1.4.0' -Folder (Join-Path $root 'app' $script:FolderName)
            } finally {
                Remove-Item Env:ALBT_MSSYMBOLS_FEED, Env:ALBT_APPSOURCESYMBOLS_FEED -ErrorAction SilentlyContinue
            }

            $result.ExitCode | Should -Be 4
            $result.Message | Should -Match '26\.1\.9\.1'
            Get-FolderSnapshot -Root $root | Should -Be $before
        }

        It 'stops with exit 4 naming a tracked .app and changes nothing' {
            $root = Join-Path $TestDrive 'tracked-app'
            New-ConsumerFixture -Root $root -Pin '26.1.9.1' -Baseline -TrackedApp
            $before = Get-FolderSnapshot -Root $root

            $result = Invoke-DownloadBaseline -Root $root -Feed $script:Feeds.AppSource -MsFeed $script:Feeds.Ms

            $result.ExitCode | Should -Be 4
            $result.Output | Should -Match ([regex]::Escape($script:StaleName))
            Get-FolderSnapshot -Root $root | Should -Be $before
        }
    }
}
