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

# download-baseline.ps1 is the Release pin check. Each case runs it as a fresh pwsh process rooted
# at a fixture Consumer repository under TestDrive, with ALBT_APPSOURCESYMBOLS_FEED pointed at a
# local flat2 feed, so Get-BuildConfig reads the fixture's al-build.json and nothing reaches the
# network.
Describe 'download-baseline.ps1 Release pin check' -Tag 'Process' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force

        $script:DownloadBaselineScript = Join-Path $base 'download-baseline.ps1'
        $script:Pwsh = Join-Path $PSHOME 'pwsh.exe'
        $script:AppId = '3ac22135-0000-4000-8000-000000000001'
        $script:PackageId = "NAVEKSA.NAVEKSAShopFloor365MES.symbols.$($script:AppId)"
        $script:AppIdentity = @{ Id = $script:AppId; Name = 'NAVEKSA ShopFloor365 MES'; Publisher = 'NAVEKSA' }

        function New-PinFixture {
            param(
                [Parameter(Mandatory)][string]$Root,
                [string]$Pin,
                [switch]$NoAppSourceCop,
                [switch]$BreakingChangeEnabled
            )
            $appDir = Join-Path $Root 'app'
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
                $asc = [ordered]@{ mandatoryAffixes = @('NALICF'); supportedCountries = @('dk') }
                if ($Pin) { $asc['version'] = $Pin }
                $asc | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'AppSourceCop.json') -Encoding UTF8
            }
        }

        function New-PinFeed {
            param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][hashtable]$Releases)
            New-FixtureReleaseFeed -FeedRoot $Root -PackageId $script:PackageId -App $script:AppIdentity -Releases $Releases | Out-Null
        }

        function Invoke-DownloadBaseline {
            param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Feed)
            # Paths travel as environment variables, so no quote in one can break the command. The
            # child's own ALBT_* variables are cleared first: they outrank the fixture's al-build.json.
            $env:PINTEST_ROOT = $Root
            $env:PINTEST_FEED = $Feed
            $env:PINTEST_SCRIPT = $script:DownloadBaselineScript
            try {
                $command = 'Get-ChildItem Env:ALBT_* | Remove-Item; $env:ALBT_APPSOURCESYMBOLS_FEED = $env:PINTEST_FEED; ' +
                    'Set-Location -LiteralPath $env:PINTEST_ROOT; & $env:PINTEST_SCRIPT; exit $LASTEXITCODE'
                $output = & $script:Pwsh -NoProfile -Command $command 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                Remove-Item Env:PINTEST_ROOT, Env:PINTEST_FEED, Env:PINTEST_SCRIPT -ErrorAction SilentlyContinue
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
    }

    It 'passes with exit 0 when the pin equals the latest Release' {
        $root = Join-Path $TestDrive 'equal'
        $feed = Join-Path $TestDrive 'equal-feed'
        New-PinFixture -Root $root -Pin '26.1.9.1'
        New-PinFeed -Root $feed -Releases @{ '26.1.4' = '26.1.4.0'; '26.1.9.1' = '26.1.9.1' }
        $before = Get-AscBase64 -Root $root

        $result = Invoke-DownloadBaseline -Root $root -Feed $feed

        $result.ExitCode | Should -Be 0
        Assert-Untouched -Root $root -Before $before
    }

    It 'stops with exit 4 and names the latest Release when the pin is stale' {
        $root = Join-Path $TestDrive 'stale'
        $feed = Join-Path $TestDrive 'stale-feed'
        New-PinFixture -Root $root -Pin '26.1.9.0'
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
        New-PinFixture -Root $current -Pin '26.1.9.0'
        $currentBefore = Get-AscBase64 -Root $current
        (Invoke-DownloadBaseline -Root $current -Feed $feed).ExitCode | Should -Be 0
        Assert-Untouched -Root $current -Before $currentBefore

        $older = Join-Path $TestDrive 'trimmed-older'
        New-PinFixture -Root $older -Pin '26.1.4.0'
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
        New-PinFixture -Root $disabled -Pin '26.1.4.0'
        (Get-Content -LiteralPath (Join-Path $disabled 'al-build.json') -Raw | ConvertFrom-Json).breakingChange.enabled | Should -BeFalse
        (Join-Path $disabled '.vscode' 'settings.json') | Should -Not -Exist
        (Join-Path $disabled 'app' '.vscode' 'settings.json') | Should -Not -Exist
        $before = Get-AscBase64 -Root $disabled
        (Invoke-DownloadBaseline -Root $disabled -Feed $feed).ExitCode | Should -Be 4
        Assert-Untouched -Root $disabled -Before $before

        $enabled = Join-Path $TestDrive 'enabled'
        New-PinFixture -Root $enabled -Pin '26.1.4.0' -BreakingChangeEnabled
        (Invoke-DownloadBaseline -Root $enabled -Feed $feed).ExitCode | Should -Be 4
    }

    It 'exits 0 and reads no feed when AppSourceCop.json is absent' {
        $root = Join-Path $TestDrive 'no-asc'
        New-PinFixture -Root $root -NoAppSourceCop
        $unreachable = Join-Path $TestDrive 'no-asc-missing-feed'

        $result = Invoke-DownloadBaseline -Root $root -Feed $unreachable

        $result.ExitCode | Should -Be 0
        Assert-Untouched -Root $root -Before $null
    }

    It 'exits 0 and reads no feed when AppSourceCop.json carries no version' {
        $root = Join-Path $TestDrive 'no-version'
        New-PinFixture -Root $root
        $unreachable = Join-Path $TestDrive 'no-version-missing-feed'
        $before = Get-AscBase64 -Root $root

        $result = Invoke-DownloadBaseline -Root $root -Feed $unreachable

        $result.ExitCode | Should -Be 0
        Assert-Untouched -Root $root -Before $before
    }

    It 'stops with exit 4, naming the file, when AppSourceCop.json is not valid JSON' {
        $root = Join-Path $TestDrive 'broken-asc'
        New-PinFixture -Root $root -NoAppSourceCop
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
        New-PinFixture -Root $root -Pin '26.1.9.0'
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
        New-PinFixture -Root $root -Pin '26.1.9.0'
        $before = Get-AscBase64 -Root $root

        $result = Invoke-DownloadBaseline -Root $root -Feed $missingFeed

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match ([regex]::Escape($missingFeed))
        Assert-Untouched -Root $root -Before $before
    }
}

