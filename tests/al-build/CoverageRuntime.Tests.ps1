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

    function New-TestPs1Harness {
        param(
            [string[]]$TestAppNames = @('test'),
            [string]$UnitTestAppName = '',
            [switch]$FailContainerRun,
            [switch]$ThrowNormalizer,
            [switch]$ConfigThrows,
            [switch]$FailBuild,
            [switch]$FailUnitTest,
            [switch]$FailPreflight,
            [switch]$AbortContainerTest,
            [switch]$FailCollector,
            [switch]$FailRawPublication,
            [switch]$FailCoverageCleanup,
            [switch]$ConfiguredCoverage
        )

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $scriptsRoot = Join-Path $root 'scripts'
        $appRoot = Join-Path $root 'app'
        $null = New-Item -ItemType Directory -Path $root, $scriptsRoot, $appRoot -Force

        $testAppPaths = @()
        foreach ($testAppName in $TestAppNames) {
            $testAppPath = Join-Path $root $testAppName
            $null = New-Item -ItemType Directory -Path $testAppPath -Force
            $testAppPaths += $testAppPath
        }

        $unitTestAppPath = ''
        if ($UnitTestAppName) {
            $unitTestAppPath = Join-Path $root $UnitTestAppName
            $null = New-Item -ItemType Directory -Path $unitTestAppPath -Force
        }

        $scenarioPath = Join-Path $root 'scenario.json'
        [ordered]@{
            RepoRoot           = $root
            AppDir             = $appRoot
            TestApps           = $testAppPaths
            UnitTestApp        = $unitTestAppPath
            TestOutcome        = if ($FailContainerRun) { 'failed' } else { 'passed' }
            NormalizerThrows   = [bool]$ThrowNormalizer
            ConfigThrows       = [bool]$ConfigThrows
            FailBuild          = [bool]$FailBuild
            UnitTestOutcome    = if ($FailUnitTest) { 'failed' } else { 'passed' }
            FailPreflight      = [bool]$FailPreflight
            AbortContainerTest = [bool]$AbortContainerTest
            FailCollector      = [bool]$FailCollector
            FailRawPublication = [bool]$FailRawPublication
            FailCoverageCleanup = [bool]$FailCoverageCleanup
            CoverageEnabled    = [bool]$ConfiguredCoverage
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $scenarioPath

        Copy-Item -LiteralPath (Join-Path $script:ScriptsDir 'test.ps1') `
            -Destination (Join-Path $scriptsRoot 'test.ps1')

        @'
Set-StrictMode -Version Latest

function Get-HarnessScenario {
    Get-Content -LiteralPath $env:TEST_PS1_SCENARIO_PATH -Raw | ConvertFrom-Json
}

function Add-HarnessEvent {
    param([string]$Name, [hashtable]$Data = @{})
    ([ordered]@{ Name = $Name; Data = $Data } | ConvertTo-Json -Compress -Depth 8) |
        Add-Content -LiteralPath $env:TEST_PS1_STATE_PATH
}

function Set-BuildEnvironment {
    param($Config)
}

function Write-BuildHeader {
    param([string]$Message)
    Add-HarnessEvent -Name 'Write-BuildHeader' -Data @{ Message = $Message }
}

function Write-BuildMessage {
    param([string]$Type, [string]$Message)
    Add-HarnessEvent -Name 'Write-BuildMessage' -Data @{
        Type = $Type
        Message = $Message
    }
}

function ConvertTo-Boolean {
    param($Value)
    [bool]$Value
}

function Get-GitRepoRoot {
    (Get-HarnessScenario).RepoRoot
}

function Get-DirtyFileCounts {
    param([string]$AppDir, [string[]]$TestDirs)
    $null
}

function Get-BCCredential {
    param([string]$Username, [string]$Password)
    [pscredential]::new(
        $Username,
        (ConvertTo-SecureString $Password -AsPlainText -Force)
    )
}

function Save-BuildTimingEntry {
    param($Task, $Steps, $TotalSeconds, $Gate, $Outcome, $Tests, $Dirty, $HeadSha)
    Add-HarnessEvent -Name 'Save-BuildTimingEntry' -Data @{
        Task = $Task
        Gate = $Gate
        Outcome = $Outcome
    }
}

function Show-BuildTimingHistory {
    param([int]$Count)
    Add-HarnessEvent -Name 'Show-BuildTimingHistory' -Data @{ Count = $Count }
}

function Remove-Item {
    param(
        [string]$LiteralPath,
        [switch]$Recurse,
        [switch]$Force,
        [switch]$Confirm
    )

    $scenario = Get-HarnessScenario
    $coverageRoot = Join-Path (Join-Path $scenario.RepoRoot '.output' 'TestResults') 'coverage'
    if ($scenario.FailCoverageCleanup -and $LiteralPath -eq $coverageRoot) {
        throw 'coverage cleanup failed boom'
    }

    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath `
        -Recurse:$Recurse -Force:$Force -Confirm:$Confirm -ErrorAction Stop
}

Export-ModuleMember -Function @(
    'Set-BuildEnvironment'
    'Write-BuildHeader'
    'Write-BuildMessage'
    'ConvertTo-Boolean'
    'Get-GitRepoRoot'
    'Get-DirtyFileCounts'
    'Get-BCCredential'
    'Save-BuildTimingEntry'
    'Show-BuildTimingHistory'
    'Remove-Item'
)
'@ | Set-Content -LiteralPath (Join-Path $scriptsRoot 'common.psm1')

        @'
Set-StrictMode -Version Latest

function Get-HarnessScenario {
    Get-Content -LiteralPath $env:TEST_PS1_SCENARIO_PATH -Raw | ConvertFrom-Json
}

function Add-HarnessEvent {
    param([string]$Name, [hashtable]$Data = @{})
    ([ordered]@{ Name = $Name; Data = $Data } | ConvertTo-Json -Compress -Depth 8) |
        Add-Content -LiteralPath $env:TEST_PS1_STATE_PATH
}

function Get-BuildConfig {
    param([hashtable]$Overrides = @{})
    $scenario = Get-HarnessScenario
    if ($scenario.ConfigThrows) {
        throw 'malformed config boom'
    }
    [pscustomobject]@{
        AppDir = $scenario.AppDir
        TestApps = @($scenario.TestApps)
        UnitTestApp = $scenario.UnitTestApp
        UnitTestInitEvents = $false
        WarnAsError = $false
        CoverageEnabled = if ($Overrides.ContainsKey('coverageEnabled')) {
            [bool]$Overrides.coverageEnabled
        } else {
            [bool]$scenario.CoverageEnabled
        }
        ContainerName = 'stub-container'
        ContainerUsername = 'admin'
        ContainerPassword = 'password'
        ContainerAuth = 'UserPassword'
        Tenant = 'default'
    }
}

function Resolve-CoverageEnabled {
    param(
        [pscustomobject]$Config,
        [switch]$Coverage,
        [switch]$UnitTestOnly
    )
    if ($Coverage -and $UnitTestOnly) {
        throw '-Coverage cannot be combined with -UnitTestOnly.'
    }
    if ($UnitTestOnly) {
        return $false
    }
    if (@($Config.TestApps).Count -eq 0) {
        return $false
    }
    if ($Coverage) {
        return $true
    }
    [bool]$Config.CoverageEnabled
}

function Get-RequiredRuntimeMajor {
    param([pscustomobject]$Config)
    12
}

function Invoke-ALBuild {
    param([string]$AppDir, [bool]$WarnAsError, [int]$RequiredRuntimeMajor)
    Add-HarnessEvent -Name 'Invoke-ALBuild' -Data @{ AppDir = $AppDir }
    if ((Get-HarnessScenario).FailBuild) {
        throw 'build failed boom'
    }
}

function Get-CompileTargets {
    param([pscustomobject]$Config, [switch]$UnitTestOnly)
    $targets = @()
    foreach ($testAppDir in $Config.TestApps) {
        $targets += [ordered]@{ AppDir = $testAppDir; Role = 'test' }
    }
    if ($Config.UnitTestApp -and ($Config.TestApps -notcontains $Config.UnitTestApp)) {
        $targets += [ordered]@{ AppDir = $Config.UnitTestApp; Role = 'unit' }
    }
    $targets
}

function Copy-ALSymbolToCache {
    param([string]$SourceAppDir, [string]$TargetAppDir)
    Add-HarnessEvent -Name 'Copy-ALSymbolToCache' -Data @{
        SourceAppDir = $SourceAppDir
        TargetAppDir = $TargetAppDir
    }
}

function Invoke-ALRunnerTest {
    param([string]$AppDir, [string]$TestDir, [string]$OutputDir, [bool]$InitEvents)
    Add-HarnessEvent -Name 'Invoke-ALRunnerTest' -Data @{ TestDir = $TestDir }
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    '<testsuite />' | Set-Content -LiteralPath (Join-Path $OutputDir 'al-runner.xml')
    $passed = (Get-HarnessScenario).UnitTestOutcome -ne 'failed'
    [pscustomobject]@{
        Runner = 'al-runner'
        AppName = Split-Path $TestDir -Leaf
        TestDir = $TestDir
        Passed = $passed
        Counts = [ordered]@{
            testCodeunits = 1
            tests = 1
            testsPassed = if ($passed) { 1 } else { 0 }
            testsFailed = if ($passed) { 0 } else { 1 }
            testsSkipped = 0
        }
        ResultFile = Join-Path $OutputDir 'al-runner.xml'
    }
}

function Ensure-BCAgentContainer {
    param([string]$ContainerName)
    Add-HarnessEvent -Name 'Ensure-BCAgentContainer' -Data @{
        ContainerName = $ContainerName
    }
}

function Get-AppJsonObject {
    param([string]$AppDir)
    [pscustomobject]@{
        name = Split-Path $AppDir -Leaf
    }
}

function Test-AppNeedsPublish {
    param([string]$AppDir, $AppJson, [string]$ContainerName, [switch]$Force)
    $false
}

function Invoke-ALPublish {
    param([string]$AppDir, [switch]$Force)
    Add-HarnessEvent -Name 'Invoke-ALPublish' -Data @{
        AppDir = $AppDir
        Force = [bool]$Force
    }
}

function Wait-BCAppsSynced {
    param([string]$ContainerName, [string[]]$AppNames, [string]$Tenant)
    Add-HarnessEvent -Name 'Wait-BCAppsSynced' -Data @{
        ContainerName = $ContainerName
        AppNames = @($AppNames)
    }
}

function Invoke-ALTest {
    param(
        [string]$TestDir,
        [string]$OutputDir,
        [switch]$Coverage,
        [string]$CoverageStagingRoot,
        $CoverageContract
    )

    $scenario = Get-HarnessScenario
    Add-HarnessEvent -Name 'Invoke-ALTest' -Data @{
        TestDir = $TestDir
        Coverage = [bool]$Coverage
        CoverageStagingRoot = $CoverageStagingRoot
    }

    if ($scenario.AbortContainerTest) {
        $coverageRoot = Split-Path $CoverageStagingRoot -Parent
        $partialRaw = Join-Path $CoverageStagingRoot 'partial.xml'
        $partialPublished = Join-Path $coverageRoot 'raw'
        $partialTemp = Join-Path $coverageRoot 'conversion.tmp'
        New-Item -ItemType Directory -Path $partialPublished -Force | Out-Null
        'partial' | Set-Content -LiteralPath $partialRaw
        'partial' | Set-Content -LiteralPath (Join-Path $partialPublished 'partial.xml')
        'partial' | Set-Content -LiteralPath $partialTemp
        throw 'container test aborted boom'
    }

    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    '<testsuite />' | Set-Content -LiteralPath (Join-Path $OutputDir 'last.xml')

    if ($scenario.FailCollector) {
        $coverageRoot = Split-Path $CoverageStagingRoot -Parent
        $partialApp = Join-Path $CoverageStagingRoot (Split-Path $TestDir -Leaf)
        $partialPublished = Join-Path $coverageRoot 'raw'
        New-Item -ItemType Directory -Path $partialApp, $partialPublished -Force | Out-Null
        'partial' | Set-Content -LiteralPath (Join-Path $partialApp 'payload-0001.xml')
        'partial' | Set-Content -LiteralPath (Join-Path $partialPublished 'partial.xml')
        'partial' | Set-Content -LiteralPath (Join-Path $coverageRoot 'collector.tmp')
        throw 'collector failed boom'
    }

    $passed = $scenario.TestOutcome -ne 'failed'
    [pscustomobject]@{
        Runner = 'container'
        AppName = Split-Path $TestDir -Leaf
        TestDir = $TestDir
        Passed = $passed
        Counts = [ordered]@{
            testCodeunits = 1
            tests = 1
            testsPassed = if ($passed) { 1 } else { 0 }
            testsFailed = if ($passed) { 0 } else { 1 }
            testsSkipped = 0
        }
        ResultFile = Join-Path $OutputDir 'last.xml'
    }
}

Export-ModuleMember -Function @(
    'Get-BuildConfig'
    'Resolve-CoverageEnabled'
    'Get-RequiredRuntimeMajor'
    'Invoke-ALBuild'
    'Get-CompileTargets'
    'Copy-ALSymbolToCache'
    'Invoke-ALRunnerTest'
    'Ensure-BCAgentContainer'
    'Get-AppJsonObject'
    'Test-AppNeedsPublish'
    'Invoke-ALPublish'
    'Wait-BCAppsSynced'
    'Invoke-ALTest'
)
'@ | Set-Content -LiteralPath (Join-Path $scriptsRoot 'build-operations.psm1')

        @'
Set-StrictMode -Version Latest

function Get-HarnessScenario {
    Get-Content -LiteralPath $env:TEST_PS1_SCENARIO_PATH -Raw | ConvertFrom-Json
}

function Add-HarnessEvent {
    param([string]$Name, [hashtable]$Data = @{})
    ([ordered]@{ Name = $Name; Data = $Data } | ConvertTo-Json -Compress -Depth 8) |
        Add-Content -LiteralPath $env:TEST_PS1_STATE_PATH
}

function Get-CoverageHelperContract {
    Add-HarnessEvent -Name 'Get-CoverageHelperContract'
    [pscustomobject]@{
        AppId = [guid]::Empty
        AppVersion = [version]'1.0.0.0'
        ExporterId = 74075
    }
}

function Test-BcCoveragePreflight {
    param([string]$ContainerName, [string]$Tenant, $Credential, $Contract)
    Add-HarnessEvent -Name 'Test-BcCoveragePreflight' -Data @{
        ContainerName = $ContainerName
        Tenant = $Tenant
    }
    if ((Get-HarnessScenario).FailPreflight) {
        throw 'preflight failed boom'
    }
}

function New-CoverageGateStaging {
    param([string]$BaseResultsPath)
    $stagePath = Join-Path (Join-Path $BaseResultsPath 'coverage') 'raw-stage'
    New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
    Add-HarnessEvent -Name 'New-CoverageGateStaging' -Data @{
        BaseResultsPath = $BaseResultsPath
        StagePath = $stagePath
    }
    $stagePath
}

function Publish-CoverageGateStaging {
    param([string]$StagePath, [string]$BaseResultsPath, [string[]]$ExpectedTestApps)
    if ((Get-HarnessScenario).FailRawPublication) {
        $coverageRoot = Join-Path $BaseResultsPath 'coverage'
        $destination = Join-Path $coverageRoot 'raw'
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        'partial' | Set-Content -LiteralPath (Join-Path $destination 'partial.xml')
        'partial' | Set-Content -LiteralPath (Join-Path $coverageRoot 'publication.tmp')
        throw 'raw publication failed boom'
    }
    $destination = Join-Path (Join-Path $BaseResultsPath 'coverage') 'raw'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    'raw' | Set-Content -LiteralPath (Join-Path $destination 'marker.txt')
    # Mirrors the real function's Move-Item: the staging directory does not
    # survive publication, so no raw-stage leftover lingers in coverage/.
    if (Test-Path -LiteralPath $StagePath) {
        Remove-Item -LiteralPath $StagePath -Recurse -Force -Confirm:$false
    }
    Add-HarnessEvent -Name 'Publish-CoverageGateStaging' -Data @{
        StagePath = $StagePath
        BaseResultsPath = $BaseResultsPath
        ExpectedTestApps = @($ExpectedTestApps)
        Destination = $destination
    }
    $destination
}

function Remove-CoverageGateStaging {
    param([string]$StagePath, [string]$BaseResultsPath, [switch]$RemovePublished)
    Add-HarnessEvent -Name 'Remove-CoverageGateStaging' -Data @{
        StagePath = $StagePath
        BaseResultsPath = $BaseResultsPath
        RemovePublished = [bool]$RemovePublished
    }
    if ($StagePath -and (Test-Path -LiteralPath $StagePath)) {
        Remove-Item -LiteralPath $StagePath -Recurse -Force -Confirm:$false
    }
    if ($RemovePublished) {
        $publishedPath = Join-Path (Join-Path $BaseResultsPath 'coverage') 'raw'
        if (Test-Path -LiteralPath $publishedPath) {
            Remove-Item -LiteralPath $publishedPath -Recurse -Force -Confirm:$false
        }
    }
}

Export-ModuleMember -Function @(
    'Get-CoverageHelperContract'
    'Test-BcCoveragePreflight'
    'New-CoverageGateStaging'
    'Publish-CoverageGateStaging'
    'Remove-CoverageGateStaging'
)
'@ | Set-Content -LiteralPath (Join-Path $scriptsRoot 'coverage-runtime.psm1')

        @'
Set-StrictMode -Version Latest

function Get-HarnessScenario {
    Get-Content -LiteralPath $env:TEST_PS1_SCENARIO_PATH -Raw | ConvertFrom-Json
}

function Add-HarnessEvent {
    param([string]$Name, [hashtable]$Data = @{})
    ([ordered]@{ Name = $Name; Data = $Data } | ConvertTo-Json -Compress -Depth 8) |
        Add-Content -LiteralPath $env:TEST_PS1_STATE_PATH
}

function Write-BcCoverageArtifacts {
    param(
        [string]$RepoRoot,
        [string]$MainAppPath,
        [string[]]$TestAppPaths,
        [string]$RawCollectionPath,
        [string]$OutputDirectory
    )

    Add-HarnessEvent -Name 'Write-BcCoverageArtifacts' -Data @{
        RepoRoot = $RepoRoot
        MainAppPath = $MainAppPath
        TestAppPaths = @($TestAppPaths)
        RawCollectionPath = $RawCollectionPath
        OutputDirectory = $OutputDirectory
    }

    $scenario = Get-HarnessScenario
    if ($scenario.NormalizerThrows) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        'partial' | Set-Content -LiteralPath (Join-Path $OutputDirectory 'per-test.jsonl')
        'partial' | Set-Content -LiteralPath (Join-Path $OutputDirectory 'cobertura.xml.tmp')
        throw 'normalizer failed'
    }

    # The real Write-BcCoverageArtifacts writes per-test.jsonl and
    # cobertura.xml together only after every configured app's coverage
    # resolves cleanly — this stub mirrors that pairing: it either produces
    # both artifacts or (above) throws before producing either.
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $perTestPath = Join-Path $OutputDirectory 'per-test.jsonl'
    $coberturaPath = Join-Path $OutputDirectory 'cobertura.xml'
    @(
        '{"schemaVersion":1,"recordType":"source","sourcePath":"src/Main.al","objectType":"Codeunit","objectName":"Main","lineNumber":10}'
        '{"schemaVersion":1,"recordType":"source","sourcePath":"src/Main.al","objectType":"Codeunit","objectName":"Main","lineNumber":20}'
        '{"schemaVersion":1,"recordType":"hit","sourcePath":"src/Main.al","objectType":"Codeunit","objectName":"Main","lineNumber":10,"testApp":"container-tests","testCodeunitId":1,"testCodeunitName":"Test","testProcedure":"Proc","hitCount":1}'
    ) -join "`n" | Set-Content -LiteralPath $perTestPath
    '<coverage />' | Set-Content -LiteralPath $coberturaPath

    [pscustomobject]@{
        TrackingMode = 'PerTest'
        LinesValid = 2
        LinesCovered = 1
        LineRate = 0.5
        PerTestPath = $perTestPath
        CoberturaPath = $coberturaPath
    }
}

