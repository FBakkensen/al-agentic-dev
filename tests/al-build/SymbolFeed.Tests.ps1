#Requires -Version 7.2

# Unit tests for symbol-feed.psm1: the feed list and its ALBT_* overrides, lookups against a
# local flat2 feed root, the .nupkg resolve, and the .app manifest reader. Nothing here reaches
# the network: every feed is a local directory or the public URL list read as data.

BeforeAll {
    $script:ScriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $script:ScriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ScriptsDir 'symbol-feed.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'SymbolFeedFixture.psm1') -Force

    $script:OverrideNames = @('ALBT_MSSYMBOLS_FEED', 'ALBT_APPSOURCESYMBOLS_FEED')
    $script:SavedOverrides = @{}
    foreach ($name in $script:OverrideNames) {
        $script:SavedOverrides[$name] = [Environment]::GetEnvironmentVariable($name)
    }

    $script:MsFeed = 'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSSymbols/nuget/v3/index.json'
    $script:AppSourceFeed = 'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json'

    $script:LibId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    $script:LibPackageId = "Contoso.Lib.symbols.$($script:LibId)"
    $script:LibApp = @{ Id = $script:LibId; Name = 'Lib'; Publisher = 'Contoso'; Version = '26.1.9.0' }
}

AfterAll {
    foreach ($name in $script:OverrideNames) {
        if ($null -eq $script:SavedOverrides[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        } else {
            Set-Item -LiteralPath "Env:$name" -Value $script:SavedOverrides[$name]
        }
    }
}

Describe 'Get-SymbolFeeds' {
    BeforeEach {
        foreach ($name in $script:OverrideNames) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
    }

    It 'returns the two public feeds, MSSymbols first, with no override set' {
        @(Get-SymbolFeeds) | Should -Be @($script:MsFeed, $script:AppSourceFeed)
    }

    It 'replaces only the feed whose override is set' {
        $env:ALBT_MSSYMBOLS_FEED = Join-Path $TestDrive 'ms'
        @(Get-SymbolFeeds) | Should -Be @((Join-Path $TestDrive 'ms'), $script:AppSourceFeed)

        $env:ALBT_MSSYMBOLS_FEED = $null
        $env:ALBT_APPSOURCESYMBOLS_FEED = Join-Path $TestDrive 'appsource'
        @(Get-SymbolFeeds) | Should -Be @($script:MsFeed, (Join-Path $TestDrive 'appsource'))
    }

    It 'returns one feed with -Feed' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = Join-Path $TestDrive 'appsource'
        Get-SymbolFeeds -Feed AppSourceSymbols | Should -Be (Join-Path $TestDrive 'appsource')
    }
}

Describe 'symbol-feed module surface' {
    It 'exports no name that common.psm1 or build-operations.psm1 also exports' {
        $feedNames = (Get-Module symbol-feed).ExportedCommands.Keys
        Import-Module (Join-Path $script:ScriptsDir 'build-operations.psm1') -Force -DisableNameChecking
        $others = @('common', 'build-operations') | ForEach-Object { (Get-Module $_).ExportedCommands.Keys }
        @($feedNames | Where-Object { $_ -in $others }) | Should -HaveCount 0
    }

    It 'holds the public feed URLs and no other al-build file does' {
        $holders = Get-ChildItem -LiteralPath (Join-Path $script:ScriptsDir '..') -Recurse -File |
            Select-String -Pattern 'DynamicsBCPublicFeeds' -List |
            ForEach-Object { $_.Path | Split-Path -Leaf }
        @($holders) | Should -Be @('symbol-feed.psm1')
    }
}

