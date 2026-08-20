#Requires -Version 7.2
<#
.SYNOPSIS
    Routing smoke: one batched non-interactive copilot run over the scenarios file.
.DESCRIPTION
    Loads this repo's plugin into a scratch-directory copilot session via --plugin-dir,
    asks the model which skill it would route each scenario in scenarios.json to, and
    prints a pass/miss table against the expected answers.
    A miss is a signal to inspect, never a gate: scenario misses exit 0. Only a
    mechanical failure — copilot missing, no output, an unparseable answer — exits 1.
    Each run costs roughly 5 AI credits; run it by hand after a routing-relevant
    change, never in CI.
.EXAMPLE
    pwsh tests/routing/Invoke-RoutingSmoke.ps1
#>
[CmdletBinding()]
param(
    [string]$ScenariosPath = (Join-Path $PSScriptRoot 'scenarios.json'),
    [string]$PluginDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Error 'copilot CLI not found on PATH.'
    exit 1
}
$scenarios = (Get-Content -LiteralPath $ScenariosPath -Raw | ConvertFrom-Json).scenarios
if (-not $scenarios -or $scenarios.Count -eq 0) {
    Write-Error "No scenarios in $ScenariosPath."
    exit 1
}

$lines = foreach ($s in $scenarios) { "$($s.id): $($s.prompt)" }
$prompt = @"
You can see a set of Agent Skills. For each numbered scenario below, name the ONE skill you would invoke to handle it, or none when no visible skill fits.
Output ONLY a markdown table with columns id | skill — one row per scenario, no tool calls, no extra prose.

$($lines -join "`n")
"@

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) "routing-smoke-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    Push-Location $scratch
    try {
        $answer = copilot -p $prompt --plugin-dir $PluginDir --log-level none -s 2>&1 | Out-String
        $copilotExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
}

if ($copilotExit -ne 0) {
    Write-Host $answer
    Write-Error "copilot exited with code $copilotExit."
    exit 1
}
if (-not $answer.Trim()) {
    Write-Error 'copilot returned no output.'
    exit 1
}

$routed = @{}
foreach ($m in [regex]::Matches($answer, '(?m)^\|?\s*(S\d+)\s*\|\s*/?([A-Za-z0-9-]+)')) {
    $routed[$m.Groups[1].Value] = $m.Groups[2].Value.ToLowerInvariant()
}
if ($routed.Count -eq 0) {
    Write-Host $answer
    Write-Error 'No id | skill rows found in the answer above.'
    exit 1
}

$misses = 0
Write-Host ''
Write-Host '| id | expected | routed | verdict |'
Write-Host '|---|---|---|---|'
foreach ($s in $scenarios) {
    $got = if ($routed.ContainsKey($s.id)) { $routed[$s.id] } else { 'missing' }
    $verdict = if ($got -eq $s.expect) { 'pass' } else { $misses++; 'MISS' }
    Write-Host "| $($s.id) | $($s.expect) | $got | $verdict |"
}
Write-Host ''
if ($misses -eq 0) {
    Write-Host "All $($scenarios.Count) scenarios routed as expected." -ForegroundColor Green
} else {
    Write-Host "$misses of $($scenarios.Count) scenarios missed — inspect the descriptions involved; LLM routing varies, so re-run before treating a miss as real." -ForegroundColor Yellow
}
exit 0
