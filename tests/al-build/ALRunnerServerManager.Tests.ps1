#Requires -Version 7.2

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'build-operations.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'alrunner-server.psm1') -Force -DisableNameChecking

    # Get-ALRunnerServerFingerprint now folds in the third-party dependency
    # set (Resolve-ALRunnerDependencySet), which loads al-build.json via
    # Get-BuildConfig — every repo fixture below needs a minimal one, with no
    # test apps, so it resolves to zero dependencies without throwing.
    function script:New-MinimalBuildConfig {
        param([Parameter(Mandatory)][string]$RepoRoot)
        New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null
        [ordered]@{ appDir = 'app'; testApps = @() } |
            ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $RepoRoot 'al-build.json') -Encoding UTF8
    }
}

Describe 'Get-ALRunnerPipeName' {
    It 'is deterministic and path-case-insensitive' {
        (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\X') | Should -Be (Get-ALRunnerPipeName -RepoRoot 'c:\repo\x')
        (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\X') | Should -Match '^albt-alr-[0-9a-f]{16}$'
        (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\Y') | Should -Not -Be (Get-ALRunnerPipeName -RepoRoot 'C:\Repo\X')
    }
}
Describe 'Get-ALRunnerServerFingerprint' {
    It 'changes on table edits, ignores codeunit edits' {
        $repo = Join-Path $TestDrive 'repo'; New-Item -ItemType Directory -Path (Join-Path $repo 'app\src') -Force | Out-Null
        New-MinimalBuildConfig -RepoRoot $repo
        Set-Content (Join-Path $repo 'app\src\T.Table.al') 'table 50100 "T" { fields { field(1; A; Integer) { } } }'
        Set-Content (Join-Path $repo 'app\src\C.Codeunit.al') 'codeunit 50101 "C" { }'
        $f1 = Get-ALRunnerServerFingerprint -RepoRoot $repo
        Set-Content (Join-Path $repo 'app\src\C.Codeunit.al') 'codeunit 50101 "C" { procedure P() begin end; }'
        Get-ALRunnerServerFingerprint -RepoRoot $repo | Should -Be $f1
        Start-Sleep -Milliseconds 20
        Set-Content (Join-Path $repo 'app\src\T.Table.al') 'table 50100 "T" { fields { field(1; A; Decimal) { } } }'
        Get-ALRunnerServerFingerprint -RepoRoot $repo | Should -Not -Be $f1
    }
    It 'detects a table declaration on line 1 of a UTF-8 BOM file, and reacts to its edits' {
        # A BOM-prefixed file puts U+FEFF right before "table" on line 1, which
        # \s does not match - the schema regex must tolerate it or the file is
        # invisible to the fingerprint (an edit to it would then never restart
        # the server).
        $repo = Join-Path $TestDrive 'repo-bom'; New-Item -ItemType Directory -Path (Join-Path $repo 'app\src') -Force | Out-Null
        New-MinimalBuildConfig -RepoRoot $repo
        $tablePath = Join-Path $repo 'app\src\T.Table.al'
        $utf8Bom = [System.Text.UTF8Encoding]::new($true)
        [System.IO.File]::WriteAllText($tablePath, 'table 50100 "T" { fields { field(1; A; Integer) { } } }', $utf8Bom)
        $f1 = Get-ALRunnerServerFingerprint -RepoRoot $repo
        Start-Sleep -Milliseconds 20
        [System.IO.File]::WriteAllText($tablePath, 'table 50100 "T" { fields { field(1; A; Decimal) { } } }', $utf8Bom)
        Get-ALRunnerServerFingerprint -RepoRoot $repo | Should -Not -Be $f1
    }
}
Describe 'Request-ALRunnerServerRun failure path' {
    It 'returns null fast with -NoAutoStart and no pipe' {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $r = Request-ALRunnerServerRun -RepoRoot (Join-Path $TestDrive 'nowhere') -SourcePaths @('C:\a') -SummaryPath (Join-Path $TestDrive 's.json') -NoAutoStart
        $r | Should -BeNullOrEmpty
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 5
    }
}
Describe 'alrunner-server-manager.ps1 failure path' -Tag 'Process' {
    It 'exits 1 and logs a failure line when al-runner never signals ready' {
        $fakeBinDir = Join-Path $TestDrive 'fake-bin'
        New-Item -ItemType Directory -Path $fakeBinDir -Force | Out-Null
        # A stub that never writes {"ready":true} to stdout: Start-Child's
        # ReadLine() sees EOF immediately, so Start-Child throws and the manager
        # must log the failure and exit non-zero instead of hanging or leaving a
        # child behind.
        Set-Content -LiteralPath (Join-Path $fakeBinDir 'al-runner.cmd') -Value @'
@echo off
exit /b 0
'@

        $repoRoot = Join-Path $TestDrive 'repo-never-ready'
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
        New-MinimalBuildConfig -RepoRoot $repoRoot

        $managerPath = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'alrunner-server-manager.ps1'

        $originalPath = $env:PATH
        try {
            $env:PATH = "$fakeBinDir;$originalPath"
            & pwsh -NoProfile -File $managerPath -RepoRoot $repoRoot
            $exitCode = $LASTEXITCODE
        }
        finally {
            $env:PATH = $originalPath
        }

        $exitCode | Should -Be 1
        # The manager's own diagnostics land in al-runner-server-manager.log, a
        # file it owns outright - al-runner-server.log is reserved for the
        # child's stderr (redirected via cmd.exe's own 2>>, held open with no
        # sharing for the child's whole lifetime, so the manager never writes
        # its own lines there).
        $managerLogPath = Join-Path $repoRoot '.output' 'logs' 'al-runner-server-manager.log'
        $managerLog = Get-Content -LiteralPath $managerLogPath -Raw
        $managerLog | Should -Match 'did not signal ready'
        # Dependencies are self-contained (design decision 3): Start-Child
        # builds the package-cache dir before it ever spawns al-runner, and
        # logs it — this is the one place the manager's own construction of
        # the --package-cache argument is observable end to end.
        $managerLog | Should -Match ([regex]::Escape('[deps] package-cache: ' + (Join-Path $repoRoot '.output' 'al-runner-deps')))
    }
}

Describe 'alrunner-server-manager.ps1 request-drift workaround' {
    It 'recycles the child after every run while the al-runner drift defect is open' {
        # Deliberate pin. Reverting to a warm multi-run child is a decision, not a
        # drive-by: the comment above MaxRunsPerChild in the manager carries the
        # revert recipe and the upstream defect it waits on. Change this test in
        # the same commit that reverts.
        $managerPath = Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'alrunner-server-manager.ps1'
        $source = Get-Content -LiteralPath $managerPath -Raw
        $source | Should -Match '(?m)^\$script:MaxRunsPerChild = 1\s*$'
        $source | Should -Match 'WORKAROUND — al-runner --server request drift'
        $source | Should -Match '\$script:runCount -ge \$script:MaxRunsPerChild'
    }
}
