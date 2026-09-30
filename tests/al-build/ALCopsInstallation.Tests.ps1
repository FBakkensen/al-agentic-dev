#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    $script:ALCopsDllNames = @(
        'ALCops.ApplicationCop.dll'
        'ALCops.Common.dll'
        'ALCops.DocumentationCop.dll'
        'ALCops.FormattingCop.dll'
        'ALCops.LinterCop.dll'
        'ALCops.PlatformCop.dll'
        'ALCops.TestAutomationCop.dll'
    )
    $script:PrimaryAssembly = [System.Management.Automation.PowerShell].Assembly.Location
    $script:OtherAssembly = [string].Assembly.Location
    $primaryVersion = [System.Reflection.AssemblyName]::GetAssemblyName($script:PrimaryAssembly).Version
    $otherVersion = [System.Reflection.AssemblyName]::GetAssemblyName($script:OtherAssembly).Version
    if ($primaryVersion -eq $otherVersion) {
        throw 'The ALCops mixed-version fixture requires two assemblies with different versions.'
    }

    function New-ALCopsCompilerFixture {
        [CmdletBinding()]
        param(
            [switch]$MissingDll,
            [switch]$MixedVersions,
            [switch]$LegacyDll
        )

        $compilerDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString('N'))
        $analyzersDir = Join-Path $compilerDir 'Analyzers'
        New-Item -ItemType Directory -Path $analyzersDir -Force | Out-Null

        for ($index = 0; $index -lt $script:ALCopsDllNames.Count; $index++) {
            if ($MissingDll -and $index -eq ($script:ALCopsDllNames.Count - 1)) {
                continue
            }
            $sourceAssembly = if ($MixedVersions -and $index -eq ($script:ALCopsDllNames.Count - 1)) {
                $script:OtherAssembly
            } else {
                $script:PrimaryAssembly
            }
            Copy-Item -LiteralPath $sourceAssembly -Destination (Join-Path $analyzersDir $script:ALCopsDllNames[$index])
        }

        $legacyDllPath = Join-Path $analyzersDir 'BusinessCentral.LinterCop.dll'
        if ($LegacyDll) {
            Set-Content -LiteralPath $legacyDllPath -Value 'legacy'
        }

        return [pscustomobject]@{
            CompilerDir  = $compilerDir
            AnalyzersDir = $analyzersDir
            LegacyDll    = $legacyDllPath
        }
    }
}

Describe 'Install-ALCops' {
    It 'skips npx when all seven DLLs have one assembly version' {
        $fixture = New-ALCopsCompilerFixture

        InModuleScope build-operations -Parameters @{ CompilerDir = $fixture.CompilerDir } {
            param($CompilerDir)

            Mock Write-BuildMessage {}
            Mock Invoke-ALCopsDownload { throw 'download must not run for a valid installation' }

            Install-ALCops -CompilerDir $CompilerDir

            Should -Invoke Invoke-ALCopsDownload -Times 0 -Exactly
            Should -Invoke Write-BuildMessage -Times 1 -Exactly -ParameterFilter {
                $Type -eq 'Success' -and $Message -like 'ALCops analyzers already installed:*'
            }
        }
    }

    It 'skips while a compiler process holds an installed DLL open against writes' {
        $fixture = New-ALCopsCompilerFixture
        $lockedDll = Join-Path $fixture.AnalyzersDir 'ALCops.Common.dll'
        $lock = [System.IO.File]::Open(
            $lockedDll,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            InModuleScope build-operations -Parameters @{ CompilerDir = $fixture.CompilerDir } {
                param($CompilerDir)

                Mock Write-BuildMessage {}
                Mock Invoke-ALCopsDownload { throw 'download must not run while a valid DLL is locked' }

                Install-ALCops -CompilerDir $CompilerDir

                Should -Invoke Invoke-ALCopsDownload -Times 0 -Exactly
            }
        } finally {
            $lock.Dispose()
        }
    }

    It 'downloads when a DLL is missing and leaves one complete version' {
        $fixture = New-ALCopsCompilerFixture -MissingDll -LegacyDll

        InModuleScope build-operations -Parameters @{
            FixtureCompilerDir = $fixture.CompilerDir
            DllNames      = $script:ALCopsDllNames
            SourceAssembly = $script:PrimaryAssembly
        } {
            param($FixtureCompilerDir, $DllNames, $SourceAssembly)

            Mock Write-BuildMessage {}
            Mock Invoke-ALCopsDownload {
                foreach ($dllName in $DllNames) {
                    Copy-Item -LiteralPath $SourceAssembly -Destination (Join-Path $AnalyzersDir $dllName) -Force
                }
            }

            Install-ALCops -CompilerDir $FixtureCompilerDir

            Should -Invoke Invoke-ALCopsDownload -Times 1 -Exactly -ParameterFilter {
                $CompilerDir -eq $FixtureCompilerDir -and
                $AnalyzersDir -eq (Join-Path $FixtureCompilerDir 'Analyzers')
            }
        }

        Test-Path -LiteralPath $fixture.LegacyDll | Should -BeFalse
        $installedDlls = @(Get-ChildItem -LiteralPath $fixture.AnalyzersDir -Filter 'ALCops.*.dll' -File)
        $installedDlls | Should -HaveCount $script:ALCopsDllNames.Count
        @(
            $installedDlls |
                ForEach-Object { [System.Reflection.AssemblyName]::GetAssemblyName($_.FullName).Version.ToString() } |
                Sort-Object -Unique
        ) | Should -HaveCount 1
    }

    It 'downloads when the installed DLL versions do not match' {
        $fixture = New-ALCopsCompilerFixture -MixedVersions

        InModuleScope build-operations -Parameters @{
            FixtureCompilerDir = $fixture.CompilerDir
            DllNames       = $script:ALCopsDllNames
            SourceAssembly = $script:PrimaryAssembly
        } {
            param($FixtureCompilerDir, $DllNames, $SourceAssembly)

            Mock Write-BuildMessage {}
            Mock Invoke-ALCopsDownload {
                foreach ($dllName in $DllNames) {
                    Copy-Item -LiteralPath $SourceAssembly -Destination (Join-Path $AnalyzersDir $dllName) -Force
                }
            }

            Install-ALCops -CompilerDir $FixtureCompilerDir

            Should -Invoke Invoke-ALCopsDownload -Times 1 -Exactly
        }
    }

    It 'propagates a download failure when no valid installation existed' {
        $fixture = New-ALCopsCompilerFixture -MissingDll

        InModuleScope build-operations -Parameters @{ CompilerDir = $fixture.CompilerDir } {
            param($CompilerDir)

            Mock Write-BuildMessage {}
            Mock Invoke-ALCopsDownload { throw 'ALCops download failed (npx exit 9): sharing violation' }

            { Install-ALCops -CompilerDir $CompilerDir } |
                Should -Throw -ExpectedMessage '*ALCops download failed (npx exit 9): sharing violation*'
        }
    }

    It 'removes the legacy LinterCop before reusing the installed ALCops suite' {
        $fixture = New-ALCopsCompilerFixture -LegacyDll

        InModuleScope build-operations -Parameters @{ CompilerDir = $fixture.CompilerDir } {
            param($CompilerDir)

            Mock Write-BuildMessage {}
            Mock Invoke-ALCopsDownload { throw 'download must not run for a valid installation' }

            Install-ALCops -CompilerDir $CompilerDir

            Should -Invoke Invoke-ALCopsDownload -Times 0 -Exactly
        }

        Test-Path -LiteralPath $fixture.LegacyDll | Should -BeFalse
    }
}
