#Requires -Version 7.2

# publish-apps.ps1 runs under Set-StrictMode -Version Latest, so a reference to a
# config property Get-BuildConfig no longer exposes throws at runtime — and the
# script has no live-container test to catch it. These surface assertions pin
# the script to the current config model. The re-assert and the result live in
# exported common.psm1 functions, because the script re-imports its modules with
# -Force and needs a real container; the script itself is pinned by surface and
# AST assertions, and the functions are tested directly.
# BcContainerHelper and docker are absent on the CI runner, so the commands the
# code under test calls get global stubs when they are absent.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'publish-apps.ps1'
    $script:Content = Get-Content -LiteralPath $script:ScriptPath -Raw
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'build-operations.psm1') -Force -DisableNameChecking

    $script:StubbedCommands = @()
    foreach ($name in 'Get-BcContainerServerConfiguration', 'Set-BcContainerServerConfiguration', 'Restart-BcContainerServiceTier') {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            $script:StubbedCommands += $name
            Set-Item -Path "function:global:$name" -Value { param([string]$containerName, [string]$keyName, [string]$keyValue) }
        }
    }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $script:StubbedCommands += 'docker'
        Set-Item -Path 'function:global:docker' -Value { }
    }

    function script:New-HostsFile {
        param([string[]]$Lines = @())
        $path = Join-Path $TestDrive ('hosts-' + [guid]::NewGuid().ToString('N'))
        Set-Content -LiteralPath $path -Value (@('127.0.0.1       localhost') + $Lines) -Encoding ascii
        return $path
    }

    # Lines that name the host, so a stray blank line never changes a count.
    function script:Get-HostLines {
        param([string]$Path, [string]$Hostname)
        @(Get-Content -LiteralPath $Path | Where-Object { $_ -match "^\s*\S+\s+$([regex]::Escape($Hostname))(\s|#|$)" })
    }

    # The four labelled result lines on the information stream, one string each.
    function script:Get-ResultLines {
        param([scriptblock]$Run)
        @(& $Run 6>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match '^(Commit|Version|Web Client|Username): ' })
    }

    function script:Get-ScriptAst {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw "publish-apps.ps1 has parse errors: $($parseErrors.Message -join '; ')" }
        return $ast
    }
}

AfterAll {
    foreach ($name in $script:StubbedCommands) {
        Remove-Item "function:global:$name" -ErrorAction SilentlyContinue
    }
}

Describe 'publish-apps.ps1 surface' {
    It 'references only properties Get-BuildConfig exposes' {
        $configProps = @('AppDir', 'TestApps', 'ContainerTestApps', 'ContainerName', 'ContainerUsername')
        $referenced = [regex]::Matches($script:Content, '\$config\.(\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $referenced | Should -Not -BeNullOrEmpty
        foreach ($prop in $referenced) {
            $prop | Should -BeIn $configProps
        }
    }

    It 'carries no retired unit-test-app vocabulary' {
        $script:Content | Should -Not -Match 'UnitTestApp|unitTestApp|UnitTestInitEvents|publish-unit-'
    }

    It 'derives the secondary publish set from Get-CompileTargets' {
        $script:Content | Should -Match 'Get-CompileTargets -Config \$config'
    }

    It 'parses under strict mode' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }
}