Describe 'Find-PackageInFeed against a local feed root' {
    BeforeAll {
        $script:Root = Join-Path $TestDrive 'feed'
        New-FixtureFeedPackage -FeedRoot $script:Root -PackageId $script:LibPackageId -NuGetVersion '26.1.9' -App $script:LibApp | Out-Null
    }

    It 'lists a package at its flat2 index, matching the id case-insensitively' {
        $result = Find-PackageInFeed -PackageId $script:LibPackageId -Feed $script:Root

        $result.Status | Should -Be 'Listed'
        $result.Versions | Should -Be @('26.1.9')
        $result.Feed | Should -Be $script:Root
    }

    It 'reports a package missing from an existing root as not listed' {
        (Find-PackageInFeed -PackageId 'Contoso.Other.symbols.cccccccc-cccc-cccc-cccc-cccccccccccc' -Feed $script:Root).Status |
            Should -Be 'NotListed'
    }

    It 'reports a root directory that does not exist as unreadable, naming it' {
        $absent = Join-Path $TestDrive 'no-such-feed'

        $result = Find-PackageInFeed -PackageId $script:LibPackageId -Feed $absent

        $result.Status | Should -Be 'Unreadable'
        $result.Message | Should -BeLike "*$absent*"
    }

    It 'moves on past a root that lacks the package and warns about one that is unreadable' {
        $absent = Join-Path $TestDrive 'no-such-feed'
        $emptyRoot = Join-Path $TestDrive 'empty-feed'
        New-Item -ItemType Directory -Path $emptyRoot | Out-Null

        $output = @(Get-PackageFeedMetadata -PackageId $script:LibPackageId -Feeds @($absent, $emptyRoot, $script:Root) 3>&1)

        $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $metadata = @($output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })[0]
        $metadata.Feed | Should -Be $script:Root
        $metadata.Versions | Should -Be @('26.1.9')
        $warnings | Should -HaveCount 1
        $warnings[0].Message | Should -BeLike "*$absent*"
    }

    It 'returns nothing when no feed lists the package' {
        Get-PackageFeedMetadata -PackageId 'Contoso.Other.symbols.cccccccc-cccc-cccc-cccc-cccccccccccc' -Feeds @($script:Root) |
            Should -BeNullOrEmpty
    }
}

