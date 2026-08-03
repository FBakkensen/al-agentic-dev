#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:ScriptsDir = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts'
    $script:RuntimeModule = Join-Path $script:ScriptsDir 'coverage-runtime.psm1'
    Import-Module (Join-Path $script:ScriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module $script:RuntimeModule -Force -DisableNameChecking
    Import-Module (Join-Path $script:ScriptsDir 'build-operations.psm1') -Force -DisableNameChecking
    $script:CoverageRuntimeModuleInfo = Get-Module coverage-runtime -ErrorAction Stop
    $script:TestRunnerPageDrainState = $null

    $securePassword = ConvertTo-SecureString 'test' -AsPlainText -Force
    $script:Credential = [pscredential]::new('test', $securePassword)

    function Get-TestRunnerPageDrainState {
        $autoLoadingPreference = Get-Variable PSModuleAutoLoadingPreference `
            -Scope Global -ErrorAction SilentlyContinue
        $autoLoadingPreferenceExists = $null -ne $autoLoadingPreference
        $autoLoadingPreferenceValue = if ($autoLoadingPreferenceExists) {
            $autoLoadingPreference.Value
        } else {
            $null
        }
        $modules = @(Get-Module -Name BcContainerHelper)
        $hostCommands = @{}

        try {
            Set-Variable PSModuleAutoLoadingPreference -Scope Global -Value 'None'
            foreach ($commandName in @('Get-BcContainerPath', 'Invoke-ScriptInBcContainer')) {
                $hostCommands[$commandName] = @(
                    Get-Command $commandName -All -ErrorAction SilentlyContinue |
                        ForEach-Object {
                            "$($_.CommandType)|$($_.Name)|$($_.ModuleName)|$($_.Source)"
                        } |
                        Sort-Object
                ) -join "`n"
            }
        } finally {
            if ($autoLoadingPreferenceExists) {
                Set-Variable PSModuleAutoLoadingPreference -Scope Global `
                    -Value $autoLoadingPreferenceValue
            } else {
                Remove-Variable PSModuleAutoLoadingPreference -Scope Global `
                    -ErrorAction SilentlyContinue
            }
        }

        $fallbackFunctions = & $script:CoverageRuntimeModuleInfo {
            $state = @{}
            foreach ($commandName in @('Get-BcContainerPath', 'Invoke-ScriptInBcContainer')) {
                $function = Get-Item -LiteralPath "Function:\$commandName" `
                    -ErrorAction SilentlyContinue
                $state[$commandName] = [pscustomobject]@{
                    Exists = $null -ne $function
                    ScriptBlock = if ($function) { $function.ScriptBlock } else { $null }
                }
            }
            $state
        }

        [pscustomobject]@{
            AutoLoadingPreferenceExists = $autoLoadingPreferenceExists
            AutoLoadingPreferenceValue = $autoLoadingPreferenceValue
            BcContainerHelperModules = $modules
            BcContainerHelperModuleState = @(
                $modules |
                    ForEach-Object { "$($_.Name)|$($_.Version)|$($_.Path)" } |
                    Sort-Object
            ) -join "`n"
            HostCommands = $hostCommands
            FallbackFunctions = $fallbackFunctions
        }
    }

    function Restore-TestRunnerPageDrainState {
        param([Parameter(Mandatory)]$State)

        try {
            try {
                & $script:CoverageRuntimeModuleInfo {
                    param($FallbackFunctions)

                    foreach ($commandName in $FallbackFunctions.Keys) {
                        Remove-Item -LiteralPath "Function:\$commandName" -Force `
                            -ErrorAction SilentlyContinue
                        $fallback = $FallbackFunctions[$commandName]
                        if ($fallback.Exists) {
                            Set-Item -LiteralPath "Function:\$commandName" `
                                -Value $fallback.ScriptBlock -Force -ErrorAction Stop
                        }
                    }
                } $State.FallbackFunctions
            } finally {
                $initialModuleIdentities = @(
                    $State.BcContainerHelperModules |
                        ForEach-Object { "$($_.Name)|$($_.Version)|$($_.Path)" }
                )
                foreach ($module in @(Get-Module -Name BcContainerHelper)) {
                    $identity = "$($module.Name)|$($module.Version)|$($module.Path)"
                    if ($identity -notin $initialModuleIdentities) {
                        Remove-Module -ModuleInfo $module -Force -ErrorAction Stop
                    }
                }
            }
        } finally {
            if ($State.AutoLoadingPreferenceExists) {
                Set-Variable PSModuleAutoLoadingPreference -Scope Global `
                    -Value $State.AutoLoadingPreferenceValue
            } else {
                Remove-Variable PSModuleAutoLoadingPreference -Scope Global `
                    -ErrorAction SilentlyContinue
            }
        }
    }

    function New-CoveragePayload {
        param([string]$Value = 'line')
        @"
<CodeCoverage SchemaVersion="1">
  <CoverageLine>
    <ObjectTypeCode>5</ObjectTypeCode>
    <ObjectTypeName>Codeunit</ObjectTypeName>
    <ObjectId>70000</ObjectId>
    <LineNumber>10</LineNumber>
    <LineTypeCode>0</LineTypeCode>
    <LineTypeName>Code</LineTypeName>
    <CoverageStatusCode>1</CoverageStatusCode>
    <CoverageStatusName>Covered</CoverageStatusName>
    <HitCount>1</HitCount>
    <SourceLine>$Value</SourceLine>
  </CoverageLine>
</CodeCoverage>
"@
    }

    function New-CompleteCollection {
        param(
            [string]$Path,
            [string]$TestApp
        )

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        New-CoveragePayload | Set-Content -LiteralPath (Join-Path $Path 'payload-0001.xml')
        [ordered]@{
            schemaVersion = 1
            testApp = $TestApp
            junitTestCount = 1
            payloadCount = 1
            drainResponseCount = 3
            terminalDoneCount = 2
            doneValue = 'Done.'
            payloads = @(
                [ordered]@{
                    order = 1
                    testCodeunitId = 70000
                    testMethod = 'CoversMainApp'
                    file = 'payload-0001.xml'
                }
            )
        } | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $Path 'manifest.json')
    }

    function New-TestRunnerPageFixture {
        param(
            [object[]]$Responses,
            [int]$ActionDelayMilliseconds = 0
        )

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $moduleRoot = Join-Path $root 'BcContainerHelper'
        $appHandlingRoot = Join-Path $moduleRoot 'AppHandling'
        $runPath = Join-Path $root 'run'
        $serviceRoot = Join-Path $root 'service'
        $null = New-Item -ItemType Directory -Path $appHandlingRoot, $runPath, $serviceRoot -Force

        @'
param(
    [string]$newtonSoftDllPath,
    [string]$clientDllPath,
    [string]$clientContextScriptPath
)
function Disable-SslVerification {}
function New-ClientContext {
    param($serviceUrl, $auth, $credential)
    $global:CoverageRuntimeClientContext
}
'@ | Set-Content -LiteralPath (Join-Path $appHandlingRoot 'PsTestFunctions.ps1')
        '' | Set-Content -LiteralPath (Join-Path $appHandlingRoot 'ClientContext.ps1')
        @'
<configuration>
  <appSettings>
    <add key="PublicWebBaseUrl" value="https://localhost:7049/BC" />
    <add key="ClientServicesCredentialType" value="NavUserPassword" />
  </appSettings>
</configuration>
'@ | Set-Content -LiteralPath (Join-Path $serviceRoot 'CustomSettings.config')

        $state = [pscustomobject]@{
            Responses = @($Responses)
            ResponseIndex = 0
            Current = $null
            ActionDelayMilliseconds = $ActionDelayMilliseconds
            OpenFormCount = 0
            CloseFormCount = 0
            DisposeCount = 0
        }
        $clientContext = [pscustomobject]@{}
        $clientContext | Add-Member ScriptMethod OpenForm {
            param([int]$PageId)
            $global:CoverageRuntimePageState.OpenFormCount++
            [pscustomobject]@{ Id = $PageId }
        }
        $clientContext | Add-Member ScriptMethod SaveValue {
            param($Control, $Value)
        }
        $clientContext | Add-Member ScriptMethod GetActionByName {
            param($Form, [string]$Name)
            [pscustomobject]@{ Name = $Name }
        }
        $clientContext | Add-Member ScriptMethod InvokeAction {
            param($Action)
            if ($global:CoverageRuntimePageState.ActionDelayMilliseconds -gt 0) {
               Start-Sleep -Milliseconds $global:CoverageRuntimePageState.ActionDelayMilliseconds
            }
            $index = $global:CoverageRuntimePageState.ResponseIndex
            $global:CoverageRuntimePageState.Current =
               $global:CoverageRuntimePageState.Responses[$index]
            $global:CoverageRuntimePageState.ResponseIndex++
        }
        $clientContext | Add-Member ScriptMethod GetControlByName {
            param($Form, [string]$Name)
            $current = $global:CoverageRuntimePageState.Current
            $value = if ($Name -eq 'CCInfo') {
               $current.Info
            } elseif ($Name -eq 'CCResultsCSVText') {
               $current.Payload
            } else {
               ''
            }
            [pscustomobject]@{ StringValue = $value }
        }
        $clientContext | Add-Member ScriptMethod CloseForm {
            param($Form)
            $global:CoverageRuntimePageState.CloseFormCount++
        }
        $clientContext | Add-Member ScriptMethod Dispose {
            $global:CoverageRuntimePageState.DisposeCount++
        }

        [pscustomobject]@{
            Module = [pscustomobject]@{ ModuleBase = $moduleRoot }
            RunPath = $runPath
            ServiceRoot = $serviceRoot
            State = $state
            ClientContext = $clientContext
        }
    }
}

