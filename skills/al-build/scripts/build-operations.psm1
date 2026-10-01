#requires -Version 7.2

<#
.SYNOPSIS
    AL Build Operations Module

.DESCRIPTION
    Core build operations for AL/Business Central projects including:
    - Compiler installation and management
    - AL project compilation
    - App publishing to BC containers
    - Test execution

.NOTES
    Import this module alongside common.psm1 for full functionality.
    All functions use Write-BuildMessage for consistent output.
#>

Set-StrictMode -Version Latest

# =============================================================================
# Configuration Loading
# =============================================================================

function Get-BuildConfig {
    <#
    .SYNOPSIS
        Load build configuration with three-tier resolution
    .DESCRIPTION
        Priority: 1. Parameter overrides → 2. Environment variables → 3. Config file defaults.
        Coverage uses false when omitted and is disabled without configured testApps.
    .PARAMETER Overrides
        Hashtable of parameter overrides
    .OUTPUTS
        PSCustomObject with all configuration values
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Overrides = @{}
    )

    # Config comes from the consumer repo root; this skill's config/al-build.json is only init.ps1's template
    $repoRoot = Get-GitRepoRoot
    $configPath = Join-Path $repoRoot 'al-build.json'

    $defaults = @{}
    if (Test-Path -LiteralPath $configPath) {
        try {
            $defaults = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
            Write-BuildMessage -Type Detail -Message "Loaded config: $configPath"
        } catch {
            Write-BuildMessage -Type Error -Message "Failed to load al-build.json: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-BuildMessage -Type Error -Message "al-build.json not found at: $configPath. Run init.ps1 from the al-build skill's scripts folder to create it."
        throw "Config file required. Expected at: $configPath. Run init.ps1 from the al-build skill's scripts folder to create it."
    }

    # Helper function for three-tier resolution
    function Resolve-Value {
        param([string]$Key, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($Key) -and $null -ne $Overrides[$Key]) { return $Overrides[$Key] }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) { return $envVal }
        if ($defaults.ContainsKey($Key) -and $null -ne $defaults[$Key]) { return $defaults[$Key] }
        return $Default
    }

    # Resolve all configuration values
    $appDir = Resolve-Value 'appDir' 'ALBT_APP_DIR' 'app'

    # Resolve testApps array
    $testAppsRaw = if ($defaults.ContainsKey('testApps') -and $defaults['testApps'] -is [System.Collections.IEnumerable] -and $defaults['testApps'] -isnot [string]) {
        @($defaults['testApps'])
    } else {
        @('test')
    }

    # Resolve to absolute paths if relative
    $workspaceRoot = (Get-Location).Path
    if (-not [System.IO.Path]::IsPathRooted($appDir)) {
        $appDir = Join-Path $workspaceRoot $appDir
    }

    $testApps = @()
    foreach ($testAppDir in $testAppsRaw) {
        if (-not [System.IO.Path]::IsPathRooted($testAppDir)) {
            $testApps += Join-Path $workspaceRoot $testAppDir
        } else {
            $testApps += $testAppDir
        }
    }

    # Resolve containerTestApps array
    $containerTestAppsRaw = if ($defaults.ContainsKey('containerTestApps') -and $defaults['containerTestApps'] -is [System.Collections.IEnumerable] -and $defaults['containerTestApps'] -isnot [string]) {
        @($defaults['containerTestApps'])
    } else {
        @()
    }

    $containerTestApps = @()
    foreach ($containerTestAppDir in $containerTestAppsRaw) {
        if (-not [System.IO.Path]::IsPathRooted($containerTestAppDir)) {
            $containerTestApps += Join-Path $workspaceRoot $containerTestAppDir
        } else {
            $containerTestApps += $containerTestAppDir
        }
    }

    # Always derive container name from git branch (no env var caching)
    try {
        $containerName = Get-BCAgentContainerName
    } catch {
        $containerName = 'bctest'
    }

    # Helper for nested container config values
    function Resolve-ContainerValue {
        param([string]$Key, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($Key) -and $null -ne $Overrides[$Key]) { return $Overrides[$Key] }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) { return $envVal }
        if ($defaults.ContainsKey('container') -and $defaults['container'] -is [hashtable]) {
            $container = $defaults['container']
            if ($container.ContainsKey($Key) -and $null -ne $container[$Key]) { return $container[$Key] }
        }
        return $Default
    }

    # Helper for nested breakingChange config values
    function Resolve-BreakingChangeValue {
        param([string]$Key, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($Key) -and $null -ne $Overrides[$Key]) { return $Overrides[$Key] }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) { return $envVal }
        if ($defaults.ContainsKey('breakingChange') -and $defaults['breakingChange'] -is [hashtable]) {
            $breakingChange = $defaults['breakingChange']
            if ($breakingChange.ContainsKey($Key) -and $null -ne $breakingChange[$Key]) { return $breakingChange[$Key] }
        }
        return $Default
    }

    function Resolve-CoverageValue {
        param([string]$Key, [string]$OverrideKey, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($OverrideKey) -and $null -ne $Overrides[$OverrideKey]) {
            return $Overrides[$OverrideKey]
        }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) {
            return ConvertFrom-EnvironmentBoolean -Name $EnvVar -Value $envVal
        }
        if ($defaults.ContainsKey('coverage') -and $defaults['coverage'] -is [hashtable]) {
            $coverage = $defaults['coverage']
            if ($coverage.ContainsKey($Key) -and $null -ne $coverage[$Key]) { return $coverage[$Key] }
        }
        return $Default
    }

    # The real Release .app's folder: no default, $null when unset. A relative value is repo-root relative.
    $releaseAppDir = Resolve-BreakingChangeValue 'releaseAppDir' 'ALBT_RELEASE_APP_DIR' $null
    $releaseAppDir = if ([string]::IsNullOrWhiteSpace([string]$releaseAppDir)) {
        $null
    } elseif ([System.IO.Path]::IsPathRooted([string]$releaseAppDir)) {
        [string]$releaseAppDir
    } else {
        Join-Path $repoRoot ([string]$releaseAppDir)
    }

    $config = [PSCustomObject]@{
        AppDir                              = $appDir
        TestApps                            = $testApps
        ContainerTestApps                   = $containerTestApps
        WarnAsError                         = Resolve-Value 'warnAsError' 'WARN_AS_ERROR' $false
        RulesetPath                         = Resolve-Value 'rulesetPath' 'RULESET_PATH' 'al.ruleset.json'
        ServerInstance                      = Resolve-Value 'serverInstance' 'ALBT_BC_SERVER_INSTANCE' 'BC'
        ContainerName                       = $containerName
        ServerUrl                           = "http://$containerName"
        ContainerUsername                   = Resolve-ContainerValue 'username' 'ALBT_BC_CONTAINER_USERNAME' 'admin'
        ContainerPassword                   = Resolve-ContainerValue 'password' 'ALBT_BC_CONTAINER_PASSWORD' 'P@ssw0rd'
        ContainerAuth                       = Resolve-ContainerValue 'auth' 'ALBT_BC_CONTAINER_AUTH' 'UserPassword'
        ArtifactCountry                     = Resolve-ContainerValue 'artifactCountry' 'ALBT_BC_ARTIFACT_COUNTRY' 'w1'
        ArtifactSelect                      = Resolve-ContainerValue 'artifactSelect' 'ALBT_BC_ARTIFACT_SELECT' 'Latest'
        GoldenContainerName                 = Resolve-ContainerValue 'name' 'ALBT_BC_GOLDEN_CONTAINER_NAME' 'bctest'
        ImageName                           = Resolve-ContainerValue 'imageName' 'ALBT_BC_IMAGE_NAME' 'bctest:snapshot'
        MemoryLimit                         = Resolve-ContainerValue 'memoryLimit' 'ALBT_BC_MEMORY_LIMIT' '8g'
        Tenant                              = Resolve-Value 'tenant' 'ALBT_BC_TENANT' 'default'
        ValidateCurrent                     = Resolve-Value 'validateCurrent' 'ALBT_VALIDATE_CURRENT' '1'
        ApplicationInsightsConnectionString = Resolve-Value 'applicationInsightsConnectionString' 'ALBT_APPLICATION_INSIGHTS_CONNECTION_STRING' ''
        CoverageEnabled                     = if ($testApps.Count -eq 0) {
            $false
        } else {
            ConvertTo-Boolean (Resolve-CoverageValue 'enabled' 'coverageEnabled' 'ALBT_COVERAGE_ENABLED' $false)
        }
        BreakingChangeEnabled               = ConvertTo-Boolean (Resolve-BreakingChangeValue 'enabled' 'ALBT_BREAKING_CHANGE_ENABLED' $false)
        ReleaseAppDir                       = $releaseAppDir
    }

    return $config
}

