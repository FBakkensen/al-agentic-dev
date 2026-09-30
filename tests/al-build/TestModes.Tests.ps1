#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking
}

Describe 'test.ps1 surface' {
    It 'exposes only Coverage parameter beyond common ones' {
        $cmd = Get-Command (Join-Path $scriptsDir 'test.ps1')
        $cmd.Parameters.Keys | Should -Contain 'Coverage'
        foreach ($gone in 'UnitTestOnly', 'AllTests', 'Force', 'Test') { $cmd.Parameters.Keys | Should -Not -Contain $gone }
    }

    It 'test.ps1 contains no container vocabulary' {
        $content = Get-Content (Join-Path $scriptsDir 'test.ps1') -Raw
        foreach ($banned in 'Ensure-BCAgentContainer', 'Invoke-ALPublish', 'Wait-BCAppsSynced', 'Invoke-ALTest', 'ContainerName') {
            $content | Should -Not -Match $banned
        }
    }

    It 'runs al-runner as one CLI process per gate and names its log on a red' {
        # Regression guard: the al-runner --server manager is gone; the gate
        # runs the CLI directly and points at .output/logs/al-runner.log.
        $content = Get-Content (Join-Path $scriptsDir 'test.ps1') -Raw
        $content | Should -Match 'Invoke-ALRunnerCli'
        $content | Should -Match ([regex]::Escape('.output/logs/al-runner.log'))
        $content | Should -Not -Match 'Request-ALRunnerServerRun'
        $content | Should -Not -Match 'al-runner-server'
    }
}
