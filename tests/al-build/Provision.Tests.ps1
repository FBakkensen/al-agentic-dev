#Requires -Version 7.2

BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts'
    $script:ScriptsDir = $scriptsRoot
    $script:ProvisionPath = Resolve-Path (Join-Path $scriptsRoot 'provision.ps1')

    Import-Module (Join-Path $scriptsRoot 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsRoot 'build-operations.psm1') -Force -DisableNameChecking

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:ProvisionPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "provision.ps1 has parse errors: $($parseErrors.Message -join '; ')"
    }
    $script:ProvisionAst = $ast

    $functionAst = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Install-LatestBcContainerHelper'
    }, $true))
    if ($functionAst.Count -ne 1) {
        throw 'Install-LatestBcContainerHelper was not found exactly once.'
    }

    . ([scriptblock]::Create($functionAst[0].Extent.Text))

    if (-not (Get-Command Write-BuildMessage -ErrorAction SilentlyContinue)) {
        function global:Write-BuildMessage {
            param([string]$Type, [string]$Message)
        }
        $script:AddedWriteBuildMessageStub = $true
    }
}

AfterAll {
    if ($script:AddedWriteBuildMessageStub) {
        Remove-Item function:global:Write-BuildMessage -ErrorAction SilentlyContinue
    }
}

Describe 'Install-LatestBcContainerHelper' {
    It 'runs the helper refresh before compiler provisioning' {
        $commands = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true))
        $refreshCalls = @($commands | Where-Object {
            $_.GetCommandName() -eq 'Install-LatestBcContainerHelper'
        })
        $compilerCalls = @($commands | Where-Object {
            $_.GetCommandName() -eq 'Install-ALCompiler'
        })

        $refreshCalls | Should -HaveCount 1
        $compilerCalls | Should -HaveCount 1
        $refreshCalls[0].Extent.StartOffset | Should -BeLessThan $compilerCalls[0].Extent.StartOffset
    }

    BeforeEach {
        Mock Write-BuildMessage {}
        Mock Find-Module {
            [pscustomobject]@{
                Name    = 'BcContainerHelper'
                Version = [version]'6.2.3'
            }
        }
        Mock Install-Module {}
    }

    It 'installs PSGallery latest on every invocation without removing older versions' {
        Install-LatestBcContainerHelper
        Install-LatestBcContainerHelper

        Should -Invoke Find-Module -Times 2 -Exactly -ParameterFilter {
            $Name -eq 'BcContainerHelper' -and
            $Repository -eq 'PSGallery' -and
            $ErrorAction -eq 'Stop'
        }
        Should -Invoke Install-Module -Times 2 -Exactly -ParameterFilter {
            $Name -eq 'BcContainerHelper' -and
            $Repository -eq 'PSGallery' -and
            $RequiredVersion -eq [version]'6.2.3' -and
            $Scope -eq 'CurrentUser' -and
            $Force -and
            $AllowClobber -and
            $ErrorAction -eq 'Stop'
        }
        $uninstallCommands = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Uninstall-Module'
        }, $true))
        $uninstallCommands | Should -HaveCount 0
    }

    It 'fails before install when PSGallery lookup fails' {
        Mock Find-Module { throw 'gallery unavailable' }

        { Install-LatestBcContainerHelper } |
            Should -Throw -ExpectedMessage '*BcContainerHelper refresh failed: gallery unavailable*'
        Should -Invoke Install-Module -Times 0 -Exactly
    }

    It 'fails when the newest version cannot be installed' {
        Mock Install-Module { throw 'package installation failed' }

        { Install-LatestBcContainerHelper } |
            Should -Throw -ExpectedMessage '*BcContainerHelper refresh failed: package installation failed*'
    }

    It 'fails when PSGallery returns no version' {
        Mock Find-Module { [pscustomobject]@{ Name = 'BcContainerHelper'; Version = $null } }

        { Install-LatestBcContainerHelper } |
            Should -Throw -ExpectedMessage '*PSGallery returned no BcContainerHelper version*'
        Should -Invoke Install-Module -Times 0 -Exactly
    }
}