function Resolve-CoverageEnabled {
    <#
    .SYNOPSIS
        Resolve effective coverage at the test invocation boundary.
    .DESCRIPTION
        Runs without configured testApps skip coverage from every source.
        Otherwise explicit -Coverage wins over configured coverage.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [switch]$Coverage
    )

    if (@($Config.TestApps).Count -eq 0) {
        return $false
    }
    if ($Coverage) {
        return $true
    }
    return [bool]$Config.CoverageEnabled
}

function Get-CompileTargets {
    <#
    .SYNOPSIS
        Resolve which apps test.ps1 compiles after the main app, in order.
    .DESCRIPTION
        The main app is compiled separately (test.ps1 Step 1) in every mode, so
        it is not in this list. This returns the secondary compile targets —
        every test app, then every container-test app not already listed —
        each carrying the Role used to name its build step ('test' or
        'container-test'). Compilation runs the analyzer gate (alc
        /analyzer:) on the host for every listed app.
    .PARAMETER Config
        Build configuration object from Get-BuildConfig.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $targets = @()
    foreach ($testAppDir in $Config.TestApps) {
        $targets += [ordered]@{ AppDir = $testAppDir; Role = 'test' }
    }
    foreach ($containerTestAppDir in $Config.ContainerTestApps) {
        if ($Config.TestApps -notcontains $containerTestAppDir) {
            $targets += [ordered]@{ AppDir = $containerTestAppDir; Role = 'container-test' }
        }
    }
    return $targets
}

function Set-BuildEnvironment {
    <#
    .SYNOPSIS
        Export build configuration to environment variables
    .PARAMETER Config
        Build configuration object from Get-BuildConfig
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $env:ALBT_APP_DIR = $Config.AppDir
    $env:WARN_AS_ERROR = $Config.WarnAsError
    $env:RULESET_PATH = $Config.RulesetPath
    $env:ALBT_BC_SERVER_URL = $Config.ServerUrl
    $env:ALBT_BC_SERVER_INSTANCE = $Config.ServerInstance
    $env:ALBT_BC_CONTAINER_NAME = $Config.ContainerName
    $env:ALBT_BC_CONTAINER_USERNAME = $Config.ContainerUsername
    $env:ALBT_BC_CONTAINER_PASSWORD = $Config.ContainerPassword
    $env:ALBT_BC_CONTAINER_AUTH = $Config.ContainerAuth
    $env:ALBT_BC_ARTIFACT_COUNTRY = $Config.ArtifactCountry
    $env:ALBT_BC_ARTIFACT_SELECT = $Config.ArtifactSelect
    $env:ALBT_BC_GOLDEN_CONTAINER_NAME = $Config.GoldenContainerName
    $env:ALBT_BC_IMAGE_NAME = $Config.ImageName
    $env:ALBT_BC_MEMORY_LIMIT = $Config.MemoryLimit
    $env:ALBT_BC_TENANT = $Config.Tenant
    $env:ALBT_VALIDATE_CURRENT = $Config.ValidateCurrent
    $env:ALBT_APPLICATION_INSIGHTS_CONNECTION_STRING = $Config.ApplicationInsightsConnectionString
    $env:ALBT_BREAKING_CHANGE_ENABLED = $Config.BreakingChangeEnabled
    # An optional override: set when the config has a value, removed when it has none, so a value from an earlier config cannot go stale.
    if ($Config.ReleaseAppDir) { $env:ALBT_RELEASE_APP_DIR = $Config.ReleaseAppDir }
    else { Remove-Item Env:\ALBT_RELEASE_APP_DIR -ErrorAction SilentlyContinue }
}

# =============================================================================
# Compiler Operations
# =============================================================================

function Get-ToolPackageId {
    <#
    .SYNOPSIS
        Get platform-specific AL compiler NuGet package ID
    #>
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return 'microsoft.dynamics.businesscentral.development.tools'
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        return 'microsoft.dynamics.businesscentral.development.tools.linux'
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return 'microsoft.dynamics.businesscentral.development.tools.osx'
    }
    return 'microsoft.dynamics.businesscentral.development.tools'
}

function Get-ToolCommandPath {
    <#
    .SYNOPSIS
        Resolve the 'al' command shim inside a --tool-path install root.
    .DESCRIPTION
        A --tool-path install drops the command shim (al.exe on Windows, al on
        unix) at the root, alongside the .store tree. This is the executable the
        build invokes by full path — never the global 'al' on PATH.
    #>
    param([Parameter(Mandatory)][string]$ToolPathRoot)

    foreach ($name in @('al.exe', 'al')) {
        $candidate = Join-Path $ToolPathRoot $name
        if (Test-Path -LiteralPath $candidate) { return (Get-Item -LiteralPath $candidate).FullName }
    }
    return $null
}

