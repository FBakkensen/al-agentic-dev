#Requires -Version 7.2
<#
.SYNOPSIS
    agentStop hook: holds the turn open while a task file this session wrote is off-grammar.

.DESCRIPTION
    Reads the agentStop payload from stdin, runs Test-TaskFileGrammar.ps1 over the task
    files written since the session began, and returns `decision: block` with the findings
    as the reason. The CLI enqueues that reason as the next user message, so the agent
    fixes the file before the session ends — including a one-prompt session, whose single
    turn ends here.

    Session start is read from the transcript's creation time, so the very first run of
    the session already sees that session's writes. A repo carrying older task files does
    not hold every turn open, and a payload carrying no usable transcript stops the hook
    rather than widening it to every file.

    Blocks at most $script:MaxBlocks times per session. A file the agent cannot fix stops
    the hook rather than the session.

    Fails open: any error, missing parser, or missing `specs/` emits nothing.
#>

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:MaxBlocks = 2

function Get-PayloadValue {
    param($Payload, [string] $Name)
    if ($Payload -and $Payload.PSObject.Properties.Name -contains $Name) { return $Payload.$Name }
    return $null
}

try {
    $raw = [Console]::In.ReadToEnd()
    $payload = if ($raw) { $raw | ConvertFrom-Json } else { $null }

    $sessionId = Get-PayloadValue $payload 'sessionId'
    if (-not $sessionId) { $sessionId = 'unknown' }

    $projectDir = if ($env:COPILOT_PROJECT_DIR) { $env:COPILOT_PROJECT_DIR }
    else {
        $cwd = Get-PayloadValue $payload 'cwd'
        if ($cwd) { $cwd } else { (Get-Location).Path }
    }

    $specs = Join-Path $projectDir 'specs'
    if (-not (Test-Path -LiteralPath $specs)) { return }

    $parser = Join-Path $PSScriptRoot 'Test-TaskFileGrammar.ps1'
    if (-not (Test-Path -LiteralPath $parser)) { return }

    $safeId = ($sessionId -replace '[^A-Za-z0-9_-]', '_')
    $statePath = Join-Path ([System.IO.Path]::GetTempPath()) "al-task-grammar-$safeId.json"
    $blocks = 0
    if (Test-Path -LiteralPath $statePath) {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ($state.PSObject.Properties.Name -contains 'Blocks') { $blocks = [int]$state.Blocks }
    }
    if ($blocks -ge $script:MaxBlocks) { return }

    # Session start: the transcript is created with the session, so its creation time is
    # the baseline the very first time this hook runs.
    $since = $null
    $transcript = Get-PayloadValue $payload 'transcriptPath'
    if ($transcript -and (Test-Path -LiteralPath $transcript)) {
        $since = (Get-Item -LiteralPath $transcript).CreationTimeUtc
    }
    # No baseline means no way to tell this session's writes from the repo's history.
    # Checking everything would block turns over files the agent never touched, so stop.
    if (-not $since) { return }

    $candidates = @(
        Get-ChildItem -LiteralPath $specs -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{3}-T-\d{3}-' -and $_.LastWriteTimeUtc -ge $since }
    )
    if ($candidates.Count -eq 0) { return }

    $findings = @(& $parser -Path $candidates.FullName -IncludeDone)
    if ($findings.Count -eq 0) { return }

    @{ Blocks = $blocks + 1 } | ConvertTo-Json -Compress | Set-Content -LiteralPath $statePath -Encoding utf8

    $reason = @(
        'A task file you wrote this session is off-grammar. Fix it before closing.'
        ''
        ($findings -join "`n")
        ''
        'Shape rules: references/task-grammar.md. Verdicts: references/doc-integrity.md.'
    ) -join "`n"

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    @{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress
}
catch {
    return
}