Describe 'Coverage helper contract' {
    It 'matches the bundled helper identity and exporter XMLport' {
        $contract = Get-CoverageHelperContract

        $contract.AppId | Should -Be ([guid]'6a7912dd-91be-4a75-a9d3-8f3b5d4e7501')
        $contract.AppVersion | Should -Be ([version]'1.0.0.0')
        $contract.ExporterId | Should -Be 74075
    }

    It 'reads exact app ID/version and uses the fixed exporter contract' {
        $helperRoot = Join-Path $TestDrive 'coverage-helper'
        New-Item -ItemType Directory -Path $helperRoot | Out-Null
        @{
            id = 'b2fe9bb7-5069-4b88-a7b2-796d8f8d1140'
            version = '1.2.3.4'
            name = 'AL Build Coverage Helper'
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $helperRoot 'app.json')
        'xmlport 70999 "Unrelated XMLport" {}' |
            Set-Content -LiteralPath (Join-Path $helperRoot 'Unrelated.XmlPort.al')

        $contract = Get-CoverageHelperContract -AppJsonPath (Join-Path $helperRoot 'app.json')

        $contract.AppId | Should -Be ([guid]'b2fe9bb7-5069-4b88-a7b2-796d8f8d1140')
        $contract.AppVersion | Should -Be ([version]'1.2.3.4')
        $contract.ExporterId | Should -Be 74075
    }

    It 'rejects a helper manifest without an exact app identity' {
        $helperRoot = Join-Path $TestDrive 'invalid-helper'
        New-Item -ItemType Directory -Path $helperRoot | Out-Null
        @{
            name = 'Helper'
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $helperRoot 'app.json')

        {
            Get-CoverageHelperContract -AppJsonPath (Join-Path $helperRoot 'app.json')
        } | Should -Throw '*must declare id and version*'
    }
}

