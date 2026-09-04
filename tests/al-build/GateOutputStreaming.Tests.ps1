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

        function Set-FakeCliRun {
            <#
                .SYNOPSIS
                Mocks Invoke-ALRunnerCli to write a CLI --output-json document
                (and optionally a Cobertura file) to the paths the gate passes,
                returning the given exit code.
            #>
            param(
                [int]$ExitCode,
                [object[]]$Tests,
                [string]$Cobertura
            )
            $script:FakeExitCode = $ExitCode
            $script:FakeTests = $Tests
            $script:FakeCobertura = $Cobertura
            Mock Invoke-ALRunnerCli {
                $failed = @($script:FakeTests | Where-Object status -eq 'fail').Count
                $document = [ordered]@{
                    tests       = @($script:FakeTests)
                    passed      = @($script:FakeTests | Where-Object status -eq 'pass').Count
                    failed      = $failed
                    errors      = 0
                    skipped     = 0
                    total       = @($script:FakeTests).Count
                    exitCode    = $script:FakeExitCode
                    wallSeconds = 0.1
                }
                New-Item -ItemType Directory -Path (Split-Path $StdoutPath -Parent) -Force | Out-Null
                $document | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StdoutPath -Encoding utf8
                Set-Content -LiteralPath $StderrPath -Value @('[bc] selected BC 99.0.0.0 (fake)', '[dep] none') -Encoding utf8
                if ($script:FakeCobertura) {
                    $coverageOut = $Arguments[[array]::IndexOf($Arguments, '--coverage-out') + 1]
                    New-Item -ItemType Directory -Path (Split-Path $coverageOut -Parent) -Force | Out-Null
                    Set-Content -LiteralPath $coverageOut -Value $script:FakeCobertura -Encoding utf8
                }
                [pscustomobject]@{ ExitCode = $script:FakeExitCode; StdoutPath = $StdoutPath; StderrPath = $StderrPath }
            }
        }
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
        Mock Stop-OrphanedALRunnerServer {}
        Mock New-ALRunnerDependencyDirectory { [pscustomobject]@{ OutputDirectory = $OutputDirectory; Packages = @() } }

        $repoRoot = Join-Path $TestDrive 'gate-repo'
        if (Test-Path -LiteralPath $repoRoot) { Remove-Item -LiteralPath $repoRoot -Recurse -Force }
        $testApp = Join-Path $repoRoot 'test'
        New-Item -ItemType Directory -Path $testApp -Force | Out-Null
        $script:TestApp = $testApp
        $script:GateRepoRoot = $repoRoot

        Mock Get-GitRepoRoot { $repoRoot }
        Mock Get-BuildConfig {
            [pscustomobject]@{
                AppDir            = $repoRoot
                TestApps          = @($script:TestApp)
                ContainerTestApps = @()
                WarnAsError       = $false
            }
        }
        Mock Get-CompileTargets { @() }

        # Stands in for a bare native command inside the gate's call tree:
        # its stdout must flow through the gate's output stream to the console,
        # never be consumed as the verdict.
        Mock Invoke-ALBuild { 'FAKE-NATIVE-STDOUT' }
    }

    It 'reports a green run as $script:GateExitCode 0 and keeps the verdict off the output stream' {
        Set-FakeCliRun -ExitCode 0 -Tests @([ordered]@{ name = 'Codeunit1.Test1'; status = 'pass'; durationMs = 5 })

        $out = @(Invoke-TestGate)

        $script:GateExitCode | Should -Be 0
        $out | Should -Not -Contain 0
        $out | Should -Contain 'FAKE-NATIVE-STDOUT'
    }

    It 'surfaces the [bc] selected line from the al-runner log' {
        Set-FakeCliRun -ExitCode 0 -Tests @([ordered]@{ name = 'Codeunit1.Test1'; status = 'pass'; durationMs = 5 })

        Invoke-TestGate | Out-Null

        Should -Invoke Write-BuildMessage -ParameterFilter {
            $Type -eq 'Info' -and $Message -eq '[bc] selected BC 99.0.0.0 (fake)'
        }
    }

    It 'reports a red run as $script:GateExitCode 1 and keeps the verdict off the output stream' {
        Set-FakeCliRun -ExitCode 1 -Tests @([ordered]@{ name = 'Codeunit1.Test1'; status = 'fail'; durationMs = 5; message = 'boom' })

        $out = @(Invoke-TestGate)

        $script:GateExitCode | Should -Be 1
        $out | Should -Not -Contain 1
        $out | Should -Contain 'FAKE-NATIVE-STDOUT'
    }

    It 'throws naming the al-runner log when al-runner exits 3 (could not compile)' {
        Mock Invoke-ALRunnerCli {
            Set-Content -LiteralPath $StderrPath -Value @('error AL0118: fake compile error') -Encoding utf8
            [pscustomobject]@{ ExitCode = 3; StdoutPath = $StdoutPath; StderrPath = $StderrPath }
        }

        { Invoke-TestGate } | Should -Throw '*al-runner exited 3*.output/logs/al-runner.log*'

        Should -Invoke Write-BuildMessage -ParameterFilter {
            $Type -eq 'Error' -and $Message -match 'AL0118'
        }
    }

    It 'throws naming the output when al-runner exits 0 without a result document' {
        Mock Invoke-ALRunnerCli {
            Set-Content -LiteralPath $StdoutPath -Value '' -Encoding utf8 -NoNewline
            [pscustomobject]@{ ExitCode = 0; StdoutPath = $StdoutPath; StderrPath = $StderrPath }
        }

        { Invoke-TestGate } | Should -Throw '*al-runner output unreadable*'
    }

    It 'reds the gate before al-runner runs when tests/expectations exists' {
        # An expectations manifest makes al-runner exit 0 on failing tests. The
        # gate never hides a failure: the folder's presence is red on its own.
        New-Item -ItemType Directory -Path (Join-Path $repoRoot 'tests' 'expectations') -Force | Out-Null
        Mock Invoke-ALRunnerCli { throw 'al-runner must not be reached' }

        { Invoke-TestGate } | Should -Not -Throw

        $script:GateExitCode | Should -Be 1
        Should -Invoke Invoke-ALRunnerCli -Times 0
        Should -Invoke Write-BuildMessage -ParameterFilter {
            $Type -eq 'Error' -and $Message -match 'tests/expectations' -and $Message -match 'containerTestApps'
        }
    }

    Context 'coverage' {
        BeforeEach {
            Mock Resolve-CoverageEnabled { $true }
            New-Item -ItemType Directory -Path (Join-Path $script:GateRepoRoot 'src') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:GateRepoRoot 'src' 'Calc.Codeunit.al') -Value "codeunit 50100 `"Calc`"`n{`n}`n" -Encoding utf8
            $script:Cobertura = @'
<?xml version="1.0" encoding="utf-8"?>
<coverage line-rate="0.5" lines-covered="1" lines-valid="2"><packages><package name="al-source"><classes>
<class name="Calc" filename="src/Calc.Codeunit.al"><lines><line number="1" hits="1" /><line number="2" hits="0" /></lines></class>
</classes></package></packages></coverage>
'@
        }

        It 'passes --coverage and --coverage-out to al-runner and reports aggregate-only coverage' {
            Set-FakeCliRun -ExitCode 0 -Tests @([ordered]@{ name = 'Codeunit1.Test1'; status = 'pass'; durationMs = 5 }) -Cobertura $script:Cobertura

            Invoke-TestGate | Out-Null

            $script:GateExitCode | Should -Be 0
            Should -Invoke Invoke-ALRunnerCli -ParameterFilter { $Arguments -contains '--coverage' -and $Arguments -contains '--coverage-out' }
            $summary = Get-Content -LiteralPath (Join-Path $script:GateRepoRoot '.output' 'TestResults' 'summary.json') -Raw | ConvertFrom-Json
            $summary.coverage.status | Should -Be 'aggregate-only'
            $summary.coverage.complete | Should -BeTrue
            $summary.coverage.perTestJsonlPath | Should -BeNullOrEmpty
            $summary.coverage.linesValid | Should -Be 2
            $summary.coverage.linesCovered | Should -Be 1
            $summary.coverage.lineRate | Should -Be 0.5
            $summary.coverage.coberturaXmlPath | Should -Be '.output/TestResults/coverage/cobertura.xml'
        }

        It 'keeps the green verdict and reports a failed coverage block when al-runner wrote no Cobertura' {
            Set-FakeCliRun -ExitCode 0 -Tests @([ordered]@{ name = 'Codeunit1.Test1'; status = 'pass'; durationMs = 5 })

            { Invoke-TestGate } | Should -Not -Throw

            $script:GateExitCode | Should -Be 0
            $summary = Get-Content -LiteralPath (Join-Path $script:GateRepoRoot '.output' 'TestResults' 'summary.json') -Raw | ConvertFrom-Json
            $summary.coverage.status | Should -Be 'failed'
            $summary.coverage.failure.message | Should -Match 'cobertura.xml'
        }

        It 'omits --coverage when coverage is disabled' {
            Mock Resolve-CoverageEnabled { $false }
            Set-FakeCliRun -ExitCode 0 -Tests @([ordered]@{ name = 'Codeunit1.Test1'; status = 'pass'; durationMs = 5 })

            Invoke-TestGate | Out-Null

            Should -Invoke Invoke-ALRunnerCli -ParameterFilter { $Arguments -notcontains '--coverage' }
        }
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
