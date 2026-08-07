#Requires -Version 7.2

BeforeAll {
    $script:TestScriptPath = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'test.ps1')
    . $script:TestScriptPath

    $script:Counts = [ordered]@{
        testCodeunits = 1
        tests         = 1
        testsPassed   = 1
        testsFailed   = 0
        testsSkipped  = 0
    }
}

Describe 'test.ps1 modes' {
    BeforeEach {
        Mock Write-BuildMessage {}
        Mock Write-BuildHeader {}
        Mock Save-BuildTimingEntry {}
        Mock Show-BuildTimingHistory {}
        Mock Get-DirtyFileCounts { $null }
        Mock Get-RequiredRuntimeMajor { 14 }
        Mock Set-BuildEnvironment {}
        Mock Resolve-CoverageEnabled { $false }
        Mock Invoke-ALBuild {}
        Mock Copy-ALSymbolToCache {}
    }

    It 'rejects a missing mode before cleanup or configuration' {
        Mock Get-GitRepoRoot { throw 'cleanup must not start' }

        (Invoke-TestGate) | Should -Be 1

        Should -Invoke Get-GitRepoRoot -Times 0 -Exactly
        Should -Invoke Write-BuildMessage -Times 1 -Exactly -ParameterFilter {
            $Type -eq 'Error' -and
            $Message -match 'Specify exactly one test mode' -and
            $Message -match '-UnitTestOnly: run AL Runner unit tests without a container' -and
            $Message -match '-AllTests: run AL Runner when configured, then container tests'
        }
    }

    It 'runs UnitTestOnly without any container operation' {
        $repoRoot = Join-Path $TestDrive 'unit-only'
        $unitTestApp = Join-Path $repoRoot 'unit'
        New-Item -ItemType Directory -Path $unitTestApp -Force | Out-Null

        Mock Get-GitRepoRoot { $repoRoot }
        Mock Get-BuildConfig {
            [pscustomobject]@{
                AppDir             = $repoRoot
                TestApps           = @()
                UnitTestApp         = $unitTestApp
                UnitTestInitEvents  = $false
                WarnAsError         = $false
                ContainerName       = 'unused'
                ContainerUsername   = 'unused'
                Tenant              = 'default'
            }
        }
        Mock Get-CompileTargets { @() }
        Mock Invoke-ALRunnerTest {
            [pscustomobject]@{
                Runner     = 'al-runner'
                AppName    = 'Unit Tests'
                TestDir    = $unitTestApp
                Passed     = $true
                Counts     = $script:Counts
                ResultFile = (Join-Path $repoRoot 'al-runner.xml')
            }
        }
        Mock Ensure-BCAgentContainer {}
        Mock Invoke-ALPublish {}
        Mock Invoke-ALTest {}

        (Invoke-TestGate -UnitTestOnly) | Should -Be 0

        Should -Invoke Invoke-ALRunnerTest -Times 1 -Exactly
        Should -Invoke Ensure-BCAgentContainer -Times 0 -Exactly
        Should -Invoke Invoke-ALPublish -Times 0 -Exactly
        Should -Invoke Invoke-ALTest -Times 0 -Exactly
    }

    It 'runs the container path for AllTests' {
        $repoRoot = Join-Path $TestDrive 'all-tests'
        $testApp = Join-Path $repoRoot 'test'
        New-Item -ItemType Directory -Path $testApp -Force | Out-Null

        Mock Get-GitRepoRoot { $repoRoot }
        Mock Get-BuildConfig {
            [pscustomobject]@{
                AppDir             = $repoRoot
                TestApps           = @($testApp)
                UnitTestApp         = $null
                UnitTestInitEvents  = $false
                WarnAsError         = $false
                ContainerName       = 'agent'
                ContainerUsername   = 'admin'
                Tenant              = 'default'
            }
        }
        Mock Get-CompileTargets {
            @([pscustomobject]@{ AppDir = $testApp; Role = 'test' })
        }
        Mock Ensure-BCAgentContainer {}
        Mock Get-AppJsonObject { [pscustomobject]@{ name = 'Test App' } }
        Mock Test-AppNeedsPublish { $false }
        Mock Invoke-ALPublish {}
        Mock Wait-BCAppsSynced {}
        Mock Invoke-ALTest {
            [pscustomobject]@{
                Runner     = 'container'
                AppName    = 'Test App'
                TestDir    = $testApp
                Passed     = $true
                Counts     = $script:Counts
                ResultFile = (Join-Path $repoRoot 'last.xml')
            }
        }
        Mock Invoke-ALRunnerTest {}

        (Invoke-TestGate -AllTests) | Should -Be 0

        Should -Invoke Ensure-BCAgentContainer -Times 1 -Exactly
        Should -Invoke Invoke-ALPublish -Times 2 -Exactly
        Should -Invoke Invoke-ALTest -Times 1 -Exactly
        Should -Invoke Invoke-ALRunnerTest -Times 0 -Exactly
    }

    It 'returns a failure from a red AllTests run without exiting Pester' {
        $repoRoot = Join-Path $TestDrive 'red-all-tests'
        $testApp = Join-Path $repoRoot 'test'
        New-Item -ItemType Directory -Path $testApp -Force | Out-Null

        Mock Get-GitRepoRoot { $repoRoot }
        Mock Get-BuildConfig {
            [pscustomobject]@{
                AppDir             = $repoRoot
                TestApps           = @($testApp)
                UnitTestApp         = $null
                UnitTestInitEvents  = $false
                WarnAsError         = $false
                ContainerName       = 'agent'
                ContainerUsername   = 'admin'
                Tenant              = 'default'
            }
        }
        Mock Get-CompileTargets {
            @([pscustomobject]@{ AppDir = $testApp; Role = 'test' })
        }
        Mock Ensure-BCAgentContainer {}
        Mock Get-AppJsonObject { [pscustomobject]@{ name = 'Test App' } }
        Mock Test-AppNeedsPublish { $false }
        Mock Invoke-ALPublish {}
        Mock Wait-BCAppsSynced {}
        Mock Invoke-ALTest {
            [pscustomobject]@{
                Runner     = 'container'
                AppName    = 'Test App'
                TestDir    = $testApp
                Passed     = $false
                Counts     = [ordered]@{
                    testCodeunits = 1
                    tests         = 1
                    testsPassed   = 0
                    testsFailed   = 1
                    testsSkipped  = 0
                }
                ResultFile = (Join-Path $repoRoot 'last.xml')
            }
        }

        (Invoke-TestGate -AllTests) | Should -Be 1

        Should -Invoke Invoke-ALTest -Times 1 -Exactly
    }
}