# download-baseline.ps1 fills the compile baseline folder once the pin is current. Each case runs it
# as a fresh pwsh process in a fixture Consumer repository under TestDrive, a git repository with
# every fixture file committed, and both symbol feeds pointed at local flat2 directories outside it.
Describe 'download-baseline.ps1 baseline fill' -Tag 'Process' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force
        Import-Module (Resolve-Path (Join-Path $base 'symbol-feed.psm1')) -Force -DisableNameChecking

        $script:DownloadBaselineScript = Join-Path $base 'download-baseline.ps1'
        $script:Pwsh = Join-Path $PSHOME 'pwsh.exe'
        $script:FolderName = '.appSourceCopPackages'
        $script:StaleName = 'Stale.Release.1.0.0.0.app'
        $script:GhostPackageId = 'Contoso.Ghost.symbols.aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'

        $script:Release = @{ Id = '3ac22135-0000-4000-8000-000000000001'; Name = 'NAVEKSA ShopFloor365 MES'; Publisher = 'NAVEKSA' }
        $script:Library = @{ Id = '3ac22135-0000-4000-8000-000000000002'; Name = 'Contoso Lib'; Publisher = 'Contoso' }
        $script:MsApplication = @{ Id = '3ac22135-0000-4000-8000-000000000003'; Name = 'Application'; Publisher = 'Microsoft' }
        $script:MsSystem = @{ Id = '3ac22135-0000-4000-8000-000000000004'; Name = 'System'; Publisher = 'Microsoft' }
        $script:ReleasePackageId = "NAVEKSA.NAVEKSAShopFloor365MES.symbols.$($script:Release.Id)"
        $script:LibraryPackageId = "Contoso.ContosoLib.symbols.$($script:Library.Id)"
        $script:ApplicationPackageId = 'Microsoft.Application.symbols'
        $script:SystemPackageId = 'Microsoft.System.symbols'

        # Release -> Contoso Lib (AppSourceSymbols) -> Application (MSSymbols), plus System (MSSymbols)
        # directly. Each package sits in exactly one feed, so its .app in the folder names the feed
        # that served it. With -MissingDependency the Release's direct dependency is on neither feed.
        function New-FillFeeds {
            param([Parameter(Mandatory)][string]$Root, [switch]$MissingDependency)
            $ms = Join-Path $Root 'mssymbols'
            $appSource = Join-Path $Root 'appsourcesymbols'
            New-FixtureFeedPackage -FeedRoot $ms -PackageId $script:ApplicationPackageId -NuGetVersion '26.0.0' `
                -App @{ Id = $script:MsApplication.Id; Name = 'Application'; Publisher = 'Microsoft'; Version = '26.0.0.0' } | Out-Null
            New-FixtureFeedPackage -FeedRoot $ms -PackageId $script:SystemPackageId -NuGetVersion '26.0.0' `
                -App @{ Id = $script:MsSystem.Id; Name = 'System'; Publisher = 'Microsoft'; Version = '26.0.0.0' } | Out-Null
            New-FixtureFeedPackage -FeedRoot $appSource -PackageId $script:LibraryPackageId -NuGetVersion '2.0.0' `
                -App @{ Id = $script:Library.Id; Name = 'Contoso Lib'; Publisher = 'Contoso'; Version = '2.0.0.0' } `
                -Dependencies @(@{ Id = $script:ApplicationPackageId; Version = '26.0.0' }) | Out-Null
            $directId = if ($MissingDependency) { $script:GhostPackageId } else { $script:SystemPackageId }
            $releaseDependencies = @(
                @{ Id = $script:LibraryPackageId; Version = '1.0.0' }
                @{ Id = $directId; Version = '26.0.0' }
            )
            foreach ($release in @{ '26.1.4' = '26.1.4.0'; '26.1.9.1' = '26.1.9.1' }.GetEnumerator()) {
                New-FixtureFeedPackage -FeedRoot $appSource -PackageId $script:ReleasePackageId -NuGetVersion $release.Key `
                    -App @{ Id = $script:Release.Id; Name = $script:Release.Name; Publisher = $script:Release.Publisher; Version = $release.Value } `
                    -Dependencies $releaseDependencies | Out-Null
            }
            [pscustomobject]@{ Ms = $ms; AppSource = $appSource }
        }

        # A committed Consumer repository: AppSourceCop.json with its pin, the baseline folder with a
        # committed README.md and .gitignore (ignoring *.app) and one stale .app.
        function New-FillFixture {
            param(
                [Parameter(Mandatory)][string]$Root,
                [string]$Pin = '26.1.9.1',
                [switch]$NoVersion,
                [switch]$NoCachePath,
                [switch]$TrackedApp
            )
            $appDir = Join-Path $Root 'app'
            $folder = Join-Path $appDir $script:FolderName
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            [ordered]@{ id = $script:Release.Id; name = $script:Release.Name; publisher = $script:Release.Publisher; version = '1.0.0.0' } |
                ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'app.json') -Encoding UTF8
            [ordered]@{ appDir = 'app'; testApps = @(); breakingChange = [ordered]@{ enabled = $false } } |
                ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'al-build.json') -Encoding UTF8
            $cop = [ordered]@{ mandatoryAffixes = @('NALICF') }
            if (-not $NoVersion) { $cop['version'] = $Pin }
            if (-not $NoCachePath) { $cop['baselinePackageCachePath'] = "./$($script:FolderName)" }
            $cop | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $appDir 'AppSourceCop.json') -Encoding UTF8
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

        function Invoke-Fill {
            param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)]$Feeds)
            $env:FILLTEST_ROOT = $Root
            $env:FILLTEST_MS = $Feeds.Ms
            $env:FILLTEST_APPSOURCE = $Feeds.AppSource
            $env:FILLTEST_SCRIPT = $script:DownloadBaselineScript
            try {
                $command = 'Get-ChildItem Env:ALBT_* | Remove-Item; $env:ALBT_MSSYMBOLS_FEED = $env:FILLTEST_MS; ' +
                    '$env:ALBT_APPSOURCESYMBOLS_FEED = $env:FILLTEST_APPSOURCE; ' +
                    'Set-Location -LiteralPath $env:FILLTEST_ROOT; & $env:FILLTEST_SCRIPT; exit $LASTEXITCODE'
                $output = & $script:Pwsh -NoProfile -Command $command 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                Remove-Item Env:FILLTEST_ROOT, Env:FILLTEST_MS, Env:FILLTEST_APPSOURCE, Env:FILLTEST_SCRIPT -ErrorAction SilentlyContinue
            }
            [pscustomobject]@{ ExitCode = $exitCode; Output = (@($output | ForEach-Object { "$_" }) -join "`n") }
        }

        # Every file in the folder with its content hash, to compare before and after a run.
        function Get-FolderSnapshot {
            param([string]$Root)
            $folder = Join-Path $Root 'app' $script:FolderName
            @(Get-ChildItem -LiteralPath $folder -File -Force | Sort-Object Name |
                ForEach-Object { '{0}:{1}' -f $_.Name, (Get-FileHash -LiteralPath $_.FullName).Hash })
        }

        function Get-FolderApps {
            param([string]$Root)
            @(Get-ChildItem -LiteralPath (Join-Path $Root 'app' $script:FolderName) -Filter '*.app' -File)
        }

        $script:Feeds = New-FillFeeds -Root (Join-Path $TestDrive 'fill-feeds')
        $script:GhostFeeds = New-FillFeeds -Root (Join-Path $TestDrive 'fill-feeds-ghost') -MissingDependency
    }

    Context 'with a current pin' {
        BeforeAll {
            $script:FilledRoot = Join-Path $TestDrive 'filled'
            New-FillFixture -Root $script:FilledRoot
            $script:CopBefore = [System.IO.File]::ReadAllBytes((Join-Path $script:FilledRoot 'app' 'AppSourceCop.json'))
            $script:ReadmeBefore = (Get-FileHash -LiteralPath (Join-Path $script:FilledRoot 'app' $script:FolderName 'README.md')).Hash
            $script:FilledResult = Invoke-Fill -Root $script:FilledRoot -Feeds $script:Feeds
        }

        It 'writes the Release and its dependencies from both feeds, transitively' {
            $script:FilledResult.ExitCode | Should -Be 0 -Because $script:FilledResult.Output

            $apps = Get-FolderApps -Root $script:FilledRoot
            $manifests = @($apps | ForEach-Object { Read-AppManifest -Path $_.FullName })
            $apps.Count | Should -Be 4
            ($manifests.Id | Sort-Object) | Should -Be (@($script:Release.Id, $script:Library.Id, $script:MsApplication.Id, $script:MsSystem.Id) | Sort-Object)
            ($manifests | Where-Object Id -eq $script:Release.Id).Version | Should -Be '26.1.9.1'
        }

        It 'changes no committed file and removes only the stale .app' {
            git -C $script:FilledRoot status --porcelain | Should -BeNullOrEmpty
            [System.IO.File]::ReadAllBytes((Join-Path $script:FilledRoot 'app' 'AppSourceCop.json')) | Should -Be $script:CopBefore
            (Get-FileHash -LiteralPath (Join-Path $script:FilledRoot 'app' $script:FolderName 'README.md')).Hash | Should -Be $script:ReadmeBefore
            (Join-Path $script:FilledRoot 'app' $script:FolderName $script:StaleName) | Should -Not -Exist
            (Get-FolderApps -Root $script:FilledRoot).Count | Should -Be 4
        }
    }

    It 'stops with exit 4 naming baselinePackageCachePath and writes nothing when the key is missing' {
        $root = Join-Path $TestDrive 'no-key'
        New-FillFixture -Root $root -NoCachePath
        $before = Get-FolderSnapshot -Root $root

        $result = Invoke-Fill -Root $root -Feeds $script:Feeds

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match 'baselinePackageCachePath'
        Get-FolderSnapshot -Root $root | Should -Be $before
        @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.app').Count | Should -Be 1
    }

    It 'leaves every file in the folder as it was when the pin is stale' {
        $root = Join-Path $TestDrive 'stale-pin'
        New-FillFixture -Root $root -Pin '26.1.4.0'
        $before = Get-FolderSnapshot -Root $root

        $result = Invoke-Fill -Root $root -Feeds $script:Feeds

        $result.ExitCode | Should -Be 4
        Get-FolderSnapshot -Root $root | Should -Be $before
    }

    It 'leaves every file in the folder as it was when AppSourceCop.json has no version' {
        $root = Join-Path $TestDrive 'no-pin'
        New-FillFixture -Root $root -NoVersion
        $before = Get-FolderSnapshot -Root $root

        $result = Invoke-Fill -Root $root -Feeds $script:Feeds

        $result.ExitCode | Should -Be 0
        Get-FolderSnapshot -Root $root | Should -Be $before
    }

    It 'stops with exit 1 naming the package, and leaves the folder as it was, when a dependency is on neither feed' {
        $root = Join-Path $TestDrive 'ghost'
        New-FillFixture -Root $root
        $before = Get-FolderSnapshot -Root $root

        $result = Invoke-Fill -Root $root -Feeds $script:GhostFeeds

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match ([regex]::Escape($script:GhostPackageId))
        Get-FolderSnapshot -Root $root | Should -Be $before
    }

    It 'stops with exit 1 naming the package, and leaves the folder as it was, when a feed fails mid-fill' {
        $root = Join-Path $TestDrive 'mid-fill'
        New-FillFixture -Root $root
        $before = Get-FolderSnapshot -Root $root
        $feeds = New-FillFeeds -Root (Join-Path $TestDrive 'mid-fill-feeds')
        Remove-Item -LiteralPath (Join-Path $feeds.Ms 'flat2' $script:ApplicationPackageId.ToLowerInvariant() '26.0.0') -Recurse -Force

        $result = Invoke-Fill -Root $root -Feeds $feeds

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match ([regex]::Escape($script:ApplicationPackageId))
        Get-FolderSnapshot -Root $root | Should -Be $before
    }

    It 'stops with exit 4 naming a tracked .app and changes nothing' {
        $root = Join-Path $TestDrive 'tracked-app'
        New-FillFixture -Root $root -TrackedApp
        $before = Get-FolderSnapshot -Root $root

        $result = Invoke-Fill -Root $root -Feeds $script:Feeds

        $result.ExitCode | Should -Be 4
        $result.Output | Should -Match ([regex]::Escape($script:StaleName))
        Get-FolderSnapshot -Root $root | Should -Be $before
    }
}