Describe 'Deterministic Test Runner state' {
    It 'pins the exact required controls, actions, and persisted values' {
        $contract = Get-BcCoveragePageContract

        $contract.SuiteControl | Should -Be 'CurrentSuiteName'
        $contract.SuiteName | Should -Be 'DEFAULT'
        $contract.TrackingControl | Should -Be 'CCTrackingType'
        $contract.AllSessionsControl | Should -Be 'CCTrackAllSessions'
        $contract.ExporterControl | Should -Be 'CCExporterID'
        $contract.MapControl | Should -Be 'CCMap'
        $contract.PayloadControl | Should -Be 'CCResultsCSVText'
        $contract.InfoControl | Should -Be 'CCInfo'
        $contract.ClearAction | Should -Be 'ClearCodeCoverage'
        $contract.DrainAction | Should -Be 'GetCodeCoverage'
        $contract.DisabledValue | Should -Be 0
        $contract.PerTestValue | Should -Be 3
        $contract.MapDisabledValue | Should -Be 0
        $contract.DoneValue | Should -Be 'Done.'
    }

    It 'sets Disabled explicitly for a normal run' {
        InModuleScope coverage-runtime -Parameters @{ Credential = $script:Credential } {
            param($Credential)
            Mock Invoke-BcTestRunnerPage {}

            Set-BcTestRunnerCoverageState -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath 'shared'

            Should -Invoke Invoke-BcTestRunnerPage -Times 1 -Exactly -ParameterFilter {
                $Operation -eq 'Disable'
            }
        }
    }

    It 'sets enabled mode through the page adapter with the helper exporter' {
        InModuleScope coverage-runtime -Parameters @{ Credential = $script:Credential } {
            param($Credential)
            Mock Invoke-BcTestRunnerPage {}

            Set-BcTestRunnerCoverageState -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath 'shared' -Enabled `
                -ExporterId 70999

            Should -Invoke Invoke-BcTestRunnerPage -Times 1 -Exactly -ParameterFilter {
                $Operation -eq 'Enable' -and $ExporterId -eq 70999
            }
        }
    }
}

Describe 'Coverage preflight' {
    BeforeAll {
        if (-not (Get-Command Get-BcContainerAppInfo -ErrorAction SilentlyContinue)) {
            function global:Get-BcContainerAppInfo {
                param([string]$containerName, [string]$tenant, [switch]$installedOnly)
            }
            $script:StubbedAppInfo = $true
        }
    }

    AfterAll {
        if ($script:StubbedAppInfo) {
            Remove-Item function:global:Get-BcContainerAppInfo -ErrorAction SilentlyContinue
        }
    }

    It 'accepts one exact installed helper and probes the page read-only' {
        $runPath = Join-Path $TestDrive 'preflight-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null
        $contract = [pscustomobject]@{
            AppId = [guid]'b2fe9bb7-5069-4b88-a7b2-796d8f8d1140'
            AppVersion = [version]'1.2.3.4'
        }

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            Contract = $contract
            RunPath = $runPath
        } {
            param($Credential, $Contract, $RunPath)
            $script:preflightRunPath = $RunPath
            Mock Import-BCContainerHelper {}
            Mock Get-BcContainerAppInfo {
                [pscustomobject]@{
                    AppId = 'b2fe9bb7-5069-4b88-a7b2-796d8f8d1140'
                    Version = '1.2.3.4'
                }
            }
            Mock New-BcSharedTestRunDirectory { $script:preflightRunPath }
            Mock Invoke-BcTestRunnerPage {}

            Test-BcCoveragePreflight -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -Contract $Contract

            Should -Invoke Invoke-BcTestRunnerPage -Times 1 -Exactly -ParameterFilter {
                $Operation -eq 'Probe'
            }
        }
    }

    It 'rejects a stale helper and instructs a golden-image rebuild' {
        $contract = [pscustomobject]@{
            AppId = [guid]'b2fe9bb7-5069-4b88-a7b2-796d8f8d1140'
            AppVersion = [version]'2.0.0.0'
        }

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            Contract = $contract
        } {
            param($Credential, $Contract)
            Mock Import-BCContainerHelper {}
            Mock Get-BcContainerAppInfo {
                [pscustomobject]@{
                    AppId = 'b2fe9bb7-5069-4b88-a7b2-796d8f8d1140'
                    Version = '1.0.0.0'
                }
            }
            Mock Invoke-BcTestRunnerPage {}

            {
                Test-BcCoveragePreflight -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -Contract $Contract
            } | Should -Throw '*Rebuild the golden image*'
            Should -Invoke Invoke-BcTestRunnerPage -Times 0 -Exactly
        }
    }
}

Describe 'JUnit completion evidence' {
    It 'accepts a non-empty suite when declared and actual testcase counts match' {
        $path = Join-Path $TestDrive 'complete-junit.xml'
        @'
<testsuites>
  <testsuite name="Tests" tests="2" failures="1">
    <testcase name="PassingTest" />
    <testcase name="FailingTest" />
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath $path

        $evidence = Get-JUnitResultEvidence -Path $path

        $evidence.DeclaredTests | Should -Be 2
        $evidence.TestCaseCount | Should -Be 2
        Test-JUnitResultComplete -Path $path | Should -BeTrue
    }

    It 'rejects an empty testsuites root' {
        $path = Join-Path $TestDrive 'empty-junit.xml'
        '<testsuites />' | Set-Content -LiteralPath $path

        Test-JUnitResultComplete -Path $path | Should -BeFalse
    }

    It 'rejects a suite that declares tests but contains no testcase evidence' {
        $path = Join-Path $TestDrive 'truncated-junit.xml'
        '<testsuites><testsuite tests="1" /></testsuites>' |
            Set-Content -LiteralPath $path

        Test-JUnitResultComplete -Path $path | Should -BeFalse
    }

    It 'rejects testcase evidence without a name' {
        $path = Join-Path $TestDrive 'unnamed-junit.xml'
        '<testsuites><testsuite tests="1"><testcase /></testsuite></testsuites>' |
            Set-Content -LiteralPath $path

        Test-JUnitResultComplete -Path $path | Should -BeFalse
    }

    It 'accepts matching summed counts across multiple suites' {
        $path = Join-Path $TestDrive 'multi-suite-junit.xml'
        @'
<testsuites>
  <testsuite name="A" tests="2">
    <testcase name="A1" />
    <testcase name="A2" />
  </testsuite>
  <testsuite name="B" tests="1">
    <testcase name="B1" />
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath $path

        $evidence = Get-JUnitResultEvidence -Path $path
        $evidence.DeclaredTests | Should -Be 3
        $evidence.TestCaseCount | Should -Be 3
    }

    It 'rejects multi-suite output when summed declared tests exceed testcases' {
        $path = Join-Path $TestDrive 'multi-suite-short-junit.xml'
        @'
<testsuites>
  <testsuite name="A" tests="2">
    <testcase name="A1" />
  </testsuite>
  <testsuite name="B" tests="1">
    <testcase name="B1" />
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath $path

        Test-JUnitResultComplete -Path $path | Should -BeFalse
    }

    It 'rejects multi-suite output when testcase count exceeds declarations' {
        $path = Join-Path $TestDrive 'multi-suite-long-junit.xml'
        @'
<testsuites>
  <testsuite name="A" tests="1">
    <testcase name="A1" />
    <testcase name="A2" />
  </testsuite>
  <testsuite name="B" tests="1">
    <testcase name="B1" />
  </testsuite>
</testsuites>
'@ | Set-Content -LiteralPath $path

        Test-JUnitResultComplete -Path $path | Should -BeFalse
    }
}

Describe 'Test Runner page drain session' {
    BeforeAll {
        $script:TestRunnerPageDrainState = Get-TestRunnerPageDrainState
        try {
            Set-Variable PSModuleAutoLoadingPreference -Scope Global -Value 'None'
            & $script:CoverageRuntimeModuleInfo {
                function script:Get-BcContainerPath {
                    param([string]$containerName, [string]$path)
                }
                function script:Invoke-ScriptInBcContainer {
                    param(
                        [string]$containerName,
                        [scriptblock]$scriptBlock,
                        [object[]]$argumentList
                    )
                }
            }
        } catch {
            $setupError = $_
            Restore-TestRunnerPageDrainState -State $script:TestRunnerPageDrainState
            throw $setupError
        }
    }

    AfterEach {
        Remove-Variable CoverageRuntimeClientContext -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable CoverageRuntimePageState -Scope Global -ErrorAction SilentlyContinue
    }

    AfterAll {
        Restore-TestRunnerPageDrainState -State $script:TestRunnerPageDrainState
    }

    It 'registers every BcContainerHelper host boundary without loading its module' {
        foreach ($commandName in @('Get-BcContainerPath', 'Invoke-ScriptInBcContainer')) {
            $fallback = & $script:CoverageRuntimeModuleInfo {
                param($Name)
                Get-Item -LiteralPath "Function:\$Name" -ErrorAction SilentlyContinue
            } $commandName
            $fallback | Should -Not -BeNullOrEmpty
        }

        $currentModules = @(
            Get-Module -Name BcContainerHelper |
                ForEach-Object { "$($_.Name)|$($_.Version)|$($_.Path)" } |
                Sort-Object
        ) -join "`n"
        $currentModules |
            Should -BeExactly $script:TestRunnerPageDrainState.BcContainerHelperModuleState
    }

    It 'drains multiple payloads and two Done responses in one container invocation' {
        $fixture = New-TestRunnerPageFixture -Responses @(
            [pscustomobject]@{ Info = '70000,FirstTest'; Payload = 'first' }
            [pscustomobject]@{ Info = 'Done.'; Payload = '' }
            [pscustomobject]@{ Info = '70001,SecondTest'; Payload = 'second' }
            [pscustomobject]@{ Info = 'Done.'; Payload = '' }
            [pscustomobject]@{ Info = 'Done.'; Payload = '' }
        )

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            Fixture = $fixture
        } {
            param($Credential, $Fixture)
            $global:CoverageRuntimeClientContext = $Fixture.ClientContext
            $global:CoverageRuntimePageState = $Fixture.State
            Mock Import-BCContainerHelper {}
            Mock Get-Module { $Fixture.Module } -ParameterFilter { $Name -eq 'BcContainerHelper' }
            Mock Get-BcContainerPath { $path }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*Newtonsoft.Json.dll' }
            Mock Get-Item {
                if ($Path -like '*Newtonsoft.Json.dll') {
                    [pscustomobject]@{ FullName = 'C:\fake\Newtonsoft.Json.dll' }
                } else {
                    [pscustomobject]@{ FullName = $Fixture.ServiceRoot }
                }
            } -ParameterFilter { $Path -like 'C:\Program Files\Microsoft Dynamics NAV\*' }
            Mock Invoke-ScriptInBcContainer {
                & $scriptBlock @argumentList
            }

            $responses = @(
                Invoke-BcTestRunnerPage -Operation Drain -ContainerName 'bc' `
                    -Tenant 'default' -Credential $Credential `
                    -SharedRunPath $Fixture.RunPath -TestAppName 'tests'
            )

            $responses | Should -HaveCount 5
            $responses[0].Info | Should -Be '70000,FirstTest'
            $responses[1].Info | Should -Be 'Done.'
            $responses[2].Payload | Should -Be 'second'
            $responses[3].Info | Should -Be 'Done.'
            $responses[4].Info | Should -Be 'Done.'
            $Fixture.State.ResponseIndex | Should -Be 5
            $Fixture.State.OpenFormCount | Should -Be 1
            $Fixture.State.CloseFormCount | Should -Be 1
            $Fixture.State.DisposeCount | Should -Be 1
            Should -Invoke Invoke-ScriptInBcContainer -Times 1 -Exactly
        }
    }

    It 'enforces the response limit inside the single container invocation' {
        $fixture = New-TestRunnerPageFixture -Responses @(
            [pscustomobject]@{ Info = '70000,FirstTest'; Payload = 'first' }
            [pscustomobject]@{ Info = '70001,SecondTest'; Payload = 'second' }
            [pscustomobject]@{ Info = '70002,ThirdTest'; Payload = 'third' }
        )

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            Fixture = $fixture
        } {
            param($Credential, $Fixture)
            $global:CoverageRuntimeClientContext = $Fixture.ClientContext
            $global:CoverageRuntimePageState = $Fixture.State
            Mock Import-BCContainerHelper {}
            Mock Get-Module { $Fixture.Module } -ParameterFilter { $Name -eq 'BcContainerHelper' }
            Mock Get-BcContainerPath { $path }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*Newtonsoft.Json.dll' }
            Mock Get-Item {
                if ($Path -like '*Newtonsoft.Json.dll') {
                    [pscustomobject]@{ FullName = 'C:\fake\Newtonsoft.Json.dll' }
                } else {
                    [pscustomobject]@{ FullName = $Fixture.ServiceRoot }
                }
            } -ParameterFilter { $Path -like 'C:\Program Files\Microsoft Dynamics NAV\*' }
            Mock Invoke-ScriptInBcContainer {
                & $scriptBlock @argumentList
            }

            {
                Invoke-BcTestRunnerPage -Operation Drain -ContainerName 'bc' `
                    -Tenant 'default' -Credential $Credential `
                    -SharedRunPath $Fixture.RunPath -TestAppName 'tests' `
                    -MaxDrainResponses 3
            } | Should -Throw "*exceeded the maximum of 3 responses*received 3 responses and 3 payloads*"
            $Fixture.State.ResponseIndex | Should -Be 3
            $Fixture.State.CloseFormCount | Should -Be 1
            $Fixture.State.DisposeCount | Should -Be 1
            Should -Invoke Invoke-ScriptInBcContainer -Times 1 -Exactly
        }
    }

    It 'enforces the wall-clock timeout inside the single container invocation' {
        $fixture = New-TestRunnerPageFixture -Responses @(
            [pscustomobject]@{ Info = '70000,SlowTest'; Payload = 'slow' }
        ) -ActionDelayMilliseconds 100

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            Fixture = $fixture
        } {
            param($Credential, $Fixture)
            $global:CoverageRuntimeClientContext = $Fixture.ClientContext
            $global:CoverageRuntimePageState = $Fixture.State
            Mock Import-BCContainerHelper {}
            Mock Get-Module { $Fixture.Module } -ParameterFilter { $Name -eq 'BcContainerHelper' }
            Mock Get-BcContainerPath { $path }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*Newtonsoft.Json.dll' }
            Mock Get-Item {
                if ($Path -like '*Newtonsoft.Json.dll') {
                    [pscustomobject]@{ FullName = 'C:\fake\Newtonsoft.Json.dll' }
                } else {
                    [pscustomobject]@{ FullName = $Fixture.ServiceRoot }
                }
            } -ParameterFilter { $Path -like 'C:\Program Files\Microsoft Dynamics NAV\*' }
            Mock Invoke-ScriptInBcContainer {
                & $scriptBlock @argumentList
            }

            {
                Invoke-BcTestRunnerPage -Operation Drain -ContainerName 'bc' `
                    -Tenant 'default' -Credential $Credential `
                    -SharedRunPath $Fixture.RunPath -TestAppName 'tests' `
                    -DrainTimeoutSeconds 0.01
            } | Should -Throw "*exceeded the 0.01-second timeout*received 1 responses and 1 payloads*"
            $Fixture.State.ResponseIndex | Should -Be 1
            $Fixture.State.CloseFormCount | Should -Be 1
            $Fixture.State.DisposeCount | Should -Be 1
            Should -Invoke Invoke-ScriptInBcContainer -Times 1 -Exactly
        }
    }
}

