#Requires -Version 7.2

BeforeAll {
    $script:RunnerPath = (
        Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Invoke-Tests.ps1')
    ).Path
    . $script:RunnerPath

    function New-PesterResult {
        param(
            [string]$Result = 'Passed',
            [int]$FailedCount = 0,
            [object[]]$Failed = @(),
            [object[]]$Containers = @()
        )

        [pscustomobject]@{
            Result = $Result
            TotalCount = 3
            PassedCount = 3 - $FailedCount
            FailedCount = $FailedCount
            SkippedCount = 0
            NotRunCount = 0
            Duration = [timespan]::FromSeconds(1.25)
            Failed = $Failed
            Containers = $Containers
        }
    }
}

Describe 'Invoke-Tests runner' -Tag 'Unit' {
    BeforeEach {
        Mock Invoke-Pester { New-PesterResult }
        Mock Write-Host {}
    }

    It 'runs Pester once and returns compact success' {
        $output = @(
            Invoke-RepositoryTests -Mode Fast -TestsPath $TestDrive
        )

        $output[-1] | Should -Be 0
        Should -Invoke Invoke-Pester -Times 1 -Exactly -ParameterFilter {
            $Configuration.Run.Path.Value -eq $TestDrive -and
            $Configuration.Run.PassThru.Value -and
            $Configuration.Output.Verbosity.Value -eq 'None' -and
            $Configuration.Filter.ExcludeTag.Value -contains 'Process' -and
            $Configuration.Filter.ExcludeTag.Value -contains 'LiveFixture'
        }
        Should -Invoke Write-Host -Times 1 -Exactly
    }

    It 'returns nonzero and reports a failed test without rerunning' {
        Mock Invoke-Pester {
            New-PesterResult -Result Failed -FailedCount 1 -Failed @(
                [pscustomobject]@{
                    ExpandedPath = 'suite'
                    Name = 'broken behavior'
                    ErrorRecord = 'expected true'
                }
            )
        }

        $output = @(
            Invoke-RepositoryTests -TestsPath $TestDrive -ErrorAction Continue *>&1
        )

        $output[-1] | Should -Be 1
        ($output | Out-String) | Should -Match 'suite :: broken behavior'
        ($output | Out-String) | Should -Match 'expected true'
        Should -Invoke Invoke-Pester -Times 1 -Exactly
    }

    It 'returns nonzero when discovery or setup fails before any test fails' {
        Mock Invoke-Pester {
            New-PesterResult -Result Failed -Containers @(
                [pscustomobject]@{
                    Result = 'Failed'
                    Item = 'broken.Tests.ps1'
                    ErrorRecord = 'BeforeAll failed'
                }
            )
        }

        $output = @(
            Invoke-RepositoryTests -TestsPath $TestDrive -ErrorAction Continue *>&1
        )

        $output[-1] | Should -Be 1
        ($output | Out-String) | Should -Match 'broken\.Tests\.ps1'
        ($output | Out-String) | Should -Match 'BeforeAll failed'
        Should -Invoke Invoke-Pester -Times 1 -Exactly
    }
}