Describe 'publish-apps.ps1 call order' {
    BeforeAll {
        $script:Ast = Get-ScriptAst
        $script:Commands = @($script:Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))

        function script:Get-CommandsNamed {
            param([string]$Name)
            @($script:Commands | Where-Object { $_.GetCommandName() -eq $Name })
        }
    }

    It 're-asserts the host once, after Ensure-BCAgentContainer and before the first unpublish' {
        $sync = Get-CommandsNamed 'Sync-BCAgentContainerHost'
        $sync | Should -HaveCount 1
        $ensure = Get-CommandsNamed 'Ensure-BCAgentContainer'
        $ensure | Should -HaveCount 1
        $unpublish = @(Get-CommandsNamed 'Invoke-ALUnpublish')
        $unpublish | Should -Not -BeNullOrEmpty
        $sync[0].Extent.StartOffset | Should -BeGreaterThan $ensure[0].Extent.StartOffset
        $sync[0].Extent.StartOffset | Should -BeLessThan ($unpublish | ForEach-Object { $_.Extent.StartOffset } | Measure-Object -Minimum).Minimum
    }

    It 'exits non-zero with an Error when the re-assert fails, before any result' {
        $call = (Get-CommandsNamed 'Sync-BCAgentContainerHost')[0]
        $try = $call.Parent
        while ($try -and $try -isnot [System.Management.Automation.Language.TryStatementAst]) { $try = $try.Parent }
        $try | Should -Not -BeNullOrEmpty
        $try.CatchClauses | Should -HaveCount 1
        $try.CatchClauses[0].Body.Extent.Text | Should -Match '(?s)-Type Error.*exit \$Exit\.Integration\s*\}$'
    }

    It 'writes the result as the last step, after every Invoke-ALPublish and the timing history' {
        $result = Get-CommandsNamed 'Write-RepublishResult'
        $result | Should -HaveCount 1
        $last = $script:Ast.EndBlock.Statements[-1]
        $last.Extent.Text | Should -Match '^Write-RepublishResult\b'
        foreach ($publish in Get-CommandsNamed 'Invoke-ALPublish') {
            $result[0].Extent.StartOffset | Should -BeGreaterThan $publish.Extent.StartOffset
        }
        $history = Get-CommandsNamed 'Show-BuildTimingHistory'
        $result[0].Extent.StartOffset | Should -BeGreaterThan $history[0].Extent.StartOffset
        $complete = $script:Content.IndexOf("Write-BuildHeader 'Publish Complete'")
        $complete | Should -BeGreaterThan -1
        $result[0].Extent.StartOffset | Should -BeGreaterThan $complete
    }

    It 'passes the config, the main app.json and the URL the re-assert returned to the result' {
        $script:Content | Should -Match '(?s)\$webClientUrl\s*=\s*Sync-BCAgentContainerHost'
        $script:Content | Should -Match 'Write-RepublishResult\b[^\r\n]*-Config \$config\b'
        $script:Content | Should -Match 'Write-RepublishResult\b[^\r\n]*-AppJson \$mainAppJson\b'
        $script:Content | Should -Match 'Write-RepublishResult\b[^\r\n]*-WebClientUrl \$webClientUrl\b'
    }

    It 'closes the sync-host timing step in a finally, so a thrown re-assert still stops it' {
        $call = (Get-CommandsNamed 'Sync-BCAgentContainerHost')[0]
        $try = $call.Parent
        while ($try -and $try -isnot [System.Management.Automation.Language.TryStatementAst]) { $try = $try.Parent }
        $try.Finally.Extent.Text | Should -Match "Stop-Step 'sync-host'"
    }
}

Describe 'Write-RepublishResult' {
    BeforeAll {
        # The real inputs: a config and a main app.json read from disk.
        $script:Config = [pscustomobject]@{ ContainerName = 'feat-x'; ContainerUsername = 'walker' }
        $appDir = Join-Path $TestDrive 'main-app'
        New-Item -ItemType Directory -Path $appDir | Out-Null
        Set-Content -LiteralPath (Join-Path $appDir 'app.json') -Value '{ "name": "Main", "version": "27.3.1.0" }'
        $script:AppJson = Get-AppJsonObject $appDir
        $script:Url = 'http://feat-x.test:7080/BC/'
    }

    It 'names the commit, the version, a URL on the .test host, and the username' {
        InModuleScope common -Parameters @{ Config = $script:Config; AppJson = $script:AppJson; Url = $script:Url } {
            param($Config, $AppJson, $Url)
            Mock Get-DeployedCommit { 'abc1234' }
            $lines = @(& { Write-RepublishResult -Config $Config -AppJson $AppJson -WebClientUrl $Url } 6>&1 | ForEach-Object { "$_" })
            $lines | Should -Contain 'Commit: abc1234'
            $lines | Should -Contain 'Version: 27.3.1.0'
            $lines | Should -Contain 'Web Client: http://feat-x.test:7080/BC/'
            $lines | Should -Contain 'Username: walker'
        }
    }

    It 'writes every line on the information stream while VerbosePreference is SilentlyContinue' {
        InModuleScope common -Parameters @{ Config = $script:Config; AppJson = $script:AppJson; Url = $script:Url } {
            param($Config, $AppJson, $Url)
            Mock Get-DeployedCommit { 'abc1234' }
            $VerbosePreference = 'SilentlyContinue'
            $info = @(& { Write-RepublishResult -Config $Config -AppJson $AppJson -WebClientUrl $Url } 6>&1 | ForEach-Object { "$_" })
            foreach ($label in 'Commit: abc1234', 'Version: 27.3.1.0', 'Web Client: http://feat-x.test:7080/BC/', 'Username: walker') {
                $info | Should -Contain $label
            }
            $verbose = @(& { Write-RepublishResult -Config $Config -AppJson $AppJson -WebClientUrl $Url } 6>$null 4>&1)
            $verbose | Should -HaveCount 0
        }
    }

    It 'throws, and writes no result line, when the main app has no app.json' {
        InModuleScope common -Parameters @{ Config = $script:Config; Url = $script:Url } {
            param($Config, $Url)
            Mock Get-DeployedCommit { 'abc1234' }
            $lines = [System.Collections.Generic.List[string]]::new()
            { & { Write-RepublishResult -Config $Config -AppJson $null -WebClientUrl $Url } 6>&1 | ForEach-Object { $lines.Add("$_") } } |
                Should -Throw '*app.json*'
            $lines | Should -HaveCount 0
        }
    }
}

