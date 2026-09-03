#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking
}

Describe 'Get-CompileTargets' {
    It 'lists testApps then containerTestApps, each once' {
        $config = [PSCustomObject]@{ TestApps = @('C:\r\test'); ContainerTestApps = @('C:\r\e2e', 'C:\r\test') }
        $targets = Get-CompileTargets -Config $config
        ($targets | ForEach-Object { $_.AppDir }) | Should -Be @('C:\r\test', 'C:\r\e2e')
        ($targets | Where-Object { $_.AppDir -eq 'C:\r\test' }).Role | Should -Be 'test'
    }
}
