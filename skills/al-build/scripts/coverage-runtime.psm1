#requires -Version 7.2

Set-StrictMode -Version Latest

$script:TestRunnerPageId = 130455
$script:CoverageExporterId = 74075

function Get-BcCoveragePageContract {
    [pscustomobject]@{
        SuiteControl       = 'CurrentSuiteName'
        SuiteName          = 'DEFAULT'
        TrackingControl    = 'CCTrackingType'
        AllSessionsControl = 'CCTrackAllSessions'
        ExporterControl    = 'CCExporterID'
        MapControl         = 'CCMap'
        PayloadControl     = 'CCResultsCSVText'
        InfoControl        = 'CCInfo'
        ClearAction        = 'ClearCodeCoverage'
        DrainAction        = 'GetCodeCoverage'
        DisabledValue      = 0
        PerTestValue       = 3
        MapDisabledValue   = 0
        DoneValue          = 'Done.'
    }
}

function Get-CoverageHelperContract {
    [CmdletBinding()]
    param(
        [string]$AppJsonPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'code-coverage-helper' 'app.json')
    )

    if (-not (Test-Path -LiteralPath $AppJsonPath -PathType Leaf)) {
        throw "Coverage helper contract not found at '$AppJsonPath'. Rebuild the golden image after bundling the coverage helper."
    }

    try {
        $appJson = Get-Content -LiteralPath $AppJsonPath -Raw | ConvertFrom-Json
    } catch {
        throw "Coverage helper app.json is invalid at '$AppJsonPath': $($_.Exception.Message)"
    }

    $idProperty = $appJson.PSObject.Properties['id']
    $versionProperty = $appJson.PSObject.Properties['version']
    $nameProperty = $appJson.PSObject.Properties['name']
    if (-not $idProperty -or -not $idProperty.Value -or
        -not $versionProperty -or -not $versionProperty.Value -or
        -not $nameProperty -or -not $nameProperty.Value) {
        throw "Coverage helper app.json must declare id and version: '$AppJsonPath'."
    }

    [pscustomobject]@{
        AppId              = [guid]$idProperty.Value
        AppVersion         = [version]$versionProperty.Value
        AppName            = [string]$nameProperty.Value
        ExporterId         = $script:CoverageExporterId
        AppJsonPath        = $AppJsonPath
    }
}

function Get-BcSharedTestBasePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName
    )

    $sharedFolders = Get-BcContainerSharedFolders -containerName $ContainerName
    $sharedBaseFolder = $sharedFolders.Keys |
        Where-Object { $_ -like "*$ContainerName*" } |
        Select-Object -First 1
    if (-not $sharedBaseFolder) {
        $sharedBaseFolder = $sharedFolders.Keys |
            Where-Object { $_ -like '*ProgramData*' } |
            Select-Object -First 1
    }
    if (-not $sharedBaseFolder) {
        $sharedBaseFolder = $sharedFolders.Keys | Select-Object -First 1
    }
    if (-not $sharedBaseFolder) {
        throw "No shared folders found for container '$ContainerName'."
    }

    $sharedResultsPath = Join-Path $sharedBaseFolder 'TestResults'
    New-Item -ItemType Directory -Path $sharedResultsPath -Force | Out-Null
    $sharedResultsPath
}

function New-BcSharedTestRunDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName
    )

    $basePath = Get-BcSharedTestBasePath -ContainerName $ContainerName
    $runPath = Join-Path $basePath "run-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $runPath -Force | Out-Null
    $runPath
}