Describe 'Test Runner page drain session cleanup' {
    BeforeAll {
        if ($null -eq $script:TestRunnerPageDrainState) {
            $script:TestRunnerPageDrainState = Get-TestRunnerPageDrainState
        }
        $script:PostCleanupTestRunnerPageDrainState = Get-TestRunnerPageDrainState
    }

    It 'restores host boundaries and process state' {
        foreach ($commandName in @('Get-BcContainerPath', 'Invoke-ScriptInBcContainer')) {
            $script:PostCleanupTestRunnerPageDrainState.HostCommands[$commandName] |
                Should -BeExactly $script:TestRunnerPageDrainState.HostCommands[$commandName]

            $expectedFallback = $script:TestRunnerPageDrainState.FallbackFunctions[$commandName]
            $actualFallback =
                $script:PostCleanupTestRunnerPageDrainState.FallbackFunctions[$commandName]
            $actualFallback.Exists | Should -Be $expectedFallback.Exists
            if ($expectedFallback.Exists) {
                $actualFallback.ScriptBlock.ToString() |
                    Should -BeExactly $expectedFallback.ScriptBlock.ToString()
            }
        }

        $script:PostCleanupTestRunnerPageDrainState.BcContainerHelperModuleState |
            Should -BeExactly $script:TestRunnerPageDrainState.BcContainerHelperModuleState

        $script:PostCleanupTestRunnerPageDrainState.AutoLoadingPreferenceExists |
            Should -Be $script:TestRunnerPageDrainState.AutoLoadingPreferenceExists
        if ($script:TestRunnerPageDrainState.AutoLoadingPreferenceExists) {
            $script:PostCleanupTestRunnerPageDrainState.AutoLoadingPreferenceValue |
                Should -BeExactly $script:TestRunnerPageDrainState.AutoLoadingPreferenceValue
        }
    }
}

