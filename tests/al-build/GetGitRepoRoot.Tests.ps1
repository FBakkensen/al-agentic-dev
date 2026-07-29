#Requires -Version 7.2

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force
}

Describe 'Get-GitRepoRoot' {
    It 'is exported from common.psm1' {
        Get-Command Get-GitRepoRoot -Module common -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'returns the repo root from a subdirectory of a git repo' {
        $expected = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..'))
        Push-Location $PSScriptRoot
        try {
            Get-GitRepoRoot | Should -Be $expected
        } finally {
            Pop-Location
        }
    }

    It 'falls back to the current directory when git is not on PATH' {
        # Child pwsh with an empty PATH: '& git' throws CommandNotFoundException even
        # under $ErrorActionPreference = 'Stop', which the function must swallow.
        $probe = @"
Import-Module '$($script:CommonModule.Path)' -Force -DisableNameChecking
`$ErrorActionPreference = 'Stop'
Set-Location ([IO.Path]::GetTempPath())
`$env:PATH = ''
Get-GitRepoRoot
"@
        $result = & pwsh -NoProfile -NonInteractive -Command $probe
        $LASTEXITCODE | Should -Be 0
        [IO.Path]::TrimEndingDirectorySeparator([string]$result) |
            Should -Be ([IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetTempPath()))
    }
}
