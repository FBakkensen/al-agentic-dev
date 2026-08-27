#Requires -Version 7.2

BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Compare-SkillToDonor.ps1')).Path
    . $script:ScriptPath

    function Invoke-DonorCompare {
        param(
            [Parameter(Mandatory = $true)]
            [string[]]$Arguments
        )

        $parameters = @{}
        for ($index = 0; $index -lt $Arguments.Count; $index += 2) {
            $parameters[$Arguments[$index].TrimStart('-')] = $Arguments[$index + 1]
        }
        $output = @(
            & {
                Invoke-SkillDonorComparison @parameters -ErrorAction Continue
            } *>&1
        )
        return [pscustomobject]@{
            ExitCode = $script:DonorComparisonExitCode
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }

    function Invoke-DonorCompareProcess {
        param(
            [Parameter(Mandatory = $true)]
            [string[]]$Arguments
        )

        $output = & pwsh -NoProfile -File $script:ScriptPath @Arguments 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }

    function New-SkillFolder {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [string]$Name,

            [string]$Body = "---`nname: demo`ndescription: Demo.`n---`n`n# demo`n"
        )

        $dir = Join-Path $Root $Name
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value $Body -Encoding utf8 -NoNewline
        return $dir
    }
}

Describe 'Compare-SkillToDonor' -Tag 'Unit' {
    It 'fails when the skill folder is missing' {
        $skillsRoot = Join-Path $TestDrive 'no-skill'
        New-Item -ItemType Directory -Path $skillsRoot | Out-Null

        $result = Invoke-DonorCompare -Arguments @('-Skill', 'ghost', '-DonorDir', $TestDrive, '-SkillsRoot', $skillsRoot)

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Skill folder not found'
    }

    It 'fails when the donor directory is missing' {
        $skillsRoot = Join-Path $TestDrive 'no-donor'
        New-SkillFolder -Root $skillsRoot -Name 'demo' | Out-Null

        $result = Invoke-DonorCompare -Arguments @('-Skill', 'demo', '-DonorDir', (Join-Path $TestDrive 'absent'), '-SkillsRoot', $skillsRoot)

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Donor directory not found'
    }

    It 'fails when the donor ref does not resolve' {
        $skillsRoot = Join-Path $TestDrive 'bad-ref'
        New-SkillFolder -Root $skillsRoot -Name 'demo' | Out-Null

        $result = Invoke-DonorCompare -Arguments @('-Skill', 'demo', '-DonorRef', 'no-such-ref-anywhere', '-SkillsRoot', $skillsRoot)

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'Donor not found at no-such-ref-anywhere'
    }

    It 'reports identical for a matching copy' {
        $skillsRoot = Join-Path $TestDrive 'same'
        $skill = New-SkillFolder -Root $skillsRoot -Name 'demo'
        $donor = Join-Path $TestDrive 'same-donor'
        Copy-Item -LiteralPath $skill -Destination $donor -Recurse

        $result = Invoke-DonorCompare -Arguments @('-Skill', 'demo', '-DonorDir', $donor, '-SkillsRoot', $skillsRoot)

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'Identical: demo matches its donor'
    }

    It 'reports the diff for a diverged port' {
        $skillsRoot = Join-Path $TestDrive 'diverged'
        $skill = New-SkillFolder -Root $skillsRoot -Name 'demo'
        $donor = Join-Path $TestDrive 'diverged-donor'
        Copy-Item -LiteralPath $skill -Destination $donor -Recurse
        Add-Content -LiteralPath (Join-Path $skill 'SKILL.md') -Value 'One ported edit.'

        $result = Invoke-DonorCompare -Arguments @('-Skill', 'demo', '-DonorDir', $donor, '-SkillsRoot', $skillsRoot)

        $result.ExitCode | Should -Be 2
        $result.Text | Should -Match 'One ported edit'
        $result.Text | Should -Match 'Differs: demo diverges from its donor'
    }
}

Describe 'Compare-SkillToDonor process wrapper' -Tag 'Process' {
    It 'returns zero for identical folders' {
        $skillsRoot = Join-Path $TestDrive 'process-same'
        $skill = New-SkillFolder -Root $skillsRoot -Name 'demo'
        $donor = Join-Path $TestDrive 'process-same-donor'
        Copy-Item -LiteralPath $skill -Destination $donor -Recurse

        $result = Invoke-DonorCompareProcess -Arguments @(
            '-Skill', 'demo', '-DonorDir', $donor, '-SkillsRoot', $skillsRoot
        )

        $result.ExitCode | Should -Be 0
    }

    It 'returns nonzero when the skill is missing' {
        $skillsRoot = Join-Path $TestDrive 'process-missing'
        New-Item -ItemType Directory -Path $skillsRoot | Out-Null

        $result = Invoke-DonorCompareProcess -Arguments @(
            '-Skill', 'ghost', '-DonorDir', $TestDrive, '-SkillsRoot', $skillsRoot
        )

        $result.ExitCode | Should -Be 1
    }
}
