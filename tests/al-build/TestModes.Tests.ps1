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

    It 'fails the gate with the manager and server log paths when the server is unavailable' {
        # Regression guard: the server is the only test path — an unavailable
        # server must red the gate with the two log paths named, not fall
        # back to a fresh al-runner CLI process.
        $content = Get-Content (Join-Path $scriptsDir 'test.ps1') -Raw
        $content | Should -Match ([regex]::Escape('.output/logs/al-runner-server-manager.log'))
        $content | Should -Match ([regex]::Escape('.output/logs/al-runner-server.log'))
        $content | Should -Not -Match 'Invoke-ALRunnerCli'
    }
}
