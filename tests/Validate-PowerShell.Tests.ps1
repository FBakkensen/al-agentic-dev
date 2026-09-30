#Requires -Version 7.2

BeforeAll {
    $script:ValidatorPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Validate-PowerShell.ps1')).Path

    function Set-FixtureFile {
        param([string]$Path, [string]$Value)
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($Path)) -Force | Out-Null
        Set-Content -LiteralPath $Path -Value $Value -Encoding utf8
    }

    function Invoke-PowerShellValidatorProcess {
        param([Parameter(Mandatory = $true)][string]$Root)

        $output = & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $Root 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
}

Describe 'Validate-PowerShell' -Tag 'Process' {
    It 'fails a script that does not parse' {
        $root = Join-Path $TestDrive 'broken'
        Set-FixtureFile (Join-Path $root 'scripts' 'Broken.ps1') 'function Broken {'

        $result = Invoke-PowerShellValidatorProcess -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'FAIL:.*Broken\.ps1'
    }

    It 'skips the eval copies of the Base plugins and the eval results' {
        $root = Join-Path $TestDrive 'eval-skip'
        Set-FixtureFile (Join-Path $root 'scripts' 'Good.ps1') 'Write-Output 1'
        Set-FixtureFile (Join-Path $root '.base-plugins' 'bcquality' 'Broken.ps1') 'function Broken {'
        Set-FixtureFile (Join-Path $root '.base-plugins' 'bcquality' 'Broken.psm1') 'function Broken {'
        Set-FixtureFile (Join-Path $root 'evals' 'results' 'run' 'Broken.ps1') 'function Broken {'

        $result = Invoke-PowerShellValidatorProcess -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Text
        $result.Text | Should -Match 'OK:.*Good\.ps1'
        $result.Text | Should -Not -Match 'Broken'
    }
}
