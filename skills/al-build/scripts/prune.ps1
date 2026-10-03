#requires -Version 7.2

<#
.SYNOPSIS
    Remove orphaned or stale agent containers, or one named agent container.

.DESCRIPTION
    Finds and removes BC agent containers that are:
    - Orphaned: branch no longer exists locally
    - Stale: unused for more than 7 days

    With -ContainerName it removes that one agent container instead, whether or not
    its branch exists, with both hosts entries (bare and .test). A name that is not a
    registered agent container, such as the golden container, is refused with a
    non-zero exit.

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

if ($ContainerName) {
    Write-BuildHeader "Prune: Remove Agent Container '$ContainerName'"
    Remove-NamedAgentContainer -ContainerName $ContainerName -WhatIf:$Preview
} else {
    Write-BuildHeader 'Prune: Orphaned Container Cleanup'
    Remove-OrphanedAgentContainers -WhatIf:$Preview
}
