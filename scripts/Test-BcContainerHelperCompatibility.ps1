#Requires -Version 7.2

<#
.SYNOPSIS
    Checks al-build's direct BcContainerHelper command and parameter usage.
.DESCRIPTION
    Imports an already-installed BcContainerHelper version, parses the al-build
    PowerShell adapter, and fails when a referenced helper command or statically
    supplied parameter is unavailable. It never queries PSGallery or starts a container.
#>

[CmdletBinding()]
param(
    [string]$ScriptsPath,
    [version]$RequiredVersion,
    [string]$ModulePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ScriptsPath) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $skillsRoot = Join-Path $repoRoot 'skills'
    $alBuildRoot = Join-Path $skillsRoot 'al-build'
    $ScriptsPath = Join-Path $alBuildRoot 'scripts'
}

if ($ModulePath) {
    $resolvedModulePath = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop
    $module = Import-Module `
        -Name $resolvedModulePath `
        -PassThru `
        -Force `
        -DisableNameChecking `
        -ErrorAction Stop
    if ($RequiredVersion -and $module.Version -ne $RequiredVersion) {
        throw "BcContainerHelper $RequiredVersion was requested, but $($module.Version) was loaded."
    }
} else {
    $availableModules = @(Get-Module -ListAvailable -Name 'BcContainerHelper')
    if ($RequiredVersion) {
        $availableModules = @($availableModules | Where-Object Version -EQ $RequiredVersion)
    }

    $moduleInfo = $availableModules | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $moduleInfo) {
        $versionText = if ($RequiredVersion) { " $RequiredVersion" } else { '' }
        throw "BcContainerHelper$versionText is not installed."
    }

    $module = Import-Module `
        -Name $moduleInfo.Path `
        -PassThru `
        -Force `
        -DisableNameChecking `
        -ErrorAction Stop
}

$exportedCommands = @{}
foreach ($entry in $module.ExportedCommands.GetEnumerator()) {
    $exportedCommands[$entry.Key.ToLowerInvariant()] = $entry.Value
}

$failures = [System.Collections.Generic.List[string]]::new()

function Get-PrivateScriptAst {
    param(
        [string]$Path,
        [string]$RelativePath
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $failures.Add("Missing required private BcContainerHelper file '$RelativePath'.")
        return $null
    }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    $syntaxErrors = @($parseErrors | Where-Object ErrorId -NE 'TypeNotFound')
    if ($syntaxErrors.Count -gt 0) {
        $failures.Add("$RelativePath has parse errors: $($syntaxErrors.Message -join '; ')")
        return $null
    }

    $ast
}

function Get-FunctionParameters {
    param([System.Management.Automation.Language.FunctionDefinitionAst]$Function)

    $parameters = @($Function.Parameters | Where-Object { $null -ne $_ })
    if ($parameters.Count -eq 0 -and $Function.Body.ParamBlock) {
        $parameters = @($Function.Body.ParamBlock.Parameters)
    }
    $parameters
}

function Get-ParameterName {
    param($Parameter)

    if ($Parameter -is [System.Management.Automation.Language.ParameterAst]) {
        $Parameter.Name.VariablePath.UserPath
    } elseif ($Parameter -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $Parameter.VariablePath.UserPath
    }
}

function Test-IsMandatoryParameter {
    param($Parameter)

    if ($Parameter -isnot [System.Management.Automation.Language.ParameterAst]) {
        return $false
    }

    foreach ($attribute in $Parameter.Attributes) {
        if ($attribute.TypeName.Name -notin @('Parameter', 'ParameterAttribute')) {
            continue
        }
        foreach ($namedArgument in $attribute.NamedArguments) {
            if ($namedArgument.ArgumentName -eq 'Mandatory' -and
                [bool]$namedArgument.Argument.SafeGetValue()) {
                return $true
            }
        }
    }
    $false
}

function Get-FunctionParameterNames {
    param([System.Management.Automation.Language.FunctionDefinitionAst]$Function)

    @(Get-FunctionParameters -Function $Function | ForEach-Object {
        if ($_ -is [System.Management.Automation.Language.ParameterAst]) {
            $_.Name.VariablePath.UserPath
        } elseif ($_ -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $_.VariablePath.UserPath
        }
    })
}

