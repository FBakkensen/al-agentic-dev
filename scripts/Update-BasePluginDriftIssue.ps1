#Requires -Version 7.2

<#
.SYNOPSIS
    Maintains the one deduplicated Base plugin drift issue.
.DESCRIPTION
    On Failure, opens the issue, or reopens and comments on the oldest one, and closes any
    open duplicates. On Success, comments on and closes every open one.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Failure', 'Success')]
    [string]$Conclusion,

    [Parameter(Mandatory)]
    [string]$WorkflowUrl,

    [string]$Failure,

    [string]$Repository = $env:GITHUB_REPOSITORY,

    [scriptblock]$GhCommand = {
        param([string[]]$Arguments)
        $output = @(& gh @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "gh $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
        }
        $output
    }
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Repository) {
    throw 'Repository is required.'
}

$issueTitle = '[Drift] Base plugin skill references'

function Invoke-Gh {
    param([string[]]$Arguments)
    @(& $GhCommand $Arguments)
}

$issueJson = Invoke-Gh @(
    'issue', 'list',
    '--repo', $Repository,
    '--state', 'all',
    '--search', "$issueTitle in:title",
    '--limit', '100',
    '--json', 'number,title,state'
) | Out-String

$matchingIssues = @(
    if ($issueJson.Trim()) {
        $issueJson | ConvertFrom-Json | Where-Object Title -EQ $issueTitle | Sort-Object Number
    }
)
$openIssues = @($matchingIssues | Where-Object State -EQ 'OPEN')

if ($Conclusion -eq 'Failure') {
    $failureText = if ($Failure) { $Failure.Trim() } else { 'No failure output was captured.' }
    if ($failureText.Length -gt 12000) {
        $failureText = $failureText.Substring($failureText.Length - 12000)
    }
    $failureText = $failureText.Replace('```', "'''")

    $body = @"
The Base plugin drift check failed: a ``<ns>:<skill>`` reference names a skill upstream no longer ships, or a declared dependency could not be fetched.

- Workflow: $WorkflowUrl

``````text
$failureText
``````
"@

    if ($matchingIssues.Count -eq 0) {
        $null = Invoke-Gh @(
            'issue', 'create',
            '--repo', $Repository,
            '--title', $issueTitle,
            '--body', $body
        )
        return
    }

    $primaryIssue = $matchingIssues[0]
    if ($primaryIssue.State -ne 'OPEN') {
        $null = Invoke-Gh @(
            'issue', 'reopen', [string]$primaryIssue.Number,
            '--repo', $Repository
        )
    }
    $null = Invoke-Gh @(
        'issue', 'comment', [string]$primaryIssue.Number,
        '--repo', $Repository,
        '--body', $body
    )

    foreach ($duplicate in @($matchingIssues | Select-Object -Skip 1 | Where-Object State -EQ 'OPEN')) {
        $null = Invoke-Gh @(
            'issue', 'comment', [string]$duplicate.Number,
            '--repo', $Repository,
            '--body', "Closing as a duplicate of #$($primaryIssue.Number)."
        )
        $null = Invoke-Gh @(
            'issue', 'close', [string]$duplicate.Number,
            '--repo', $Repository,
            '--reason', 'not planned'
        )
    }
    return
}

foreach ($issue in $openIssues) {
    $null = Invoke-Gh @(
        'issue', 'comment', [string]$issue.Number,
        '--repo', $Repository,
        '--body', "The Base plugin drift check passed.`n`n- Workflow: $WorkflowUrl"
    )
    $null = Invoke-Gh @(
        'issue', 'close', [string]$issue.Number,
        '--repo', $Repository,
        '--reason', 'completed'
    )
}