Export-ModuleMember -Function 'Write-BcCoverageArtifacts'
'@ | Set-Content -LiteralPath (Join-Path $scriptsRoot 'coverage-normalizer.psm1')

        [pscustomobject]@{
            Root = $root
            ScenarioPath = $scenarioPath
            StatePath = Join-Path $root 'state.jsonl'
            TestScript = Join-Path $scriptsRoot 'test.ps1'
            BaseResultsPath = Join-Path (Join-Path $root '.output') 'TestResults'
            RawPath = Join-Path (Join-Path (Join-Path $root '.output' 'TestResults') 'coverage') 'raw'
            PerTestPath = Join-Path (Join-Path (Join-Path $root '.output' 'TestResults') 'coverage') 'per-test.jsonl'
            CoberturaPath = Join-Path (Join-Path (Join-Path $root '.output' 'TestResults') 'coverage') 'cobertura.xml'
            SummaryPath = Join-Path (Join-Path $root '.output' 'TestResults') 'summary.json'
            AppDir = $appRoot
            TestAppPaths = $testAppPaths
        }
    }

    function Add-StaleResultsMarker {
        param($Harness)
        New-Item -ItemType Directory -Path $Harness.BaseResultsPath -Force | Out-Null
        'stale' | Set-Content -LiteralPath (Join-Path $Harness.BaseResultsPath 'stale-marker.txt')
    }

    function Assert-CoverageSummaryArtifactConsistency {
        param(
            [Parameter(Mandatory)]
            $Harness,

            [Parameter(Mandatory)]
            $Summary
        )

        $coverageRoot = Split-Path $Harness.PerTestPath -Parent
        if ($Summary.coverage.complete) {
            $Summary.coverage.status | Should -Be 'complete'
            foreach ($propertyName in @('perTestJsonlPath', 'coberturaXmlPath')) {
                $relativePath = [string]$Summary.coverage.$propertyName
                $relativePath | Should -Not -BeNullOrEmpty
                $artifactPath = Join-Path $Harness.Root ($relativePath -replace '/', '\')
                Test-Path -LiteralPath $artifactPath -PathType Leaf | Should -BeTrue
            }
            (Get-ChildItem -LiteralPath $coverageRoot -Name | Sort-Object) |
                Should -Be @('cobertura.xml', 'per-test.jsonl')
            return
        }

        $Summary.coverage.PSObject.Properties.Name | Should -Not -Contain 'perTestJsonlPath'
        $Summary.coverage.PSObject.Properties.Name | Should -Not -Contain 'coberturaXmlPath'
        Test-Path -LiteralPath $coverageRoot | Should -BeFalse
    }

    function Invoke-TestPs1Harness {
        param(
            [Parameter(Mandatory)]
            $Harness,

            [switch]$Coverage,
            [switch]$UnitTestOnly
        )

        $oldScenarioPath = [Environment]::GetEnvironmentVariable('TEST_PS1_SCENARIO_PATH', 'Process')
        $oldStatePath = [Environment]::GetEnvironmentVariable('TEST_PS1_STATE_PATH', 'Process')

        try {
            [Environment]::SetEnvironmentVariable('TEST_PS1_SCENARIO_PATH', $Harness.ScenarioPath, 'Process')
            [Environment]::SetEnvironmentVariable('TEST_PS1_STATE_PATH', $Harness.StatePath, 'Process')

            $pwsh = Join-Path $PSHOME 'pwsh.exe'
            $coverageArg = if ($Coverage) { ' -Coverage' } else { '' }
            $modeArg = if ($UnitTestOnly) { ' -UnitTestOnly' } else { ' -AllTests' }
            $output = & $pwsh -NoProfile -Command "Set-Location '$($Harness.Root)'; & '$($Harness.TestScript)'$coverageArg$modeArg" 2>&1
            $events = @()
            if (Test-Path -LiteralPath $Harness.StatePath) {
                $events = @(
                    Get-Content -LiteralPath $Harness.StatePath |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        ForEach-Object { $_ | ConvertFrom-Json }
                )
            }

            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = @($output)
                Events = $events
            }
        } finally {
            [Environment]::SetEnvironmentVariable('TEST_PS1_SCENARIO_PATH', $oldScenarioPath, 'Process')
            [Environment]::SetEnvironmentVariable('TEST_PS1_STATE_PATH', $oldStatePath, 'Process')
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
        $evidence.PassedTests | Should -Be 1
        $evidence.FailedTests | Should -Be 1
        $evidence.SkippedTests | Should -Be 0
        $evidence.TestsPassed | Should -BeFalse
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

    It 'rejects outcome totals that exceed the declared test count' {
        $path = Join-Path $TestDrive 'invalid-outcome-counts.xml'
        @'
<testsuites>
  <testsuite name="Tests" tests="1" failures="1" errors="1">
    <testcase name="BrokenTest" />
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
    It 'classifies completed red from JUnit and drains even when the runner callback reports success' {
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
                    $true
                }

            $result.CompletionStatus | Should -Be 'completed-red'
            $result.TestRunnerCompleted | Should -BeTrue
            $result.CollectorCompleted | Should -BeTrue
            $result.TestsPassed | Should -BeFalse
            $result.JUnitEvidence.FailedTests | Should -Be 1
            $result.PostCompletionRunnerError | Should -BeNullOrEmpty
            $script:order | Should -Be @('configure', 'runner', 'drain')
            Should -Invoke Receive-BcTestCoverage -Times 1 -Exactly
        }
    }

    It 'drains and returns completed-red when the runner throws after writing complete red JUnit' {
        $junitPath = Join-Path $TestDrive 'red-runner-error.xml'
        $runPath = Join-Path $TestDrive 'red-runner-error-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            Mock Set-BcTestRunnerCoverageState {}
            Mock Receive-BcTestCoverage { Join-Path $RunPath 'coverage' }

            $result = Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                -TestAppName 'tests' -Coverage -ExporterId 70999 -RunTests {
                    '<testsuites><testsuite tests="1" failures="1"><testcase name="Fails" /></testsuite></testsuites>' |
                        Set-Content -LiteralPath $JUnitPath
                    throw 'runner transport closed after completion'
                }

            $result.CompletionStatus | Should -Be 'completed-red'
            $result.TestRunnerCompleted | Should -BeTrue
            $result.CollectorCompleted | Should -BeTrue
            $result.PostCompletionRunnerError.Exception.Message |
                Should -Be 'runner transport closed after completion'
            Should -Invoke Receive-BcTestCoverage -Times 1 -Exactly
        }
    }

    It 'classifies completed green from JUnit and collector evidence despite a false runner callback' {
        $junitPath = Join-Path $TestDrive 'green.xml'
        $runPath = Join-Path $TestDrive 'green-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            Mock Set-BcTestRunnerCoverageState {}
            Mock Receive-BcTestCoverage { Join-Path $RunPath 'coverage' }

            $result = Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                -TestAppName 'tests' -Coverage -ExporterId 70999 -RunTests {
                    '<testsuites><testsuite tests="1"><testcase name="Passes" /></testsuite></testsuites>' |
                        Set-Content -LiteralPath $JUnitPath
                    $false
                }

            $result.CompletionStatus | Should -Be 'completed-green'
            $result.TestRunnerCompleted | Should -BeTrue
            $result.CollectorCompleted | Should -BeTrue
            $result.TestsPassed | Should -BeTrue
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

    It 'preserves a runner error with incomplete JUnit and does not drain' {
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
                        throw 'runner failed after partial JUnit'
                    }
            } | Should -Throw '*runner failed after partial JUnit*'
            Should -Invoke Receive-BcTestCoverage -Times 0 -Exactly
        }
    }

    It 'treats collector failure as incomplete after a completed Test Runner result' {
        $junitPath = Join-Path $TestDrive 'collector-failure.xml'
        $runPath = Join-Path $TestDrive 'collector-failure-run'
        New-Item -ItemType Directory -Path $runPath | Out-Null

        InModuleScope coverage-runtime -Parameters @{
            Credential = $script:Credential
            JUnitPath = $junitPath
            RunPath = $runPath
        } {
            param($Credential, $JUnitPath, $RunPath)
            Mock Set-BcTestRunnerCoverageState {}
            Mock Receive-BcTestCoverage { throw 'collector transport lost' }

            {
                Invoke-BcTestRunWithCoverage -ContainerName 'bc' -Tenant 'default' `
                    -Credential $Credential -SharedRunPath $RunPath -JUnitPath $JUnitPath `
                    -TestAppName 'tests' -Coverage -ExporterId 70999 -RunTests {
                        '<testsuites><testsuite tests="1" failures="1"><testcase name="Fails" /></testsuite></testsuites>' |
                            Set-Content -LiteralPath $JUnitPath
                        $false
                    }
            } | Should -Throw '*collector transport lost*'
            Should -Invoke Receive-BcTestCoverage -Times 1 -Exactly
        }
    }

    It 'uses JUnit completion and verdict without a coverage drain when disabled' {
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
                -TestAppName 'tests' -RunTests {
                    '<testsuites><testsuite tests="1"><testcase name="Passes" /></testsuite></testsuites>' |
                        Set-Content -LiteralPath $JUnitPath
                    $false
                }

            $result.CompletionStatus | Should -Be 'completed-green'
            $result.TestRunnerCompleted | Should -BeTrue
            $result.CollectorCompleted | Should -BeFalse
            $result.TestsPassed | Should -BeTrue
            Should -Invoke Set-BcTestRunnerCoverageState -Times 1 -Exactly -ParameterFilter {
                -not $Enabled
            }
            Should -Invoke Receive-BcTestCoverage -Times 0 -Exactly
        }
    }
}

