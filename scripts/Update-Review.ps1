#Requires -Version 7.2
<#
.SYNOPSIS
    Regenerates REVIEW.md from .github/instructions/skills.instructions.md.
.DESCRIPTION
    REVIEW.md is the reviewer-facing copy of skills.instructions.md behind a
    fixed preamble. Default: write REVIEW.md. -Check: compare whole-file
    equality without writing and exit 1 on drift (the CI gate).
.EXAMPLE
    pwsh scripts/Update-Review.ps1
.EXAMPLE
    pwsh scripts/Update-Review.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourcePath = Join-Path $repoRoot '.github' 'instructions' 'skills.instructions.md'
$reviewPath = Join-Path $repoRoot 'REVIEW.md'

$preamble = @'
Report a violation of any directive below — they govern `skills/**/*.md` and `agents/*.agent.md` — as **Important**, not as a nit.

Skip findings under `skills/al-build/scripts/`; CI already covers that path.


'@

# The instruction file opens with an applyTo: frontmatter block that governs the
# instruction harness, not the reviewer; REVIEW.md carries only the body.
$body = ((Get-Content -LiteralPath $sourcePath -Raw) -replace '(?s)^---.*?---\r?\n').TrimStart("`r", "`n")
$expected = $preamble + $body

if ($Check) {
    $actual = if (Test-Path -LiteralPath $reviewPath) { Get-Content -LiteralPath $reviewPath -Raw } else { '' }
    if (($actual -replace "`r`n", "`n") -ne ($expected -replace "`r`n", "`n")) {
        Write-Host 'REVIEW.md is out of sync with skills.instructions.md. Run scripts/Update-Review.ps1 to regenerate it.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'REVIEW.md is in sync with skills.instructions.md.' -ForegroundColor Green
} else {
    Set-Content -LiteralPath $reviewPath -Value $expected -NoNewline -Encoding utf8
    Write-Host 'REVIEW.md regenerated from skills.instructions.md.' -ForegroundColor Green
}
