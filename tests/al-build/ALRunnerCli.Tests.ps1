#Requires -Version 7.2

BeforeAll {
    $script:ScriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $script:ScriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ScriptsDir 'alrunner-cli.psm1') -Force -DisableNameChecking
    $script:GreenFixture = Join-Path $PSScriptRoot 'fixtures' 'alrunner-cli' 'green-output.json'

    function Write-CliOutputFile {
        param(
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][AllowEmptyString()][string]$Content
        )
        $path = Join-Path $TestDrive $Name
        [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
        $path
    }
}

Describe 'Get-ALRunnerCliArguments' {
    It 'places the bundles first, then --package-cache, --output-json and --output-junit' {
        $arguments = Get-ALRunnerCliArguments -Bundles @('app', 'tests') -PackageCache '.output\al-runner-deps' -JUnitPath '.output\TestResults\al-runner.xml'

        $arguments[0..1] | Should -Be @('app', 'tests')
        $arguments[[array]::IndexOf($arguments, '--package-cache') + 1] | Should -Be '.output\al-runner-deps'
        $arguments | Should -Contain '--output-json'
        $arguments[[array]::IndexOf($arguments, '--output-junit') + 1] | Should -Be '.output\TestResults\al-runner.xml'
    }

    It 'adds --coverage and --coverage-out when coverage is requested' {
        $arguments = Get-ALRunnerCliArguments -Bundles @('app') -PackageCache 'deps' -JUnitPath 'r.xml' -Coverage -CoverageOutPath 'cov\cobertura.xml'

        $arguments | Should -Contain '--coverage'
        $arguments[[array]::IndexOf($arguments, '--coverage-out') + 1] | Should -Be 'cov\cobertura.xml'
    }

    It 'adds neither coverage flag when coverage is off' {
        $arguments = Get-ALRunnerCliArguments -Bundles @('app') -PackageCache 'deps' -JUnitPath 'r.xml'

        $arguments | Should -Not -Contain '--coverage'
        $arguments | Should -Not -Contain '--coverage-out'
    }

    It 'never passes --server or --expectations' {
        $arguments = Get-ALRunnerCliArguments -Bundles @('app') -PackageCache 'deps' -JUnitPath 'r.xml' -Coverage -CoverageOutPath 'c.xml'

        $arguments | Should -Not -Contain '--server'
        $arguments | Should -Not -Contain '--expectations'
    }

    It 'throws when -Coverage arrives without a Cobertura path' {
        { Get-ALRunnerCliArguments -Bundles @('app') -PackageCache 'deps' -JUnitPath 'r.xml' -Coverage } | Should -Throw '*CoverageOutPath*'
    }
}

Describe 'Read-ALRunnerCliOutput' {
    It 'reads the green fixture al-runner 2.10 wrote' {
        $result = Read-ALRunnerCliOutput -Path $script:GreenFixture

        $result.Passed | Should -BeTrue
        $result.ExitCode | Should -Be 0
        $result.Total | Should -Be 1
        $result.PassedCount | Should -Be 1
        $result.Failed | Should -Be 0
        $result.Errors | Should -Be 0
        $result.Tests.Count | Should -Be 1
        $result.Tests[0].Name | Should -Be 'Codeunit60000.InitAppliesItemStatusCalcDefault'
        $result.Tests[0].Status | Should -Be 'pass'
        $result.Tests[0].DurationMs | Should -Be 6
    }

    It 'carries a failed test with its message and reports Passed false' {
        $path = Write-CliOutputFile -Name 'red.json' -Content @'
{"tests":[{"name":"Codeunit1.Good","status":"pass","durationMs":3},{"name":"Codeunit1.Bad","status":"fail","message":"Assert.AreEqual failed. Expected 1, actual 2","stackTrace":"Codeunit1(CodeUnit 1).Bad line 7","durationMs":4}],"passed":1,"failed":1,"errors":0,"skipped":0,"total":2,"exitCode":1,"wallSeconds":2.5}
'@
        $result = Read-ALRunnerCliOutput -Path $path

        $result.Passed | Should -BeFalse
        $result.ExitCode | Should -Be 1
        $result.Failed | Should -Be 1
        ($result.Tests | Where-Object Status -eq 'fail').Message | Should -Be 'Assert.AreEqual failed. Expected 1, actual 2'
    }

    It 'counts an error status as not passed even when exitCode is missing' {
        $path = Write-CliOutputFile -Name 'error.json' -Content '{"tests":[{"name":"Codeunit1.Boom","status":"error","message":"x","durationMs":1}],"passed":0,"failed":0,"errors":1,"skipped":0,"total":1}'

        $result = Read-ALRunnerCliOutput -Path $path

        $result.Passed | Should -BeFalse
        $result.Errors | Should -Be 1
    }

    It 'throws naming the path on an aborted (truncated) document' {
        $path = Write-CliOutputFile -Name 'truncated.json' -Content '{"tests":[{"name":"Codeunit1.A","status":"pass","durationMs":3}'

        { Read-ALRunnerCliOutput -Path $path } | Should -Throw "*$path*"
    }

    It 'throws naming the path on an empty file' {
        $path = Write-CliOutputFile -Name 'empty.json' -Content ''

        { Read-ALRunnerCliOutput -Path $path } | Should -Throw "*$path*"
    }

    It 'throws naming the path when the file is missing' {
        $path = Join-Path $TestDrive 'never-written.json'

        { Read-ALRunnerCliOutput -Path $path } | Should -Throw "*$path*"
    }

    It 'throws naming the missing tests array on a document without it' {
        $path = Write-CliOutputFile -Name 'no-tests.json' -Content '{"exitCode":0}'

        { Read-ALRunnerCliOutput -Path $path } | Should -Throw "*tests*"
    }
}

