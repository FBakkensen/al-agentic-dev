#Requires -Version 7.2

Set-StrictMode -Version Latest

$script:CoverageExporterId = 74075
$script:GoldenImageRecovery = 'Rebuild the golden image: ' + (@(
    'run new-bc-container.ps1'
    'restart the machine'
    'run commit-bc-container.ps1'
    'recreate the branch container with new-agent-container.ps1'
) -join ', ')

function Get-CoveragePreflightPageContract {
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

function Get-CoveragePreflightHelperContract {
    [CmdletBinding()]
    param(
        [string]$AppJsonPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'code-coverage-helper' 'app.json')
    )

    if (-not (Test-Path -LiteralPath $AppJsonPath -PathType Leaf)) {
        throw "Coverage helper contract not found at '$AppJsonPath'."
    }

    try {
        $appJson = Get-Content -LiteralPath $AppJsonPath -Raw | ConvertFrom-Json
    } catch {
        throw "Coverage helper app.json is invalid at '$AppJsonPath': $($_.Exception.Message)"
    }

    $required = @('id', 'name', 'version')
    $missing = @($required | Where-Object {
        -not $appJson.PSObject.Properties[$_] -or
        [string]::IsNullOrWhiteSpace([string]$appJson.$_)
    })
    if ($missing.Count -gt 0) {
        throw "Coverage helper app.json must declare id and version: '$AppJsonPath'. Missing: $($missing -join ', ')."
    }

    try {
        $appId = [guid]$appJson.id
        $appVersion = [version]$appJson.version
    } catch {
        throw "Coverage helper app.json has an invalid id or version at '$AppJsonPath': $($_.Exception.Message)"
    }
    $publisher = if ($appJson.PSObject.Properties['publisher']) {
        [string]$appJson.publisher
    } else {
        ''
    }

    [pscustomobject]@{
        AppId        = $appId
        AppVersion   = $appVersion
        AppName      = [string]$appJson.name
        AppPublisher = $publisher
        ExporterId   = $script:CoverageExporterId
        AppJsonPath  = $AppJsonPath
    }
}

function Assert-CoveragePreflightHelperIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Contract,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$InstalledApps
    )

    $matchingApps = @($InstalledApps | Where-Object {
        $installedId = if ($_.PSObject.Properties['AppId']) {
            $_.AppId
        } elseif ($_.PSObject.Properties['Id']) {
            $_.Id
        }

        $parsedId = [guid]::Empty
        $installedId -and [guid]::TryParse([string]$installedId, [ref]$parsedId) -and
            $parsedId -eq [guid]$Contract.AppId
    })

    if ($matchingApps.Count -eq 0) {
        throw "Coverage helper '$($Contract.AppName)' ($($Contract.AppId)) version $($Contract.AppVersion) is not installed."
    }
    if ($matchingApps.Count -gt 1) {
        $versions = @($matchingApps | ForEach-Object {
            if ($_.PSObject.Properties['Version']) { [string]$_.Version } else { '<missing>' }
        }) -join ', '
        throw "Coverage helper $($Contract.AppId) is installed $($matchingApps.Count) times; expected exactly one app at version $($Contract.AppVersion). Found versions: $versions."
    }

    $versionText = if ($matchingApps[0].PSObject.Properties['Version']) {
        [string]$matchingApps[0].Version
    } else {
        '<missing>'
    }
    $installedVersion = $null
    if (-not [version]::TryParse($versionText, [ref]$installedVersion) -or
        $installedVersion -ne [version]$Contract.AppVersion) {
        throw "Coverage helper $($Contract.AppId) version mismatch. Expected $($Contract.AppVersion), installed $versionText."
    }

    $matchingApps[0]
}

function Invoke-CoveragePreflightChecks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Contract,

        [Parameter(Mandatory)]
        [scriptblock]$GetInstalledApps,

        [Parameter(Mandatory)]
        [scriptblock]$ProbeTestRunner
    )

    try {
        $installedApps = @(& $GetInstalledApps)
        Assert-CoveragePreflightHelperIdentity -Contract $Contract -InstalledApps $installedApps | Out-Null
        & $ProbeTestRunner | Out-Null
    } catch {
        throw "Coverage preflight failed before consumer app publication or test execution: $($_.Exception.Message) Recovery: $script:GoldenImageRecovery. No automatic repair was attempted."
    }
}

Export-ModuleMember -Function @(
    'Get-CoveragePreflightPageContract'
    'Get-CoveragePreflightHelperContract'
    'Assert-CoveragePreflightHelperIdentity'
    'Invoke-CoveragePreflightChecks'
)
