#Requires -Version 7.2

Set-StrictMode -Version Latest

$script:BusinessCentralMcpPackage = 'business-central-mcp'

function Get-BusinessCentralMcpSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config,

        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [string]$UserHome
    )

    $authMode = ([string]$Config.ContainerAuth).Trim()
    if ($authMode -notin @('UserPassword', 'NavUserPassword')) {
        throw "Unsupported Business Central container authentication mode '$authMode'. Expected UserPassword or NavUserPassword."
    }

    $serverUrl = ([string]$Config.ServerUrl).Trim().TrimEnd([char[]]@('/', '\'))
    $serverInstance = ([string]$Config.ServerInstance).Trim().Trim([char[]]@('/', '\'))
    if (-not $serverUrl) {
        throw 'Business Central ServerUrl is empty.'
    }
    if (-not $serverInstance) {
        throw 'Business Central ServerInstance is empty.'
    }

    $username = [string]$Config.ContainerUsername
    $password = [string]$Config.ContainerPassword
    if (-not $username) {
        throw 'Business Central container username is empty.'
    }
    if (-not $password) {
        throw 'Business Central container password is empty.'
    }

    $containerName = ([string]$Config.ContainerName).Trim()
    if (-not $containerName -or $containerName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw 'Business Central container name is not a safe path segment.'
    }

    if (-not $UserHome) {
        $UserHome = $env:USERPROFILE
    }
    if (-not $UserHome) {
        $UserHome = $env:HOME
    }
    if (-not $UserHome) {
        throw 'The per-user home directory could not be resolved.'
    }

    $resolvedRepoRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $repoBytes = [Text.Encoding]::UTF8.GetBytes($resolvedRepoRoot.ToUpperInvariant())
    $repoHash = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($repoBytes)
    ).Substring(0, 16).ToLowerInvariant()

    $copilotRoot = Join-Path $UserHome '.copilot'
    $mcpRoot = Join-Path $copilotRoot 'business-central-mcp'
    $repoStorageRoot = Join-Path $mcpRoot $repoHash
    $storageRoot = Join-Path $repoStorageRoot $containerName

    return [pscustomobject]@{
        BaseUrl       = "$serverUrl/$serverInstance"
        Username      = $username
        Password      = $password
        Tenant        = [string]$Config.Tenant
        Auth           = 'NavUserPassword'
        ApplicationId = 'NAV'
        LogDir         = Join-Path $storageRoot 'logs'
        StateDir       = Join-Path $storageRoot 'state'
        ContainerName  = $containerName
        Package        = $script:BusinessCentralMcpPackage
    }
}

function Set-BusinessCentralMcpEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Settings
    )

    foreach ($path in @($Settings.LogDir, $Settings.StateDir)) {
        $null = New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop
    }

    $environment = @{
        BC_BASE_URL       = $Settings.BaseUrl
        BC_USERNAME       = $Settings.Username
        BC_PASSWORD       = $Settings.Password
        BC_TENANT_ID      = $Settings.Tenant
        BC_AUTH           = $Settings.Auth
        BC_APPLICATION_ID = $Settings.ApplicationId
        LOG_DIR           = $Settings.LogDir
        STATE_DIR         = $Settings.StateDir
    }
    foreach ($entry in $environment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, [string]$entry.Value, 'Process')
    }
}

Export-ModuleMember -Function @(
    'Get-BusinessCentralMcpSettings'
    'Set-BusinessCentralMcpEnvironment'
)
