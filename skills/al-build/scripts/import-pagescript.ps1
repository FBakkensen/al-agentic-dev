#requires -Version 7.2

<#
.SYNOPSIS
    Move a downloaded Page Scripting recording into pagescripts/recordings/.

.DESCRIPTION
    Takes the .yml the user downloaded from BC's Page Scripting recorder and
    lands it in the consumer repo under pagescripts/recordings/ with the
    convention name the caller supplies, creating the folders when missing.
    Prints the repo-relative path of the imported recording; replay it with
    pagescript-replay.ps1 -File <that path>.

.PARAMETER File
    Path to the downloaded .yml recording. Absolute, or relative to the
    current directory.

.PARAMETER TargetName
    File name the recording lands under — a name, not a path, ending in .yml.

.PARAMETER Force
    Overwrite an existing recording of the same name (a re-record).

.EXAMPLE
    pwsh -File import-pagescript.ps1 -File "$env:USERPROFILE\Downloads\recording.yml" -TargetName 007-flag-late-receipt__flag-late-receipt-date__01.yml
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [Parameter(Mandatory = $true)]
    [string]$TargetName,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking

$workspaceRoot = Get-GitRepoRoot

if ($TargetName -match '[\\/]') {
    Write-BuildMessage -Type Error -Message "TargetName is a file name, not a path: $TargetName"
    exit 1
}
if ($TargetName -notmatch '\.yml$') {
    Write-BuildMessage -Type Error -Message "TargetName must end in .yml: $TargetName"
    exit 1
}
if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    Write-BuildMessage -Type Error -Message "Recording not found: $File"
    exit 1
}

$recordingsDir = Join-Path $workspaceRoot 'pagescripts' 'recordings'
Ensure-Directory -Path $recordingsDir

$target = Join-Path $recordingsDir $TargetName
if ((Test-Path -LiteralPath $target) -and -not $Force) {
    Write-BuildMessage -Type Error -Message "Recording already exists: $target. Pass -Force to overwrite (a re-record)."
    exit 1
}

Move-Item -LiteralPath $File -Destination $target -Force
$relative = [IO.Path]::GetRelativePath($workspaceRoot, $target) -replace '\\', '/'
Write-BuildMessage -Type Success -Message "Imported: $relative"
$relative
