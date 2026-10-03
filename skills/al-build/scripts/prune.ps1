#requires -Version 7.2

<#
.SYNOPSIS
    Remove orphaned or stale agent containers, or one named agent container.

.DESCRIPTION
    Finds and removes BC agent containers that are:
    - Orphaned: branch no longer exists locally
    - Stale: unused for more than 7 days

    With -ContainerName it removes that one agent container instead, whether or not
    its branch exists, with both hosts entries (bare and .test). The golden container
    and a container that is not a registered agent container are refused with a
    non-zero exit, and so is a failed removal.

.PARAMETER ContainerName
    The one agent container to remove.

.PARAMETER Preview
    Show what would be removed without making changes.

.EXAMPLE
    pwsh -File prune.ps1
    # Remove orphaned containers

.EXAMPLE
    pwsh -File prune.ps1 -Preview
    # Preview only (dry run)

.EXAMPLE
    pwsh -File prune.ps1 -ContainerName feat-x
    # Remove the agent container feat-x while its branch still exists
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ContainerName,
    [switch]$Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -DisableNameChecking

if ($ContainerName) {
    Write-BuildHeader "Prune: Remove Agent Container '$ContainerName'"
    $config = Get-BuildConfig
    Remove-NamedAgentContainer -ContainerName $ContainerName -GoldenContainerName $config.GoldenContainerName -WhatIf:$Preview
} else {
    Write-BuildHeader 'Prune: Orphaned Container Cleanup'
    Remove-OrphanedAgentContainers -WhatIf:$Preview
}