function Invoke-BcTestRunnerPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Probe', 'Disable', 'Enable', 'Drain')]
        [string]$Operation,

        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$Tenant,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [string]$SharedRunPath,

        [int]$ExporterId
    )

    Import-BCContainerHelper

    $bcModule = Get-Module -Name BcContainerHelper
    if (-not $bcModule) {
        throw 'BcContainerHelper is not loaded.'
    }

    $appHandlingPath = Join-Path $bcModule.ModuleBase 'AppHandling'
    $psTestFunctionsSource = Join-Path $appHandlingPath 'PsTestFunctions.ps1'
    $clientContextSource = Join-Path $appHandlingPath 'ClientContext.ps1'
    $psTestFunctionsPath = Join-Path $SharedRunPath 'PsTestFunctions.ps1'
    $clientContextPath = Join-Path $SharedRunPath 'ClientContext.ps1'

    Copy-Item -LiteralPath $psTestFunctionsSource -Destination $psTestFunctionsPath -Force
    Copy-Item -LiteralPath $clientContextSource -Destination $clientContextPath -Force

    $containerPsTestFunctionsPath = Get-BcContainerPath -containerName $ContainerName -path $psTestFunctionsPath
    $containerClientContextPath = Get-BcContainerPath -containerName $ContainerName -path $clientContextPath
    if (-not $containerPsTestFunctionsPath -or -not $containerClientContextPath) {
        throw "Coverage runtime path '$SharedRunPath' is not shared with container '$ContainerName'."
    }

    $pageContract = Get-BcCoveragePageContract
    Invoke-ScriptInBcContainer -containerName $ContainerName -scriptBlock {
        param(
            [string]$Operation,
            [string]$Tenant,
            [pscredential]$Credential,
            [string]$PsTestFunctionsPath,
            [string]$ClientContextPath,
            [int]$ExporterId,
            [int]$TestRunnerPageId,
            $PageContract
        )

        $newtonSoftDllPath = 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Management\Newtonsoft.Json.dll'
        if (-not (Test-Path -Path $newtonSoftDllPath)) {
            $newtonSoftDllPath = 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Newtonsoft.Json.dll'
        }
        $newtonSoftDllPath = (Get-Item -Path $newtonSoftDllPath).FullName
        $clientDllPath = 'C:\Test Assemblies\Microsoft.Dynamics.Framework.UI.Client.dll'
        $customConfigFile = Join-Path (Get-Item -Path 'C:\Program Files\Microsoft Dynamics NAV\*\Service').FullName 'CustomSettings.config'
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $publicWebBaseUrl = $customConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value.TrimEnd('/')
        $credentialType = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value
        $uri = [uri]::new($publicWebBaseUrl)
        $serviceUrl = "$($uri.Scheme)://localhost:$($uri.Port)$($uri.PathAndQuery)/cs?tenant=$Tenant"

        . $PsTestFunctionsPath -newtonSoftDllPath $newtonSoftDllPath -clientDllPath $clientDllPath -clientContextScriptPath $ClientContextPath

        function Get-RequiredControl {
            param($Context, $Form, [string]$Name)
            $control = $Context.GetControlByName($Form, $Name)
            if ($null -eq $control) {
                throw "Test Runner page is missing control '$Name'."
            }
            $control
        }

        function Get-RequiredAction {
            param($Context, $Form, [string]$Name)
            $action = $Context.GetActionByName($Form, $Name)
            if ($null -eq $action) {
                throw "Test Runner page is missing action '$Name'."
            }
            $action
        }

        $clientContext = $null
        $form = $null
        try {
            Disable-SslVerification
            $clientContext = New-ClientContext -serviceUrl $serviceUrl -auth $credentialType -credential $Credential
            $form = $clientContext.OpenForm($TestRunnerPageId)
            if (-not $form) {
                throw "Cannot open Test Runner page $TestRunnerPageId."
            }

            $suite = Get-RequiredControl $clientContext $form $PageContract.SuiteControl
            if ($Operation -ne 'Probe') {
                $clientContext.SaveValue($suite, $PageContract.SuiteName)
            }
            $tracking = Get-RequiredControl $clientContext $form $PageContract.TrackingControl

            if ($Operation -eq 'Probe') {
                foreach ($controlName in @(
                    $PageContract.AllSessionsControl,
                    $PageContract.ExporterControl,
                    $PageContract.MapControl,
                    $PageContract.PayloadControl,
                    $PageContract.InfoControl
                )) {
                    Get-RequiredControl $clientContext $form $controlName | Out-Null
                }
                Get-RequiredAction $clientContext $form $PageContract.ClearAction | Out-Null
                Get-RequiredAction $clientContext $form $PageContract.DrainAction | Out-Null
                return [pscustomobject]@{ Compatible = $true }
            }

            if ($Operation -eq 'Disable') {
                $clientContext.SaveValue($tracking, $PageContract.DisabledValue)
                return [pscustomobject]@{ Tracking = 'Disabled' }
            }

            if ($Operation -eq 'Enable') {
                $clientContext.SaveValue($tracking, $PageContract.PerTestValue)
                $clientContext.SaveValue(
                    (Get-RequiredControl $clientContext $form $PageContract.AllSessionsControl),
                    $false
                )
                $clientContext.SaveValue(
                    (Get-RequiredControl $clientContext $form $PageContract.ExporterControl),
                    $ExporterId
                )
                $clientContext.SaveValue(
                    (Get-RequiredControl $clientContext $form $PageContract.MapControl),
                    $PageContract.MapDisabledValue
                )
                $clientContext.InvokeAction(
                    (Get-RequiredAction $clientContext $form $PageContract.ClearAction)
                )
                return [pscustomobject]@{ Tracking = 'PerTest' }
            }

            $clientContext.InvokeAction(
                (Get-RequiredAction $clientContext $form $PageContract.DrainAction)
            )
            $info = (Get-RequiredControl $clientContext $form $PageContract.InfoControl).StringValue
            $payload = (Get-RequiredControl $clientContext $form $PageContract.PayloadControl).StringValue
            [pscustomobject]@{
                Info    = [string]$info
                Payload = [string]$payload
            }
        } finally {
            if ($form -and $clientContext) {
                $clientContext.CloseForm($form)
            }
            if ($clientContext) {
                $clientContext.Dispose()
            }
        }
    } -argumentList @(
        $Operation,
        $Tenant,
        $Credential,
        $containerPsTestFunctionsPath,
        $containerClientContextPath,
        $ExporterId,
        $script:TestRunnerPageId,
        $pageContract
    )
}

