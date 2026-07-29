#Requires -Version 7.2

BeforeAll {
    $script:ImportScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'import-pagescript.ps1')).Path

    function Invoke-Import {
        param(
            [Parameter(Mandatory = $true)][string]$WorkDir,
            [Parameter(Mandatory = $true)][string[]]$Arguments
        )

        Push-Location $WorkDir
        try {
            $output = & pwsh -NoProfile -File $script:ImportScriptPath @Arguments 2>&1
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
            }
        } finally {
            Pop-Location
        }
    }

    function New-WorkDir {
        param([Parameter(Mandatory = $true)][string]$Name)
        (New-Item -ItemType Directory -Path (Join-Path $TestDrive $Name) -Force).FullName
    }

    function New-Download {
        param(
            [Parameter(Mandatory = $true)][string]$Name,
            [string]$Content = 'name: recorded scenario'
        )
        $path = Join-Path $TestDrive $Name
        Set-Content -LiteralPath $path -Value $Content -Encoding utf8
        $path
    }
}

Describe 'import-pagescript' {
    It 'moves the recording into pagescripts/recordings under the target name, creating the folders' {
        $work = New-WorkDir 'repo-happy'
        $download = New-Download 'happy-download.yml'

        $result = Invoke-Import -WorkDir $work -Arguments @('-File', $download, '-TargetName', '001-demo__slice__01.yml')

        $result.ExitCode | Should -Be 0
        $imported = Join-Path $work 'pagescripts' 'recordings' '001-demo__slice__01.yml'
        Test-Path -LiteralPath $imported | Should -BeTrue
        Test-Path -LiteralPath $download | Should -BeFalse
        $result.Text | Should -Match 'pagescripts/recordings/001-demo__slice__01\.yml'
    }

    It 'fails when the source recording does not exist' {
        $work = New-WorkDir 'repo-missing-source'

        $result = Invoke-Import -WorkDir $work -Arguments @('-File', (Join-Path $TestDrive 'absent.yml'), '-TargetName', '001-demo__slice__01.yml')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Recording not found'
    }

    It 'refuses to overwrite an existing recording without -Force' {
        $work = New-WorkDir 'repo-collision'
        $existing = Join-Path $work 'pagescripts' 'recordings'
        New-Item -ItemType Directory -Path $existing -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $existing '001-demo__slice__01.yml') -Value 'name: first take'
        $download = New-Download 'collision-download.yml' -Content 'name: second take'

        $result = Invoke-Import -WorkDir $work -Arguments @('-File', $download, '-TargetName', '001-demo__slice__01.yml')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'already exists'
        Get-Content -LiteralPath (Join-Path $existing '001-demo__slice__01.yml') -Raw | Should -Match 'first take'
        Test-Path -LiteralPath $download | Should -BeTrue
    }

    It 'overwrites an existing recording with -Force' {
        $work = New-WorkDir 'repo-force'
        $existing = Join-Path $work 'pagescripts' 'recordings'
        New-Item -ItemType Directory -Path $existing -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $existing '001-demo__slice__01.yml') -Value 'name: first take'
        $download = New-Download 'force-download.yml' -Content 'name: second take'

        $result = Invoke-Import -WorkDir $work -Arguments @('-File', $download, '-TargetName', '001-demo__slice__01.yml', '-Force')

        $result.ExitCode | Should -Be 0
        Get-Content -LiteralPath (Join-Path $existing '001-demo__slice__01.yml') -Raw | Should -Match 'second take'
    }

    It 'rejects a TargetName that is a path rather than a file name' {
        $work = New-WorkDir 'repo-target-path'
        $download = New-Download 'path-download.yml'

        $result = Invoke-Import -WorkDir $work -Arguments @('-File', $download, '-TargetName', '..\evil.yml')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'file name, not a path'
    }

    It 'rejects a TargetName without a .yml extension' {
        $work = New-WorkDir 'repo-target-ext'
        $download = New-Download 'ext-download.yml'

        $result = Invoke-Import -WorkDir $work -Arguments @('-File', $download, '-TargetName', '001-demo__slice__01.txt')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'must end in \.yml'
    }
}