function Test-ScriptParameters {
    param(
        [System.Management.Automation.Language.ScriptBlockAst]$Ast,
        [string]$RelativePath,
        [string[]]$RequiredParameters
    )

    $parameters = @(
        if ($Ast.ParamBlock) {
            $Ast.ParamBlock.Parameters
        }
    )
    $availableParameters = @($parameters | ForEach-Object { Get-ParameterName -Parameter $_ })
    foreach ($requiredParameter in $RequiredParameters) {
        if ($availableParameters -notcontains $requiredParameter) {
            $failures.Add("$RelativePath is missing script parameter '-$requiredParameter'.")
        }
    }

    $unsuppliedMandatoryParameters = @($parameters | Where-Object {
        (Test-IsMandatoryParameter -Parameter $_) -and
        (Get-ParameterName -Parameter $_) -notin $RequiredParameters
    } | ForEach-Object { Get-ParameterName -Parameter $_ })
    if ($unsuppliedMandatoryParameters.Count -gt 0) {
        $failures.Add(
            "$RelativePath requires unsupplied mandatory parameter(s): " +
            "$($unsuppliedMandatoryParameters -join ', ')."
        )
    }
}

function Test-FunctionParameters {
    param(
        [System.Management.Automation.Language.ScriptBlockAst]$Ast,
        [string]$RelativePath,
        [string]$FunctionName,
        [string[]]$RequiredParameters
    )

    $functions = @($Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $FunctionName
    }, $true))
    if ($functions.Count -eq 0) {
        $failures.Add("$RelativePath is missing private function '$FunctionName'.")
        return
    }

    $compatibleFunction = $functions | Where-Object {
        $parameters = @(Get-FunctionParameters -Function $_)
        $availableParameters = @(Get-FunctionParameterNames -Function $_)
        $missingParameters = @($RequiredParameters | Where-Object {
            $availableParameters -notcontains $_
        })
        $unsuppliedMandatoryParameters = @($parameters | Where-Object {
            (Test-IsMandatoryParameter -Parameter $_) -and
            (Get-ParameterName -Parameter $_) -notin $RequiredParameters
        })
        $missingParameters.Count -eq 0 -and $unsuppliedMandatoryParameters.Count -eq 0
    } | Select-Object -First 1
    if (-not $compatibleFunction) {
        $failures.Add(
            "$RelativePath private function '$FunctionName' no longer supports the runtime call with " +
            "parameter(s): $($RequiredParameters -join ', ')."
        )
    }
}

function Test-MethodArity {
    param(
        [System.Management.Automation.Language.ScriptBlockAst]$Ast,
        [string]$RelativePath,
        [string]$MethodName,
        [int]$ArgumentCount
    )

    $methods = @($Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $MethodName
    }, $true))
    $compatibleMethod = $methods | Where-Object {
        @(Get-FunctionParameterNames -Function $_).Count -eq $ArgumentCount
    } | Select-Object -First 1
    if (-not $compatibleMethod) {
        $failures.Add(
            "$RelativePath private method '$MethodName' no longer accepts $ArgumentCount argument(s)."
        )
    }
}

$appHandlingPath = Join-Path $module.ModuleBase 'AppHandling'
$psTestFunctionsRelativePath = Join-Path 'AppHandling' 'PsTestFunctions.ps1'
$clientContextRelativePath = Join-Path 'AppHandling' 'ClientContext.ps1'
$psTestFunctionsPath = Join-Path $appHandlingPath 'PsTestFunctions.ps1'
$clientContextPath = Join-Path $appHandlingPath 'ClientContext.ps1'

$psTestFunctionsAst = Get-PrivateScriptAst `
    -Path $psTestFunctionsPath `
    -RelativePath $psTestFunctionsRelativePath
$clientContextAst = Get-PrivateScriptAst `
    -Path $clientContextPath `
    -RelativePath $clientContextRelativePath

if ($psTestFunctionsAst) {
    Test-ScriptParameters `
        -Ast $psTestFunctionsAst `
        -RelativePath $psTestFunctionsRelativePath `
        -RequiredParameters @('newtonSoftDllPath', 'clientDllPath', 'clientContextScriptPath')
    Test-FunctionParameters `
        -Ast $psTestFunctionsAst `
        -RelativePath $psTestFunctionsRelativePath `
        -FunctionName 'New-ClientContext' `
        -RequiredParameters @('serviceUrl', 'auth', 'credential')
    Test-FunctionParameters `
        -Ast $psTestFunctionsAst `
        -RelativePath $psTestFunctionsRelativePath `
        -FunctionName 'Disable-SslVerification' `
        -RequiredParameters @()
}

if ($clientContextAst) {
    Test-ScriptParameters `
        -Ast $clientContextAst `
        -RelativePath $clientContextRelativePath `
        -RequiredParameters @('clientDllPath')

    foreach ($contract in @(
        @{ Method = 'OpenSession'; ArgumentCount = 0 }
        @{ Method = 'Dispose'; ArgumentCount = 0 }
        @{ Method = 'OpenForm'; ArgumentCount = 1 }
        @{ Method = 'CloseForm'; ArgumentCount = 1 }
        @{ Method = 'GetControlByName'; ArgumentCount = 2 }
        @{ Method = 'SaveValue'; ArgumentCount = 2 }
        @{ Method = 'GetActionByName'; ArgumentCount = 2 }
        @{ Method = 'InvokeAction'; ArgumentCount = 1 }
    )) {
        Test-MethodArity `
            -Ast $clientContextAst `
            -RelativePath $clientContextRelativePath `
            -MethodName $contract.Method `
            -ArgumentCount $contract.ArgumentCount
    }
}