Describe 'Resolve-SymbolPackage against a local feed root' {
    It 'extracts the .app under {cleanName}.{version}.app and reads the .nuspec dependencies' {
        $root = Join-Path $TestDrive 'resolve-feed'
        New-FixtureFeedPackage -FeedRoot $root -PackageId $script:LibPackageId -NuGetVersion '26.1.9' -App $script:LibApp `
            -Dependencies @(@{ Id = 'Microsoft.Application.symbols'; Version = '26.0.0.0' }) | Out-Null
        $cacheDir = Join-Path $TestDrive 'resolve-cache'
        New-Item -ItemType Directory -Path $cacheDir | Out-Null

        $result = Resolve-SymbolPackage -PackageId $script:LibPackageId -MinimumVersion '26.0.0.0' -Feeds @($root) -CacheDir $cacheDir

        $result.Version | Should -Be '26.1.9'
        @($result.Dependencies) | Should -HaveCount 1
        $result.Dependencies[0].Id | Should -Be 'Microsoft.Application.symbols'
        $result.Dependencies[0].MinimumVersion | Should -Be '26.0.0.0'
        $appPath = Join-Path $cacheDir 'Contoso.Lib.26.1.9.app'
        $appPath | Should -Exist
        (Read-AppManifest -Path $appPath).Id | Should -Be $script:LibId
    }

    It 'throws, naming the package, when no feed lists it' {
        $root = Join-Path $TestDrive 'empty-resolve-feed'
        New-Item -ItemType Directory -Path $root | Out-Null

        { Resolve-SymbolPackage -PackageId $script:LibPackageId -MinimumVersion $null -Feeds @($root) -CacheDir $TestDrive } |
            Should -Throw "*$($script:LibPackageId)*"
    }
}

Describe 'Read-AppManifest' {
    It 'returns the id, name, publisher, and 4-part version exactly as the manifest carries them' {
        $appPath = Join-Path $TestDrive 'reader' 'Lib.app'
        New-FixtureAppFile -Path $appPath -Id $script:LibId -Name 'Lib & Co' -Publisher 'Contoso' -Version '26.1.9.0' | Out-Null

        $manifest = Read-AppManifest -Path $appPath

        $manifest.Id | Should -Be $script:LibId
        $manifest.Name | Should -Be 'Lib & Co'
        $manifest.Publisher | Should -Be 'Contoso'
        $manifest.Version | Should -Be '26.1.9.0'
    }

    It 'finds the manifest when it follows more than 1 MiB of other entries' {
        $appPath = Join-Path $TestDrive 'reader' 'Padded.app'
        New-FixtureAppFile -Path $appPath -Id $script:LibId -Name 'Padded' -Publisher 'Contoso' -Version '26.1.9.0' -LeadingPadBytes (2MB) | Out-Null

        $manifest = Read-AppManifest -Path $appPath

        $manifest.Name | Should -Be 'Padded'
        $manifest.Version | Should -Be '26.1.9.0'
    }

    It 'keeps the 4-part version when the package carries the NuGet-trimmed one' {
        $root = Join-Path $TestDrive 'trim-feed'
        $nupkg = New-FixtureFeedPackage -FeedRoot $root -PackageId $script:LibPackageId -NuGetVersion '26.1.9' -App $script:LibApp
        $archive = [System.IO.Compression.ZipFile]::OpenRead($nupkg)
        try {
            $entry = $archive.Entries | Where-Object { $_.FullName -like '*.app' } | Select-Object -First 1
            $extracted = Join-Path $TestDrive 'trim-extracted.app'
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $extracted, $true)
        } finally {
            $archive.Dispose()
        }

        (Read-AppManifest -Path $extracted).Version | Should -Be '26.1.9.0'
    }

    It 'throws, naming the file, on a file with no NAVX manifest' {
        $placeholder = Join-Path $TestDrive 'placeholder.app'
        Set-Content -LiteralPath $placeholder -Value 'not an app'

        { Read-AppManifest -Path $placeholder } | Should -Throw "*$placeholder*"
    }

    It 'throws, naming the file, on a NAVX file whose zip holds no manifest' {
        $appPath = Join-Path $TestDrive 'no-manifest.app'
        New-FixtureAppFile -Path $appPath -Id $script:LibId -Name 'Lib' -Publisher 'Contoso' -Version '1.0.0.0' | Out-Null
        # Corrupt the manifest entry's name inside the local header: NavxManifest.xml -> NavxManifesX.xml.
        $bytes = [System.IO.File]::ReadAllBytes($appPath)
        $text = [System.Text.Encoding]::Latin1.GetString($bytes).Replace('NavxManifest.xml', 'NavxManifesX.xml')
        [System.IO.File]::WriteAllBytes($appPath, [System.Text.Encoding]::Latin1.GetBytes($text))

        { Read-AppManifest -Path $appPath } | Should -Throw "*$appPath*"
    }

    It 'throws, naming the file, when it does not exist' {
        $absent = Join-Path $TestDrive 'absent.app'

        { Read-AppManifest -Path $absent } | Should -Throw "*$absent*"
    }
}

Describe 'Test-ReleasePin' {
    BeforeAll {
        $script:PinAppId = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
        $script:PinPackageId = "Contoso.My Lib.symbols.$($script:PinAppId)" -replace ' ', ''
        $script:PinAppJson = [pscustomobject]@{ id = $script:PinAppId; name = 'My Lib'; publisher = 'Contoso' }

        function New-ReleaseFeed {
            param([string]$Name, [hashtable]$Releases)
            $root = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            foreach ($nuGetVersion in $Releases.Keys) {
                $app = @{ Id = $script:PinAppId; Name = 'My Lib'; Publisher = 'Contoso'; Version = $Releases[$nuGetVersion] }
                New-FixtureFeedPackage -FeedRoot $root -PackageId $script:PinPackageId -NuGetVersion $nuGetVersion -App $app | Out-Null
            }
            return $root
        }
    }

    BeforeEach {
        Remove-Item -LiteralPath 'Env:ALBT_APPSOURCESYMBOLS_FEED' -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item -LiteralPath 'Env:ALBT_APPSOURCESYMBOLS_FEED' -ErrorAction SilentlyContinue
    }

    It 'passes with 0 when the pin equals the manifest version of the latest Release' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = New-ReleaseFeed 'pin-ok' @{ '26.1.4' = '26.1.4.0'; '26.1.9' = '26.1.9.1' }

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.1'

        $result.ExitCode | Should -Be 0
        $result.LatestRelease | Should -Be '26.1.9.1'
    }

    It 'orders versions numerically, so 26.1.10 is later than 26.1.9' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = New-ReleaseFeed 'pin-numeric' @{ '26.1.9' = '26.1.9.0'; '26.1.10' = '26.1.10.0' }

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.0'

        $result.ExitCode | Should -Be 4
        $result.LatestRelease | Should -Be '26.1.10.0'
    }

    It 'stops with 4 and names the pin and the latest Release when the pin is stale' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = New-ReleaseFeed 'pin-stale' @{ '26.1.9' = '26.1.9.1' }

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.0'

        $result.ExitCode | Should -Be 4
        $result.Message | Should -Be 'AppSourceCop.json pins 26.1.9.0, but the latest Release on AppSourceSymbols is 26.1.9.1. Update version in AppSourceCop.json.'
    }

    It 'does not accept the NuGet-trimmed form of a 4-part Release as the pin' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = New-ReleaseFeed 'pin-trimmed' @{ '26.1.9' = '26.1.9.0' }

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9'

        $result.ExitCode | Should -Be 4
        $result.LatestRelease | Should -Be '26.1.9.0'
    }

    It 'skips a prerelease version when it picks the latest Release' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = New-ReleaseFeed 'pin-prerelease' @{ '26.1.9' = '26.1.9.0'; '26.2.0-beta' = '26.2.0.0' }

        (Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.0').ExitCode | Should -Be 0
    }

    It 'stops with 4 when the feed lists no Release of the app' {
        $root = Join-Path $TestDrive 'pin-empty'
        New-Item -ItemType Directory -Path $root | Out-Null
        $env:ALBT_APPSOURCESYMBOLS_FEED = $root

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.0'

        $result.ExitCode | Should -Be 4
        $result.LatestRelease | Should -BeNullOrEmpty
        $result.Message | Should -Be "AppSourceSymbols lists no Release of $($script:PinPackageId); AppSourceCop.json pins 26.1.9.0."
    }

    It 'stops with 1, naming the feed root, when the feed cannot be read' {
        $absent = Join-Path $TestDrive 'pin-no-feed'
        $env:ALBT_APPSOURCESYMBOLS_FEED = $absent

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.0'

        $result.ExitCode | Should -Be 1
        $result.Message | Should -BeLike "*$absent*"
    }

    It 'stops with 1 when the latest package holds no readable .app' {
        $root = Join-Path $TestDrive 'pin-bad-app'
        $packageDir = Join-Path $root 'flat2' $script:PinPackageId.ToLowerInvariant()
        New-Item -ItemType Directory -Path (Join-Path $packageDir '26.1.9') -Force | Out-Null
        [ordered]@{ versions = @('26.1.9') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageDir 'index.json')
        $nupkg = Join-Path $packageDir '26.1.9' "$($script:PinPackageId.ToLowerInvariant()).26.1.9.nupkg"
        $archive = [System.IO.Compression.ZipFile]::Open($nupkg, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('readme.txt').Open())
            try { $writer.Write('no app here') } finally { $writer.Dispose() }
        } finally { $archive.Dispose() }
        $env:ALBT_APPSOURCESYMBOLS_FEED = $root

        $result = Test-ReleasePin -AppJson $script:PinAppJson -Pin '26.1.9.0'

        $result.ExitCode | Should -Be 1
        $result.Message | Should -BeLike "*$($script:PinPackageId)*"
    }

    It 'builds the package id from publisher, the name without spaces, and the app id' {
        $env:ALBT_APPSOURCESYMBOLS_FEED = New-ReleaseFeed 'pin-id' @{ '1.0.0' = '1.0.0.0' }

        # The feed holds Contoso.MyLib.symbols.<id>; a name with another spelling finds nothing.
        $other = [pscustomobject]@{ id = $script:PinAppId; name = 'My Other Lib'; publisher = 'Contoso' }
        (Test-ReleasePin -AppJson $other -Pin '1.0.0.0').ExitCode | Should -Be 4
        (Test-ReleasePin -AppJson $script:PinAppJson -Pin '1.0.0.0').ExitCode | Should -Be 0
    }

    It 'stops with 4 when app.json cannot be read' {
        $result = Test-ReleasePin -AppJson $null -Pin '1.0.0.0'

        $result.ExitCode | Should -Be 4
        $result.Message | Should -BeLike '*app.json*'
    }
}
