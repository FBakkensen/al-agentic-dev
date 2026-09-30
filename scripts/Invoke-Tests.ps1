#Requires -Version 7.2

[CmdletBinding()]
param(
    [ValidateSet('Full', 'Fast', 'Process', 'LiveFixture')]
    [string]$Mode = 'Full'
)

function Invoke-RepositoryTests {
    [CmdletBinding()]
    param(
        [ValidateSet('Full', 'Fast', 'Process', 'LiveFixture')]
        [string]$Mode = 'Full',

        [string[]]$TestsPath = (Join-Path $PSScriptRoot '..' 'tests')
    )

    $config = New-PesterConfiguration
    $config.Run.Path = $TestsPath
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'None'

    switch ($Mode) {
        'Fast' {
            $config.Filter.ExcludeTag = @('Process', 'LiveFixture')
        }
        'Process' {
            $config.Filter.Tag = @('Process')
        }
        'LiveFixture' {
            $config.Filter.Tag = @('LiveFixture')
        }
    }

    $testOutput = @(
        & {
            Invoke-Pester -Configuration $config
        } *>&1
    )
    $result = $testOutput |
        Where-Object {
            $_.PSObject.Properties.Name -contains 'TotalCount' -and
            $_.PSObject.Properties.Name -contains 'Containers' -and
            $_.PSObject.Properties.Name -contains 'Duration'
        } |
        Select-Object -Last 1
    if (-not $result) {
        throw 'Pester did not return a run result.'
    }

    $summary = [ordered]@{
        mode = $Mode
        result = [string]$result.Result
        total = $result.TotalCount - $result.NotRunCount
        passed = $result.PassedCount
        failed = $result.FailedCount
        skipped = $result.SkippedCount
        durationSeconds = [math]::Round($result.Duration.TotalSeconds, 2)
    }
    Write-Host ($summary | ConvertTo-Json -Compress)

    if ($result.Result -ne 'Passed') {
        foreach ($failure in $result.Failed) {
            Write-Error "$($failure.ExpandedPath) :: $($failure.Name)`n$($failure.ErrorRecord)"
        }
        foreach ($container in @($result.Containers | Where-Object Result -eq 'Failed')) {
            Write-Error "$($container.Item)`n$($container.ErrorRecord)"
        }
        return 1
    }

    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-RepositoryTests -Mode $Mode)
}
