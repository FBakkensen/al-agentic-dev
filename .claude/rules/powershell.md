---
paths:
  - "**/*.ps1"
---

# Editing a PowerShell script

1. The first line is `#Requires -Version 7.2`. Flag Windows PowerShell 5.1 syntax and any construct that needs the desktop edition.
2. Every failure path exits non-zero — `throw`, or `exit 1` after writing the error. Flag a script that reports a failure and still returns 0; that turns a red gate green.
3. Scripts run unattended, in CI and in agent sessions. Flag `Read-Host`, `Get-Credential`, `Pause`, and a destructive cmdlet left able to prompt; pass `-Confirm:$false` where the action is intended.
4. Paths are quoted and composed with `Join-Path`. Runner paths contain spaces.
   - Correct: `Import-Module (Join-Path $PSScriptRoot 'common.psm1')`
   - Incorrect: `Import-Module $PSScriptRoot\common.psm1`
5. A new script under `skills/al-build/scripts/` needs a Pester test under `tests/al-build/` covering at least its failure path.