function Install-ALCompilerChannel {
    <#
    .SYNOPSIS
        Install or refresh one AL compiler channel as a private --tool-path install.
    .DESCRIPTION
        Installs the compiler into its own tool-path root (never the global slot,
        which is the user's own). Refreshes to latest on every provision: updates an
        existing install, installs when absent. -Update forces a clean reinstall
        (uninstall + install). -Prerelease selects the prerelease NuGet channel.
        Returns the resolved version, major, tool-path root, command (al) path, and
        alc path.
    .PARAMETER PackageId
        Compiler NuGet package id.
    .PARAMETER ToolPathRoot
        Directory for this channel's --tool-path install.
    .PARAMETER Prerelease
        Install from the prerelease channel (dotnet's --prerelease).
    .PARAMETER Update
        Force a clean reinstall instead of an in-place update.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$ToolPathRoot,
        [switch]$Prerelease,
        [switch]$Update
    )

    $channelLabel = if ($Prerelease) { 'prerelease' } else { 'stable' }
    Ensure-Directory -Path $ToolPathRoot

    $existing = Get-InstalledCompilerVersion -PackageId $PackageId -ToolPath $ToolPathRoot
    $commonArgs = @('--tool-path', $ToolPathRoot)
    if ($Prerelease) { $commonArgs += '--prerelease' }

    if ($existing -and $Update) {
        Write-BuildMessage -Type Step -Message "Reinstalling $channelLabel AL compiler (clean)..."
        & dotnet tool uninstall --tool-path $ToolPathRoot $PackageId 2>&1 | Out-Null
        $action = 'install'
        $out = & dotnet tool install @commonArgs $PackageId 2>&1
    } elseif ($existing) {
        Write-BuildMessage -Type Step -Message "Updating $channelLabel AL compiler to latest..."
        $action = 'update'
        $out = & dotnet tool update @commonArgs $PackageId 2>&1
    } else {
        Write-BuildMessage -Type Step -Message "Installing $channelLabel AL compiler..."
        $action = 'install'
        $out = & dotnet tool install @commonArgs $PackageId 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet tool $action ($channelLabel) failed with exit code $LASTEXITCODE. Output: $($out -join [Environment]::NewLine)"
    }

    $version = Get-InstalledCompilerVersion -PackageId $PackageId -ToolPath $ToolPathRoot
    if (-not $version) {
        throw "$channelLabel AL compiler version not found after provisioning at $ToolPathRoot."
    }
    $alcPath = Get-LatestCompilerPath -PackageId $PackageId -ToolRoot $ToolPathRoot
    if (-not $alcPath) {
        throw "$channelLabel compiler executable (alc) not found under $ToolPathRoot after provisioning."
    }
    $commandPath = Get-ToolCommandPath -ToolPathRoot $ToolPathRoot
    if (-not $commandPath) {
        throw "$channelLabel compiler command (al) not found under $ToolPathRoot after provisioning."
    }

    $majorToken = ($version -split '\.')[0]
    $major = 0
    [void][int]::TryParse($majorToken, [ref]$major)

    Write-BuildMessage -Type Success -Message "$channelLabel AL compiler: $version (major $major)"
    return [pscustomobject]@{
        Channel     = $channelLabel
        Version     = $version
        Major       = $major
        Root        = $ToolPathRoot
        CommandPath = $commandPath
        AlcPath     = $alcPath
    }
}

function Get-RequiredRuntimeMajor {
    <#
    .SYNOPSIS
        Highest app.json runtime major across all of a build's apps.
    .DESCRIPTION
        Scans the main app, every test app, and every container-test app —
        the full compile set — and returns the max 'runtime' major, or 0 when
        no app pins a runtime. One compiler compiles them all, so it must
        satisfy the most demanding app — an app at a runtime newer than the
        latest stable pulls the whole build onto the prerelease channel.
    #>
    param([Parameter(Mandatory)]$Config)

    $dirs = New-Object System.Collections.Generic.List[string]
    if ($Config.AppDir) { $dirs.Add([string]$Config.AppDir) }
    foreach ($t in @($Config.TestApps)) { if ($t) { $dirs.Add([string]$t) } }
    $containerTestApps = if ($Config.PSObject.Properties['ContainerTestApps']) { @($Config.ContainerTestApps) } else { @() }
    foreach ($t in $containerTestApps) { if ($t -and -not $dirs.Contains([string]$t)) { $dirs.Add([string]$t) } }

    $max = 0
    foreach ($d in $dirs) {
        $m = Get-AppRuntimeMajor -AppDir $d
        if ($null -ne $m -and $m -gt $max) { $max = $m }
    }
    return $max
}

function Install-ALCompiler {
    <#
    .SYNOPSIS
        Provision al-build's two private side-by-side AL compilers.
    .DESCRIPTION
        Installs both the latest stable and the latest prerelease compiler into
        their own --tool-path roots under the tool cache, refreshing both to latest
        on every provision. The global dotnet tool is the user's own (LSP/MCP daily
        driver) and is deliberately NEVER installed, updated, or invoked here — the
        build picks stable vs prerelease per app.json runtime and invokes the chosen
        compiler by full path. ALCops is installed into each channel's Analyzers
        folder so lint coverage is identical whichever channel a build selects.
        A two-channel sentinel records the resolved versions, majors, and paths for
        the offline build-time channel decision (Get-LatestCompilerInfo).
    .PARAMETER Update
        Force a clean reinstall of both channels instead of an in-place update.
    #>
    [CmdletBinding()]
    param(
        [switch]$Update
    )

    Write-BuildHeader 'AL Compiler Provisioning'

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'dotnet CLI not found. Install .NET SDK from https://dotnet.microsoft.com/download'
    }

    $packageId = Get-ToolPackageId
    Write-BuildMessage -Type Detail -Message "Package: $packageId"

    $toolCacheRoot = Get-ToolCacheRoot
    $alCacheDir = Join-Path $toolCacheRoot 'al'
    Ensure-Directory -Path $alCacheDir

    $stableRoot = Join-Path $alCacheDir 'stable'
    $prereleaseRoot = Join-Path $alCacheDir 'prerelease'

    $stable = Install-ALCompilerChannel -PackageId $packageId -ToolPathRoot $stableRoot -Update:$Update
    $prerelease = Install-ALCompilerChannel -PackageId $packageId -ToolPathRoot $prereleaseRoot -Prerelease -Update:$Update

    # ALCops into each channel's Analyzers folder; built-in cops ship inside each compiler.
    Install-ALCops -CompilerDir (Split-Path -Parent $stable.AlcPath)
    Install-ALCops -CompilerDir (Split-Path -Parent $prerelease.AlcPath)

    $sentinel = [ordered]@{
        schemaVersion   = 2
        installedAt     = (Get-Date).ToString('o')
        stableMajor     = $stable.Major
        prereleaseMajor = $prerelease.Major
        channels        = [ordered]@{
            stable     = [ordered]@{
                root        = $stable.Root
                commandPath = $stable.CommandPath
                alcPath     = $stable.AlcPath
                version     = $stable.Version
            }
            prerelease = [ordered]@{
                root        = $prerelease.Root
                commandPath = $prerelease.CommandPath
                alcPath     = $prerelease.AlcPath
                version     = $prerelease.Version
            }
        }
    }
    $sentinelPath = Join-Path $alCacheDir 'sentinel.json'
    $sentinel | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $sentinelPath -Encoding UTF8

    Write-BuildMessage -Type Detail -Message "Sentinel saved: $sentinelPath"
    Write-BuildMessage -Type Success -Message "Stable $($stable.Version) (major $($stable.Major)) + prerelease $($prerelease.Version) (major $($prerelease.Major))"
    Write-BuildMessage -Type Success -Message "Compiler provisioning complete"
}

function ConvertTo-ALRunnerVersion {
    <#
    .SYNOPSIS
        Parse an al-runner --version banner into a [version].
    .DESCRIPTION
        Accepts a numeric core of two to four parts with an optional SemVer
        prerelease (-local.9017de3a, -beta.1) and build (+build.5) suffix.
        Throws when the banner does not match.
    .PARAMETER VersionLine
        A single line of al-runner --version output, e.g. 'al-runner v2.10.0.0'
        or 'al-runner v2.10.0-local.9017de3a'.
    .PARAMETER Detailed
        Return [pscustomobject] Version, Prerelease, IsPrerelease instead of the
        bare [version].
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionLine,

        [switch]$Detailed
    )

    $trimmed = $VersionLine.Trim()
    if ($trimmed -match '^al-runner v(\d+(?:\.\d+){1,3})(?:-([0-9A-Za-z][0-9A-Za-z.-]*))?(?:\+[0-9A-Za-z][0-9A-Za-z.-]*)?$') {
        $version = [version]$Matches[1]
        if (-not $Detailed) {
            return $version
        }
        $prerelease = if ($Matches.ContainsKey(2)) { $Matches[2] } else { $null }
        return [pscustomobject]@{
            Version      = $version
            Prerelease   = $prerelease
            IsPrerelease = [bool]$prerelease
        }
    }

    throw "Unable to parse al-runner version from banner: '$VersionLine'"
}