Describe 'ConvertTo-ALRunnerVersion' {
    It 'parses the al-runner version banner' {
        ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0.0' | Should -Be ([version]'2.10.0.0')
    }

    It 'parses a three-part release banner' {
        ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0' | Should -Be ([version]'2.10.0')
    }

    It 'parses a local build banner with a prerelease suffix' {
        ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0-local.9017de3a' | Should -Be ([version]'2.10.0')
    }

    It 'parses a beta banner' {
        ConvertTo-ALRunnerVersion -VersionLine 'al-runner v3.0.0-beta.1' | Should -Be ([version]'3.0.0')
    }

    It 'parses a banner with build metadata' {
        ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0+build.5' | Should -Be ([version]'2.10.0')
    }

    It 'exposes the prerelease suffix with -Detailed' {
        $d = ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0-local.9017de3a' -Detailed
        $d.Version | Should -Be ([version]'2.10.0')
        $d.Prerelease | Should -Be 'local.9017de3a'
        $d.IsPrerelease | Should -BeTrue
    }

    It 'reports a release banner as not prerelease with -Detailed' {
        $d = ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0.0' -Detailed
        $d.Prerelease | Should -BeNullOrEmpty
        $d.IsPrerelease | Should -BeFalse
    }

    It 'throws on an unrecognizable banner' {
        { ConvertTo-ALRunnerVersion -VersionLine 'nonsense' } | Should -Throw '*nonsense*'
    }

    It 'throws instead of matching a version-shaped substring in an unrecognized banner' {
        { ConvertTo-ALRunnerVersion -VersionLine 'nonsense v2.10' } | Should -Throw '*nonsense v2.10*'
    }

    It 'throws on a dangling prerelease separator' {
        { ConvertTo-ALRunnerVersion -VersionLine 'al-runner v2.10.0-' } | Should -Throw '*al-runner v2.10.0-*'
    }
}

Describe 'provision.ps1 AL Runner provisioning' {
    It 'calls Install-ALRunner unconditionally' {
        $content = Get-Content (Join-Path $script:ScriptsDir 'provision.ps1') -Raw
        $content | Should -Match '(?m)^Install-ALRunner'
    }
}

