#Requires -Version 7.2

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force -DisableNameChecking

    $script:OriginalHome = $env:HOME
    $script:OriginalUserProfile = $env:USERPROFILE
    $script:FakeHome = Join-Path $TestDrive 'home'
    New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
    $env:HOME = $script:FakeHome
    $env:USERPROFILE = $script:FakeHome

    $script:CheckoutA = Join-Path $TestDrive 'checkout-a'
    $script:CheckoutB = Join-Path $TestDrive 'checkout-b'
    foreach ($checkoutPath in @($script:CheckoutA, $script:CheckoutB)) {
        New-Item -ItemType Directory -Path $checkoutPath -Force | Out-Null
        git -C $checkoutPath init -q
        git -C $checkoutPath config user.email 'test@example.invalid'
        git -C $checkoutPath config user.name 'test'
        git -C $checkoutPath config commit.gpgsign false
        git -C $checkoutPath remote add origin 'https://example.invalid/contoso/shared-app.git'
        git -C $checkoutPath checkout -q -b 'shared-branch'
        git -C $checkoutPath commit -q --allow-empty -m 'init'
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to initialize test checkout '$checkoutPath'."
        }
    }

    $script:AppJson = [pscustomobject]@{
        publisher = 'Contoso'
        name      = 'Shared App'
        id        = '11111111-2222-3333-4444-555555555555'
    }

    function script:Initialize-AppCache {
        param(
            [Parameter(Mandatory)][string]$CheckoutPath,
            [Parameter(Mandatory)][string]$Marker
        )

        Push-Location $CheckoutPath
        try {
            $cacheRoot = Get-SymbolCacheRoot
            $publisherDir = Join-Path $cacheRoot (ConvertTo-SafePathSegment -Value $script:AppJson.publisher)
            $appDir = Join-Path $publisherDir (ConvertTo-SafePathSegment -Value $script:AppJson.name)
            $cacheDir = Join-Path $appDir (ConvertTo-SafePathSegment -Value $script:AppJson.id)
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

            [ordered]@{ marker = $Marker } |
                ConvertTo-Json |
                Set-Content -LiteralPath (Join-Path $cacheDir 'symbols.lock.json') -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $cacheDir 'Contoso_Shared_App_1.0.0.0.app') -Value $Marker

            [pscustomobject]@{
                CacheRoot = $cacheRoot
                CacheInfo = Get-SymbolCacheInfo -AppJson $script:AppJson
            }
        } finally {
            Pop-Location
        }
    }
}

AfterAll {
    foreach ($checkoutPath in @($script:CheckoutA, $script:CheckoutB)) {
        if (Test-Path -LiteralPath $checkoutPath) {
            Get-ChildItem -LiteralPath $checkoutPath -Recurse -Force -File |
                Where-Object { $_.IsReadOnly } |
                ForEach-Object { $_.IsReadOnly = $false }
            Remove-Item -LiteralPath $checkoutPath -Recurse -Force -Confirm:$false
        }
    }
    $env:HOME = $script:OriginalHome
    $env:USERPROFILE = $script:OriginalUserProfile
}

Describe 'Workspace symbol-cache isolation' {
    It 'returns a stable checkout-scoped cache root' {
        Push-Location $script:CheckoutA
        try {
            $first = Get-SymbolCacheRoot
            $second = Get-SymbolCacheRoot
        } finally {
            Pop-Location
        }

        $first | Should -Be $second
        Split-Path (Split-Path $first -Parent) -Leaf | Should -Be '.bc-symbol-cache'
        Split-Path $first -Leaf | Should -Match '^[0-9a-f]{12}$'
    }

    It 'separates identical app identities in two checkouts' {
        $checkoutA = Initialize-AppCache -CheckoutPath $script:CheckoutA -Marker 'checkout-a'
        $checkoutB = Initialize-AppCache -CheckoutPath $script:CheckoutB -Marker 'checkout-b'

        $checkoutA.CacheRoot | Should -Not -Be $checkoutB.CacheRoot
        $checkoutA.CacheInfo.CacheDir | Should -Not -Be $checkoutB.CacheInfo.CacheDir
        $checkoutA.CacheInfo.Manifest.marker | Should -Be 'checkout-a'
        $checkoutB.CacheInfo.Manifest.marker | Should -Be 'checkout-b'

        $appFileName = 'Contoso_Shared_App_1.0.0.0.app'
        Get-Content -LiteralPath (Join-Path $checkoutA.CacheInfo.CacheDir $appFileName) -Raw |
            Should -Be "checkout-a$([Environment]::NewLine)"
        Get-Content -LiteralPath (Join-Path $checkoutB.CacheInfo.CacheDir $appFileName) -Raw |
            Should -Be "checkout-b$([Environment]::NewLine)"
    }
}
