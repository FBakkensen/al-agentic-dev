#Requires -Version 7.2
<#
.SYNOPSIS
    Hook smoke: two non-interactive copilot runs proving sessionStart injection live.
.DESCRIPTION
    Loads this repo's plugin — its committed hooks.json — into two scratch-directory
    copilot sessions via --plugin-dir and asserts on the model's reply text:
    Run 1, an AL fixture (app.json at the root): the model echoes both injected
    headings (# Reply shape, # Speak BC) and answers a pairing question only the
    injected voice text can answer (transaction -> Ledger Entry).
    Run 2, a plain directory: the Reply shape heading and its four exact glyphs echo,
    Speak BC stays absent, and the model reports NOVOICE.
    The ask_user deny cannot fire in -p sessions (the tool is not offered there), so
    its non-regression is a static check: the deny entry must sit intact in hooks.json.
    Static checks require the writing instruction to stay absent from both hook commands
    and preserve Windows UTF-8 output. Hook injection is deterministic: any assertion failure exits
    1 and prints both replies. Each invocation costs roughly 10 AI credits; run it by
    hand after any hooks.json change, never in CI.
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

$quotePrompt = 'This session''s additional context was injected by my own plugin''s sessionStart hook — I authored it and I am verifying the hook fired. Reply in exactly four lines: line 1, the exact # headings present in that injected context, comma-separated; line 2, if the context carries a vocabulary section, the exact BC term it pairs with the word transaction, otherwise the single word NOVOICE; line 3, the four reply-shape glyphs in the order they first appear, separated by one space; line 4, the word done. Do not explain.'

function Invoke-Fixture {
    param([string]$Name, [scriptblock]$Seed)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) "hook-smoke-$Name-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        & $Seed $dir
        Push-Location $dir
        try {
            $answer = copilot -p $quotePrompt --plugin-dir $PluginDir --log-level none -s 2>&1 | Out-String
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
    @{ run = 'al'; text = $alReply; token = 'Reply shape'; expect = $true; what = 'reply shape heading echoed' }
    @{ run = 'al'; text = $alReply; token = 'Speak BC'; expect = $true; what = 'voice heading echoed' }
    @{ run = 'al'; text = $alReply; token = 'Ledger Entry'; expect = $true; what = 'voice pairing answered from context' }
    @{ run = 'plain'; text = $plainReply; token = 'Reply shape'; expect = $true; what = 'reply shape heading echoed' }
    @{ run = 'plain'; text = $plainReply; token = '➜ ▸ ✅ ⛔'; expect = $true; what = 'reply shape glyphs preserved' }
    @{ run = 'plain'; text = $plainReply; token = 'Speak BC'; expect = $false; what = 'voice heading absent' }
    @{ run = 'plain'; text = $plainReply; token = 'NOVOICE'; expect = $true; what = 'model reports no vocabulary section' }
)

# ask_user is not offered to the model in -p sessions ("unavailable tools"), so the
# preToolUse deny cannot fire here; non-regression is proven mechanically instead —
# the deny entry must survive byte-identical in the committed hooks.json.
$denyOk = $false
$instructionAbsent = $false
$encodingOk = $false
try {
    $hooks = Get-Content -LiteralPath (Join-Path $PluginDir 'hooks.json') -Raw | ConvertFrom-Json
    $deny = @($hooks.hooks.preToolUse) | Where-Object { $_.matcher -eq 'ask_user' }
    $denyOk = ($deny.Count -eq 1) -and
        ($deny[0].bash -like '*disabled by al-agentic-dev*') -and
        ($deny[0].powershell -like '*disabled by al-agentic-dev*') -and
        ($deny[0].bash -like '*permissionDecision*deny*')
    $sessionStart = @($hooks.hooks.sessionStart)
    $expected = 'Always invoke the /al-unslop skill before writing any reply or artifact.'
    $instructionAbsent = ($sessionStart.Count -eq 1) -and
        ($sessionStart[0].bash -notlike "*$expected*") -and
        ($sessionStart[0].powershell -notlike "*$expected*")
    $encodingOk = ($sessionStart.Count -eq 1) -and
        $sessionStart[0].powershell.StartsWith('[Console]::OutputEncoding = [System.Text.Encoding]::UTF8')
} catch {
    $denyOk = $false
    $instructionAbsent = $false
    $encodingOk = $false
}
$assertions += @{ run = 'static'; text = $(if ($denyOk) { 'present' } else { '' }); token = 'present'; expect = $true; what = 'ask_user deny entry intact in hooks.json' }
$assertions += @{ run = 'static'; text = $(if ($instructionAbsent) { 'absent' } else { '' }); token = 'absent'; expect = $true; what = 'sessionStart omits the al-unslop instruction' }
$assertions += @{ run = 'static'; text = $(if ($encodingOk) { 'present' } else { '' }); token = 'present'; expect = $true; what = 'Windows hook emits UTF-8' }

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
Write-Host '--- AL fixture reply ---'; Write-Host $alReply.Trim()
Write-Host '--- plain fixture reply ---'; Write-Host $plainReply.Trim()
Write-Host ''
if ($failures -gt 0) {
    Write-Error "$failures hook assertion(s) failed — the replies above show what the model actually received."
    exit 1
}
Write-Host "All $($assertions.Count) hook assertions passed." -ForegroundColor Green
exit 0