Describe 'Get-ALRunnerSelectedBcLine' {
    It 'returns the [bc] selected line from the log' {
        $log = Write-CliOutputFile -Name 'al-runner.log' -Content "[dep] A/B 1.0.0.0  <- x.app`n[bc] selected BC 28.1.49838.53910 (C:\artifacts\28.1)`n[expectations] none`n"

        Get-ALRunnerSelectedBcLine -LogPath $log | Should -Be '[bc] selected BC 28.1.49838.53910 (C:\artifacts\28.1)'
    }

    It 'returns nothing when the log has no [bc] selected line or does not exist' {
        $log = Write-CliOutputFile -Name 'quiet.log' -Content "[dep] only`n"

        Get-ALRunnerSelectedBcLine -LogPath $log | Should -BeNullOrEmpty
        Get-ALRunnerSelectedBcLine -LogPath (Join-Path $TestDrive 'missing.log') | Should -BeNullOrEmpty
    }
}

Describe 'Stop-OrphanedALRunnerServer' {
    BeforeEach {
        $script:RepoRoot = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $script:RepoRoot -Force | Out-Null
        Mock Stop-Process {} -ModuleName alrunner-cli
        Mock Write-BuildMessage {} -ModuleName alrunner-cli
    }

    It 'stops a --server child whose --package-cache is inside the repo, by id, and logs it' {
        $cache = Join-Path $script:RepoRoot '.output' 'al-runner-deps'
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{ ProcessId = 4242; CommandLine = "dotnet exec `"C:\Users\x\.dotnet\tools\.store\al-runner.dll`" --server --package-cache `"$cache`"" },
                [pscustomobject]@{ ProcessId = 4243; CommandLine = 'dotnet exec "C:\Users\x\.dotnet\tools\.store\al-runner.dll" --server --package-cache "C:\other\repo\.output\al-runner-deps"' },
                [pscustomobject]@{ ProcessId = 4244; CommandLine = "dotnet exec al-runner.dll app tests --package-cache `"$cache`"" }
            )
        } -ModuleName alrunner-cli

        $stopped = Stop-OrphanedALRunnerServer -RepoRoot $script:RepoRoot

        $stopped | Should -Be @(4242)
        Should -Invoke Stop-Process -ModuleName alrunner-cli -Times 1 -Exactly -ParameterFilter { $Id -eq 4242 }
        Should -Invoke Write-BuildMessage -ModuleName alrunner-cli -ParameterFilter {
            $Message -eq '[i] terminated orphaned al-runner server (pid 4242)'
        }
    }

    It 'touches nothing when no matching process exists' {
        Mock Get-CimInstance { @() } -ModuleName alrunner-cli

        $stopped = Stop-OrphanedALRunnerServer -RepoRoot $script:RepoRoot

        @($stopped).Count | Should -Be 0
        Should -Invoke Stop-Process -ModuleName alrunner-cli -Times 0
    }

    It 'skips a server whose --package-cache is relative — it belongs to that process cwd, not this repo' {
        Mock Get-CimInstance {
            @([pscustomobject]@{ ProcessId = 5150; CommandLine = 'dotnet exec al-runner.dll --server --package-cache .output\al-runner-deps' })
        } -ModuleName alrunner-cli

        $stopped = Stop-OrphanedALRunnerServer -RepoRoot $script:RepoRoot

        @($stopped).Count | Should -Be 0
        Should -Invoke Stop-Process -ModuleName alrunner-cli -Times 0
    }

    It 'reads a quoted --package-cache with spaces whole' {
        $spacedRoot = Join-Path $TestDrive 'repo with space'
        New-Item -ItemType Directory -Path $spacedRoot -Force | Out-Null
        $cache = Join-Path $spacedRoot '.output' 'al-runner-deps'
        Mock Get-CimInstance {
            @([pscustomobject]@{ ProcessId = 6160; CommandLine = "dotnet exec al-runner.dll --server --package-cache `"$cache`" --verbose" })
        } -ModuleName alrunner-cli

        $stopped = Stop-OrphanedALRunnerServer -RepoRoot $spacedRoot

        $stopped | Should -Be @(6160)
        Should -Invoke Stop-Process -ModuleName alrunner-cli -Times 1 -Exactly -ParameterFilter { $Id -eq 6160 }
    }
}

Describe 'Invoke-ALRunnerCli' -Tag 'Process' {
    BeforeAll {
        # Fake al-runner: two stderr progress lines, one JSON document on stdout,
        # exit code taken from the first argument.
        $script:FakeRunner = Join-Path $TestDrive 'fake-al-runner.cmd'
        Set-Content -LiteralPath $script:FakeRunner -Encoding ascii -Value @'
@echo off
echo [bc] selected BC 99.0.0.0 (fake)>&2
echo [dep] none>&2
echo {"tests":[],"passed":0,"failed":0,"errors":0,"skipped":0,"total":0,"exitCode":%1,"wallSeconds":0.1}
exit /b %1
'@
    }

    It 'writes stdout and stderr to their files, echoes stderr lines, and returns the exit code unchanged' {
        $stdout = Join-Path $TestDrive 'out' 'al-runner-output.json'
        $stderr = Join-Path $TestDrive 'logs' 'al-runner.log'

        $information = [System.Collections.Generic.List[string]]::new()
        $result = Invoke-ALRunnerCli -Command $script:FakeRunner -Arguments @('3') -WorkingDirectory $TestDrive `
            -StdoutPath $stdout -StderrPath $stderr -PollIntervalMs 50 6>&1 |
            ForEach-Object {
                if ($_ -is [System.Management.Automation.InformationRecord]) { $information.Add("$($_.MessageData)") } else { $_ }
            }

        $result.ExitCode | Should -Be 3
        $result.StdoutPath | Should -Be $stdout
        $result.StderrPath | Should -Be $stderr
        (Get-Content -LiteralPath $stdout -Raw) | Should -Match '"exitCode":3'
        @(Get-Content -LiteralPath $stderr) | Should -Contain '[bc] selected BC 99.0.0.0 (fake)'
        $information | Should -Contain '  [al-runner] [bc] selected BC 99.0.0.0 (fake)'
        $information | Should -Contain '  [al-runner] [dep] none'
    }

    It 'replaces a stale log from the previous run' {
        $stdout = Join-Path $TestDrive 'out2' 'al-runner-output.json'
        $stderr = Join-Path $TestDrive 'logs2' 'al-runner.log'
        New-Item -ItemType Directory -Path (Split-Path $stderr -Parent) -Force | Out-Null
        Set-Content -LiteralPath $stderr -Value 'stale line from last time'

        Invoke-ALRunnerCli -Command $script:FakeRunner -Arguments @('0') -WorkingDirectory $TestDrive `
            -StdoutPath $stdout -StderrPath $stderr -PollIntervalMs 50 6>$null | Out-Null

        @(Get-Content -LiteralPath $stderr) | Should -Not -Contain 'stale line from last time'
    }

    It 'hands each argument to al-runner as one token when paths and the working directory contain spaces' {
        # Regression guard: Start-Process -ArgumentList joined with spaces and
        # split `C:\Users\John Doe\...` into two tokens; ArgumentList quotes.
        $workDir = Join-Path $TestDrive 'work dir with space'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $echoArgs = Join-Path $TestDrive 'echo-args.ps1'
        Set-Content -LiteralPath $echoArgs -Value @'
foreach ($a in $args) { [Console]::Error.WriteLine("[$a]") }
[Console]::Out.WriteLine("[cwd:$((Get-Location).Path)]")
exit 0
'@
        $stdout = Join-Path $TestDrive 'out 3' 'al-runner-output.json'
        $stderr = Join-Path $TestDrive 'logs 3' 'al-runner.log'
        $bundle = Join-Path $workDir 'my app'
        $cache = Join-Path $workDir '.output' 'al-runner deps'

        Invoke-ALRunnerCli -Command (Join-Path $PSHOME 'pwsh.exe') -WorkingDirectory $workDir `
            -Arguments @('-NoProfile', '-File', $echoArgs, $bundle, '--package-cache', $cache, '--output-junit', 'plain.xml') `
            -StdoutPath $stdout -StderrPath $stderr -PollIntervalMs 50 6>$null | Out-Null

        $tokens = @(Get-Content -LiteralPath $stderr)
        $tokens | Should -Contain "[$bundle]"
        $tokens | Should -Contain "[$cache]"
        $tokens | Should -Contain '[--package-cache]'
        $tokens | Should -Contain '[plain.xml]'
        $tokens.Count | Should -Be 5
        (Get-Content -LiteralPath $stdout -Raw) | Should -Match ([regex]::Escape("[cwd:$workDir]"))
    }
}