function Install-ALRunner {
    <#
    .SYNOPSIS
        Ensure the AL Runner tool is available at the required version floor
    .DESCRIPTION
        Installs BusinessCentral.AL.Runner as a global dotnet tool for containerless
        unit testing. Mirrors the Install-ALCompiler pattern. After presence is
        ensured, verifies the installed version meets the 2.10 floor, updating
        once if it does not.

        Prerelease decision: a banner with a SemVer prerelease suffix
        (al-runner v2.10.0-local.9017de3a) is a developer's local or preview
        build. The implicit floor update never runs against it — `dotnet tool
        update --global` would replace the local build with the feed's release.
        A prerelease at or above the floor passes untouched; one below the floor
        throws and names the suffix. The explicit -Update switch still updates,
        because the user asked for it.
    .PARAMETER Update
        Force update of an existing global tool.
    #>
    [CmdletBinding()]
    param(
        [switch]$Update
    )

    Write-BuildHeader 'AL Runner Provisioning'

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'dotnet CLI not found. Install .NET SDK from https://dotnet.microsoft.com/download'
    }

    $packageId = 'MSDyn365BC.AL.Runner'
    $existing = Get-Command al-runner -ErrorAction SilentlyContinue
    $updated = $false

    if ($existing -and -not $Update) {
        Write-BuildMessage -Type Success -Message "AL Runner already installed: $($existing.Source)"
    } elseif ($existing -and $Update) {
        Write-BuildMessage -Type Step -Message "Updating AL Runner..."
        $updateOutput = & dotnet tool update --global $packageId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool update failed for $packageId with exit code $LASTEXITCODE. Output: $($updateOutput -join [Environment]::NewLine)"
        }
        $updated = $true
        Write-BuildMessage -Type Success -Message "AL Runner updated"
    } else {
        Write-BuildMessage -Type Step -Message "Installing AL Runner..."
        $installOutput = & dotnet tool install --global $packageId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool install failed for $packageId with exit code $LASTEXITCODE. Output: $($installOutput -join [Environment]::NewLine)"
        }
        Write-BuildMessage -Type Success -Message "AL Runner installed"
    }

    # Verify al-runner is on PATH after install
    $postInstall = Get-Command al-runner -ErrorAction SilentlyContinue
    if (-not $postInstall) {
        $dotnetToolsDir = Join-Path (if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }) '.dotnet' 'tools'
        if (Test-Path $dotnetToolsDir) {
            $env:PATH = "$dotnetToolsDir$([IO.Path]::PathSeparator)$env:PATH"
            Write-BuildMessage -Type Detail -Message "Added $dotnetToolsDir to PATH"
        }
        $postInstall = Get-Command al-runner -ErrorAction SilentlyContinue
        if (-not $postInstall) {
            throw "al-runner not found on PATH after installation. Ensure ~/.dotnet/tools is on your PATH."
        }
    }

    Write-BuildMessage -Type Detail -Message "Path: $($postInstall.Source)"

    # Enforce the version floor: containerless test execution depends on 2.10+.
    # At most one update runs per invocation — if -Update already ran the
    # dotnet tool update above, a still-below-floor version throws directly
    # instead of updating a second time.
    $requiredVersion = [version]'2.10'
    $versionLine = @(& al-runner --version 2>&1)[0]
    $found = ConvertTo-ALRunnerVersion -VersionLine $versionLine -Detailed
    $foundVersion = $found.Version

    if ($foundVersion -lt $requiredVersion) {
        if ($updated) {
            throw "al-runner $foundVersion found, 2.10 required"
        }
        if ($found.IsPrerelease) {
            throw "al-runner $foundVersion-$($found.Prerelease) found, 2.10 required; prerelease/local build left untouched — update it yourself or run with -Update"
        }

        Write-BuildMessage -Type Step -Message "AL Runner $foundVersion found, updating to meet the $requiredVersion floor..."
        $floorUpdateOutput = & dotnet tool update --global $packageId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool update failed for $packageId with exit code $LASTEXITCODE. Output: $($floorUpdateOutput -join [Environment]::NewLine)"
        }
        $updated = $true

        $versionLine = @(& al-runner --version 2>&1)[0]
        $foundVersion = ConvertTo-ALRunnerVersion -VersionLine $versionLine
        if ($foundVersion -lt $requiredVersion) {
            throw "al-runner $foundVersion found, 2.10 required"
        }
    } elseif ($found.IsPrerelease) {
        Write-BuildMessage -Type Detail -Message "AL Runner $foundVersion-$($found.Prerelease) is a prerelease/local build; left untouched"
    }

    Write-BuildMessage -Type Success -Message "AL Runner provisioning complete"
}

function Get-InstalledCompilerVersion {
    <#
    .SYNOPSIS
        Get currently installed AL compiler version from dotnet tools
    .PARAMETER PackageId
        NuGet package id to look up.
    .PARAMETER ToolPath
        When set, query a --tool-path install at this directory instead of the
        global tool store. al-build's compilers are tool-path installs (the global
        slot is the user's own, untouched), so the build path always passes this.
    #>
    param([string]$PackageId, [string]$ToolPath)

    try {
        $listArgs = if ($ToolPath) { @('tool', 'list', '--tool-path', $ToolPath) } else { @('tool', 'list', '--global') }
        $output = & dotnet @listArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { return $null }

        $packageIdLower = $PackageId.ToLowerInvariant()
        $lines = $output -split "`r?`n"
        foreach ($line in $lines) {
            if ($line -match '^Package Id' -or $line -match '^-+$' -or [string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $parts = $line -split '\s+', 3
            if ($parts.Count -ge 2) {
                $idFromLine = $parts[0].Trim().ToLowerInvariant()
                if ($idFromLine -eq $packageIdLower) {
                    return $parts[1].Trim()
                }
            }
        }
        return $null
    } catch {
        return $null
    }
}

function Get-InstalledRuntimeMajors {
    <#
    .SYNOPSIS
        Major versions of installed Microsoft.NETCore.App runtimes
    #>
    try {
        $runtimes = & dotnet --list-runtimes 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
        return @($runtimes |
            Where-Object { $_ -match '^Microsoft\.NETCore\.App (\d+)\.' } |
            ForEach-Object { [int]($_ -replace '^Microsoft\.NETCore\.App (\d+)\..*$', '$1') } |
            Sort-Object -Unique)
    } catch {
        return @()
    }
}

function Select-CompilerCandidate {
    <#
    .SYNOPSIS
        Pick the compiler executable among multi-target candidates.
    .DESCRIPTION
        The compiler dotnet tool ships one alc per target framework (tools/net8.0,
        tools/net10.0). Prefer candidates whose target framework has an installed
        .NET runtime, then the highest target framework, then the newest file.
        Deterministic, so the analyzers installed next to the compiler at provision
        time keep matching the compiler directory picked at build time. Runs per
        channel — each side-by-side install (stable / prerelease) has its own .store
        tree, so this picks within one channel's tool-path root, not across them.
    .PARAMETER Candidates
        Objects with FullName and LastWriteTime (FileInfo or equivalent).
    .PARAMETER InstalledRuntimeMajors
        Major versions of installed Microsoft.NETCore.App runtimes. Candidates whose
        path carries no target framework rank as runnable.
    #>
    param(
        [object[]]$Candidates,
        [int[]]$InstalledRuntimeMajors = @()
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) { return $null }

    $ranked = foreach ($item in $Candidates) {
        $tfmMajor = 0
        if ($item.FullName -match '[\\/]tools[\\/]net(\d+)\.\d+[\\/]') {
            $tfmMajor = [int]$matches[1]
        }
        [pscustomobject]@{
            Item       = $item
            TfmMajor   = $tfmMajor
            HasRuntime = ($tfmMajor -eq 0) -or ($InstalledRuntimeMajors -contains $tfmMajor)
        }
    }

    $chosen = $ranked |
        Sort-Object -Property @{Expression = 'HasRuntime'; Descending = $true },
                              @{Expression = 'TfmMajor'; Descending = $true },
                              @{Expression = { $_.Item.LastWriteTime }; Descending = $true } |
        Select-Object -First 1
    return $chosen.Item
}

function Get-LatestCompilerPath {
    <#
    .SYNOPSIS
        Find the AL compiler executable (alc) in a dotnet tool store
    .PARAMETER PackageId
        Compiler NuGet package id.
    .PARAMETER ToolRoot
        Root of a --tool-path install (contains the '.store' tree). When omitted,
        the global ~/.dotnet/tools store is searched. al-build provisions its
        compilers under --tool-path roots, so the install/build paths pass this.
    #>
    param(
        [string]$PackageId,
        [string]$ToolRoot
    )

    if ($ToolRoot) {
        $storeRoot = Join-Path $ToolRoot '.store'
    } else {
        $userHome = $env:HOME
        if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
        $globalToolsRoot = Join-Path $userHome '.dotnet' 'tools'
        $storeRoot = Join-Path $globalToolsRoot '.store'
    }

    if (-not (Test-Path -LiteralPath $storeRoot)) { return $null }

    $packageDirName = $PackageId.ToLower()
    $packageRoot = Join-Path $storeRoot $packageDirName

    if (-not (Test-Path -LiteralPath $packageRoot)) { return $null }

    $toolExecutableNames = @('alc.exe', 'alc')
    $items = Get-ChildItem -Path $packageRoot -Recurse -File -Depth 8 -ErrorAction SilentlyContinue |
        Where-Object { $toolExecutableNames -contains $_.Name }

    $candidate = Select-CompilerCandidate -Candidates @($items) -InstalledRuntimeMajors (Get-InstalledRuntimeMajors)
    if ($candidate) { return $candidate.FullName }
    return $null
}

function Get-ALCopsExpectedDllNames {
    return @(
        'ALCops.ApplicationCop.dll'
        'ALCops.Common.dll'
        'ALCops.DocumentationCop.dll'
        'ALCops.FormattingCop.dll'
        'ALCops.LinterCop.dll'
        'ALCops.PlatformCop.dll'
        'ALCops.TestAutomationCop.dll'
    )
}

function Get-InstalledALCopsVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AnalyzersDir
    )

    $versions = [System.Collections.Generic.List[string]]::new()
    foreach ($dllName in Get-ALCopsExpectedDllNames) {
        $dllPath = Join-Path $AnalyzersDir $dllName
        if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) {
            return $null
        }

        try {
            $assemblyVersion = [System.Reflection.AssemblyName]::GetAssemblyName($dllPath).Version
        } catch {
            return $null
        }
        if (-not $assemblyVersion) {
            return $null
        }
        $versions.Add($assemblyVersion.ToString())
    }

    $distinctVersions = @($versions | Sort-Object -Unique)
    if ($distinctVersions.Count -ne 1) {
        return $null
    }
    return $distinctVersions[0]
}