Describe 'Install-ALRunner keeps al-runner at the newest release (#145)' {
    # Mocks target the build-operations module scope, so the real al-runner, dotnet and
    # NuGet on this machine are never reached. Mock state lives in $global: variables:
    # a $script: read inside a module-scoped mock resolves to the wrong scope (#139).
    BeforeAll {
        # Pester's Mock needs a real command to shadow; CI runners have no al-runner.
        $script:stubBin = Join-Path $TestDrive 'stub-bin'
        New-Item -ItemType Directory -Path $script:stubBin -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:stubBin 'al-runner.cmd') -Value "@echo off`r`necho al-runner v0.0.0"
        $script:savedPath = $env:PATH
        $env:PATH = "$($script:stubBin)$([IO.Path]::PathSeparator)$env:PATH"
    }
    AfterAll {
        $env:PATH = $script:savedPath
        Remove-Variable -Name AlrBanner, AlrLatest, AlrInstalled -Scope Global -ErrorAction SilentlyContinue
    }
    BeforeEach {
        $global:AlrInstalled = $true
        Mock -ModuleName 'build-operations' Write-BuildHeader {}
        Mock -ModuleName 'build-operations' Write-BuildMessage {}
        Mock -ModuleName 'build-operations' Get-ALRunnerLatestRelease { [version]$global:AlrLatest }
        Mock -ModuleName 'build-operations' al-runner { $global:AlrBanner }
        Mock -ModuleName 'build-operations' Get-Command { if ($global:AlrInstalled) { [pscustomobject]@{ Source = 'al-runner.exe' } } } -ParameterFilter { $Name -eq 'al-runner' }
        Mock -ModuleName 'build-operations' Get-Command { [pscustomobject]@{ Source = 'dotnet.exe' } } -ParameterFilter { $Name -eq 'dotnet' }
        Mock -ModuleName 'build-operations' dotnet {
            $global:LASTEXITCODE = 0
            if ($args -contains 'install' -or $args -contains 'update') {
                $global:AlrInstalled = $true
                $i = [array]::IndexOf($args, '--version')
                if ($i -ge 0) { $global:AlrBanner = "al-runner v$($args[$i + 1])" }
            }
        }
    }

    It 'with <Installed> installed and <Latest> released, updates: <Updates>' -ForEach @(
        @{ Installed = '2.11.0'; Latest = '2.12.0'; Updates = $true }
        @{ Installed = '2.12.1-local.0e50f688'; Latest = '2.12.0'; Updates = $false }
        @{ Installed = '2.12.1-local.0e50f688'; Latest = '2.13.0'; Updates = $true }
        @{ Installed = '2.13.0'; Latest = '2.13.0'; Updates = $false }
    ) {
        $global:AlrBanner = "al-runner v$Installed"
        $global:AlrLatest = $Latest

        { Install-ALRunner } | Should -Not -Throw

        $expected = if ($Updates) { 1 } else { 0 }
        Should -Invoke -ModuleName 'build-operations' dotnet -Times $expected -Exactly -ParameterFilter {
            $args -contains 'update' -and $args -contains '--version' -and $args -contains $Latest
        }
        Should -Invoke -ModuleName 'build-operations' dotnet -Times $expected -Exactly
    }

    It 'installs the newest release when no al-runner is installed' {
        $global:AlrInstalled = $false
        $global:AlrBanner = 'al-runner v0.0.0'
        $global:AlrLatest = '2.13.0'

        { Install-ALRunner } | Should -Not -Throw

        Should -Invoke -ModuleName 'build-operations' dotnet -Times 1 -Exactly -ParameterFilter {
            $args -contains 'install' -and $args -contains '--version' -and $args -contains '2.13.0'
        }
    }

    It 'keeps the installed tool with a warning when NuGet cannot be read' {
        $global:AlrBanner = 'al-runner v2.11.0'
        Mock -ModuleName 'build-operations' Get-ALRunnerLatestRelease { throw 'NuGet unreachable' }

        { Install-ALRunner } | Should -Not -Throw

        Should -Invoke -ModuleName 'build-operations' dotnet -Times 0 -Exactly
        Should -Invoke -ModuleName 'build-operations' Write-BuildMessage -ParameterFilter {
            $Type -eq 'Warning' -and $Message -like '*NuGet unreachable*'
        }
    }

    It 'fails below the 2.10 floor when NuGet cannot be read' {
        $global:AlrBanner = 'al-runner v2.9.0-local.abc1234'
        Mock -ModuleName 'build-operations' Get-ALRunnerLatestRelease { throw 'NuGet unreachable' }

        { Install-ALRunner } | Should -Throw '*al-runner 2.9.0 found, 2.10 required*'
        Should -Invoke -ModuleName 'build-operations' dotnet -Times 0 -Exactly
    }

    It 'takes no -Update switch' {
        (Get-Command Install-ALRunner).Parameters.Keys | Should -Not -Contain 'Update'
    }
}

Describe 'Test-ALRunnerReleaseIsNewer' {
    It 'is <Expected> for installed <Installed> against release <Release>' -ForEach @(
        @{ Installed = '2.11.0'; Release = '2.12.0'; Expected = $true }
        @{ Installed = '2.12.1-local.0e50f688'; Release = '2.12.0'; Expected = $false }
        @{ Installed = '2.12.1-local.0e50f688'; Release = '2.12.1'; Expected = $true }
        @{ Installed = '2.12.1-local.0e50f688'; Release = '2.13.0'; Expected = $true }
        @{ Installed = '2.13.0'; Release = '2.13.0'; Expected = $false }
        @{ Installed = '2.14.0'; Release = '2.13.0'; Expected = $false }
    ) {
        $installedVersion = ConvertTo-ALRunnerVersion -VersionLine "al-runner v$Installed" -Detailed
        Test-ALRunnerReleaseIsNewer -Installed $installedVersion -Release $Release | Should -Be $Expected
    }
}

Describe 'Get-ALRunnerLatestRelease' {
    It 'returns the highest stable version, ignoring prereleases and listing order' {
        Mock -ModuleName 'build-operations' Invoke-RestMethod { [pscustomobject]@{ versions = @('2.9.0', '2.12.0', '2.13.0-beta.1', '2.10.0', '2.11.0') } }
        Get-ALRunnerLatestRelease | Should -Be ([version]'2.12.0')
    }

    It 'throws when NuGet lists no stable release' {
        Mock -ModuleName 'build-operations' Invoke-RestMethod { [pscustomobject]@{ versions = @('3.0.0-beta.1') } }
        { Get-ALRunnerLatestRelease } | Should -Throw '*no stable al-runner release*'
    }
}

