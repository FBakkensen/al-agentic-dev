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
        [Environment]::SetEnvironmentVariable($name, $script:SavedOverrides[$name])
    }
}

Describe 'Get-SymbolFeeds' {
    BeforeEach {
        foreach ($name in $script:OverrideNames) { [Environment]::SetEnvironmentVariable($name, $null) }
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

        $metadata = Get-PackageFeedMetadata -PackageId $script:LibPackageId -Feeds @($absent, $emptyRoot, $script:Root) -WarningVariable warnings -WarningAction SilentlyContinue

        $metadata.Feed | Should -Be $script:Root
        $metadata.Versions | Should -Be @('26.1.9')
        @($warnings) | Should -HaveCount 1
        "$($warnings[0])" | Should -BeLike "*$absent*"
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