function Invoke-ALCopsDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CompilerDir,

        [Parameter(Mandatory)]
        [string]$AnalyzersDir
    )

    # Own the native-command error path: with $PSNativeCommandUseErrorActionPreference
    # on, a non-zero npx exit would throw at the call site and discard the captured
    # npm diagnostics. The explicit $LASTEXITCODE check below produces the richer error.
    $PSNativeCommandUseErrorActionPreference = $false

    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw "npx not found. ALCops analyzers are installed via the official '@alcops/core' CLI, which requires Node.js. Install Node >= 22 (any source: MSI, Volta, nvm) so 'npx' is on PATH, then re-run provision."
    }

    $npxArgs = @(
        '--yes', '@alcops/core@latest', 'download'
        '--output', $AnalyzersDir
        '--detect-using', $CompilerDir
        '--detect-from', 'compiler-path'
    )
    $output = & npx @npxArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "ALCops download failed (npx exit $LASTEXITCODE): $($output -join [Environment]::NewLine)"
    }
}

function Install-ALCops {
    <#
    .SYNOPSIS
        Download and install the ALCops analyzers into the compiler's Analyzers folder.
    .DESCRIPTION
        Reuses a complete ALCops suite when all seven DLLs report one assembly version.
        Otherwise uses the official '@alcops/core' CLI to detect the compiler's target
        framework and download the latest ALCops.Analyzers NuGet package (six cops plus
        the shared ALCops.Common.dll).
        Removes a legacy BusinessCentral.LinterCop.dll when present: ALCops shares
        diagnostic IDs with the discontinued LinterCop, so the two must never load
        together. Fails loudly; a missing analyzer must stop provisioning rather
        than silently degrade the build gate's lint coverage.
    .PARAMETER CompilerDir
        Directory containing alc.exe. DLLs land in '<CompilerDir>\Analyzers' where
        Get-EnabledAnalyzerPath resolves '${analyzerFolder}' entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CompilerDir
    )

    $analyzersDir = Join-Path $CompilerDir 'Analyzers'
    Ensure-Directory -Path $analyzersDir

    # ALCops shares diagnostic IDs with the discontinued LinterCop; never load both.
    $legacyDll = Join-Path $analyzersDir 'BusinessCentral.LinterCop.dll'
    if (Test-Path -LiteralPath $legacyDll) {
        Remove-Item -LiteralPath $legacyDll -Force
        Write-BuildMessage -Type Detail -Message "Removed legacy BusinessCentral.LinterCop.dll"
    }

    $installedVersion = Get-InstalledALCopsVersion -AnalyzersDir $analyzersDir
    if ($installedVersion) {
        Write-BuildMessage -Type Success -Message "ALCops analyzers already installed: $installedVersion"
        Write-BuildMessage -Type Detail -Message "Folder: $analyzersDir"
        return
    }

    Write-BuildMessage -Type Step -Message "Installing ALCops analyzers..."
    Invoke-ALCopsDownload -CompilerDir $CompilerDir -AnalyzersDir $analyzersDir

    $installedVersion = Get-InstalledALCopsVersion -AnalyzersDir $analyzersDir
    if (-not $installedVersion) {
        throw "ALCops installation incomplete or inconsistent in '$analyzersDir'."
    }

    $expectedDllCount = @(Get-ALCopsExpectedDllNames).Count
    Write-BuildMessage -Type Success -Message "ALCops analyzers installed: $installedVersion ($expectedDllCount DLLs)"
    Write-BuildMessage -Type Detail -Message "Folder: $analyzersDir"
}

# =============================================================================
# Build Operations
# =============================================================================

function Invoke-ALBuild {
    <#
    .SYNOPSIS
        Compile an AL project
    .PARAMETER AppDir
        Directory containing app.json and AL source files
    .PARAMETER WarnAsError
        Treat warnings as errors (default: true)
    .PARAMETER RequiredRuntimeMajor
        Max app.json runtime major across the build, driving the stable-vs-prerelease
        compiler channel. Omit (-1) to self-compute from al-build.json; the gate
        (test.ps1) computes it once and passes it to every compile for consistency.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir,

        [switch]$WarnAsError = $true,

        [int]$RequiredRuntimeMajor = -1
    )

    Write-BuildHeader "AL Project Compilation"

    $appJson = Get-AppJsonObject $AppDir
    if (-not $appJson) {
        throw "app.json not found or invalid in '$AppDir'"
    }

    Write-BuildMessage -Type Step -Message "Building: $($appJson.name) v$($appJson.version)"

    # Resolve the build's required runtime once; self-compute for callers that don't
    # pass it (the channel is repo-wide, so every app compiles on the same compiler).
    if ($RequiredRuntimeMajor -lt 0) {
        $RequiredRuntimeMajor = Get-RequiredRuntimeMajor -Config (Get-BuildConfig)
    }

    # Pick the stable/prerelease compiler for the required runtime and invoke it by
    # full path — never the global 'al' (the user's own LSP/MCP tool).
    $compilerInfo = Get-LatestCompilerInfo -RequiredRuntimeMajor $RequiredRuntimeMajor
    $compilerRoot = $compilerInfo.CompilerDir

    Write-BuildMessage -Type Detail -Message "Compiler: $($compilerInfo.Version) [$($compilerInfo.Channel)]"

    # Get symbol cache
    $symbolCacheInfo = Get-SymbolCacheInfo -AppJson $appJson
    $packageCachePath = $symbolCacheInfo.CacheDir

    # Get analyzers (Get-EnabledAnalyzerPath throws when a requested analyzer is missing)
    $filteredAnalyzers = @(Get-EnabledAnalyzerPath -AppDir $AppDir -CompilerDir $compilerRoot)

    if ($filteredAnalyzers.Count -gt 0) {
        Write-BuildMessage -Type Detail -Message "Analyzers: $($filteredAnalyzers.Count) configured"
    }

    # Build output path
    $outputFullPath = Get-OutputPath $AppDir
    $outputFile = Split-Path -Path $outputFullPath -Leaf

    # Clean previous build
    if (Test-Path $outputFullPath) {
        Remove-Item $outputFullPath -Force
    }

    # Build compiler arguments (the 'al compile' wrapper from the selected tool-path install)
    $alcArgs = @(
        'compile'
        '/project:' + $AppDir
        '/packagecachepath:' + $packageCachePath
        '/out:' + $outputFullPath
    )

    # Add ruleset if exists
    $rulesetPath = $env:RULESET_PATH
    if ($rulesetPath) {
        $resolvedRuleset = if ([System.IO.Path]::IsPathRooted($rulesetPath)) { $rulesetPath } else { Join-Path (Get-Location).Path $rulesetPath }
        if (Test-Path $resolvedRuleset) {
            $alcArgs += '/ruleset:' + $resolvedRuleset
        }
    }

    # Add analyzers
    foreach ($analyzer in $filteredAnalyzers) {
        $alcArgs += '/analyzer:' + $analyzer
    }

    # Add warning as error
    if ($WarnAsError) {
        $alcArgs += '/warnaserror+'
    }

    Write-BuildMessage -Type Step -Message "Compiling..."

    # Execute the selected channel's compiler by full path (not the global 'al').
    # Diagnostics arrive on the compiler's stdout — route them to the host
    # stream so no capturing caller can swallow them ($LASTEXITCODE survives
    # the pipeline).
    & $compilerInfo.CommandPath @alcArgs | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0) {
        throw "AL compilation failed with exit code $LASTEXITCODE"
    }

    # Verify output
    if (-not (Test-Path $outputFullPath)) {
        throw "Build completed but output file not found: $outputFullPath"
    }

    $fileInfo = Get-Item $outputFullPath
    $sizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
    Write-BuildMessage -Type Success -Message "Build complete: $outputFile ($sizeKB KB)"
}

