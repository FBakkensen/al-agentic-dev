#Requires -Version 7.2
<#
.SYNOPSIS
    Hook smoke: two non-interactive copilot runs proving sessionStart injection live.
.DESCRIPTION
    Loads this repo's plugin — its committed hooks.json — into two scratch-directory
    copilot sessions via --plugin-dir and asserts on the model's reply text:
    Run 1, an AL fixture (app.json at the root): the Speak BC voice rule and the reply
    shape both injected, and the ask_user deny still firing.
    Run 2, a plain directory: the reply shape injected, the voice rule absent.
    Assertions match short distinctive substrings, not whole sentences. Unlike routing
    misses, these are deterministic hook behavior: any assertion failure exits 1.
    Each run costs roughly 5 AI credits; run it by hand after any hooks.json change,
    never in CI.
.EXAMPLE
    pwsh tests/hooks/Invoke-HookSmoke.ps1
#>
[CmdletBinding()]
param(
    [string]$PluginDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Error 'copilot CLI not found on PATH.'
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $PluginDir 'hooks.json') -PathType Leaf)) {
    Write-Error "No hooks.json under $PluginDir."
    exit 1
}

$quotePrompt = 'Quote verbatim every standing instruction you received as additional context this session about reply shape and about vocabulary. Then attempt to call the ask_user tool once and report the exact denial reason you get back. No other commentary.'

function Invoke-Fixture {
    param([string]$Name, [scriptblock]$Seed)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) "hook-smoke-$Name-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        & $Seed $dir
        Push-Location $dir
        try {
            $answer = copilot -p $quotePrompt --plugin-dir $PluginDir --allow-tool 'ask_user' --log-level none -s 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
    } finally {
        Remove-Item -LiteralPath $dir -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
    if ($exit -ne 0) {
        Write-Host $answer
        Write-Error "copilot exited with code $exit in the $Name fixture."
        exit 1
    }
    return $answer
}

$alReply = Invoke-Fixture -Name 'al' -Seed {
    param($dir)
    '{"id":"00000000-0000-0000-0000-000000000000","name":"Hook Smoke Fixture","publisher":"al-agentic-dev","version":"1.0.0.0"}' |
        Set-Content -Path (Join-Path $dir 'app.json')
}
$plainReply = Invoke-Fixture -Name 'plain' -Seed { param($dir) }

$assertions = @(
    @{ run = 'al'; text = $alReply; token = 'one sentence before the first tool call'; expect = $true; what = 'reply shape injected' }
    @{ run = 'al'; text = $alReply; token = 'Insert not create'; expect = $true; what = 'voice rule injected' }
    @{ run = 'al'; text = $alReply; token = 'codeunit not class'; expect = $true; what = 'voice rule injected (second token)' }
    @{ run = 'al'; text = $alReply; token = 'disabled by al-agentic-dev'; expect = $true; what = 'ask_user deny fired' }
    @{ run = 'plain'; text = $plainReply; token = 'one sentence before the first tool call'; expect = $true; what = 'reply shape injected' }
    @{ run = 'plain'; text = $plainReply; token = 'Insert not create'; expect = $false; what = 'voice rule absent' }
    @{ run = 'plain'; text = $plainReply; token = 'codeunit not class'; expect = $false; what = 'voice rule absent (second token)' }
)

$failures = 0
Write-Host ''
Write-Host '| run | assertion | token | verdict |'
Write-Host '|---|---|---|---|'
foreach ($a in $assertions) {
    $has = $a.text.Contains($a.token)
    $ok = ($has -eq $a.expect)
    if (-not $ok) { $failures++ }
    $verdict = if ($ok) { 'pass' } else { 'FAIL' }
    Write-Host "| $($a.run) | $($a.what) | $($a.token) | $verdict |"
}
Write-Host ''
if ($failures -gt 0) {
    Write-Host '--- AL fixture reply ---'; Write-Host $alReply
    Write-Host '--- plain fixture reply ---'; Write-Host $plainReply
    Write-Error "$failures hook assertion(s) failed — the replies above show what the model actually received."
    exit 1
}
Write-Host "All $($assertions.Count) hook assertions passed." -ForegroundColor Green
exit 0
