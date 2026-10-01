#Requires -Version 7.2

BeforeAll {
    function Get-StaticCommandParameterValue {
        param(
            [System.Management.Automation.Language.CommandAst]$Command,
            [string]$ParameterName
        )

        for ($index = 0; $index -lt $Command.CommandElements.Count; $index++) {
            $element = $Command.CommandElements[$index]
            if ($element -isnot [System.Management.Automation.Language.CommandParameterAst] -or
                $element.ParameterName -ne $ParameterName) {
                continue
            }

            $valueIndex = $index + 1
            if ($valueIndex -ge $Command.CommandElements.Count -or
                $Command.CommandElements[$valueIndex] -is [System.Management.Automation.Language.CommandParameterAst]) {
                return $null
            }

            $value = $Command.CommandElements[$valueIndex]
            if ($value -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                return $value.Value
            }

            return $null
        }

        return $null
    }

    function Get-ScriptCommand {
        param([string[]]$Name)

        @($script:GoldenContainerAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -in $Name
        }, $true))
    }

    $scriptsRoot = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts'
    $script:GoldenContainerScriptPath = Resolve-Path (Join-Path $scriptsRoot 'new-bc-container.ps1')
    $script:BuildOperationsModulePath = Resolve-Path (Join-Path $scriptsRoot 'build-operations.psm1')
    $script:CommonModulePath = Resolve-Path (Join-Path $scriptsRoot 'common.psm1')

    $tokens = $null
    $parseErrors = $null
    $script:GoldenContainerAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:GoldenContainerScriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "new-bc-container.ps1 has parse errors: $($parseErrors.Message -join '; ')"
    }

    $tokens = $null
    $parseErrors = $null
    $script:BuildOperationsAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:BuildOperationsModulePath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "build-operations.psm1 has parse errors: $($parseErrors.Message -join '; ')"
    }

    $script:ServerConfigurationCommands = @($script:GoldenContainerAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Set-BcContainerServerConfiguration'
    }, $true))
}

Describe 'Golden container server settings' {
    It 'disables server debugging' {
        $commands = @($script:ServerConfigurationCommands | Where-Object {
            (Get-StaticCommandParameterValue -Command $_ -ParameterName 'keyName') -eq 'EnableDebugging'
        })

        $commands | Should -HaveCount 1
        Get-StaticCommandParameterValue -Command $commands[0] -ParameterName 'keyValue' | Should -Be 'false'
    }

    It 'keeps symbol loading enabled at server startup' {
        $commands = @($script:ServerConfigurationCommands | Where-Object {
            (Get-StaticCommandParameterValue -Command $_ -ParameterName 'keyName') -eq 'EnableSymbolLoadingAtServerStartup'
        })

        $commands | Should -HaveCount 1
        Get-StaticCommandParameterValue -Command $commands[0] -ParameterName 'keyValue' | Should -Be 'true'
    }
}

Describe 'Golden container without AL-Go settings' {
    It 'attempts no AL-Go dependency install' {
        Get-ScriptCommand -Name 'Install-AlGoDependencies', 'Get-AlGoSettingsPath', 'Get-AlGoDependencyProbingPaths' |
            Should -HaveCount 0

        $module = Import-Module $script:CommonModulePath -Force -DisableNameChecking -PassThru
        try {
            $module.ExportedFunctions.Keys | Should -Not -Contain 'Install-AlGoDependencies'
        }
        finally {
            Remove-Module -ModuleInfo $module -Force
        }
    }

    It 'imports no license' {
        Get-ScriptCommand -Name 'New-BcContainer' | Should -HaveCount 1

        # Text, not syntax: a licenseFile parameter, splat key, or later hashtable assignment all contain it.
        $script:GoldenContainerAst.Extent.Text | Should -Not -Match 'licenseFile'

        Get-ScriptCommand -Name 'Import-BcContainerLicense' | Should -HaveCount 0
    }

    It 'never prints the container password' {
        $messageWriters = Get-ScriptCommand -Name 'Write-BuildMessage', 'Write-BuildHeader', 'Write-Host', 'Write-Information', 'Write-Output', 'Write-Warning', 'Write-Error', 'Write-Verbose'
        $messageWriters | Should -Not -BeNullOrEmpty

        @($messageWriters | Where-Object { $_.Extent.Text -match 'ContainerPassword|\.Password\b' }) |
            Should -HaveCount 0
    }
}

Describe 'Gate publishing contract' {
    It 'keeps every Invoke-ALPublish publish on the developer endpoint' {
        $invokeAlPublish = @($script:BuildOperationsAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Invoke-ALPublish'
        }, $true))
        $invokeAlPublish | Should -HaveCount 1

        $publishCommands = @($invokeAlPublish[0].Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Publish-BcContainerApp'
        }, $true))
        $publishCommands | Should -Not -BeNullOrEmpty

        foreach ($command in $publishCommands) {
            @($command.CommandElements | Where-Object {
                $_ -is [System.Management.Automation.Language.CommandParameterAst] -and
                $_.ParameterName -eq 'useDevEndpoint'
            }) | Should -HaveCount 1
        }
    }
}
