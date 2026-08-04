#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:ModulePath = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts' 'coverage-preflight.psm1'
    $script:HelperManifestPath = Join-Path $script:RepoRoot 'skills' 'al-build' 'code-coverage-helper' 'app.json'
    Import-Module $script:ModulePath -Force -DisableNameChecking
    $script:Contract = Get-CoveragePreflightHelperContract
}

Describe 'Coverage preflight contracts' {
    It 'reads the exact bundled helper identity and exporter from current source' {
        $script:Contract.AppId | Should -Be ([guid]'6a7912dd-91be-4a75-a9d3-8f3b5d4e7501')
        $script:Contract.AppVersion | Should -Be ([version]'1.0.0.0')
        $script:Contract.AppName | Should -Be 'AL Build Code Coverage Helper'
        $script:Contract.AppPublisher | Should -Be 'bc-agentic-dev-tools'
        $script:Contract.ExporterId | Should -Be 74075
        $script:Contract.AppJsonPath | Should -Be $script:HelperManifestPath
    }

    It 'pins every required Test Runner control and action' {
        $contract = Get-CoveragePreflightPageContract

        @(
            $contract.SuiteControl
            $contract.TrackingControl
            $contract.AllSessionsControl
            $contract.ExporterControl
            $contract.MapControl
            $contract.PayloadControl
            $contract.InfoControl
        ) | Should -Be @(
            'CurrentSuiteName'
            'CCTrackingType'
            'CCTrackAllSessions'
            'CCExporterID'
            'CCMap'
            'CCResultsCSVText'
            'CCInfo'
        )
        @($contract.ClearAction, $contract.DrainAction) |
            Should -Be @('ClearCodeCoverage', 'GetCodeCoverage')
    }

    It 'requires helper app ID, name, and version' {
        $path = Join-Path $TestDrive 'app.json'
        @{ id = [guid]::NewGuid(); name = 'Helper' } |
            ConvertTo-Json |
            Set-Content -LiteralPath $path

        {
            Get-CoveragePreflightHelperContract -AppJsonPath $path
        } | Should -Throw "*must declare id and version*Missing: version*"
    }
}

Describe 'Coverage infrastructure preflight' {
    It 'accepts exactly one helper at the expected ID and version before probing' {
        $events = [System.Collections.Generic.List[string]]::new()
        $installed = [pscustomobject]@{
            AppId = $script:Contract.AppId
            Version = $script:Contract.AppVersion
        }

        Invoke-CoveragePreflightChecks -Contract $script:Contract `
            -GetInstalledApps {
                $events.Add('identity') | Out-Null
                $installed
            } -ProbeTestRunner {
                $events.Add('probe') | Out-Null
            }

        $events | Should -Be @('identity', 'probe')
    }

    It 'accepts the installed app identifier exposed through Id' {
        $installed = [pscustomobject]@{
            Id = $script:Contract.AppId
            Version = $script:Contract.AppVersion
        }

        {
            Assert-CoveragePreflightHelperIdentity -Contract $script:Contract `
                -InstalledApps @($installed)
        } | Should -Not -Throw
    }

    It 'fails missing helper identity before the Test Runner probe' {
        $probeCalls = 0

        {
            Invoke-CoveragePreflightChecks -Contract $script:Contract `
                -GetInstalledApps { @() } `
                -ProbeTestRunner { $probeCalls++ }
        } | Should -Throw "*$($script:Contract.AppId)*version $($script:Contract.AppVersion)*not installed*"
        $probeCalls | Should -Be 0
    }

    It 'fails a stale helper with exact expected and installed versions' {
        $installed = [pscustomobject]@{
            AppId = $script:Contract.AppId
            Version = [version]'0.9.0.0'
        }

        {
            Invoke-CoveragePreflightChecks -Contract $script:Contract `
                -GetInstalledApps { $installed } `
                -ProbeTestRunner { throw 'probe must not run' }
        } | Should -Throw "*Expected $($script:Contract.AppVersion), installed 0.9.0.0*"
    }

    It 'rejects side-by-side helper versions instead of choosing one' {
        $installed = @(
            [pscustomobject]@{
                AppId = $script:Contract.AppId
                Version = $script:Contract.AppVersion
            }
            [pscustomobject]@{
                AppId = $script:Contract.AppId
                Version = [version]'0.9.0.0'
            }
        )

        {
            Invoke-CoveragePreflightChecks -Contract $script:Contract `
                -GetInstalledApps { $installed } `
                -ProbeTestRunner { throw 'probe must not run' }
        } | Should -Throw "*installed 2 times*expected exactly one app*"
    }

    It 'turns a missing required control into precise rebuild-only recovery' {
        {
            Invoke-CoveragePreflightChecks -Contract $script:Contract `
                -GetInstalledApps {
                    [pscustomobject]@{
                        AppId = $script:Contract.AppId
                        Version = $script:Contract.AppVersion
                    }
                } -ProbeTestRunner {
                    throw "Test Runner page is missing control 'CCExporterID'."
                }
        } | Should -Throw (
            "*failed before consumer app publication or test execution*" +
            "missing control 'CCExporterID'*" +
            "Rebuild the golden image*run new-bc-container.ps1*restart the machine*run commit-bc-container.ps1*" +
            "recreate the branch container with new-agent-container.ps1*" +
            "No automatic repair was attempted*"
        )
    }

    It 'turns a missing required action into the same rebuild-only recovery' {
        {
            Invoke-CoveragePreflightChecks -Contract $script:Contract `
                -GetInstalledApps {
                    [pscustomobject]@{
                        AppId = $script:Contract.AppId
                        Version = $script:Contract.AppVersion
                    }
                } -ProbeTestRunner {
                    throw "Test Runner page is missing action 'GetCodeCoverage'."
                }
        } | Should -Throw "*missing action 'GetCodeCoverage'*No automatic repair was attempted*"
    }
}