Describe 'Coverage drain' {
    It 'requires two consecutive Done responses and writes exact sequential identities' {
        $runPath = Join-Path $TestDrive 'drain'
        New-Item -ItemType Directory -Path $runPath | Out-Null
        $passingPayload = New-CoveragePayload 'pass'
        $failingPayload = New-CoveragePayload 'fail'

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            RunPath = $runPath
            PassingPayload = $passingPayload
            FailingPayload = $failingPayload
        } {
            param($Credential, $RunPath, $PassingPayload, $FailingPayload)
            $script:responses = @(
                [pscustomobject]@{ Info = '70000,PassingTest'; Payload = $PassingPayload }
                [pscustomobject]@{ Info = 'Done.'; Payload = '' }
                [pscustomobject]@{ Info = '70001,FailingTest'; Payload = $FailingPayload }
                [pscustomobject]@{ Info = 'Done.'; Payload = '' }
                [pscustomobject]@{ Info = 'Done.'; Payload = '' }
            )
            Mock Invoke-BcTestRunnerPage {
                $script:responses
            }

            $path = Receive-BcTestCoverage -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath $RunPath -TestAppName 'tests-a' `
                -JUnitTestCount 2

            $manifest = Get-Content -LiteralPath (Join-Path $path 'manifest.json') -Raw |
                ConvertFrom-Json
            $manifest.payloadCount | Should -Be 2
            $manifest.drainResponseCount | Should -Be 5
            $manifest.terminalDoneCount | Should -Be 2
            $manifest.doneValue | Should -Be 'Done.'
            $manifest.payloads[0].file | Should -Be 'payload-0001.xml'
            $manifest.payloads[0].testCodeunitId | Should -Be 70000
            $manifest.payloads[0].testMethod | Should -Be 'PassingTest'
            $manifest.payloads[1].file | Should -Be 'payload-0002.xml'
            Should -Invoke Invoke-BcTestRunnerPage -Times 1 -Exactly -ParameterFilter {
                $Operation -eq 'Drain' -and
                $MaxDrainResponses -eq 10000 -and
                $DrainTimeoutSeconds -eq 600 -and
                $TestAppName -eq 'tests-a'
            }
            $bytes = [System.IO.File]::ReadAllBytes(
                (Join-Path $path 'payload-0001.xml')
            )
            $bytes[0] | Should -Be 0xFF
            $bytes[1] | Should -Be 0xFE
        }
    }

    It 'rejects malformed XML before a collection becomes complete' {
        $runPath = Join-Path $TestDrive 'bad-drain'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            RunPath = $runPath
        } {
            param($Credential, $RunPath)
            Mock Invoke-BcTestRunnerPage {
                [pscustomobject]@{ Info = '70000,Test'; Payload = '<not-closed>' }
            }

            {
                Receive-BcTestCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -TestAppName 'tests' `
                    -JUnitTestCount 1
            } | Should -Throw '*not valid XML*'
            Test-Path -LiteralPath (Join-Path $RunPath 'coverage' 'manifest.json') |
                Should -BeFalse
        }
    }

    It 'passes response and timeout bounds to the single drain invocation' {
        $runPath = Join-Path $TestDrive 'bounded-drain'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            RunPath = $runPath
        } {
            param($Credential, $RunPath)
            Mock Invoke-BcTestRunnerPage {
                throw "Coverage drain for 'tests' exceeded the maximum of 3 responses."
            }

            {
                Receive-BcTestCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -TestAppName 'tests' `
                    -JUnitTestCount 10 -MaxDrainResponses 3 `
                    -DrainTimeout ([timespan]::FromSeconds(4))
            } | Should -Throw "*exceeded the maximum of 3 responses*"
            Should -Invoke Invoke-BcTestRunnerPage -Times 1 -Exactly -ParameterFilter {
                $Operation -eq 'Drain' -and
                $MaxDrainResponses -eq 3 -and
                $DrainTimeoutSeconds -eq 4 -and
                $TestAppName -eq 'tests'
            }
        }
    }

    It 'reports an unexpected or nonlocalized sentinel precisely' {
        $runPath = Join-Path $TestDrive 'unexpected-sentinel'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            RunPath = $runPath
        } {
            param($Credential, $RunPath)
            Mock Invoke-BcTestRunnerPage {
                [pscustomobject]@{ Info = 'Fertig.'; Payload = '' }
            }

            {
                Receive-BcTestCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -TestAppName 'tests' `
                    -JUnitTestCount 1
            } | Should -Throw "*unexpected response 'Fertig.'*exact sentinel 'Done.'*"
        }
    }

    It 'rejects two Done responses when the executed app produced zero payloads' {
        $runPath = Join-Path $TestDrive 'zero-payload'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            RunPath = $runPath
        } {
            param($Credential, $RunPath)
            Mock Invoke-BcTestRunnerPage {
                @(
                    [pscustomobject]@{ Info = 'Done.'; Payload = '' }
                    [pscustomobject]@{ Info = 'Done.'; Payload = '' }
                )
            }

            {
                Receive-BcTestCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -TestAppName 'tests' `
                    -JUnitTestCount 1
            } | Should -Throw "*contains zero payloads for executed test app 'tests'*"
            Should -Invoke Invoke-BcTestRunnerPage -Times 1 -Exactly
        }
    }

    It 'rejects a well-formed payload without a coverage record' {
        $path = Join-Path $TestDrive 'no-records.xml'
        '<CodeCoverage SchemaVersion="1" />' | Set-Content -LiteralPath $path

        { Test-BcCoveragePayload -Path $path } |
            Should -Throw '*contains no coverage records*'
    }

    It 'rejects a coverage record with a missing required field' {
        $path = Join-Path $TestDrive 'missing-field.xml'
        (New-CoveragePayload).Replace(
            '    <LineTypeName>Code</LineTypeName>' + [Environment]::NewLine,
            ''
        ) | Set-Content -LiteralPath $path

        { Test-BcCoveragePayload -Path $path } |
            Should -Throw "*record is missing 'LineTypeName'*"
    }

    It 'rejects a coverage record with a nonnumeric code value' {
        $path = Join-Path $TestDrive 'nonnumeric-code.xml'
        (New-CoveragePayload).Replace(
            '<CoverageStatusCode>1</CoverageStatusCode>',
            '<CoverageStatusCode>Covered</CoverageStatusCode>'
        ) | Set-Content -LiteralPath $path

        { Test-BcCoveragePayload -Path $path } |
            Should -Throw "*field 'CoverageStatusCode' is not an integer*"
    }
}