$scriptFiles = @(
    Get-ChildItem -LiteralPath $ScriptsPath -File |
        Where-Object Extension -In @('.ps1', '.psm1')
)
if ($scriptFiles.Count -eq 0) {
    throw "No PowerShell adapter files found at '$ScriptsPath'."
}

$parsedFiles = @()
$localFunctions = @{}
foreach ($file in $scriptFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "$($file.Name) has parse errors: $($parseErrors.Message -join '; ')"
    }

    foreach ($function in $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)) {
        $localFunctions[$function.Name.ToLowerInvariant()] = $true
    }

    $parsedFiles += [pscustomobject]@{
        File = $file
        Ast  = $ast
    }
}

function Get-SplatParameterNames {
    param(
        [System.Management.Automation.Language.CommandAst]$Command,
        [System.Management.Automation.Language.VariableExpressionAst]$Splat
    )

    $scope = $Command
    while ($scope.Parent -and
        $scope.Parent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
        $scope = $scope.Parent
    }
    if ($scope.Parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        $scope = $scope.Parent.Body
    } else {
        while ($scope.Parent) {
            $scope = $scope.Parent
        }
    }

    $variableName = $Splat.VariablePath.UserPath
    $assignment = $scope.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -eq $variableName -and
        $node.Right -is [System.Management.Automation.Language.HashtableAst]
    }, $true) |
        Where-Object { $_.Extent.StartOffset -lt $Command.Extent.StartOffset } |
        Sort-Object { $_.Extent.StartOffset } -Descending |
        Select-Object -First 1

    if (-not $assignment) {
        return
    }

    foreach ($pair in $assignment.Right.KeyValuePairs) {
        if ($pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $pair.Item1.Value
        }
    }
}

$checkedInvocations = 0

foreach ($parsedFile in $parsedFiles) {
    $commands = $parsedFile.Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true)

    foreach ($command in $commands) {
        $commandName = $command.GetCommandName()
        if (-not $commandName) {
            continue
        }

        $normalizedName = $commandName.ToLowerInvariant()
        if ($localFunctions.ContainsKey($normalizedName)) {
            continue
        }

        $looksLikeHelperCommand = $commandName -match '(?i)(BcContainer|NavContainer|BcArtifact)' -or
            $commandName -eq 'Run-AlValidation'
        if (-not $looksLikeHelperCommand -and -not $exportedCommands.ContainsKey($normalizedName)) {
            continue
        }

        $checkedInvocations++
        if (-not $exportedCommands.ContainsKey($normalizedName)) {
            $failures.Add(
                "$($parsedFile.File.Name):$($command.Extent.StartLineNumber) references missing command '$commandName'."
            )
            continue
        }

        $parameterNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        foreach ($element in $command.CommandElements) {
            if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                $null = $parameterNames.Add($element.ParameterName)
            } elseif ($element -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $element.Splatted) {
                foreach ($parameterName in Get-SplatParameterNames -Command $command -Splat $element) {
                    $null = $parameterNames.Add($parameterName)
                }
            }
        }

        $helperCommand = $exportedCommands[$normalizedName]
        foreach ($parameterName in $parameterNames) {
            if (-not $helperCommand.Parameters.ContainsKey($parameterName)) {
                $failures.Add(
                    "$($parsedFile.File.Name):$($command.Extent.StartLineNumber) passes unavailable parameter " +
                    "'-$parameterName' to '$commandName'."
                )
            }
        }
    }
}

if ($failures.Count -gt 0) {
    throw "BcContainerHelper $($module.Version) compatibility failed:`n$($failures -join "`n")"
}

Write-Host "BcContainerHelper $($module.Version) compatibility passed for $checkedInvocations adapter invocation(s)."