# =============================================================================
# Publish Operations
# =============================================================================

function Invoke-ALPublish {
    <#
    .SYNOPSIS
        Publish an AL app to a Business Central container
    .PARAMETER AppDir
        Directory containing the compiled .app file
    .PARAMETER Force
        Force republish even if app is unchanged
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir,

        [switch]$Force
    )

    $config = Get-BuildConfig
    $appJson = Get-AppJsonObject $AppDir
    if (-not $appJson) {
        throw "app.json not found in '$AppDir'"
    }

    Write-BuildHeader "App Publishing"
    Write-BuildMessage -Type Step -Message "Publishing: $($appJson.name) v$($appJson.version)"

    # Check if publish needed
    $needsPublish = Test-AppNeedsPublish -AppDir $AppDir -AppJson $appJson -ContainerName $config.ContainerName -Force:$Force
    if (-not $needsPublish) {
        Write-BuildMessage -Type Success -Message "App unchanged, skipping publish"
        return
    }

    # Get app file path
    $appFilePath = Get-OutputPath $AppDir
    if (-not (Test-Path -LiteralPath $appFilePath)) {
        throw "App file not found: $appFilePath. Build first."
    }

    # Import BcContainerHelper
    Import-BCContainerHelper

    # Get credentials
    $credential = Get-BCCredential -Username $config.ContainerUsername -Password $config.ContainerPassword

    try {
        Publish-BcContainerApp `
            -containerName $config.ContainerName `
            -appFile $appFilePath `
            -skipVerification `
            -sync `
            -install `
            -syncMode ForceSync `
            -useDevEndpoint `
            -credential $credential
    } catch {
        throw "Failed to publish app: $_"
    }

    # Save publish state
    Save-PublishState -AppDir $AppDir -AppJson $appJson -ContainerName $config.ContainerName

    Write-BuildMessage -Type Success -Message "App published successfully"
}

# =============================================================================
# Test Operations
# =============================================================================

function Get-XmlAttributeInt {
    param(
        [System.Xml.XmlElement]$Element,
        [string]$Name
    )
    $value = $Element.GetAttribute($Name)
    if ($value) { [int]$value } else { 0 }
}

function Get-JUnitTestCounts {
    <#
    .SYNOPSIS
        Parse test counts from a JUnit XML result file
    .DESCRIPTION
        Both result producers emit the same JUnit schema: the container via
        Run-TestsInBcContainer -JUnitResultFileName and AL Runner via --output-junit.
        One testsuite element per test codeunit; tests=/failures=/errors=/skipped=
        attributes carry the counts.
    .PARAMETER ResultFile
        Path to the JUnit XML result file
    .OUTPUTS
        PSCustomObject with testCodeunits, tests, testsPassed, testsFailed,
        testsSkipped. $null when the file is missing or unparseable — unknown
        counts are never reported as zeros.
    #>
    [CmdletBinding()]
    param(
        [string]$ResultFile
    )

    if (-not $ResultFile -or -not (Test-Path -LiteralPath $ResultFile)) {
        return $null
    }

    try {
        [xml]$doc = Get-Content -LiteralPath $ResultFile -Raw
        $suites = @($doc.SelectNodes('//testsuite'))

        $tests = 0
        $failed = 0
        $skipped = 0
        foreach ($suite in $suites) {
            $tests += Get-XmlAttributeInt -Element $suite -Name 'tests'
            $failed += (Get-XmlAttributeInt -Element $suite -Name 'failures') + (Get-XmlAttributeInt -Element $suite -Name 'errors')
            $skipped += Get-XmlAttributeInt -Element $suite -Name 'skipped'
        }

        return [PSCustomObject]@{
            testCodeunits = $suites.Count
            tests         = $tests
            testsPassed   = $tests - $failed - $skipped
            testsFailed   = $failed
            testsSkipped  = $skipped
        }
    } catch {
        Write-BuildMessage -Type Warning -Message "Could not parse test counts from ${ResultFile}: $_"
        return $null
    }
}

function Format-TestCountSummary {
    <#
    .SYNOPSIS
        Format a counts object as one unambiguous console line fragment
    .DESCRIPTION
        Keeps "tests" and "test codeunits" labeled and adjacent so a reader
        quoting any single line cannot transpose the two numbers.
    #>
    param(
        [Parameter(Mandatory)]
        $Counts
    )
    "$($Counts.tests) tests in $($Counts.testCodeunits) test codeunits - $($Counts.testsPassed) passed, $($Counts.testsFailed) failed, $($Counts.testsSkipped) skipped"
}

function Get-BcSharedTestBasePath {
    <#
    .SYNOPSIS
        Resolve the container's shared folder that JUnit results are written to.
    .DESCRIPTION
        BcContainerHelper writes -JUnitResultFileName from inside the container,
        so the path must be one already shared with the host filesystem.
    #>
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
    <#
    .SYNOPSIS
        Create a fresh, uniquely named run folder under the container's shared path.
    #>
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

function Invoke-ALTest {
    <#
    .SYNOPSIS
        Run AL tests in a Business Central container
    .PARAMETER TestDir
        Directory containing the test app
    .PARAMETER OutputDir
        Directory to write test results (last.xml)
    .OUTPUTS
        PSCustomObject with Passed, Runner, AppName, TestDir, Counts, ResultFile properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestDir,

        [Parameter(Mandatory)]
        [string]$OutputDir
    )

    $config = Get-BuildConfig

    $appJson = Get-AppJsonObject $TestDir
    if (-not $appJson) {
        throw "app.json not found in '$TestDir'"
    }
    $dirName = Split-Path $TestDir -Leaf

    Write-BuildHeader "AL Test Execution"
    Write-BuildMessage -Type Step -Message "Running tests: $($appJson.name)"

    # Setup output directory. The top-level test.ps1 gate already removed
    # and recreated the whole .output/TestResults tree before this run
    # started, so no per-run local JUnit cleanup happens here.
    Ensure-Directory -Path $OutputDir

    # Import BcContainerHelper
    Import-BCContainerHelper

    $sharedRunPath = New-BcSharedTestRunDirectory -ContainerName $config.ContainerName
    $sharedResultFile = Join-Path $sharedRunPath 'last.xml'

    # Get credentials
    $credential = Get-BCCredential -Username $config.ContainerUsername -Password $config.ContainerPassword

    # Build test parameters — JUnit result format, same schema AL Runner emits (one parser for both)
    $testParams = @{
        containerName         = $config.ContainerName
        tenant                = $config.Tenant
        credential            = $credential
        extensionId           = $appJson.id
        JUnitResultFileName   = $sharedResultFile
        returnTrueIfAllPassed = $true
    }

    $resultFile = Join-Path $OutputDir 'last.xml'
    $primaryError = $null
    $testsPassed = $false
    try {
        $testsPassed = [bool](Run-TestsInBcContainer @testParams)
    } catch {
        $primaryError = $_
    }

    $transportErrors = [System.Collections.Generic.List[object]]::new()
    try {
        if (Test-Path -LiteralPath $sharedResultFile) {
            Copy-Item -LiteralPath $sharedResultFile -Destination $resultFile -Force
            Write-BuildMessage -Type Success -Message "Results saved: $resultFile"
        }
    } catch {
        $transportErrors.Add([pscustomobject]@{
            Operation = 'copy JUnit result'
            Error = $_
        })
    }

    try {
        if (Test-Path -LiteralPath $sharedRunPath) {
            Remove-Item -LiteralPath $sharedRunPath -Recurse -Force -Confirm:$false
        }
    } catch {
        $transportErrors.Add([pscustomobject]@{
            Operation = 'remove shared test run'
            Error = $_
        })
    }

    if ($primaryError) {
        foreach ($transportError in $transportErrors) {
            try {
                Write-BuildMessage -Type Warning -Message "Secondary failure while attempting to $($transportError.Operation): $($transportError.Error.Exception.Message)"
            } catch {
                # Preserve the active runner failure.
            }
        }
        throw $primaryError
    }

    if ($transportErrors.Count -gt 0) {
        for ($index = 1; $index -lt $transportErrors.Count; $index++) {
            try {
                Write-BuildMessage -Type Warning -Message "Secondary failure while attempting to $($transportErrors[$index].Operation): $($transportErrors[$index].Error.Exception.Message)"
            } catch {
                # Preserve the first transport failure.
            }
        }
        throw $transportErrors[0].Error
    }

    # Parse authoritative counts from the JUnit result — never derived from console lines
    $counts = Get-JUnitTestCounts -ResultFile $resultFile

    # Return result object
    $result = [PSCustomObject]@{
        Passed        = [bool]$testsPassed
        Runner        = 'container'
        AppName       = $appJson.name
        TestDir       = $TestDir
        Counts        = $counts
        ResultFile    = $resultFile
    }

    if ($testsPassed) {
        if ($counts) {
            Write-BuildMessage -Type Success -Message "container - $($appJson.name): $(Format-TestCountSummary $counts)"
        } else {
            Write-BuildMessage -Type Success -Message "All tests passed: $($appJson.name) (test counts unavailable - result XML missing)"
        }
    } else {
        if ($counts) {
            Write-BuildMessage -Type Error -Message "container - $($appJson.name): $(Format-TestCountSummary $counts). See results in $OutputDir"
        } else {
            Write-BuildMessage -Type Error -Message "Tests failed: $($appJson.name). See results in $OutputDir"
        }
    }

    return $result
}