function Test-BcCoveragePreflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$Tenant,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        $Contract
    )

    Import-BCContainerHelper
    $runPath = $null
    try {
        $installed = @(
            Get-BcContainerAppInfo -containerName $ContainerName -tenant $Tenant -installedOnly |
                Where-Object {
                    $installedId = if ($_.PSObject.Properties['AppId']) {
                        $_.AppId
                    } elseif ($_.PSObject.Properties['Id']) {
                        $_.Id
                    }
                    $installedId -and ([guid]$installedId -eq [guid]$Contract.AppId)
                }
        )

        $exact = @(
            $installed |
                Where-Object { [version]$_.Version -eq [version]$Contract.AppVersion }
        )
        if ($exact.Count -ne 1) {
            $foundVersions = @($installed | ForEach-Object { $_.Version.ToString() }) -join ', '
            if (-not $foundVersions) { $foundVersions = 'not installed' }
            throw "Coverage helper $($Contract.AppId) must be installed at version $($Contract.AppVersion); found $foundVersions."
        }

        $runPath = New-BcSharedTestRunDirectory -ContainerName $ContainerName
        Invoke-BcTestRunnerPage -Operation Probe -ContainerName $ContainerName -Tenant $Tenant `
            -Credential $Credential -SharedRunPath $runPath | Out-Null
    } catch {
        throw "Coverage preflight failed before app mutation: $($_.Exception.Message) Rebuild the golden image and retry."
    } finally {
        if ($runPath -and (Test-Path -LiteralPath $runPath)) {
            Remove-Item -LiteralPath $runPath -Recurse -Force -Confirm:$false
        }
    }
}

function Set-BcTestRunnerCoverageState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$Tenant,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [string]$SharedRunPath,

        [switch]$Enabled,

        [int]$ExporterId
    )

    if ($Enabled) {
        if ($ExporterId -le 0) {
            throw 'Coverage exporter ID is required when coverage is enabled.'
        }
        Invoke-BcTestRunnerPage -Operation Enable -ContainerName $ContainerName -Tenant $Tenant `
            -Credential $Credential -SharedRunPath $SharedRunPath `
            -ExporterId $ExporterId | Out-Null
        return
    }

    Invoke-BcTestRunnerPage -Operation Disable -ContainerName $ContainerName -Tenant $Tenant `
        -Credential $Credential -SharedRunPath $SharedRunPath | Out-Null
}

function Get-JUnitResultEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        [xml]$document = Get-Content -LiteralPath $Path -Raw
    } catch {
        return $null
    }

    $root = $document.DocumentElement
    if (-not $root -or $root.LocalName -ne 'testsuites') {
        return $null
    }

    $suites = @($root.ChildNodes | Where-Object { $_.LocalName -eq 'testsuite' })
    if ($suites.Count -eq 0) {
        return $null
    }

    $declaredTests = 0
    $testCases = [System.Collections.Generic.List[object]]::new()
    foreach ($suite in $suites) {
        $suiteTests = 0
        if (-not [int]::TryParse($suite.GetAttribute('tests'), [ref]$suiteTests) -or
            $suiteTests -lt 0) {
            return $null
        }
        $declaredTests += $suiteTests
        foreach ($testCase in @($suite.ChildNodes | Where-Object { $_.LocalName -eq 'testcase' })) {
            if ([string]::IsNullOrWhiteSpace($testCase.GetAttribute('name'))) {
                return $null
            }
            $testCases.Add($testCase)
        }
    }

    if ($declaredTests -le 0 -or $testCases.Count -ne $declaredTests) {
        return $null
    }

    [pscustomobject]@{
        DeclaredTests = $declaredTests
        TestCaseCount = $testCases.Count
    }
}