Describe 'Write-RepublishResult commit line' -Tag 'Process' {
    BeforeAll {
        function script:Invoke-Git {
            param([string[]]$GitArgs)
            & git @GitArgs 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed" }
        }
        function script:New-Repo {
            param([switch]$NoCommit)
            $repo = Join-Path $TestDrive ('repo-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $repo | Out-Null
            Push-Location $repo
            try {
                Invoke-Git @('init', '-q')
                Invoke-Git @('config', 'user.email', 'test@example.com')
                Invoke-Git @('config', 'user.name', 'Test')
                Invoke-Git @('config', 'commit.gpgsign', 'false')
                New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
                if (-not $NoCommit) {
                    Set-Content -LiteralPath (Join-Path $repo 'tracked.txt') -Value 'one'
                    Invoke-Git @('add', 'tracked.txt')
                    Invoke-Git @('commit', '-q', '-m', 'first')
                }
            }
            finally { Pop-Location }
            return $repo
        }
        # The commit line a result written from $Cwd carries.
        function script:Get-CommitLine {
            param([string]$Cwd)
            $config = [pscustomobject]@{ ContainerUsername = 'walker' }
            $appJson = [pscustomobject]@{ version = '1.0.0.0' }
            Push-Location $Cwd
            try {
                $lines = Get-ResultLines { Write-RepublishResult -Config $config -AppJson $appJson -WebClientUrl 'http://feat-x.test/BC/' }
            }
            finally { Pop-Location }
            return @($lines | Where-Object { $_ -like 'Commit: *' })
        }
        function script:Get-HeadShort {
            param([string]$Repo)
            Push-Location $Repo
            try { return ([string](& git rev-parse --short HEAD)).Trim() }
            finally { Pop-Location }
        }
    }

    It 'reports the HEAD short SHA, unmarked, on a clean tree' {
        $repo = New-Repo
        $line = @(Get-CommitLine $repo)
        $line | Should -HaveCount 1
        $line[0] | Should -Be "Commit: $(Get-HeadShort $repo)"
    }

    It 'marks the commit when a tracked file has uncommitted changes' {
        $repo = New-Repo
        Set-Content -LiteralPath (Join-Path $repo 'tracked.txt') -Value 'two'
        $line = @(Get-CommitLine $repo)
        $line | Should -HaveCount 1
        $line[0] | Should -Be "Commit: $(Get-HeadShort $repo) (uncommitted changes)"
    }

    It 'leaves the commit unmarked when only an untracked file exists' {
        $repo = New-Repo
        Set-Content -LiteralPath (Join-Path $repo 'untracked.txt') -Value 'new'
        $line = @(Get-CommitLine $repo)
        $line | Should -HaveCount 1
        $line[0] | Should -Be "Commit: $(Get-HeadShort $repo)"
    }

    It 'reads the repository root when it runs from a subdirectory, including its dirty state' {
        $repo = New-Repo
        Set-Content -LiteralPath (Join-Path $repo 'tracked.txt') -Value 'two'
        $line = @(Get-CommitLine (Join-Path $repo 'sub'))
        $line | Should -HaveCount 1
        $line[0] | Should -Be "Commit: $(Get-HeadShort $repo) (uncommitted changes)"
    }

    It 'says there are no commits in a repository without one' {
        $repo = New-Repo -NoCommit
        $line = @(Get-CommitLine $repo)
        $line | Should -HaveCount 1
        $line[0] | Should -Be 'Commit: (no commits)'
    }

    It 'says so outside a git repository' {
        $plain = Join-Path $TestDrive ('plain-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $plain | Out-Null
        $line = @(Get-CommitLine $plain)
        $line | Should -HaveCount 1
        $line[0] | Should -Be 'Commit: (not a git repository)'
    }
}

Describe 'Sync-BCAgentContainerHost' {
    BeforeEach {
        # The in-container .test mapping has its own Describe; here it must not reach a container.
        Mock Set-BCContainerInternalHost {} -ModuleName common
    }

    It 'adds both hosts lines with the current IP when the container had none' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '172.28.0.9' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x.test:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts | Out-Null
        }
        $bare = @(Get-HostLines -Path $hosts -Hostname 'feat-x')
        $test = @(Get-HostLines -Path $hosts -Hostname 'feat-x.test')
        $bare | Should -HaveCount 1
        $test | Should -HaveCount 1
        ($bare[0] -split '\s+')[0] | Should -Be '172.28.0.9'
        ($test[0] -split '\s+')[0] | Should -Be '172.28.0.9'
    }

    It 'replaces both hosts lines that sit on an old IP' {
        $hosts = New-HostsFile -Lines @('172.28.0.5       feat-x', '172.28.0.5       feat-x.test')
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '172.28.0.9' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x.test:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts | Out-Null
        }
        $bare = @(Get-HostLines -Path $hosts -Hostname 'feat-x')
        $test = @(Get-HostLines -Path $hosts -Hostname 'feat-x.test')
        $bare | Should -HaveCount 1
        $test | Should -HaveCount 1
        ($bare[0] -split '\s+')[0] | Should -Be '172.28.0.9'
        ($test[0] -split '\s+')[0] | Should -Be '172.28.0.9'
    }

    It 'sets PublicWebBaseUrl to the .test host when it is on another host, and returns that URL' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '172.28.0.9' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            $url = Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts

            $url | Should -Be 'http://feat-x.test:7080/BC/'
            Should -Invoke Set-BcContainerServerConfiguration -Times 1 -Exactly -ParameterFilter {
                $containerName -eq 'feat-x' -and $keyName -eq 'PublicWebBaseUrl' -and $keyValue -eq 'http://feat-x.test:7080/BC/'
            }
            Should -Invoke Restart-BcContainerServiceTier -Times 1 -Exactly -ParameterFilter { $containerName -eq 'feat-x' }
        }
    }

    It 'makes no set and no restart when PublicWebBaseUrl is already on the .test host' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '172.28.0.9' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x.test:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts | Should -Be 'http://feat-x.test:7080/BC/'

            Should -Invoke Set-BcContainerServerConfiguration -Times 0 -Exactly
            Should -Invoke Restart-BcContainerServiceTier -Times 0 -Exactly
        }
    }

    It 'imports BcContainerHelper before it reads PublicWebBaseUrl' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            $script:order = [System.Collections.Generic.List[string]]::new()
            Mock Import-BCContainerHelper { $script:order.Add('import') }
            Mock docker { '172.28.0.9' }
            Mock Get-BcContainerServerConfiguration { $script:order.Add('read'); [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x.test:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts | Out-Null

            $script:order[0] | Should -Be 'import'
            $script:order | Should -Contain 'read'
        }
    }

    It 'throws when Set-BcContainerServerConfiguration throws' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '172.28.0.9' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration { throw 'service tier unreachable' }
            Mock Restart-BcContainerServiceTier {}

            { Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts } | Should -Throw '*service tier unreachable*'
        }
    }

    It 'takes the first IP of a container on several networks, never the concatenation' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '172.28.0.9 10.0.0.2 ' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x.test:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Get-BCAgentContainerIP -ContainerName 'feat-x' | Should -Be '172.28.0.9'
            Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts | Out-Null
        }
        $bare = @(Get-HostLines -Path $hosts -Hostname 'feat-x')
        $bare | Should -HaveCount 1
        ($bare[0] -split '\s+')[0] | Should -Be '172.28.0.9'
        $bare[0] | Should -Not -Match '10\.0\.0\.2'
    }

    It 'throws, and writes no hosts line, when the container has no IP' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Import-BCContainerHelper {}
            Mock docker { '' }
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            { Sync-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts } | Should -Throw '*No IP*feat-x*'
            Should -Invoke Set-BcContainerServerConfiguration -Times 0 -Exactly
        }
        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 0
    }
}