# =============================================================================
# Test Result Summary Helpers
# =============================================================================
# Shared by every gate that runs tests (test.ps1's al-runner runner today,
# container-test.ps1's container runner) so summary.json and console totals
# share one shape and one aggregation rule regardless of which gate wrote them.

function ConvertTo-RunRecord {
    param($Result)
    $record = [ordered]@{
        runner     = $Result.Runner
        appName    = $Result.AppName
        dir        = (Split-Path $Result.TestDir -Leaf)
        passed     = $Result.Passed
        counts     = $Result.Counts
        resultFile = $Result.ResultFile
    }
    if ($Result.Filter) { $record.filter = $Result.Filter }
    $record.notices = @($Result.Notices)
    $record
}

function Get-RunnerTotals {
    # Totals are aggregated per runner. Today there is exactly one runner and
    # one run, but the shape stays runner-keyed so a future second runner
    # never overwrites this one's totals.
    param($Results)
    $totals = [ordered]@{}
    foreach ($runner in @($Results | ForEach-Object { $_.Runner } | Select-Object -Unique)) {
        $runnerResults = @($Results | Where-Object { $_.Runner -eq $runner })
        $counted = @($runnerResults | Where-Object { $_.Counts })
        if ($counted.Count -eq 0) {
            # Counts unknown for every run of this runner — null, never zeros
            $totals[$runner] = $null
            continue
        }
        $totals[$runner] = [ordered]@{
            runs          = $runnerResults.Count
            testCodeunits = [int](($counted | ForEach-Object { $_.Counts.testCodeunits } | Measure-Object -Sum).Sum)
            tests         = [int](($counted | ForEach-Object { $_.Counts.tests } | Measure-Object -Sum).Sum)
            testsPassed   = [int](($counted | ForEach-Object { $_.Counts.testsPassed } | Measure-Object -Sum).Sum)
            testsFailed   = [int](($counted | ForEach-Object { $_.Counts.testsFailed } | Measure-Object -Sum).Sum)
            testsSkipped  = [int](($counted | ForEach-Object { $_.Counts.testsSkipped } | Measure-Object -Sum).Sum)
        }
    }
    return $totals
}

function ConvertTo-RepoRelativePath {
    <#
    .SYNOPSIS
        Format a path repo-relative with forward slashes for summary.json.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Path
    )
    $resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    ([System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedPath)) -replace '\\', '/'
}

function Write-TestSummary {
    param(
        [string]$Gate,
        $Results,
        [Parameter(Mandatory)]
        $CoverageBlock,
        $ErrorBlock,
        [string]$Path
    )
    $summary = [ordered]@{
        gate     = $Gate
        totals   = Get-RunnerTotals $Results
        runs     = @($Results | ForEach-Object { ConvertTo-RunRecord $_ })
        coverage = $CoverageBlock
    }
    if ($ErrorBlock) { $summary.error = $ErrorBlock }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Force
}

function Show-RunnerTotals {
    param($Results)
    $totals = Get-RunnerTotals $Results
    foreach ($runner in $totals.Keys) {
        $t = $totals[$runner]
        if ($null -eq $t) {
            Write-BuildMessage -Type Warning -Message "${runner}: test counts unavailable (no parseable result XML)"
            continue
        }
        $runWord = if ($t.runs -eq 1) { 'run' } else { 'runs' }
        Write-BuildMessage -Type Info -Message "${runner}: $($t.runs) $runWord - $($t.tests) tests in $($t.testCodeunits) test codeunits - $($t.testsPassed) passed, $($t.testsFailed) failed, $($t.testsSkipped) skipped"
    }
}

function Invoke-ALUnpublish {
    <#
    .SYNOPSIS
        Unpublish an AL app from a Business Central container
    .PARAMETER AppName
        Name of the app to unpublish
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )

    Write-BuildHeader "App Unpublishing"

    $config = Get-BuildConfig

    Import-BCContainerHelper

    # Check if app is installed
    Write-BuildMessage -Type Step -Message "Checking if app is installed: $AppName"
    try {
        $installedApp = Get-BcContainerAppInfo -containerName $config.ContainerName |
            Where-Object { $_.Name -eq $AppName }
    } catch {
        throw "Failed to check app installation: $_"
    }

    if (-not $installedApp) {
        Write-BuildMessage -Type Info -Message "App not installed, skipping unpublish"
        return
    }

    Write-BuildMessage -Type Detail -Message "App found - Version $($installedApp.Version)"

    # Unpublish the app
    Write-BuildMessage -Type Step -Message "Unpublishing: $AppName"
    try {
        Unpublish-BcContainerApp `
            -containerName $config.ContainerName `
            -name $AppName `
            -unInstall `
            -doNotSaveData `
            -doNotSaveSchema `
            -force
    } catch {
        throw "Failed to unpublish app: $_"
    }
    Write-BuildMessage -Type Success -Message "App unpublished"
}

function Copy-ALSymbolToCache {
    <#
    .SYNOPSIS
        Copy a built app to another app's symbol cache
    .PARAMETER SourceAppDir
        Directory containing the built app
    .PARAMETER TargetAppDir
        Directory of the app that needs the symbol
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceAppDir,

        [Parameter(Mandatory)]
        [string]$TargetAppDir
    )

    Write-BuildHeader 'Local Symbol Provisioning'

    $sourceAppPath = Get-OutputPath $SourceAppDir
    if (-not (Test-Path -LiteralPath $sourceAppPath)) {
        throw "Source app not found: $sourceAppPath. Build first."
    }

    $targetAppJson = Get-AppJsonObject $TargetAppDir
    if (-not $targetAppJson) {
        throw "Target app.json not found in '$TargetAppDir'"
    }

    $targetCacheInfo = Get-SymbolCacheInfo -AppJson $targetAppJson
    $targetPath = Join-Path $targetCacheInfo.CacheDir (Split-Path -Leaf $sourceAppPath)

    Copy-Item -LiteralPath $sourceAppPath -Destination $targetPath -Force
    Write-BuildMessage -Type Success -Message "Symbol provisioned: $(Split-Path -Leaf $sourceAppPath)"
}

# =============================================================================
# Boolean Conversion
# =============================================================================

function ConvertFrom-EnvironmentBoolean {
    <#
    .SYNOPSIS
        Parse a boolean environment override without truthy-string coercion.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    switch ($Value.ToLowerInvariant()) {
        'true' { return $true }
        '1' { return $true }
        'false' { return $false }
        '0' { return $false }
        default {
            throw "Environment variable $Name must be one of: true, false, 1, 0. Received: '$Value'."
        }
    }
}

