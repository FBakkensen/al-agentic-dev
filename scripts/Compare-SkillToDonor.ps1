#Requires -Version 7.2
<#
.SYNOPSIS
    Compares a skill folder against its donor and reports the diff.
.DESCRIPTION
    Ports land as pinned forks: the body stays donor text except the al- namespace, and
    the diff against the donor is the port note and the debug surface when a ported
    skill misbehaves. This script materializes the donor — a git ref in this repo
    (-DonorRef, with -DonorPath when the donor lived at a different path) or a local
    directory such as an external donor checkout (-DonorDir) — and runs git diff
    --no-index against the skill folder, ignoring CR/LF differences so a Windows
    checkout compares clean against committed LF. On a pinned fork the expected report
    is exit 2 with exactly the namespace hunks — the frontmatter name line and any
    renamed sibling reference — and nothing else.
    Exit codes: 0 the skill matches its donor line for line, 2 the diff is
    non-empty, 1 the skill or donor cannot be resolved.
.EXAMPLE
    pwsh scripts/Compare-SkillToDonor.ps1 -Skill al-grill-me -DonorRef 688915f -DonorPath skills/grill-me
.EXAMPLE
    pwsh scripts/Compare-SkillToDonor.ps1 -Skill al-grill-me -DonorDir C:\donors\pocock-skills\grill-me
#>
[CmdletBinding(DefaultParameterSetName = 'Ref')]
param(
    [string]$Skill,

    [Parameter(ParameterSetName = 'Ref')]
    [string]$DonorRef,

    [Parameter(ParameterSetName = 'Ref')]
    [string]$DonorPath,

    [Parameter(ParameterSetName = 'Dir')]
    [string]$DonorDir,

    [string]$SkillsRoot = (Join-Path $PSScriptRoot '..' 'skills')
)

function Invoke-SkillDonorComparison {
    [CmdletBinding(DefaultParameterSetName = 'Ref')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Skill,

        [Parameter(Mandatory = $true, ParameterSetName = 'Ref')]
        [string]$DonorRef,

        [Parameter(ParameterSetName = 'Ref')]
        [string]$DonorPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Dir')]
        [string]$DonorDir,

        [string]$SkillsRoot = (Join-Path $PSScriptRoot '..' 'skills')
    )

$script:DonorComparisonExitCode = 1
$skillDir = Join-Path $SkillsRoot $Skill
if (-not (Test-Path -LiteralPath $skillDir -PathType Container)) {
    Write-Error "Skill folder not found: $skillDir"
    return
}
$skillDir = (Resolve-Path -LiteralPath $skillDir).Path

$stage = $null
try {
    if ($PSCmdlet.ParameterSetName -eq 'Dir') {
        if (-not (Test-Path -LiteralPath $DonorDir -PathType Container)) {
            Write-Error "Donor directory not found: $DonorDir"
            return
        }
        $donor = (Resolve-Path -LiteralPath $DonorDir).Path
    } else {
        if (-not $DonorPath) { $DonorPath = "skills/$Skill" }
        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        $entries = @(git -C $repoRoot ls-tree -r --name-only $DonorRef -- $DonorPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $entries.Count -eq 0) {
            Write-Error "Donor not found at ${DonorRef}:${DonorPath}"
            return
        }
        $stage = Join-Path ([System.IO.Path]::GetTempPath()) "donor-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $stage | Out-Null
        $tarFile = Join-Path $stage 'donor.tar'
        git -C $repoRoot archive --format=tar -o $tarFile $DonorRef -- $DonorPath
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git archive failed for ${DonorRef}:${DonorPath}"
            return
        }
        tar -xf $tarFile -C $stage
        if ($LASTEXITCODE -ne 0) {
            Write-Error "tar extraction failed for $tarFile"
            return
        }
        Remove-Item -LiteralPath $tarFile
        $donor = Join-Path $stage ($DonorPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $donor -PathType Container)) {
            Write-Error "Donor extraction produced no folder at $donor"
            return
        }
    }

    git --no-pager diff --no-index --ignore-cr-at-eol -- $donor $skillDir
    $diffExit = $LASTEXITCODE
    if ($diffExit -eq 0) {
        Write-Host "Identical: $Skill matches its donor." -ForegroundColor Green
        $script:DonorComparisonExitCode = 0
        return
    }
    if ($diffExit -eq 1) {
        Write-Host "Differs: $Skill diverges from its donor; the diff above is the port note." -ForegroundColor Yellow
        $script:DonorComparisonExitCode = 2
        return
    }
    Write-Error "git diff failed with exit code $diffExit"
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force -Confirm:$false
    }
}
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    Invoke-SkillDonorComparison @PSBoundParameters
    exit $script:DonorComparisonExitCode
}