Describe 'Explicit container completion contract' {
    It 'classifies green and red from completion status instead of the legacy Boolean' {
        InModuleScope build-operations {
            $green = [pscustomobject]@{
                CompletionStatus = 'completed-green'
                TestRunnerCompleted = $true
                CollectorCompleted = $true
                TestsPassed = $false
            }
            $red = [pscustomobject]@{
                CompletionStatus = 'completed-red'
                TestRunnerCompleted = $true
                CollectorCompleted = $true
                TestsPassed = $true
            }

            Get-BcTestExecutionVerdict -Execution $green -TestAppName 'tests' -Coverage |
                Should -BeTrue
            Get-BcTestExecutionVerdict -Execution $red -TestAppName 'tests' -Coverage |
                Should -BeFalse
        }
    }

    It 'rejects missing Test Runner completion evidence' {
        InModuleScope build-operations {
            {
                Get-BcTestExecutionVerdict -Execution ([pscustomobject]@{
                    CompletionStatus = 'completed-green'
                    CollectorCompleted = $true
                }) -TestAppName 'tests' -Coverage
            } | Should -Throw '*explicit Test Runner completion evidence*'
        }
    }

    It 'rejects missing collector completion evidence when coverage is enabled' {
        InModuleScope build-operations {
            {
                Get-BcTestExecutionVerdict -Execution ([pscustomobject]@{
                    CompletionStatus = 'completed-red'
                    TestRunnerCompleted = $true
                    CollectorCompleted = $false
                }) -TestAppName 'tests' -Coverage
            } | Should -Throw '*explicit collector completion evidence*'
        }
    }

    It 'rejects an unsupported completion status' {
        InModuleScope build-operations {
            {
                Get-BcTestExecutionVerdict -Execution ([pscustomobject]@{
                    CompletionStatus = 'aborted'
                    TestRunnerCompleted = $true
                    CollectorCompleted = $true
                }) -TestAppName 'tests' -Coverage
            } | Should -Throw "*unsupported completion status 'aborted'*"
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

    It 'preserves completed-red JUnit and coverage using explicit completion evidence' {
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
                '<testsuites><testsuite tests="1" failures="1"><testcase name="Fails" /></testsuite></testsuites>' |
                    Set-Content -LiteralPath $JUnitPath
                [pscustomobject]@{
                    CompletionStatus = 'completed-red'
                    TestRunnerCompleted = $true
                    CollectorCompleted = $true
                    TestsPassed = $true
                    CoveragePath = $script:invokeSharedCoverage
                    PostCompletionRunnerError = [pscustomobject]@{
                        Exception = [System.InvalidOperationException]::new(
                            'runner transport closed after completion'
                        )
                    }
                }
            }

            $result = Invoke-ALTest -TestDir $TestDir -OutputDir $OutputDir -Coverage `
                -CoverageStagingRoot $StageRoot -CoverageContract $Contract

            $result.Passed | Should -BeFalse
            $result.Counts.testsFailed | Should -Be 1
            Test-Path -LiteralPath (Join-Path $StageRoot 'tests-a' 'manifest.json') |
                Should -BeTrue
            Test-Path -LiteralPath (Join-Path $OutputDir 'last.xml') | Should -BeTrue
            Test-Path -LiteralPath $SharedRun | Should -BeFalse
            Should -Invoke Invoke-BcTestRunWithCoverage -Times 1 -Exactly -ParameterFilter {
                $Coverage -and $ExporterId -eq 74075
            }
            Should -Invoke Write-BuildMessage -Times 1 -Exactly -ParameterFilter {
                $Type -eq 'Warning' -and
                $Message -like '*non-fatal error*runner transport closed after completion*'
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
                [pscustomobject]@{
                    CompletionStatus = 'completed-green'
                    TestRunnerCompleted = $true
                    CollectorCompleted = $false
                    TestsPassed = $true
                    CoveragePath = $null
                }
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
        ($output -join "`n") | Should -Match 'Specify exactly one test mode'
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

    It 'runs enabled preflight before AL Runner or consumer app publication' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') `
            -UnitTestAppName 'unit-tests' -ConfiguredCoverage

        $result = Invoke-TestPs1Harness $harness
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $preflightIndex = [array]::IndexOf($eventNames, 'Test-BcCoveragePreflight')

        $result.ExitCode | Should -Be 0
        $preflightIndex | Should -BeGreaterThan ([array]::IndexOf($eventNames, 'Ensure-BCAgentContainer'))
        $preflightIndex | Should -BeLessThan ([array]::IndexOf($eventNames, 'Invoke-ALRunnerTest'))
        $preflightIndex | Should -BeLessThan ([array]::IndexOf($eventNames, 'Invoke-ALPublish'))
    }

    It 'stops a failed preflight before AL Runner, consumer publication, or container tests' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') `
            -UnitTestAppName 'unit-tests' -FailPreflight

        $result = Invoke-TestPs1Harness $harness -Coverage
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'preflight failed boom'
        [array]::IndexOf($eventNames, 'Test-BcCoveragePreflight') |
            Should -BeGreaterThan ([array]::IndexOf($eventNames, 'Ensure-BCAgentContainer'))
        $eventNames | Should -Not -Contain 'Invoke-ALRunnerTest'
        $eventNames | Should -Not -Contain 'Invoke-ALPublish'
        $eventNames | Should -Not -Contain 'Invoke-ALTest'
        $summary.coverage.status | Should -Be 'not-run'
        $summary.coverage.failure.stage | Should -Be 'coverage-preflight'
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'uses configured coverage for a full gate without the explicit switch' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -ConfiguredCoverage

        $result = Invoke-TestPs1Harness $harness
        $containerCall = $result.Events |
            Where-Object Name -eq 'Invoke-ALTest' |
            Select-Object -First 1
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json

        $result.ExitCode | Should -Be 0
        $containerCall.Data.Coverage | Should -BeTrue
        $summary.coverage.status | Should -Be 'complete'
        $summary.coverage.complete | Should -BeTrue
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'ignores configured coverage for UnitTestOnly' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') `
            -UnitTestAppName 'unit-tests' -ConfiguredCoverage

        $result = Invoke-TestPs1Harness $harness -UnitTestOnly
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json

        $result.ExitCode | Should -Be 0
        $eventNames | Should -Not -Contain 'Ensure-BCAgentContainer'
        $eventNames | Should -Not -Contain 'Test-BcCoveragePreflight'
        $eventNames | Should -Not -Contain 'Invoke-ALTest'
        $summary.coverage.status | Should -Be 'disabled'
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'skips coverage with no test apps and completes the compile-only gate' -TestCases @(
        @{ ConfiguredCoverage = $true; ExplicitCoverage = $false }
        @{ ConfiguredCoverage = $false; ExplicitCoverage = $true }
    ) {
        param($ConfiguredCoverage, $ExplicitCoverage)

        $harness = New-TestPs1Harness -TestAppNames @() `
            -ConfiguredCoverage:$ConfiguredCoverage
        $result = Invoke-TestPs1Harness $harness -Coverage:$ExplicitCoverage
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json

        $result.ExitCode | Should -Be 0
        $eventNames | Should -Contain 'Invoke-ALBuild'
        $eventNames | Should -Not -Contain 'Ensure-BCAgentContainer'
        $eventNames | Should -Not -Contain 'Test-BcCoveragePreflight'
        $eventNames | Should -Not -Contain 'Invoke-ALRunnerTest'
        $eventNames | Should -Not -Contain 'Invoke-ALTest'
        $summary.coverage.enabled | Should -BeFalse
        $summary.coverage.status | Should -Be 'disabled'
        $summary.coverage.complete | Should -BeFalse
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'passes both the container username and password to Get-BCCredential with no stray token' {
        $testScript = Get-Content -LiteralPath (Join-Path $script:ScriptsDir 'test.ps1') -Raw
        $testScript | Should -Match '(?m)^\s*\$coverageCredential = Get-BCCredential -Username \$config\.ContainerUsername -Password \$config\.ContainerPassword\s*$'
        $testScript | Should -Not -Match '\*{2,}'
    }

    It 'contains one unchanged public container runner call for both modes' {
        $operations = Get-Content -LiteralPath (Join-Path $script:ScriptsDir 'build-operations.psm1') -Raw
        [regex]::Matches(
            $operations,
            '(?m)^\s*Run-TestsInBcContainer\s+@testParams\s*$'
        ).Count | Should -Be 1
        $operations | Should -Match 'Invoke-BcTestRunWithCoverage'
    }

    It 'runs coverage across every configured test app in a single aggregate call' {
        $harness = New-TestPs1Harness -TestAppNames @('tests-a', 'tests-b') -UnitTestAppName 'unit-tests'
        $result = Invoke-TestPs1Harness $harness -Coverage
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $aggregateCalls = @($result.Events | Where-Object Name -eq 'Write-BcCoverageArtifacts')

        $result.ExitCode | Should -Be 0
        $eventNames | Should -Contain 'Invoke-ALBuild'
        $eventNames | Should -Contain 'Ensure-BCAgentContainer'
        $eventNames | Should -Contain 'Test-BcCoveragePreflight'
        (@($eventNames | Where-Object { $_ -eq 'Invoke-ALTest' })).Count | Should -Be 2
        $aggregateCalls.Count | Should -Be 1
        $aggregateCalls[0].Data.TestAppPaths | Should -Be @($harness.TestAppPaths[0], $harness.TestAppPaths[1])
    }

    It 'passes configured test app paths through in configuration order regardless of app order' {
        $forwardHarness = New-TestPs1Harness -TestAppNames @('tests-a', 'tests-b')
        $reverseHarness = New-TestPs1Harness -TestAppNames @('tests-b', 'tests-a')

        $forwardResult = Invoke-TestPs1Harness $forwardHarness -Coverage
        $reverseResult = Invoke-TestPs1Harness $reverseHarness -Coverage

        $forwardCall = $forwardResult.Events | Where-Object Name -eq 'Write-BcCoverageArtifacts' | Select-Object -First 1
        $reverseCall = $reverseResult.Events | Where-Object Name -eq 'Write-BcCoverageArtifacts' | Select-Object -First 1

        $forwardResult.ExitCode | Should -Be 0
        $reverseResult.ExitCode | Should -Be 0
        $forwardCall.Data.TestAppPaths | Should -Be @($forwardHarness.TestAppPaths[0], $forwardHarness.TestAppPaths[1])
        $reverseCall.Data.TestAppPaths | Should -Be @($reverseHarness.TestAppPaths[0], $reverseHarness.TestAppPaths[1])

        $forwardSummary = Get-Content -LiteralPath $forwardHarness.SummaryPath -Raw | ConvertFrom-Json
        $reverseSummary = Get-Content -LiteralPath $reverseHarness.SummaryPath -Raw | ConvertFrom-Json
        $forwardSummary.coverage.status | Should -Be $reverseSummary.coverage.status
        $forwardSummary.coverage.lineRate | Should -Be $reverseSummary.coverage.lineRate
        $forwardSummary.coverage.linesValid | Should -Be $reverseSummary.coverage.linesValid
        $forwardSummary.coverage.linesCovered | Should -Be $reverseSummary.coverage.linesCovered
    }

    It 'imports the normalizer with Join-Path and calls it with the published raw root and staging output' {
        $testScript = Get-Content -LiteralPath (Join-Path $script:ScriptsDir 'test.ps1') -Raw
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')
        $result = Invoke-TestPs1Harness $harness -Coverage
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $normalizerCall = $result.Events |
            Where-Object Name -eq 'Write-BcCoverageArtifacts' |
            Select-Object -First 1

        $testScript | Should -Match 'Import-Module \(Join-Path \$PSScriptRoot ''coverage-normalizer\.psm1''\) -Force -DisableNameChecking'
        $testScript | Should -Not -Match 'Write-BcCoveragePerTestJsonl'
        $result.ExitCode | Should -Be 0
        [array]::IndexOf($eventNames, 'Publish-CoverageGateStaging') |
            Should -BeLessThan ([array]::IndexOf($eventNames, 'Write-BcCoverageArtifacts'))
        $normalizerCall.Data.RepoRoot | Should -Be $harness.Root
        $normalizerCall.Data.MainAppPath | Should -Be $harness.AppDir
        $normalizerCall.Data.TestAppPaths | Should -Be @($harness.TestAppPaths[0])
        $normalizerCall.Data.RawCollectionPath | Should -Be $harness.RawPath
        $normalizerCall.Data.OutputDirectory | Should -Be (Split-Path $harness.PerTestPath -Parent)
    }

    It 'reports coverage complete using the returned metrics and artifact paths, retains them and removes raw, even when container test assertions fail' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -FailContainerRun
        $result = Invoke-TestPs1Harness $harness -Coverage
        $eventNames = @($result.Events | ForEach-Object { $_.Name })
        $finalHeader = $result.Events |
            Where-Object { $_.Name -eq 'Write-BuildHeader' } |
            Select-Object -Last 1

        $result.ExitCode | Should -Not -Be 0
        $finalHeader.Data.Message | Should -Be 'Test FAILED'
        [array]::IndexOf($eventNames, 'Publish-CoverageGateStaging') |
            Should -BeLessThan ([array]::IndexOf($eventNames, 'Write-BcCoverageArtifacts'))
        Test-Path -LiteralPath $harness.SummaryPath | Should -BeTrue

        # Coverage completeness is independent of the test verdict: complete
        # artifacts are retained and the now-unneeded raw collection is gone.
        Test-Path -LiteralPath $harness.PerTestPath | Should -BeTrue
        Test-Path -LiteralPath $harness.CoberturaPath | Should -BeTrue
        Test-Path -LiteralPath $harness.RawPath | Should -BeFalse

        # Current-run JUnit (the container test's last.xml) is preserved.
        $junitPath = Join-Path (Join-Path $harness.BaseResultsPath 'container-tests') 'last.xml'
        Test-Path -LiteralPath $junitPath | Should -BeTrue

        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.schemaVersion | Should -Be 1
        $summary.coverage.enabled | Should -BeTrue
        $summary.coverage.status | Should -Be 'complete'
        $summary.coverage.complete | Should -BeTrue
        $summary.coverage.trackingMode | Should -Be 'PerTest'
        $summary.coverage.lineRate | Should -Be 0.5
        $summary.coverage.linesValid | Should -Be 2
        $summary.coverage.linesCovered | Should -Be 1
        $summary.coverage.perTestJsonlPath | Should -Match '/'
        $summary.coverage.perTestJsonlPath | Should -Not -Match '\\'
        $summary.coverage.coberturaXmlPath | Should -Match '/'
        $summary.coverage.coberturaXmlPath | Should -Not -Match '\\'
        # The test run itself failed — totals/runs still reflect the real
        # (red) outcome; coverage completeness is independent of test verdict.
        $summary.gate | Should -Be 'full'
        ($summary.runs | Where-Object { $_.runner -eq 'container' }).passed | Should -Be $false
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'writes a failed coverage summary, removes incomplete coverage, and retains current-run JUnit after aggregation failure' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -ThrowNormalizer

        $result = Invoke-TestPs1Harness $harness -Coverage
        $eventNames = @($result.Events | ForEach-Object { $_.Name })

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'normalizer failed'
        $eventNames | Should -Contain 'Publish-CoverageGateStaging'
        $eventNames | Should -Contain 'Write-BcCoverageArtifacts'
        Test-Path -LiteralPath $harness.RawPath | Should -BeFalse

        # The normalizer threw before writing either artifact — no new (nor
        # stale, since startup cleanup wiped any prior run) file exists.
        Test-Path -LiteralPath $harness.PerTestPath | Should -BeFalse
        Test-Path -LiteralPath $harness.CoberturaPath | Should -BeFalse
        Test-Path -LiteralPath (Split-Path $harness.RawPath -Parent) | Should -BeFalse

        # Current-run JUnit (the container test's last.xml) is untouched by
        # the downstream aggregation failure.
        $junitPath = Join-Path (Join-Path $harness.BaseResultsPath 'container-tests') 'last.xml'
        Test-Path -LiteralPath $junitPath | Should -BeTrue

        Test-Path -LiteralPath $harness.SummaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.status | Should -Be 'failed'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.PSObject.Properties.Name | Should -Not -Contain 'perTestJsonlPath'
        $summary.coverage.PSObject.Properties.Name | Should -Not -Contain 'coberturaXmlPath'
        $summary.coverage.failure.stage | Should -Be 'coverage-aggregation'
        $summary.error.stage | Should -Be 'coverage-aggregation'
        $summary.error.message | Should -Match 'normalizer failed'
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }
}

Describe 'test.ps1 startup cleanup' {
    It 'clears stale final, raw, and temporary coverage artifacts on a disabled invocation' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')
        $coverageRoot = Split-Path $harness.RawPath -Parent
        $rawTemp = Join-Path $coverageRoot 'raw-stale'
        New-Item -ItemType Directory -Path $harness.RawPath, $rawTemp -Force | Out-Null
        'stale' | Set-Content -LiteralPath (Join-Path $coverageRoot 'per-test.jsonl')
        'stale' | Set-Content -LiteralPath (Join-Path $coverageRoot 'cobertura.xml')
        'stale' | Set-Content -LiteralPath (Join-Path $harness.RawPath 'manifest.json')
        'stale' | Set-Content -LiteralPath (Join-Path $rawTemp 'partial.xml')

        $result = Invoke-TestPs1Harness $harness

        $result.ExitCode | Should -Be 0
        Test-Path -LiteralPath $coverageRoot | Should -BeFalse
    }

    It 'removes a stale TestResults tree before a disabled (no -Coverage) run' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')
        Add-StaleResultsMarker -Harness $harness

        $result = Invoke-TestPs1Harness $harness

        $result.ExitCode | Should -Be 0
        Test-Path -LiteralPath (Join-Path $harness.BaseResultsPath 'stale-marker.txt') | Should -BeFalse
        Test-Path -LiteralPath $harness.BaseResultsPath | Should -BeTrue
    }

    It 'removes a stale TestResults tree before a -UnitTestOnly run' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -UnitTestAppName 'unit-tests'
        Add-StaleResultsMarker -Harness $harness

        $result = Invoke-TestPs1Harness $harness -UnitTestOnly

        $result.ExitCode | Should -Be 0
        Test-Path -LiteralPath (Join-Path $harness.BaseResultsPath 'stale-marker.txt') | Should -BeFalse
        Test-Path -LiteralPath $harness.BaseResultsPath | Should -BeTrue
    }

    It 'removes a stale TestResults tree before a full -Coverage run' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')
        Add-StaleResultsMarker -Harness $harness

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Be 0
        Test-Path -LiteralPath (Join-Path $harness.BaseResultsPath 'stale-marker.txt') | Should -BeFalse
        Test-Path -LiteralPath $harness.BaseResultsPath | Should -BeTrue
    }

    It 'removes a stale TestResults tree before a compile-only run (no test apps configured)' {
        $harness = New-TestPs1Harness -TestAppNames @()
        Add-StaleResultsMarker -Harness $harness

        $result = Invoke-TestPs1Harness $harness

        $result.ExitCode | Should -Be 0
        Test-Path -LiteralPath (Join-Path $harness.BaseResultsPath 'stale-marker.txt') | Should -BeFalse
        Test-Path -LiteralPath $harness.BaseResultsPath | Should -BeTrue
    }

    It 'exits nonzero and reports the failure when the stale tree cannot be removed' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')
        New-Item -ItemType Directory -Path $harness.BaseResultsPath -Force | Out-Null
        $lockedFile = Join-Path $harness.BaseResultsPath 'locked.bin'
        'locked' | Set-Content -LiteralPath $lockedFile
        $stream = [System.IO.File]::Open($lockedFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)

        try {
            $result = Invoke-TestPs1Harness $harness

            $result.ExitCode | Should -Not -Be 0
            $eventNames = @($result.Events | ForEach-Object { $_.Name })
            $failureMessage = $result.Events |
                Where-Object { $_.Name -eq 'Write-BuildMessage' -and $_.Data.Message -match 'Failed to remove' } |
                Select-Object -First 1
            $failureMessage | Should -Not -BeNullOrEmpty
            $eventNames | Should -Not -Contain 'Invoke-ALBuild'
        } finally {
            $stream.Close()
        }
    }
}

Describe 'test.ps1 malformed config ordering' {
    It 'still runs startup cleanup but writes no summary.json when config fails to load' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -ConfigThrows
        Add-StaleResultsMarker -Harness $harness

        $result = Invoke-TestPs1Harness $harness

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'malformed config boom'
        Test-Path -LiteralPath (Join-Path $harness.BaseResultsPath 'stale-marker.txt') | Should -BeFalse
        Test-Path -LiteralPath $harness.BaseResultsPath | Should -BeTrue
        Test-Path -LiteralPath $harness.SummaryPath | Should -BeFalse
    }
}

Describe 'build-operations.psm1 no longer performs local per-run JUnit cleanup' {
    It 'contains no per-run "Removed previous result" cleanup message' {
        $operations = Get-Content -LiteralPath (Join-Path $script:ScriptsDir 'build-operations.psm1') -Raw
        $operations | Should -Not -Match 'Removed previous result'
        $operations | Should -Not -Match 'Cleaning test results'
    }
}

Describe 'test.ps1 coverage summary lifecycle' {
    It 'writes a disabled coverage block when -Coverage is not specified' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')

        $result = Invoke-TestPs1Harness $harness

        $result.ExitCode | Should -Be 0
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.schemaVersion | Should -Be 1
        $summary.coverage.enabled | Should -BeFalse
        $summary.coverage.status | Should -Be 'disabled'
        $summary.coverage.complete | Should -BeFalse
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'reports coverage not-run when an enabled run fails before container coverage execution (unit test failure)' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -UnitTestAppName 'unit-tests' -FailUnitTest

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Not -Be 0
        Test-Path -LiteralPath $harness.SummaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.schemaVersion | Should -Be 1
        $summary.coverage.enabled | Should -BeTrue
        $summary.coverage.status | Should -Be 'not-run'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.failure.stage | Should -Not -BeNullOrEmpty
        $summary.coverage.failure.message | Should -Not -BeNullOrEmpty
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'reports coverage not-run when an enabled run fails before container coverage execution (build failure)' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -FailBuild

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Not -Be 0
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.status | Should -Be 'not-run'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.failure.stage | Should -Be 'build'
        $summary.error.stage | Should -Be 'build'
        $summary.error.message | Should -Match 'build failed boom'
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'reports coverage aborted and leaves no final coverage artifacts when the selected container test run does not complete' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -AbortContainerTest

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Not -Be 0
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.status | Should -Be 'aborted'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.failure.stage | Should -Not -BeNullOrEmpty
        $summary.error.message | Should -Match 'container test aborted boom'
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'writes summary and timing while preserving the primary error when coverage cleanup fails' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') `
            -AbortContainerTest -FailCoverageCleanup

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'container test aborted boom'
        Test-Path -LiteralPath $harness.SummaryPath -PathType Leaf | Should -BeTrue
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.error.message | Should -Be 'container test aborted boom'
        $summary.coverage.status | Should -Be 'aborted'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.failure.message | Should -Match 'container test aborted boom'
        $summary.coverage.failure.message | Should -Match 'coverage cleanup failed boom'
        @($result.Events | Where-Object { $_.Name -eq 'Save-BuildTimingEntry' }).Count |
            Should -Be 1
    }

    It 'reports a collector failure as aborted, retains JUnit, and deletes partial coverage' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -FailCollector

        $result = Invoke-TestPs1Harness $harness -Coverage
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $junitPath = Join-Path (Join-Path $harness.BaseResultsPath 'container-tests') 'last.xml'

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'collector failed boom'
        $summary.coverage.status | Should -Be 'aborted'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.failure.stage | Should -Be 'test-container-tests'
        Test-Path -LiteralPath $junitPath -PathType Leaf | Should -BeTrue
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'reports coverage failed when collection (raw publication) fails after the container run completes' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -FailRawPublication

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Not -Be 0
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.status | Should -Be 'failed'
        $summary.coverage.complete | Should -BeFalse
        $summary.coverage.failure.stage | Should -Be 'coverage-collection'
        $summary.error.stage | Should -Be 'coverage-collection'
        $summary.error.message | Should -Match 'raw publication failed boom'
        $junitPath = Join-Path (Join-Path $harness.BaseResultsPath 'container-tests') 'last.xml'
        Test-Path -LiteralPath $junitPath -PathType Leaf | Should -BeTrue
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'reports coverage complete for a fully green run and removes the raw collection' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests')

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Be 0
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.status | Should -Be 'complete'
        $summary.coverage.complete | Should -BeTrue
        $summary.coverage.enabled | Should -BeTrue
        $summary.coverage.trackingMode | Should -Be 'PerTest'
        $summary.coverage.lineRate | Should -Be 0.5
        $summary.coverage.linesValid | Should -Be 2
        $summary.coverage.linesCovered | Should -Be 1
        Test-Path -LiteralPath $harness.PerTestPath | Should -BeTrue
        Test-Path -LiteralPath $harness.CoberturaPath | Should -BeTrue

        # On success the raw per-test payloads and staging work are gone —
        # the final coverage directory keeps only the two published reports.
        Test-Path -LiteralPath $harness.RawPath | Should -BeFalse
        (Get-ChildItem -LiteralPath (Split-Path $harness.PerTestPath -Parent) -Name) |
            Sort-Object | Should -Be @('cobertura.xml', 'per-test.jsonl')
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'does not resurrect a stale complete coverage state from a previous run' {
        # Seed a previous run's final coverage artifacts directly in the
        # results tree. Startup cleanup must remove them before this run
        # begins, so a run whose own aggregation fails cannot inherit a
        # stale 'complete' verdict from a prior run's leftovers.
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -ThrowNormalizer
        $coverageDir = Split-Path $harness.PerTestPath -Parent
        New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
        '{"schemaVersion":1,"recordType":"source","sourcePath":"src/Main.al","lineNumber":1}' |
            Set-Content -LiteralPath $harness.PerTestPath
        '<coverage />' | Set-Content -LiteralPath $harness.CoberturaPath

        $result = Invoke-TestPs1Harness $harness -Coverage

        $result.ExitCode | Should -Not -Be 0
        Test-Path -LiteralPath $harness.PerTestPath | Should -BeFalse
        Test-Path -LiteralPath $harness.CoberturaPath | Should -BeFalse
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.coverage.status | Should -Be 'failed'
        $summary.coverage.complete | Should -BeFalse
        Assert-CoverageSummaryArtifactConsistency -Harness $harness -Summary $summary
    }

    It 'leaves totals and per-runner run records unchanged in shape for a disabled run' {
        $harness = New-TestPs1Harness -TestAppNames @('container-tests') -UnitTestAppName 'unit-tests'

        $result = Invoke-TestPs1Harness $harness

        $result.ExitCode | Should -Be 0
        $summary = Get-Content -LiteralPath $harness.SummaryPath -Raw | ConvertFrom-Json
        $summary.gate | Should -Be 'full'
        $summary.totals.container.tests | Should -Be 1
        $summary.totals.container.testsPassed | Should -Be 1
        ($summary.runs | Where-Object { $_.runner -eq 'container' }).appName | Should -Be 'container-tests'
        ($summary.runs | Where-Object { $_.runner -eq 'al-runner' }).appName | Should -Be 'unit-tests'
    }
}
