#Requires -Version 7.2

BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts'
    $script:ProvisionPath = Resolve-Path (Join-Path $scriptsRoot 'provision.ps1')

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
