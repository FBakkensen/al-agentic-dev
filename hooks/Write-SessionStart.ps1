#Requires -Version 7.2
<#
.SYNOPSIS
    Prints the SessionStart hook payload for al-agentic-dev.
.DESCRIPTION
    Reads the static delegation rules from session-start.md beside this script and
    writes them to stdout as SessionStart additionalContext. Exits 1 when the text
    file is missing or empty.
.EXAMPLE
    pwsh -NoProfile -File hooks/Write-SessionStart.ps1
#>
[CmdletBinding()]
param()

$textPath = Join-Path $PSScriptRoot 'session-start.md'
if (-not (Test-Path -LiteralPath $textPath -PathType Leaf)) {
    [Console]::Error.WriteLine("SessionStart text is missing: $textPath")
    exit 1
}

$text = Get-Content -LiteralPath $textPath -Raw -Encoding utf8
if (-not $text -or -not $text.Trim()) {
    [Console]::Error.WriteLine("SessionStart text is empty: $textPath")
    exit 1
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$payload = @{
    hookSpecificOutput = @{
        hookEventName     = 'SessionStart'
        additionalContext = $text
    }
}
[Console]::Out.Write(($payload | ConvertTo-Json -Compress -Depth 3))
exit 0