Describe 'provision.ps1 keeps al-runner current without a switch (#145)' {
    It 'calls Install-ALRunner with no arguments' {
        $calls = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Install-ALRunner'
        }, $true))
        $calls | Should -HaveCount 1
        $calls[0].CommandElements | Should -HaveCount 1
    }
}

Describe 'provision.ps1 Release pin check' {
    BeforeAll {
        $script:Invocations = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand
        }, $true))
        $script:SymbolCalls = @($script:Invocations | Where-Object { $_.CommandElements[0].Extent.Text -eq '$downloadSymbolsScript' })
        $script:BaselineCalls = @($script:Invocations | Where-Object { $_.CommandElements[0].Extent.Text -eq '$downloadBaselineScript' })
    }

    It 'reads no BreakingChangeEnabled' {
        $reads = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $node.Member.Extent.Text -eq 'BreakingChangeEnabled'
        }, $true))
        $reads | Should -HaveCount 0
        (Get-Content -LiteralPath $script:ProvisionPath -Raw) | Should -Not -Match 'BreakingChangeEnabled'
    }

    It 'runs download-baseline.ps1 once, unconditionally, after both download-symbols.ps1 calls' {
        $assignments = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$downloadBaselineScript'
        }, $true))
        $assignments | Should -HaveCount 1
        $assignments[0].Right.Extent.Text | Should -Match "download-baseline\.ps1"

        $script:SymbolCalls | Should -HaveCount 2
        $script:BaselineCalls | Should -HaveCount 1
        foreach ($symbolCall in $script:SymbolCalls) {
            $script:BaselineCalls[0].Extent.StartOffset | Should -BeGreaterThan $symbolCall.Extent.StartOffset
        }

        $parent = $script:BaselineCalls[0].Parent
        while ($parent) {
            $parent | Should -Not -BeOfType [System.Management.Automation.Language.IfStatementAst]
            $parent = $parent.Parent
        }
    }

    It 'runs the same-folder guard after both download-symbols.ps1 calls and before download-baseline.ps1' {
        $guards = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Get-BaselineFolderConflict'
        }, $true))
        $guards | Should -HaveCount 1

        $script:SymbolCalls | Should -HaveCount 2
        $script:BaselineCalls | Should -HaveCount 1
        foreach ($symbolCall in $script:SymbolCalls) {
            $guards[0].Extent.StartOffset | Should -BeGreaterThan $symbolCall.Extent.StartOffset
        }

        # The guard's message stops provision with the contract exit code, before the baseline step.
        $stops = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and
            $node.Clauses[0].Item1.Extent.Text -eq '$folderConflict'
        }, $true))
        $stops | Should -HaveCount 1
        $stops[0].Extent.StartOffset | Should -BeGreaterThan $guards[0].Extent.StartOffset
        $stops[0].Extent.EndOffset | Should -BeLessThan $script:BaselineCalls[0].Extent.StartOffset
        $stops[0].Clauses[0].Item2.Extent.Text | Should -Match 'exit\s+\(Get-ExitCode\)\.Contract'

        # The guard names no breakingChange.enabled: it runs whenever the folder resolves.
        $guards[0].Extent.Text | Should -Match '-ReleaseAppDir\s+\$config\.ReleaseAppDir'
    }

    It 'exits with download-baseline.ps1''s non-zero exit code, with no refresh-failed throw' {
        $baselineOffset = $script:BaselineCalls[0].Extent.StartOffset
        $exits = @($script:ProvisionAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ExitStatementAst] -and
            $node.Pipeline -and $node.Pipeline.Extent.Text -eq '$LASTEXITCODE' -and
            $node.Extent.StartOffset -gt $baselineOffset
        }, $true))
        $exits | Should -HaveCount 1
        $guard = $exits[0].Parent
        while ($guard -and $guard -isnot [System.Management.Automation.Language.IfStatementAst]) { $guard = $guard.Parent }
        $guard.Clauses[0].Item1.Extent.Text | Should -Match '\$LASTEXITCODE\s+-ne\s+0'

        (Get-Content -LiteralPath $script:ProvisionPath -Raw) | Should -Not -Match 'Breaking-change baseline refresh failed'
    }
}
