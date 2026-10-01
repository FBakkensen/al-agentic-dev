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

Describe 'Install-ALRunner update-once contract' {
    # -Update can already run a `dotnet tool update` (existing tool, forced
    # refresh); the version-floor check must not run a second one in the same
    # invocation. Mocks target the build-operations module scope so the real
    # al-runner/dotnet on this machine are never invoked.
    BeforeAll {
        # Pester's Mock needs a real command to shadow. CI runners have no
        # al-runner, so a PATH stub stands in; the mock below overrides it.
        $script:stubBin = Join-Path $TestDrive 'stub-bin'
        New-Item -ItemType Directory -Path $script:stubBin -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:stubBin 'al-runner.cmd') -Value "@echo off`r`necho al-runner v2.9.0.0"
        $script:savedPath = $env:PATH
        $env:PATH = "$($script:stubBin)$([IO.Path]::PathSeparator)$env:PATH"
    }
    AfterAll {
        $env:PATH = $script:savedPath
    }
    BeforeEach {
        Mock -ModuleName 'build-operations' Write-BuildHeader {}
        Mock -ModuleName 'build-operations' Write-BuildMessage {}
        Mock -ModuleName 'build-operations' al-runner { 'al-runner v2.9.0.0' }
        Mock -ModuleName 'build-operations' dotnet { $global:LASTEXITCODE = 0 }
    }

    It 'throws without a second dotnet tool update when -Update already ran one and the tool is still below floor' {
        { Install-ALRunner -Update } | Should -Throw '*al-runner 2.9.0.0 found, 2.10 required*'
        Should -Invoke -ModuleName 'build-operations' dotnet -Times 1 -Exactly
    }
}

Describe 'Install-ALRunner prerelease builds' {
    # A -local./-beta. suffix marks a developer's own build: the implicit floor
    # update must never replace it via `dotnet tool update --global`.
    BeforeAll {
        $script:stubBin = Join-Path $TestDrive 'stub-bin'
        New-Item -ItemType Directory -Path $script:stubBin -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:stubBin 'al-runner.cmd') -Value "@echo off`r`necho al-runner v2.10.0-local.9017de3a"
        $script:savedPath = $env:PATH
        $env:PATH = "$($script:stubBin)$([IO.Path]::PathSeparator)$env:PATH"
    }
    AfterAll {
        $env:PATH = $script:savedPath
    }
    BeforeEach {
        Mock -ModuleName 'build-operations' Write-BuildHeader {}
        Mock -ModuleName 'build-operations' Write-BuildMessage {}
        Mock -ModuleName 'build-operations' dotnet { $global:LASTEXITCODE = 0 }
    }

    It 'accepts a local build at the floor without running dotnet' {
        Mock -ModuleName 'build-operations' al-runner { 'al-runner v2.10.0-local.9017de3a' }
        { Install-ALRunner } | Should -Not -Throw
        Should -Invoke -ModuleName 'build-operations' dotnet -Times 0 -Exactly
    }

    It 'throws on a local build below the floor instead of updating it' {
        Mock -ModuleName 'build-operations' al-runner { 'al-runner v2.9.0-local.abc1234' }
        { Install-ALRunner } | Should -Throw '*al-runner 2.9.0-local.abc1234 found, 2.10 required*'
        Should -Invoke -ModuleName 'build-operations' dotnet -Times 0 -Exactly
    }

    It 'still updates a local build when -Update is explicit' {
        Mock -ModuleName 'build-operations' al-runner { 'al-runner v2.10.0-local.9017de3a' }
        { Install-ALRunner -Update } | Should -Not -Throw
        Should -Invoke -ModuleName 'build-operations' dotnet -Times 1 -Exactly
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
            $node.GetCommandName() -eq 'Test-BaselineFoldersDistinct'
        }, $true))
        $guards | Should -HaveCount 1

        $script:SymbolCalls | Should -HaveCount 2
        $script:BaselineCalls | Should -HaveCount 1
        foreach ($symbolCall in $script:SymbolCalls) {
            $guards[0].Extent.StartOffset | Should -BeGreaterThan $symbolCall.Extent.StartOffset
        }
        $guards[0].Extent.StartOffset | Should -BeLessThan $script:BaselineCalls[0].Extent.StartOffset

        # A failed guard stops provision with the contract exit code, before the baseline step.
        $guard = $guards[0].Parent
        while ($guard -and $guard -isnot [System.Management.Automation.Language.IfStatementAst]) { $guard = $guard.Parent }
        $guard | Should -Not -BeNullOrEmpty
        $guard.Clauses[0].Item2.Extent.Text | Should -Match 'exit\s+\(Get-ExitCode\)\.Contract'
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