function Test-JUnitResultComplete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $null -ne (Get-JUnitResultEvidence -Path $Path)
}

function Test-BcCoveragePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        [xml]$document = Get-Content -LiteralPath $Path -Raw
    } catch {
        throw "Coverage payload '$Path' is not valid XML: $($_.Exception.Message)"
    }

    $root = $document.DocumentElement
    if (-not $root) {
        throw "Coverage payload '$Path' has no XML root element."
    }
    if ($root.LocalName -ne 'CodeCoverage') {
        throw "Coverage payload '$Path' has unexpected root '$($root.LocalName)'."
    }
    if (-not $root.HasAttribute('SchemaVersion') -or $root.GetAttribute('SchemaVersion') -ne '1') {
        throw "Coverage payload '$Path' does not declare supported SchemaVersion 1."
    }

    $records = @($root.ChildNodes | Where-Object { $_.LocalName -eq 'CoverageLine' })
    if ($records.Count -eq 0) {
        throw "Coverage payload '$Path' contains no coverage records."
    }
    $requiredFields = @(
        'ObjectTypeCode',
        'ObjectTypeName',
        'ObjectId',
        'LineNumber',
        'LineTypeCode',
        'LineTypeName',
        'CoverageStatusCode',
        'CoverageStatusName',
        'HitCount',
        'SourceLine'
    )
    $numericFields = @(
        'ObjectTypeCode',
        'ObjectId',
        'LineNumber',
        'LineTypeCode',
        'CoverageStatusCode',
        'HitCount'
    )
    foreach ($record in $records) {
        foreach ($fieldName in $requiredFields) {
            if (-not ($record.ChildNodes | Where-Object { $_.LocalName -eq $fieldName })) {
                throw "Coverage payload '$Path' record is missing '$fieldName'."
            }
        }
        foreach ($fieldName in $numericFields) {
            $value = 0
            $field = @($record.ChildNodes | Where-Object { $_.LocalName -eq $fieldName })[0]
            if (-not [int]::TryParse([string]$field.InnerText, [ref]$value)) {
                throw "Coverage payload '$Path' record field '$fieldName' is not an integer."
            }
        }
    }
}