function ConvertTo-Boolean {
    <#
    .SYNOPSIS
        Convert various value types to boolean
    .DESCRIPTION
        Handles bool, numeric (1/0), and string ('true'/'false') values
    #>
    param($Value)
    if ($Value -is [bool]) { return $Value }
    if ($Value -eq 1 -or $Value -eq '1') { return $true }
    if ($Value -eq 0 -or $Value -eq '0') { return $false }
    if ($Value -is [string]) {
        if ($Value -ieq 'true') { return $true }
        if ($Value -ieq 'false') { return $false }
    }
    return [bool]$Value
}

# =============================================================================
# Breaking-Change Baseline
# =============================================================================

function Get-AppSourceCopSettings {
    <#
    .SYNOPSIS
        Read the committed AppSourceCop.json of an app folder.
    .DESCRIPTION
        Returns $null when the app folder holds no AppSourceCop.json. Otherwise returns Path, Version
        ($null when the key is absent or empty), and BaselinePackageCachePath ($null when the key
        is absent; a relative value is resolved against the app folder with Join-Path, an absolute
        one is kept). Never writes the file.
    .PARAMETER AppDir
        The app folder, which holds app.json and AppSourceCop.json.
    #>
    param([Parameter(Mandatory)][string]$AppDir)

    $path = Join-Path $AppDir 'AppSourceCop.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    try {
        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "AppSourceCop.json at '$path' is not valid JSON: $($_.Exception.Message)"
    }

    $read = {
        param([string]$Name)
        $property = if ($json) { $json.PSObject.Properties[$Name] } else { $null }
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) { return [string]$property.Value }
        return $null
    }

    $cachePath = & $read 'baselinePackageCachePath'
    if ($cachePath -and -not [System.IO.Path]::IsPathRooted($cachePath)) {
        $cachePath = Join-Path $AppDir $cachePath
    }

    return [PSCustomObject]@{
        Path                     = $path
        Version                  = & $read 'version'
        BaselinePackageCachePath = $cachePath
    }
}

function Test-BaselineFoldersDistinct {
    <#
    .SYNOPSIS
        Test that the Release .app folder and the compile baseline folder are two folders.
    .DESCRIPTION
        Returns $false when the two paths name one folder, $true otherwise. Each path is compared
        by its full path, without a trailing separator, ignoring case. A relative path resolves
        against the current location, so callers pass the paths each key resolves to from its own
        base: breakingChange.releaseAppDir from the repo root, AppSourceCop.json's
        baselinePackageCachePath from the app folder.
    .PARAMETER ReleaseAppDir
        The folder breakingChange.releaseAppDir resolves to.
    .PARAMETER BaselinePackageCachePath
        The folder AppSourceCop.json's baselinePackageCachePath resolves to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ReleaseAppDir,
        [Parameter(Mandatory)][string]$BaselinePackageCachePath
    )

    $normalize = {
        param([string]$Path)
        $rooted = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $PWD.Path $Path }
        [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($rooted))
    }
    return -not ((& $normalize $ReleaseAppDir) -ieq (& $normalize $BaselinePackageCachePath))
}

function Find-ReleaseApp {
    <#
    .SYNOPSIS
        Find the .app files in a folder whose manifest carries an app id and version.
    .DESCRIPTION
        Reads each .app's manifest through Read-AppManifest (symbol-feed.psm1), so the file name
        plays no part: a feed-style name without spaces and a compiler-style name with spaces match
        alike. A .app whose manifest cannot be read is skipped with a warning. Returns every match
        as a FileInfo, an empty array when the folder is missing or nothing matches.
    .PARAMETER Folder
        The folder to search; it is not searched recursively.
    .PARAMETER AppId
        The app id from app.json.
    .PARAMETER Version
        The version AppSourceCop.json pins, compared with the manifest's 4-part version as written.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$AppId,
        [Parameter(Mandatory)][string]$Version
    )

    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return @() }

    $found = @()
    foreach ($file in Get-ChildItem -LiteralPath $Folder -Filter '*.app' -File) {
        try {
            $manifest = Read-AppManifest -Path $file.FullName
        } catch {
            Write-BuildMessage -Type Warning -Message "Skipping $($file.Name): $($_.Exception.Message)"
            continue
        }
        if ($manifest.Id.Trim('{}') -ieq $AppId.Trim('{}') -and $manifest.Version -eq $Version.Trim()) {
            $found += $file
        }
    }
    return $found
}

function Test-SymbolOnlyApp {
    <#
    .SYNOPSIS
        Test whether a .app holds symbols only, through `al IsSymbolOnly`.
    .DESCRIPTION
        Runs `al IsSymbolOnly <path>` from the provisioned compiler that Get-LatestCompilerInfo
        names. AL CLI 30.0 exits 0 for both answers and prints `Extension is symbol-only: True` or
        `Extension is symbol-only: False`; a missing file exits 1 with a message. Throws when the
        compiler is not provisioned, when the command exits non-zero, or when its output holds no
        answer.
    .PARAMETER Path
        The .app file.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $compilerInfo = Get-LatestCompilerInfo
    $output = @(& $compilerInfo.CommandPath IsSymbolOnly $Path 2>&1 | ForEach-Object { "$_" })
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    if ($exitCode -ne 0) {
        throw "al IsSymbolOnly failed for '$Path' (exit $exitCode): $text"
    }
    if ($text -match 'symbol-only:\s*(True|False)') {
        return $Matches[1] -ieq 'True'
    }
    throw "al IsSymbolOnly gave no answer for '$Path': $text"
}

function Get-AlValidationVerdict {
    <#
    .SYNOPSIS
        Classify Run-AlValidation's returned result lines into a verdict.
    .DESCRIPTION
        Run-AlValidation (without -throwOnError) returns its accumulated
        $validationResult strings: AppSourceCop findings from Run-AlCops plus
        environment errors its internal catch tags with the prefix
        "Unexpected error while validating app". The two demand different
        responses — a finding stops for a human, an environment failure is
        fix-and-re-run — so the verdict splits them. Any finding outranks
        environment errors: a run that both found a break and hit an
        environment error is still a detected break.
    .PARAMETER ValidationResult
        The lines Run-AlValidation returned. Empty/blank lines are noise
        (Run-AlCops appends separators) and are ignored.
    #>
    param(
        [AllowEmptyCollection()][string[]]$ValidationResult = @()
    )
    $envErrorPattern = '^Unexpected error while validating app'
    $lines = @($ValidationResult | Where-Object { $_ -and $_.Trim() })
    $environmentErrors = @($lines | Where-Object { $_ -match $envErrorPattern })
    $findings = @($lines | Where-Object { $_ -notmatch $envErrorPattern })
    $verdict = if ($findings.Count -gt 0) { 'BreakingChange' }
    elseif ($environmentErrors.Count -gt 0) { 'EnvironmentError' }
    else { 'Passed' }
    return [PSCustomObject]@{
        Verdict           = $verdict
        Findings          = $findings
        EnvironmentErrors = $environmentErrors
    }
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    # Configuration
    'Get-BuildConfig'
    'Resolve-CoverageEnabled'
    'Get-CompileTargets'
    'Set-BuildEnvironment'
    'ConvertTo-Boolean'

    # Breaking-change baseline
    'Get-AppSourceCopSettings'
    'Test-BaselineFoldersDistinct'
    'Find-ReleaseApp'
    'Test-SymbolOnlyApp'
    'Get-AlValidationVerdict'

    # Compiler
    'Get-ToolPackageId'
    'Install-ALCompiler'
    'Install-ALCompilerChannel'
    'Get-ToolCommandPath'
    'Get-RequiredRuntimeMajor'
    'Get-InstalledCompilerVersion'
    'Get-LatestCompilerPath'
    'Select-CompilerCandidate'
    'Install-ALCops'

    # Build
    'Invoke-ALBuild'

    # Publish
    'Invoke-ALPublish'
    'Invoke-ALUnpublish'

    # Test
    'Invoke-ALTest'
    'Get-JUnitTestCounts'
    'Format-TestCountSummary'

    # Test Result Summary
    'ConvertTo-RunRecord'
    'Get-RunnerTotals'
    'ConvertTo-RepoRelativePath'
    'Write-TestSummary'
    'Show-RunnerTotals'

    # AL Runner
    'Install-ALRunner'
    'ConvertTo-ALRunnerVersion'

    # Local Symbols
    'Copy-ALSymbolToCache'
)
