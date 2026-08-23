#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $script:LauncherPath = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts' 'start-business-central-mcp.ps1'
    $script:LauncherModulePath = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts' 'business-central-mcp.psm1'
    $script:ManifestPath = Join-Path $script:RepoRoot '.mcp.json'
    $script:CompanyNpxPath = 'C:\Program Files\nodejs\npx.cmd'
    $script:ExpectedTools = @(
        'bc_open_page'
        'bc_read_data'
        'bc_write_data'
        'bc_execute_action'
        'bc_close_page'
        'bc_search_pages'
        'bc_navigate'
        'bc_respond_dialog'
        'bc_switch_company'
        'bc_list_companies'
        'bc_run_report'
        'bc_wizard_navigate'
        'bc_lookup'
    )
    $script:ManagedEnvironmentNames = @(
        'ALBT_BC_CONTAINER_USERNAME'
        'ALBT_BC_CONTAINER_PASSWORD'
        'ALBT_BC_CONTAINER_AUTH'
        'ALBT_BC_SERVER_INSTANCE'
        'ALBT_BC_TENANT'
        'BC_MCP_TEST_CAPTURE'
        'USERPROFILE'
        'HOME'
    )

    function New-BusinessCentralMcpConsumerRepo {
        param(
            [Parameter(Mandatory)]
            [string]$Root,

            [string]$Branch = 'feature/mcp+smoke',

            [AllowNull()]
            [string]$ConfigContent = @'
{
  "appDir": "app",
  "testApps": [],
  "serverInstance": "ConfigInstance",
  "container": {
    "username": "config-user",
    "password": "config-password",
    "auth": "UserPassword"
  },
  "tenant": "config-tenant"
}
'@
        )

        $null = New-Item -ItemType Directory -Path $Root -Force
        & git -C $Root init --quiet --initial-branch main
        & git -C $Root config user.email 'mcp-tests@example.invalid'
        & git -C $Root config user.name 'MCP Tests'
        Set-Content -LiteralPath (Join-Path $Root '.fixture') -Value 'fixture' -Encoding utf8
        if ($null -ne $ConfigContent) {
            Set-Content -LiteralPath (Join-Path $Root 'al-build.json') -Value $ConfigContent -Encoding utf8
        }
        & git -C $Root add .
        & git -C $Root commit --quiet -m 'Create fixture'
        & git -C $Root checkout --quiet -b $Branch
        if ($LASTEXITCODE -ne 0) {
            throw "Could not create test branch '$Branch'."
        }
    }

    function New-FakeNpx {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        Set-Content -LiteralPath $Path -Encoding utf8 -Value @'
#Requires -Version 7.2

$capture = [ordered]@{
    Args          = @($args)
    BaseUrl       = $env:BC_BASE_URL
    Username      = $env:BC_USERNAME
    Password      = $env:BC_PASSWORD
    Tenant        = $env:BC_TENANT_ID
    Auth          = $env:BC_AUTH
    ApplicationId = $env:BC_APPLICATION_ID
    LogDir        = $env:LOG_DIR
    StateDir      = $env:STATE_DIR
    WorkingDir    = (Get-Location).Path
}
$capture | ConvertTo-Json -Compress |
    Set-Content -LiteralPath $env:BC_MCP_TEST_CAPTURE -Encoding utf8
[Console]::Error.WriteLine('[fake-npx] diagnostic')
[Console]::Out.WriteLine('{"jsonrpc":"2.0","id":1,"result":{"ok":true}}')
$global:LASTEXITCODE = 0
'@
    }

    function Invoke-BusinessCentralMcpLauncher {
        param(
            [Parameter(Mandatory)]
            [string]$ConsumerRoot,

            [hashtable]$Environment = @{}
        )

        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $caseRoot -Force
        $fakeNpxPath = Join-Path $caseRoot 'fake-npx.ps1'
        $capturePath = Join-Path $caseRoot 'capture.json'
        $stdoutPath = Join-Path $caseRoot 'stdout.txt'
        $stderrPath = Join-Path $caseRoot 'stderr.txt'
        $userHome = Join-Path $caseRoot 'user'
        New-FakeNpx -Path $fakeNpxPath

        $savedEnvironment = @{}
        foreach ($name in $script:ManagedEnvironmentNames) {
            $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }

        try {
            [Environment]::SetEnvironmentVariable('BC_MCP_TEST_CAPTURE', $capturePath, 'Process')
            [Environment]::SetEnvironmentVariable('USERPROFILE', $userHome, 'Process')
            [Environment]::SetEnvironmentVariable('HOME', $userHome, 'Process')
            foreach ($entry in $Environment.GetEnumerator()) {
                [Environment]::SetEnvironmentVariable($entry.Key, [string]$entry.Value, 'Process')
            }

            Push-Location $ConsumerRoot
            try {
                & pwsh -NoLogo -NoProfile -NonInteractive -File $script:LauncherPath `
                    -NpxPath $fakeNpxPath 1> $stdoutPath 2> $stderrPath
                $exitCode = $LASTEXITCODE
            } finally {
                Pop-Location
            }
        } finally {
            foreach ($name in $script:ManagedEnvironmentNames) {
                [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
            }
        }

        return [pscustomobject]@{
            ExitCode = $exitCode
            StdOut   = if (Test-Path -LiteralPath $stdoutPath) {
                Get-Content -LiteralPath $stdoutPath -Raw
            } else {
                ''
            }
            StdErr   = if (Test-Path -LiteralPath $stderrPath) {
                Get-Content -LiteralPath $stderrPath -Raw
            } else {
                ''
            }
            Capture  = if (Test-Path -LiteralPath $capturePath) {
                Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
            } else {
                $null
            }
            UserHome = $userHome
        }
    }
}

Describe 'Bundled business-central MCP contract' {
    It 'uses the plugin root launcher and exposes exactly the 13 Web Client tools' {
        $manifest = Get-Content -LiteralPath $script:ManifestPath -Raw | ConvertFrom-Json
        $server = $manifest.mcpServers.'business-central'

        $server.type | Should -Be 'stdio'
        $server.command | Should -Be 'pwsh'
        ($server.args -join ' ') | Should -Match '\$env:COPILOT_PLUGIN_ROOT'
        ($server.args -join ' ') | Should -Match 'start-business-central-mcp\.ps1'
        @($server.tools).Count | Should -Be 13
        Compare-Object -ReferenceObject $script:ExpectedTools -DifferenceObject @($server.tools) |
            Should -BeNullOrEmpty
        @($server.tools) | Should -Not -Contain 'bc_query'
    }

    It 'delegates branch and configuration resolution to al-build and leaves the package unpinned' {
        $launcher = Get-Content -LiteralPath $script:LauncherPath -Raw
        $module = Get-Content -LiteralPath $script:LauncherModulePath -Raw

        $launcher | Should -Match "Import-Module .*common\.psm1"
        $launcher | Should -Match "Import-Module .*build-operations\.psm1"
        $launcher | Should -Match '\$config = Get-BuildConfig'
        $launcher | Should -Not -Match 'rev-parse|docker'
        $launcher | Should -Match ([regex]::Escape("C:\Program Files\nodejs\npx.cmd"))
        $module | Should -Match (
            [regex]::Escape("`$script:BusinessCentralMcpPackage = 'business-central-mcp'")
        )
    }

    It 'maps branch, ALBT overrides, tenant, and server instance without polluting stdout' {
        $consumerRoot = Join-Path $TestDrive 'configured-consumer'
        New-BusinessCentralMcpConsumerRepo -Root $consumerRoot
        $secret = 'override-secret-value'

        $result = Invoke-BusinessCentralMcpLauncher -ConsumerRoot $consumerRoot -Environment @{
            ALBT_BC_CONTAINER_USERNAME = 'override-user'
            ALBT_BC_CONTAINER_PASSWORD = $secret
            ALBT_BC_CONTAINER_AUTH     = 'UserPassword'
            ALBT_BC_SERVER_INSTANCE    = 'CustomInstance'
            ALBT_BC_TENANT             = 'tenant-42'
        }

        $result.ExitCode | Should -Be 0
        $result.StdOut.Trim() | Should -Be '{"jsonrpc":"2.0","id":1,"result":{"ok":true}}'
        $result.StdErr | Should -Match 'Starting business-central-mcp'
        $result.StdErr | Should -Not -Match ([regex]::Escape($secret))
        $result.Capture.Args | Should -Be @('-y', 'business-central-mcp')
        ($result.Capture.Args -join ' ') | Should -Not -Match ([regex]::Escape($secret))
        $result.Capture.BaseUrl | Should -Be 'http://feature-mcpsmoke/CustomInstance'
        $result.Capture.Username | Should -Be 'override-user'
        $result.Capture.Password | Should -Be $secret
        $result.Capture.Tenant | Should -Be 'tenant-42'
        $result.Capture.Auth | Should -Be 'NavUserPassword'
        $result.Capture.ApplicationId | Should -Be 'NAV'
        $result.Capture.WorkingDir | Should -Be ([IO.Path]::GetFullPath($consumerRoot))

        $copilotMcpRoot = Join-Path $result.UserHome '.copilot' 'business-central-mcp'
        $result.Capture.LogDir.StartsWith($copilotMcpRoot, [StringComparison]::OrdinalIgnoreCase) |
            Should -BeTrue
        $result.Capture.StateDir.StartsWith($copilotMcpRoot, [StringComparison]::OrdinalIgnoreCase) |
            Should -BeTrue
        $result.Capture.LogDir.StartsWith($consumerRoot, [StringComparison]::OrdinalIgnoreCase) |
            Should -BeFalse
        $result.Capture.StateDir.StartsWith($consumerRoot, [StringComparison]::OrdinalIgnoreCase) |
            Should -BeFalse
        (Split-Path (Split-Path $result.Capture.LogDir -Parent) -Leaf) |
            Should -Be 'feature-mcpsmoke'
        Test-Path -LiteralPath $result.Capture.LogDir -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $result.Capture.StateDir -PathType Container | Should -BeTrue
    }

    It 'fails cleanly when al-build.json is missing' {
        $consumerRoot = Join-Path $TestDrive 'missing-config'
        New-BusinessCentralMcpConsumerRepo -Root $consumerRoot -ConfigContent $null

        $result = Invoke-BusinessCentralMcpLauncher -ConsumerRoot $consumerRoot

        $result.ExitCode | Should -Be 1
        $result.StdOut | Should -BeNullOrEmpty
        $result.StdErr | Should -Match 'Could not load al-build configuration'
        $result.StdErr | Should -Match ([regex]::Escape((Join-Path $consumerRoot 'al-build.json')))
    }

    It 'fails malformed configuration without disclosing its secret' {
        $consumerRoot = Join-Path $TestDrive 'malformed-config'
        $secret = 'malformed-secret-value'
        New-BusinessCentralMcpConsumerRepo -Root $consumerRoot `
            -ConfigContent "{`"container`":{`"password`":`"$secret`"},`"tenant`":"

        $result = Invoke-BusinessCentralMcpLauncher -ConsumerRoot $consumerRoot

        $result.ExitCode | Should -Be 1
        $result.StdOut | Should -BeNullOrEmpty
        $result.StdErr | Should -Match 'Could not load al-build configuration'
        $result.StdErr | Should -Not -Match ([regex]::Escape($secret))
    }

    It 'rejects unsupported container authentication without disclosing the password' {
        $consumerRoot = Join-Path $TestDrive 'unsupported-auth'
        $secret = 'unsupported-auth-secret'
        $config = @{
            appDir        = 'app'
            testApps      = @()
            serverInstance = 'BC'
            container     = @{
                username = 'admin'
                password = $secret
                auth     = 'Windows'
            }
            tenant        = 'default'
        } | ConvertTo-Json -Depth 4
        New-BusinessCentralMcpConsumerRepo -Root $consumerRoot -ConfigContent $config

        $result = Invoke-BusinessCentralMcpLauncher -ConsumerRoot $consumerRoot -Environment @{
            ALBT_BC_CONTAINER_AUTH = 'Windows'
        }

        $result.ExitCode | Should -Be 1
        $result.StdOut | Should -BeNullOrEmpty
        $result.StdErr | Should -Match "Unsupported Business Central container authentication mode 'Windows'"
        $result.StdErr | Should -Not -Match ([regex]::Escape($secret))
    }
}

Describe 'business-central-mcp stdio smoke' -Tag 'McpSmoke' {
    It 'initializes and reports the upstream 14 tools without a running container' `
        -Skip:($env:ALBT_RUN_BUSINESS_CENTRAL_MCP_SMOKE -ne '1' -or
            -not (Test-Path -LiteralPath 'C:\Program Files\nodejs\npx.cmd' -PathType Leaf)) {
        $consumerRoot = Join-Path $TestDrive 'stdio-smoke'
        $userHome = Join-Path $TestDrive 'stdio-smoke-user'
        New-BusinessCentralMcpConsumerRepo -Root $consumerRoot -Branch 'feature/mcp-smoke'

        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = 'pwsh'
        $startInfo.WorkingDirectory = $consumerRoot
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @(
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-File',
            $script:LauncherPath
        )) {
            $null = $startInfo.ArgumentList.Add($argument)
        }
        $startInfo.Environment['USERPROFILE'] = $userHome
        $startInfo.Environment['HOME'] = $userHome

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            $process.Start() | Should -BeTrue
            $initialize = @{
                jsonrpc = '2.0'
                id = 1
                method = 'initialize'
                params = @{
                    protocolVersion = '2024-11-05'
                    capabilities = @{}
                    clientInfo = @{ name = 'al-agentic-dev-smoke'; version = '1.0.0' }
                }
            } | ConvertTo-Json -Depth 5 -Compress
            $initialized = @{
                jsonrpc = '2.0'
                method = 'notifications/initialized'
                params = @{}
            } | ConvertTo-Json -Depth 3 -Compress
            $toolsList = @{
                jsonrpc = '2.0'
                id = 2
                method = 'tools/list'
                params = @{}
            } | ConvertTo-Json -Depth 3 -Compress

            $process.StandardInput.WriteLine($initialize)
            $process.StandardInput.WriteLine($initialized)
            $process.StandardInput.WriteLine($toolsList)
            $process.StandardInput.Flush()

            $initializeResponse = $process.StandardOutput.ReadLineAsync().
                WaitAsync([TimeSpan]::FromSeconds(60)).GetAwaiter().GetResult() |
                ConvertFrom-Json
            $toolsResponse = $process.StandardOutput.ReadLineAsync().
                WaitAsync([TimeSpan]::FromSeconds(60)).GetAwaiter().GetResult() |
                ConvertFrom-Json

            $initializeResponse.id | Should -Be 1
            $toolsResponse.id | Should -Be 2
            @($toolsResponse.result.tools).Count | Should -Be 14
            $toolNames = @($toolsResponse.result.tools | ForEach-Object name)
            Compare-Object -ReferenceObject ($script:ExpectedTools + 'bc_query') `
                -DifferenceObject $toolNames | Should -BeNullOrEmpty

            $process.StandardInput.Close()
            $process.WaitForExit(10000) | Should -BeTrue
            $process.ExitCode | Should -Be 0
        } finally {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            $process.Dispose()
        }
    }
}