function Receive-BcTestCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$Tenant,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [string]$SharedRunPath,

        [Parameter(Mandatory)]
        [string]$TestAppName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483647)]
        [int]$JUnitTestCount,

        [ValidateRange(1, 2147483647)]
        [int]$MaxDrainResponses = 10000,

        [timespan]$DrainTimeout = ([timespan]::FromMinutes(10))
    )

    if ($DrainTimeout -le [timespan]::Zero) {
        throw 'Coverage drain timeout must be greater than zero.'
    }

    $collectionPath = Join-Path $SharedRunPath 'coverage'
    New-Item -ItemType Directory -Path $collectionPath -Force | Out-Null

    $payloads = [System.Collections.Generic.List[object]]::new()
    $doneCount = 0
    $order = 0
    $doneValue = (Get-BcCoveragePageContract).DoneValue
    $responseCount = 0
    $stopwatch = [diagnostics.stopwatch]::StartNew()

    while ($doneCount -lt 2) {
        if ($responseCount -ge $MaxDrainResponses -or $stopwatch.Elapsed -ge $DrainTimeout) {
            throw "Coverage drain for '$TestAppName' did not reach two consecutive '$doneValue' responses within $MaxDrainResponses responses or $($DrainTimeout.TotalSeconds) seconds; received $responseCount responses and $order payloads."
        }

        $response = Invoke-BcTestRunnerPage -Operation Drain -ContainerName $ContainerName `
            -Tenant $Tenant -Credential $Credential -SharedRunPath $SharedRunPath
        $responseCount++
        $info = [string]$response.Info

        if ($info -eq $doneValue) {
            $doneCount++
            continue
        }

        $doneCount = 0
        $identity = [regex]::Match($info, '^\s*(?<id>\d+)\s*,\s*(?<method>.+?)\s*$')
        if (-not $identity.Success) {
            throw "Coverage drain for '$TestAppName' returned unexpected response '$info'; expected '<test codeunit ID>,<test method>' or exact sentinel '$doneValue'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$response.Payload)) {
            throw "Coverage payload for '$info' is empty."
        }

        $order++
        $fileName = 'payload-{0:d4}.xml' -f $order
        $payloadPath = Join-Path $collectionPath $fileName
        Set-Content -LiteralPath $payloadPath -Value ([string]$response.Payload) -Encoding unicode
        Test-BcCoveragePayload -Path $payloadPath

        $payloads.Add([ordered]@{
            order          = $order
            testCodeunitId = [int]$identity.Groups['id'].Value
            testMethod     = $identity.Groups['method'].Value
            file           = $fileName
        })
    }

    $manifestPath = Join-Path $collectionPath 'manifest.json'
    [ordered]@{
        schemaVersion      = 1
        testApp            = $TestAppName
        junitTestCount     = $JUnitTestCount
        payloadCount       = $payloads.Count
        drainResponseCount = $responseCount
        terminalDoneCount  = $doneCount
        doneValue          = $doneValue
        payloads           = @($payloads)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8

    Test-BcCoverageCollection -Path $collectionPath -ExpectedTestApp $TestAppName | Out-Null
    $collectionPath
}

function Test-BcCoverageCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ExpectedTestApp
    )

    $manifestPath = Join-Path $Path 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Coverage collection '$Path' has no manifest.json."
    }

    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    } catch {
        throw "Coverage manifest '$manifestPath' is invalid: $($_.Exception.Message)"
    }

    foreach ($fieldName in @(
        'schemaVersion',
        'testApp',
        'junitTestCount',
        'payloadCount',
        'drainResponseCount',
        'terminalDoneCount',
        'doneValue',
        'payloads'
    )) {
        if (-not $manifest.PSObject.Properties[$fieldName]) {
            throw "Coverage manifest '$manifestPath' is missing required field '$fieldName'."
        }
    }
    if ($manifest.schemaVersion -ne 1 -or $manifest.testApp -ne $ExpectedTestApp) {
        throw "Coverage manifest '$manifestPath' has the wrong schema or test app."
    }

    $payloads = @($manifest.payloads)
    if ([int]$manifest.payloadCount -ne $payloads.Count) {
        throw "Coverage manifest '$manifestPath' payload count does not match its entries."
    }
    if ($payloads.Count -le 0) {
        throw "Coverage collection '$Path' contains zero payloads for executed test app '$ExpectedTestApp'."
    }
    if ([int]$manifest.terminalDoneCount -ne 2 -or [string]$manifest.doneValue -ne 'Done.') {
        throw "Coverage manifest '$manifestPath' does not prove two consecutive 'Done.' responses."
    }
    if ([int]$manifest.drainResponseCount -lt ($payloads.Count + 2)) {
        throw "Coverage manifest '$manifestPath' has an invalid drain response count."
    }

    $junitTestCount = 0
    if (-not $manifest.PSObject.Properties['junitTestCount'] -or
        -not [int]::TryParse([string]$manifest.junitTestCount, [ref]$junitTestCount) -or
        $junitTestCount -le 0) {
        throw "Coverage manifest '$manifestPath' has no positive JUnit test count."
    }
    if ($payloads.Count -gt $junitTestCount) {
        throw "Coverage collection '$Path' has $($payloads.Count) payloads for only $junitTestCount declared JUnit tests."
    }

    for ($index = 0; $index -lt $payloads.Count; $index++) {
        $entry = $payloads[$index]
        $expectedOrder = $index + 1
        $expectedFile = 'payload-{0:d4}.xml' -f $expectedOrder
        foreach ($fieldName in @('order', 'testCodeunitId', 'testMethod', 'file')) {
            if (-not $entry.PSObject.Properties[$fieldName]) {
                throw "Coverage manifest '$manifestPath' entry $expectedOrder is missing required field '$fieldName'."
            }
        }
        if ([int]$entry.order -ne $expectedOrder -or $entry.file -ne $expectedFile) {
            throw "Coverage manifest '$manifestPath' is not sequential at entry $expectedOrder."
        }
        if ([int]$entry.testCodeunitId -le 0 -or [string]::IsNullOrWhiteSpace([string]$entry.testMethod)) {
            throw "Coverage manifest '$manifestPath' has an incomplete test identity at entry $expectedOrder."
        }

        $payloadPath = Join-Path $Path $entry.file
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw "Coverage payload '$payloadPath' is missing."
        }
        Test-BcCoveragePayload -Path $payloadPath
    }

    $xmlFiles = @(Get-ChildItem -LiteralPath $Path -Filter 'payload-*.xml' -File)
    if ($xmlFiles.Count -ne $payloads.Count) {
        throw "Coverage collection '$Path' contains unexpected payload files."
    }

    $true
}

function Invoke-BcTestRunWithCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$RunTests,

        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$Tenant,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [string]$SharedRunPath,

        [Parameter(Mandatory)]
        [string]$JUnitPath,

        [Parameter(Mandatory)]
        [string]$TestAppName,

        [switch]$Coverage,

        [int]$ExporterId
    )

    Set-BcTestRunnerCoverageState -ContainerName $ContainerName -Tenant $Tenant `
        -Credential $Credential -SharedRunPath $SharedRunPath -Enabled:$Coverage `
        -ExporterId $ExporterId

    $testsPassed = & $RunTests

    $coveragePath = $null
    if ($Coverage) {
        $junitEvidence = Get-JUnitResultEvidence -Path $JUnitPath
        if (-not $junitEvidence) {
            throw "Coverage collection aborted because JUnit result '$JUnitPath' is missing or incomplete."
        }
        $coveragePath = Receive-BcTestCoverage -ContainerName $ContainerName -Tenant $Tenant `
            -Credential $Credential -SharedRunPath $SharedRunPath -TestAppName $TestAppName `
            -JUnitTestCount $junitEvidence.DeclaredTests
    }

    [pscustomobject]@{
        TestsPassed = [bool]$testsPassed
        CoveragePath = $coveragePath
    }
}

function New-CoverageGateStaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseResultsPath
    )

    $coverageRoot = Join-Path $BaseResultsPath 'coverage'
    New-Item -ItemType Directory -Path $coverageRoot -Force | Out-Null
    $stagePath = Join-Path $coverageRoot "raw-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
    $stagePath
}

function Publish-CoverageGateStaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StagePath,

        [Parameter(Mandatory)]
        [string]$BaseResultsPath,

        [Parameter(Mandatory)]
        [string[]]$ExpectedTestApps
    )

    $actualApps = @(
        Get-ChildItem -LiteralPath $StagePath -Directory |
            ForEach-Object { $_.Name } |
            Sort-Object
    )
    $expectedApps = @($ExpectedTestApps | Sort-Object)
    if (($actualApps -join "`n") -ne ($expectedApps -join "`n")) {
        throw "Coverage staging is incomplete. Expected [$($expectedApps -join ', ')], found [$($actualApps -join ', ')]."
    }

    foreach ($appName in $expectedApps) {
        Test-BcCoverageCollection -Path (Join-Path $StagePath $appName) `
            -ExpectedTestApp $appName | Out-Null
    }

    $coverageRoot = Join-Path $BaseResultsPath 'coverage'
    $destination = Join-Path $coverageRoot 'raw'
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force -Confirm:$false
    }
    Move-Item -LiteralPath $StagePath -Destination $destination
    $destination
}