Describe 'Shared runner semantics' {
    It 'configures, runs once, then drains even when assertions fail' {
        $junitPath = Join-Path $TestDrive 'red.xml'
        $runPath = Join-Path $TestDrive 'red-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            $script:order = [System.Collections.Generic.List[string]]::new()
            Mock Set-BcTestRunnerCoverageState { $script:order.Add('configure') }
            Mock Receive-BcTestCoverage {
                $script:order.Add('drain')
                Join-Path $RunPath 'coverage'
            }

            $result = Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                -TestAppName 'tests' -Coverage -ExporterId 70999 -RunTests {
                    $script:order.Add('runner')
                    '<testsuites><testsuite tests="1" failures="1"><testcase name="Fails" /></testsuite></testsuites>' |
                        Set-Content -LiteralPath $JUnitPath
                    $false
                }

            $result.TestsPassed | Should -BeFalse
            $script:order | Should -Be @('configure', 'runner', 'drain')
            Should -Invoke Receive-BcTestCoverage -Times 1 -Exactly
        }
    }

    It 'does not drain after a runner abort' {
        $junitPath = Join-Path $TestDrive 'abort.xml'
        $runPath = Join-Path $TestDrive 'abort-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            Mock Set-BcTestRunnerCoverageState {}
            Mock Receive-BcTestCoverage {}

            {
                Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                    -TestAppName 'tests' -Coverage -ExporterId 70999 `
                    -RunTests { throw 'lost session' }
            } | Should -Throw '*lost session*'
            Should -Invoke Receive-BcTestCoverage -Times 0 -Exactly
        }
    }

    It 'rejects incomplete JUnit before draining' {
        $junitPath = Join-Path $TestDrive 'incomplete.xml'
        $runPath = Join-Path $TestDrive 'incomplete-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            Mock Set-BcTestRunnerCoverageState {}
            Mock Receive-BcTestCoverage {}

            {
                Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                    -TestAppName 'tests' -Coverage -ExporterId 70999 `
                    -RunTests {
                        '<testsuites><testsuite>' | Set-Content -LiteralPath $JUnitPath
                        $false
                    }
            } | Should -Throw '*missing or incomplete*'
            Should -Invoke Receive-BcTestCoverage -Times 0 -Exactly
        }
    }

    It 'uses the same runner callback without a coverage drain when disabled' {
        $junitPath = Join-Path $TestDrive 'normal.xml'
        $runPath = Join-Path $TestDrive 'normal-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            Mock Set-BcTestRunnerCoverageState {}
            Mock Receive-BcTestCoverage {}

            $result = Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                -TestAppName 'tests' -RunTests { $true }

            $result.TestsPassed | Should -BeTrue
            Should -Invoke Set-BcTestRunnerCoverageState -Times 1 -Exactly -ParameterFilter {
                -not $Enabled
            }
            Should -Invoke Receive-BcTestCoverage -Times 0 -Exactly
        }
    }
}

