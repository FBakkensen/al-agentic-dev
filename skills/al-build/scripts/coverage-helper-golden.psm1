#Requires -Version 7.2

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CodeCoverageHelperManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectFolder
    )

    $manifestPath = Join-Path $ProjectFolder 'app.json'
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "Code coverage helper manifest not found: $manifestPath"
    }

    $manifestJson = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
    if (-not $manifestJson.id -or -not $manifestJson.name -or
        -not $manifestJson.publisher -or -not $manifestJson.version) {
        throw "Code coverage helper manifest must define id, name, publisher, and version: $manifestPath"
    }

    try {
        $appId = [guid]$manifestJson.id
        $version = [version]$manifestJson.version
    } catch {
        throw "Code coverage helper manifest has an invalid id or version: $manifestPath"
    }

    [PSCustomObject]@{
        Id        = $appId
        Name      = [string]$manifestJson.name
        Publisher = [string]$manifestJson.publisher
        Version   = $version
    }
}

function Assert-CodeCoverageHelperIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Manifest,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$InstalledApps
    )

    $matchingApps = @($InstalledApps | Where-Object {
        $_.AppId -and ([guid]$_.AppId -eq $Manifest.Id)
    })
    if ($matchingApps.Count -ne 1) {
        throw "Code coverage helper $($Manifest.Id) is not installed exactly once."
    }

    $installedVersion = [version]$matchingApps[0].Version
    if ($installedVersion -ne $Manifest.Version) {
        throw "Code coverage helper $($Manifest.Id) version mismatch. Expected $($Manifest.Version), installed $installedVersion."
    }

    $matchingApps[0]
}

function Install-CodeCoverageHelperInBcContainer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [PSCredential]$Credential,

        [Parameter(Mandatory)]
        [string]$ProjectFolder,

        [string]$Tenant = 'default'
    )

    $manifest = Get-CodeCoverageHelperManifest -ProjectFolder $ProjectFolder
    $sharedFolders = Get-BcContainerSharedFolders -containerName $ContainerName
    $sharedRoot = @($sharedFolders.Keys | Where-Object {
        [string]::Equals(
            [string]$_,
            [string]$sharedFolders[$_],
            [System.StringComparison]::OrdinalIgnoreCase
        )
    } | Sort-Object Length | Select-Object -First 1)
    if ($sharedRoot.Count -ne 1) {
        throw "No identity-mapped shared folder was found for container '$ContainerName'."
    }

    $containerExtensionsRoot = Join-Path $sharedRoot[0] 'Extensions'
    $buildRoot = Join-Path $containerExtensionsRoot "$ContainerName-al-build-code-coverage-helper"
    $stagedProjectFolder = Join-Path $buildRoot 'project'
    $outputFolder = Join-Path $buildRoot 'output'
    $symbolsFolder = Join-Path $buildRoot '.alpackages'

    if (Test-Path -Path $buildRoot) {
        Remove-Item -Path $buildRoot -Recurse -Force -Confirm:$false
    }

    try {
        New-Item -Path $stagedProjectFolder -ItemType Directory -Force | Out-Null
        New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
        New-Item -Path $symbolsFolder -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $ProjectFolder '*') -Destination $stagedProjectFolder -Recurse -Force

        $appFile = Compile-AppInBcContainer `
            -containerName $ContainerName `
            -tenant $Tenant `
            -credential $Credential `
            -appProjectFolder $stagedProjectFolder `
            -appOutputFolder $outputFolder `
            -appSymbolsFolder $symbolsFolder `
            -UpdateSymbols

        if (-not $appFile -or -not (Test-Path -Path $appFile -PathType Leaf)) {
            throw 'Code coverage helper compilation did not produce an app package.'
        }

        Publish-BcContainerApp `
            -containerName $ContainerName `
            -appFile $appFile `
            -credential $Credential `
            -skipVerification

        Sync-BcContainerApp `
            -containerName $ContainerName `
            -tenant $Tenant `
            -appName $manifest.Name `
            -appPublisher $manifest.Publisher `
            -appVersion $manifest.Version.ToString()

        Install-BcContainerApp `
            -containerName $ContainerName `
            -tenant $Tenant `
            -appName $manifest.Name `
            -appPublisher $manifest.Publisher `
            -appVersion $manifest.Version.ToString()

        $installedApps = @(Get-BcContainerAppInfo `
            -containerName $ContainerName `
            -tenant $Tenant `
            -installedOnly)
        Assert-CodeCoverageHelperIdentity -Manifest $manifest -InstalledApps $installedApps | Out-Null
        $manifest
    } finally {
        if (Test-Path -Path $buildRoot) {
            Remove-Item -Path $buildRoot -Recurse -Force -Confirm:$false
        }
    }
}

Export-ModuleMember -Function @(
    'Get-CodeCoverageHelperManifest',
    'Assert-CodeCoverageHelperIdentity',
    'Install-CodeCoverageHelperInBcContainer'
)
