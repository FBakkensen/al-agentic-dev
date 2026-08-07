#Requires -Version 7.2

# Regression guard: the gate's verdict must never ride the success stream.
# test.ps1 used to end in `exit (Invoke-TestGate ...)`, which captured the
# gate's ENTIRE stdout as the exit expression — every bare native command in
# the call tree (above all the AL compiler) had its output swallowed, so a
# red compile printed zero diagnostic lines.

BeforeAll {
    $script:ScriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    $script:TestScriptPath = Join-Path $script:ScriptsDir 'test.ps1'
    Import-Module (Join-Path $script:ScriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ScriptsDir 'coverage-runtime.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ScriptsDir 'build-operations.psm1') -Force -DisableNameChecking
}

Describe 'Invoke-ALBuild compiler output routing' {
    BeforeEach {
        Mock Write-BuildHeader {} -ModuleName build-operations
        Mock Write-BuildMessage {} -ModuleName build-operations
        Mock Get-AppJsonObject { [pscustomobject]@{ name = 'Fake App'; version = '1.0.0.0' } } -ModuleName build-operations
        Mock Get-SymbolCacheInfo { [pscustomobject]@{ CacheDir = $TestDrive } } -ModuleName build-operations
        Mock Get-EnabledAnalyzerPath { @() } -ModuleName build-operations

        $script:OutputPath = Join-Path $TestDrive 'Fake_App.app'
        Mock Get-OutputPath { $script:OutputPath } -ModuleName build-operations

        $script:SavedRulesetPath = $env:RULESET_PATH
        $env:RULESET_PATH = $null
    }

    AfterEach {
        $env:RULESET_PATH = $script:SavedRulesetPath
    }

    Context 'failed compile' {
        BeforeEach {
            # Fake compiler: emits a diagnostic on stdout (the real `al compile`
            # writes its errors there) and exits 1.
            $script:FakeCompiler = Join-Path $TestDrive 'fake-alc-red.ps1'
            Set-Content -LiteralPath $script:FakeCompiler -Value @'
Write-Output 'C:\src\File.al(12,34): error AL0432: fake diagnostic'
exit 1
'@
            Mock Get-LatestCompilerInfo {
                [pscustomobject]@{
                    CommandPath = $script:FakeCompiler
                    CompilerDir = $TestDrive
                    Version     = '99.0'
                    Channel     = 'stable'
                }
            } -ModuleName build-operations
        }

        It 'throws the exit-code failure and surfaces the diagnostic on the information stream' {
            $information = [System.Collections.Generic.List[object]]::new()
            $captured = $null
            {
                # Capture the success stream the way the defective call site did —
                # the diagnostic must NOT be there, and must reach stream 6 instead.
                $captured = Invoke-ALBuild -AppDir $TestDrive -RequiredRuntimeMajor 14 6>&1 |
                    ForEach-Object {
                        if ($_ -is [System.Management.Automation.InformationRecord]) {
                            $information.Add($_)
                        } else {
                            $_
                        }
                    }
            } | Should -Throw '*AL compilation failed with exit code 1*'

            @($information | ForEach-Object { "$($_.MessageData)" }) |
                Should -Contain 'C:\src\File.al(12,34): error AL0432: fake diagnostic'
            @($captured) | Should -Not -Contain 'C:\src\File.al(12,34): error AL0432: fake diagnostic'
        }
    }

    Context 'green compile' {
        BeforeEach {
            # Fake compiler: emits a summary line on stdout, creates the /out:
            # target, exits 0.
            $script:FakeCompiler = Join-Path $TestDrive 'fake-alc-green.ps1'
            Set-Content -LiteralPath $script:FakeCompiler -Value @'
Write-Output 'Compilation succeeded (fake summary line)'
foreach ($arg in $args) {
    if ($arg -like '/out:*') {
        Set-Content -LiteralPath $arg.Substring(5) -Value 'fake app'
    }
}
exit 0
'@
            Mock Get-LatestCompilerInfo {
                [pscustomobject]@{
                    CommandPath = $script:FakeCompiler
                    CompilerDir = $TestDrive
                    Version     = '99.0'
                    Channel     = 'stable'
                }
            } -ModuleName build-operations
        }

        It 'keeps compiler stdout off the success stream' {
            $captured = @(Invoke-ALBuild -AppDir $TestDrive -RequiredRuntimeMajor 14)
            $captured | Should -Not -Contain 'Compilation succeeded (fake summary line)'
        }
    }
}

Describe 'Invoke-TestGate verdict channel' {
    BeforeAll {
        . $script:TestScriptPath
    }

    BeforeEach {
        Mock Write-BuildMessage {}
        Mock Write-BuildHeader {}
        Mock Save-BuildTimingEntry {}
        Mock Show-BuildTimingHistory {}
        Mock Get-DirtyFileCounts { $null }
        Mock Get-RequiredRuntimeMajor { 14 }
        Mock Set-BuildEnvironment {}
        Mock Resolve-CoverageEnabled { $false }
        Mock Copy-ALSymbolToCache {}
        Mock Ensure-BCAgentContainer {}
        Mock Invoke-ALPublish {}
        Mock Invoke-ALTest {}

        $repoRoot = Join-Path $TestDrive 'gate-repo'
        $unitTestApp = Join-Path $repoRoot 'unit'
        New-Item -ItemType Directory -Path $unitTestApp -Force | Out-Null
        $script:UnitTestApp = $unitTestApp

        Mock Get-GitRepoRoot { $repoRoot }
        Mock Get-BuildConfig {
            [pscustomobject]@{
                AppDir             = $repoRoot
                TestApps           = @()
                UnitTestApp        = $script:UnitTestApp
                UnitTestInitEvents = $false
                WarnAsError        = $false
                ContainerName      = 'unused'
                ContainerUsername  = 'unused'
                Tenant             = 'default'
            }
        }
        Mock Get-CompileTargets { @() }

        # Stands in for a bare native command inside the gate's call tree:
        # its stdout must flow through the gate's output stream to the console,
        # never be consumed as the verdict.
        Mock Invoke-ALBuild { 'FAKE-NATIVE-STDOUT' }
    }

    It 'reports a green run as $script:GateExitCode 0 and keeps the verdict off the output stream' {
        Mock Invoke-ALRunnerTest {
            [pscustomobject]@{
                Runner     = 'al-runner'
                AppName    = 'Unit Tests'
                TestDir    = $script:UnitTestApp
                Passed     = $true
                Counts     = [ordered]@{ testCodeunits = 1; tests = 1; testsPassed = 1; testsFailed = 0; testsSkipped = 0 }
                ResultFile = (Join-Path $TestDrive 'al-runner.xml')
            }
        }

        $out = @(Invoke-TestGate -UnitTestOnly)

        $script:GateExitCode | Should -Be 0
        $out | Should -Not -Contain 0
        $out | Should -Contain 'FAKE-NATIVE-STDOUT'
    }

    It 'reports a red run as $script:GateExitCode 1 and keeps the verdict off the output stream' {
        Mock Invoke-ALRunnerTest {
            [pscustomobject]@{
                Runner     = 'al-runner'
                AppName    = 'Unit Tests'
                TestDir    = $script:UnitTestApp
                Passed     = $false
                Counts     = [ordered]@{ testCodeunits = 1; tests = 1; testsPassed = 0; testsFailed = 1; testsSkipped = 0 }
                ResultFile = (Join-Path $TestDrive 'al-runner.xml')
            }
        }

        $out = @(Invoke-TestGate -UnitTestOnly)

        $script:GateExitCode | Should -Be 1
        $out | Should -Not -Contain 1
        $out | Should -Contain 'FAKE-NATIVE-STDOUT'
    }
}

Describe 'test.ps1 entry point' {
    BeforeAll {
        $tokens = $null
        $errors = $null
        $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:TestScriptPath, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'exits on a variable, never consuming Invoke-TestGate output as the exit expression' {
        $exitStatements = $script:Ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.ExitStatementAst] }, $true)

        foreach ($exit in $exitStatements) {
            if (-not $exit.Pipeline) { continue }
            $gateCalls = $exit.Pipeline.FindAll(
                { param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Invoke-TestGate'
                }, $true)
            $gateCalls | Should -BeNullOrEmpty -Because 'exit (Invoke-TestGate ...) swallows every native stdout line in the gate'
        }
    }

    It 'still invokes Invoke-TestGate bare so its output streams to the console' {
        $bareGateCalls = $script:Ast.FindAll(
            { param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'Invoke-TestGate' -and
                $node.Parent -is [System.Management.Automation.Language.PipelineAst] -and
                $node.Parent.Parent -isnot [System.Management.Automation.Language.ExitStatementAst] -and
                $node.Parent.Parent -isnot [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Parent.Parent -isnot [System.Management.Automation.Language.ParenExpressionAst]
            }, $true)
        @($bareGateCalls).Count | Should -BeGreaterOrEqual 1
    }
}