Describe 'Invoke-ALTest transport and failure preservation' {
    BeforeAll {
        if (-not (Get-Command Run-TestsInBcContainer -ErrorAction SilentlyContinue)) {
            function global:Run-TestsInBcContainer { param() }
            $script:StubbedRunTests = $true
        }
    }

    AfterAll {
        if ($script:StubbedRunTests) {
            Remove-Item function:global:Run-TestsInBcContainer -ErrorAction SilentlyContinue
        }
    }

    It 'copies validated per-app coverage into hidden gate staging' {
        $testDir = Join-Path $TestDrive 'tests-a'
        $outputDir = Join-Path $TestDrive 'output-a'
        $stageRoot = Join-Path $TestDrive 'stage-a'
        $sharedRun = Join-Path $TestDrive 'shared-a'
        New-Item -ItemType Directory -Path $testDir, $stageRoot, $sharedRun -Force | Out-Null
        $sharedCoverage = Join-Path $sharedRun 'coverage'
        New-CompleteCollection -Path $sharedCoverage -TestApp 'tests-a'
        $contract = [pscustomobject]@{ ExporterId = 74075 }

        InModuleScope build-operations -Parameters @{
            Credential = $script:Credential
            TestDir = $testDir
            OutputDir = $outputDir
            StageRoot = $stageRoot
            SharedRun = $sharedRun
            SharedCoverage = $sharedCoverage
            Contract = $contract
        } {
            param(
                $Credential,
                $TestDir,
                $OutputDir,
                $StageRoot,
                $SharedRun,
                $SharedCoverage,
                $Contract
            )
            $script:invokeSharedRun = $SharedRun
            $script:invokeSharedCoverage = $SharedCoverage
            Mock Get-BuildConfig {
                [pscustomobject]@{
                    ContainerName = 'bc'
                    Tenant = 'default'
                    ContainerUsername = 'test'
                    ContainerPassword = 'test'
                }
            }
            Mock Get-AppJsonObject {
                [pscustomobject]@{
                    id = 'd5c6f34a-70f5-44d7-944c-260ba63c2247'
                    name = 'Tests A'
                }
            }
            Mock Write-BuildHeader {}
            Mock Write-BuildMessage {}
            Mock Ensure-Directory {
                param([string]$Path)
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
            Mock Import-BCContainerHelper {}
            Mock New-BcSharedTestRunDirectory { $script:invokeSharedRun }
            Mock Get-BCCredential { $Credential }
            Mock Invoke-BcTestRunWithCoverage {
                '<testsuites><testsuite tests="1" failures="0" /></testsuites>' |
                    Set-Content -LiteralPath $JUnitPath
                [pscustomobject]@{
                    TestsPassed = $true
                    CoveragePath = $script:invokeSharedCoverage
                }
            }

            $result = Invoke-ALTest -TestDir $TestDir -OutputDir $OutputDir -Coverage `
                -CoverageStagingRoot $StageRoot -CoverageContract $Contract

            $result.Passed | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $StageRoot 'tests-a' 'manifest.json') |
                Should -BeTrue
            Test-Path -LiteralPath (Join-Path $OutputDir 'last.xml') | Should -BeTrue
            Test-Path -LiteralPath $SharedRun | Should -BeFalse
            Should -Invoke Invoke-BcTestRunWithCoverage -Times 1 -Exactly -ParameterFilter {
                $Coverage -and $ExporterId -eq 74075
            }
        }
    }

    It 'preserves a produced JUnit file when collection aborts' {
        $testDir = Join-Path $TestDrive 'tests-abort'
        $outputDir = Join-Path $TestDrive 'output-abort'
        $stageRoot = Join-Path $TestDrive 'stage-abort'
        $sharedRun = Join-Path $TestDrive 'shared-abort'
        New-Item -ItemType Directory -Path $testDir, $stageRoot, $sharedRun -Force | Out-Null
        $contract = [pscustomobject]@{ ExporterId = 74075 }

        InModuleScope build-operations -Parameters @{
            Credential = $script:Credential
            TestDir = $testDir
            OutputDir = $outputDir
            StageRoot = $stageRoot
            SharedRun = $sharedRun
            Contract = $contract
        } {
            param($Credential, $TestDir, $OutputDir, $StageRoot, $SharedRun, $Contract)
            $script:abortSharedRun = $SharedRun
            Mock Get-BuildConfig {
                [pscustomobject]@{
                    ContainerName = 'bc'
                    Tenant = 'default'
                    ContainerUsername = 'test'
                    ContainerPassword = 'test'
                }
            }
            Mock Get-AppJsonObject {
                [pscustomobject]@{
                    id = 'd5c6f34a-70f5-44d7-944c-260ba63c2247'
                    name = 'Abort Tests'
                }
            }
            Mock Write-BuildHeader {}
            Mock Write-BuildMessage {}
            Mock Ensure-Directory {
                param([string]$Path)
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
            Mock Import-BCContainerHelper {}
            Mock New-BcSharedTestRunDirectory { $script:abortSharedRun }
            Mock Get-BCCredential { $Credential }
            Mock Invoke-BcTestRunWithCoverage {
                '<testsuites><testsuite tests="1" failures="0" /></testsuites>' |
                    Set-Content -LiteralPath $JUnitPath
                throw 'coverage drain failed'
            }

            {
                Invoke-ALTest -TestDir $TestDir -OutputDir $OutputDir -Coverage `
                    -CoverageStagingRoot $StageRoot -CoverageContract $Contract
            } | Should -Throw '*coverage drain failed*'

            Test-Path -LiteralPath (Join-Path $OutputDir 'last.xml') | Should -BeTrue
            Test-Path -LiteralPath $SharedRun | Should -BeFalse
            @(Get-ChildItem -LiteralPath $StageRoot -Force).Count | Should -Be 0
        }
    }

    It 'removes the shared run when copying JUnit throws' {
        $testDir = Join-Path $TestDrive 'tests-copy-failure'
        $outputDir = Join-Path $TestDrive 'output-copy-failure'
        $sharedRun = Join-Path $TestDrive 'shared-copy-failure'
        New-Item -ItemType Directory -Path $testDir, $sharedRun -Force | Out-Null

        InModuleScope build-operations -Parameters @{
            Credential = $script:Credential
            TestDir = $testDir
            OutputDir = $outputDir
            SharedRun = $sharedRun
        } {
            param($Credential, $TestDir, $OutputDir, $SharedRun)
            $script:copyFailureSharedRun = $SharedRun
            Mock Get-BuildConfig {
                [pscustomobject]@{
                    ContainerName = 'bc'
                    Tenant = 'default'
                    ContainerUsername = 'test'
                    ContainerPassword = 'test'
                }
            }
            Mock Get-AppJsonObject {
                [pscustomobject]@{
                    id = 'd5c6f34a-70f5-44d7-944c-260ba63c2247'
                    name = 'Copy Failure Tests'
                }
            }
            Mock Write-BuildHeader {}
            Mock Write-BuildMessage {}
            Mock Ensure-Directory {
                param([string]$Path)
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
            Mock Import-BCContainerHelper {}
            Mock New-BcSharedTestRunDirectory { $script:copyFailureSharedRun }
            Mock Get-BCCredential { $Credential }
            Mock Invoke-BcTestRunWithCoverage {
                '<testsuites><testsuite tests="1"><testcase name="Pass" /></testsuite></testsuites>' |
                    Set-Content -LiteralPath $JUnitPath
                [pscustomobject]@{ TestsPassed = $true; CoveragePath = $null }
            }
            Mock Copy-Item { throw 'JUnit copy failed' }

            {
                Invoke-ALTest -TestDir $TestDir -OutputDir $OutputDir
            } | Should -Throw '*JUnit copy failed*'

            Test-Path -LiteralPath $SharedRun | Should -BeFalse
        }
    }

    It 'preserves a primary runner error when JUnit copy also fails' {
        $testDir = Join-Path $TestDrive 'tests-primary-copy'
        $outputDir = Join-Path $TestDrive 'output-primary-copy'
        $sharedRun = Join-Path $TestDrive 'shared-primary-copy'
        New-Item -ItemType Directory -Path $testDir, $sharedRun -Force | Out-Null

        InModuleScope build-operations -Parameters @{
            Credential = $script:Credential
            TestDir = $testDir
            OutputDir = $outputDir
            SharedRun = $sharedRun
        } {
            param($Credential, $TestDir, $OutputDir, $SharedRun)
            $script:primaryCopySharedRun = $SharedRun
            Mock Get-BuildConfig {
                [pscustomobject]@{
                    ContainerName = 'bc'
                    Tenant = 'default'
                    ContainerUsername = 'test'
                    ContainerPassword = 'test'
                }
            }
            Mock Get-AppJsonObject {
                [pscustomobject]@{
                    id = 'd5c6f34a-70f5-44d7-944c-260ba63c2247'
                    name = 'Primary Copy Tests'
                }
            }
            Mock Write-BuildHeader {}
            Mock Write-BuildMessage {}
            Mock Ensure-Directory {
                param([string]$Path)
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
            Mock Import-BCContainerHelper {}
            Mock New-BcSharedTestRunDirectory { $script:primaryCopySharedRun }
            Mock Get-BCCredential { $Credential }
            Mock Invoke-BcTestRunWithCoverage {
                '<testsuites><testsuite tests="1"><testcase name="Pass" /></testsuite></testsuites>' |
                    Set-Content -LiteralPath $JUnitPath
                throw 'primary runner failure'
            }
            Mock Copy-Item { throw 'secondary JUnit copy failure' }

            {
                Invoke-ALTest -TestDir $TestDir -OutputDir $OutputDir
            } | Should -Throw '*primary runner failure*'

            Test-Path -LiteralPath $SharedRun | Should -BeFalse
            Should -Invoke Write-BuildMessage -Times 1 -ParameterFilter {
                $Type -eq 'Warning' -and $Message -like '*secondary JUnit copy failure*'
            }
        }
    }

    It 'preserves a primary coverage error when shared cleanup fails' {
        $testDir = Join-Path $TestDrive 'tests-primary-cleanup'
        $outputDir = Join-Path $TestDrive 'output-primary-cleanup'
        $sharedRun = Join-Path $TestDrive 'shared-primary-cleanup'
        New-Item -ItemType Directory -Path $testDir, $sharedRun -Force | Out-Null

        InModuleScope build-operations -Parameters @{
            Credential = $script:Credential
            TestDir = $testDir
            OutputDir = $outputDir
            SharedRun = $sharedRun
        } {
            param($Credential, $TestDir, $OutputDir, $SharedRun)
            $script:primaryCleanupSharedRun = $SharedRun
            Mock Get-BuildConfig {
                [pscustomobject]@{
                    ContainerName = 'bc'
                    Tenant = 'default'
                    ContainerUsername = 'test'
                    ContainerPassword = 'test'
                }
            }
            Mock Get-AppJsonObject {
                [pscustomobject]@{
                    id = 'd5c6f34a-70f5-44d7-944c-260ba63c2247'
                    name = 'Primary Cleanup Tests'
                }
            }
            Mock Write-BuildHeader {}
            Mock Write-BuildMessage {}
            Mock Ensure-Directory {
                param([string]$Path)
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
            Mock Import-BCContainerHelper {}
            Mock New-BcSharedTestRunDirectory { $script:primaryCleanupSharedRun }
            Mock Get-BCCredential { $Credential }
            Mock Invoke-BcTestRunWithCoverage {
                throw 'primary coverage failure'
            }
            Mock Remove-Item { throw 'secondary cleanup failure' }

            {
                Invoke-ALTest -TestDir $TestDir -OutputDir $OutputDir
            } | Should -Throw '*primary coverage failure*'

            Should -Invoke Write-BuildMessage -Times 1 -ParameterFilter {
                $Type -eq 'Warning' -and $Message -like '*secondary cleanup failure*'
            }
        }
    }
}

Describe 'Gate-wide atomic staging' {
    It 'rejects malformed collection manifests' {
        $path = Join-Path $TestDrive 'malformed-manifest'
        New-CompleteCollection -Path $path -TestApp 'tests'
        '{' | Set-Content -LiteralPath (Join-Path $path 'manifest.json')

        {
            Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests'
        } | Should -Throw '*manifest*is invalid*'
    }

    It 'rejects collection manifests with missing required fields' {
        $path = Join-Path $TestDrive 'missing-manifest-field'
        New-CompleteCollection -Path $path -TestApp 'tests'
        $manifestPath = Join-Path $path 'manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.PSObject.Properties.Remove('payloadCount')
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath

        {
            Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests'
        } | Should -Throw "*is missing required field 'payloadCount'*"
    }

    It 'rejects manifest entries with missing identity fields' {
        $path = Join-Path $TestDrive 'missing-entry-field'
        New-CompleteCollection -Path $path -TestApp 'tests'
        $manifestPath = Join-Path $path 'manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.payloads[0].PSObject.Properties.Remove('testMethod')
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath

        {
            Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests'
        } | Should -Throw "*entry 1 is missing required field 'testMethod'*"
    }

    It 'rejects a collection with an empty JUnit denominator' {
        $path = Join-Path $TestDrive 'empty-denominator'
        New-CompleteCollection -Path $path -TestApp 'tests'
        $manifestPath = Join-Path $path 'manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.junitTestCount = 0
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath

        {
            Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests'
        } | Should -Throw '*has no positive JUnit test count*'
    }

    It 'uses JUnit count as an upper bound without requiring payload equality' {
        $path = Join-Path $TestDrive 'junit-upper-bound'
        New-CompleteCollection -Path $path -TestApp 'tests'
        $manifestPath = Join-Path $path 'manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.junitTestCount = 2
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath
        Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests' | Should -BeTrue

        Copy-Item -LiteralPath (Join-Path $path 'payload-0001.xml') `
            -Destination (Join-Path $path 'payload-0002.xml')
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.junitTestCount = 1
        $manifest.payloadCount = 2
        $manifest.drainResponseCount = 4
        $manifest.payloads = @(
            $manifest.payloads
            [pscustomobject]@{
                order = 2
                testCodeunitId = 70001
                testMethod = 'SecondTest'
                file = 'payload-0002.xml'
            }
        )
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath

        {
            Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests'
        } | Should -Throw '*2 payloads for only 1 declared JUnit tests*'
    }

    It 'rejects a collection without persisted two-Done drain evidence' {
        $path = Join-Path $TestDrive 'missing-done-proof'
        New-CompleteCollection -Path $path -TestApp 'tests'
        $manifestPath = Join-Path $path 'manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.terminalDoneCount = 1
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath

        {
            Test-BcCoverageCollection -Path $path -ExpectedTestApp 'tests'
        } | Should -Throw "*does not prove two consecutive 'Done.' responses*"
    }

    It 'publishes multiple app collections only when every app is complete' {
        $baseResults = Join-Path $TestDrive 'results'
        $stage = New-CoverageGateStaging -BaseResultsPath $baseResults
        New-CompleteCollection -Path (Join-Path $stage 'tests-a') -TestApp 'tests-a'
        New-CompleteCollection -Path (Join-Path $stage 'tests-b') -TestApp 'tests-b'

        $published = Publish-CoverageGateStaging -StagePath $stage `
            -BaseResultsPath $baseResults -ExpectedTestApps @('tests-a', 'tests-b')

        Test-Path -LiteralPath (Join-Path $published 'tests-a' 'manifest.json') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $published 'tests-b' 'manifest.json') |
            Should -BeTrue
        Test-Path -LiteralPath $stage | Should -BeFalse
    }

    It 'removes all raw coverage after an incomplete gate but preserves JUnit' {
        $baseResults = Join-Path $TestDrive 'failed-results'
        $stage = New-CoverageGateStaging -BaseResultsPath $baseResults
        New-CompleteCollection -Path (Join-Path $stage 'tests-a') -TestApp 'tests-a'
        $published = Join-Path $baseResults 'coverage' 'raw'
        New-CompleteCollection -Path (Join-Path $published 'old-tests') -TestApp 'old-tests'
        $junit = Join-Path $baseResults 'tests-a' 'last.xml'
        New-Item -ItemType Directory -Path (Split-Path $junit -Parent) -Force | Out-Null
        '<testsuites />' | Set-Content -LiteralPath $junit

        {
            Publish-CoverageGateStaging -StagePath $stage -BaseResultsPath $baseResults `
                -ExpectedTestApps @('tests-a', 'tests-b')
        } | Should -Throw '*incomplete*'

        Remove-CoverageGateStaging -StagePath $stage -BaseResultsPath $baseResults `
            -RemovePublished
        Test-Path -LiteralPath $stage | Should -BeFalse
        Test-Path -LiteralPath $published | Should -BeFalse
        Test-Path -LiteralPath $junit | Should -BeTrue
    }
}

Describe 'test.ps1 coverage integration' {
    It 'rejects -Coverage -UnitTestOnly before loading configuration' {
        $testScript = Join-Path $script:ScriptsDir 'test.ps1'
        $pwsh = Join-Path $PSHOME 'pwsh.exe'
        $output = & $pwsh -NoProfile -File $testScript -Coverage -UnitTestOnly 2>&1
        $exitCode = $LASTEXITCODE

        $exitCode | Should -Not -Be 0
        ($output -join "`n") | Should -Match '-Coverage cannot be combined with -UnitTestOnly'
        ($output -join "`n") | Should -Not -Match 'al-build.json'
    }

    It 'places enabled preflight after container readiness and before app mutation' {
        $testScript = Get-Content -LiteralPath (Join-Path $script:ScriptsDir 'test.ps1') -Raw
        $ready = $testScript.IndexOf('Ensure-BCAgentContainer')
        $preflight = $testScript.IndexOf('Test-BcCoveragePreflight')
        $firstMutation = $testScript.IndexOf('Test-AppNeedsPublish')

        $ready | Should -BeGreaterThan -1
        $preflight | Should -BeGreaterThan $ready
        $firstMutation | Should -BeGreaterThan $preflight
    }

    It 'contains one unchanged public container runner call for both modes' {
        $operations = Get-Content -LiteralPath (Join-Path $script:ScriptsDir 'build-operations.psm1') -Raw
        [regex]::Matches(
            $operations,
            '(?m)^\s*Run-TestsInBcContainer\s+@testParams\s*$'
        ).Count | Should -Be 1
        $operations | Should -Match 'Invoke-BcTestRunWithCoverage'
    }
}