function Remove-CoverageGateStaging {
    [CmdletBinding()]
    param(
        [string]$StagePath,

        [Parameter(Mandatory)]
        [string]$BaseResultsPath,

        [switch]$RemovePublished
    )

    if ($StagePath -and (Test-Path -LiteralPath $StagePath)) {
        Remove-Item -LiteralPath $StagePath -Recurse -Force -Confirm:$false
    }
    if ($RemovePublished) {
        $publishedPath = Join-Path $BaseResultsPath 'coverage' 'raw'
        if (Test-Path -LiteralPath $publishedPath) {
            Remove-Item -LiteralPath $publishedPath -Recurse -Force -Confirm:$false
        }
    }
}

Export-ModuleMember -Function @(
    'Get-BcCoveragePageContract'
    'Get-CoverageHelperContract'
    'Get-BcSharedTestBasePath'
    'New-BcSharedTestRunDirectory'
    'Invoke-BcTestRunnerPage'
    'Test-BcCoveragePreflight'
    'Set-BcTestRunnerCoverageState'
    'Get-JUnitResultEvidence'
    'Test-JUnitResultComplete'
    'Test-BcCoveragePayload'
    'Receive-BcTestCoverage'
    'Test-BcCoverageCollection'
    'Invoke-BcTestRunWithCoverage'
    'New-CoverageGateStaging'
    'Publish-CoverageGateStaging'
    'Remove-CoverageGateStaging'
)
