#Requires -Version 7.2
<#
.SYNOPSIS
    Prints the SessionStart or SubagentStart hook payload for al-agentic-dev.
.DESCRIPTION
    Reads the static delegation rules and entry -> addition table from
    session-start.md beside this script. SessionStart writes the whole text to
    stdout as additionalContext; SubagentStart writes only the entry -> addition
    section, up to the next level-2 heading, so a subagent loads an addition beside its entry skill. Exits 1 when
    the text file is missing or empty, or lacks that section.
.EXAMPLE
    pwsh -NoProfile -File hooks/Write-SessionStart.ps1
.EXAMPLE
    pwsh -NoProfile -File hooks/Write-SessionStart.ps1 -Event SubagentStart
#>
[CmdletBinding()]
param(
    [ValidateSet('SessionStart', 'SubagentStart')]
    [string]$Event = 'SessionStart'
)

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

if ($Event -eq 'SubagentStart') {
    $start = $text.IndexOf('## Entry skills and their AL additions', [StringComparison]::Ordinal)
    if ($start -lt 0) {
        [Console]::Error.WriteLine("SubagentStart section is missing from: $textPath")
        exit 1
    }
    $text = $text.Substring($start)
    $next = [regex]::Match($text.Substring(1), '(?m)^## ')
    if ($next.Success) {
        $text = $text.Substring(0, $next.Index + 1).TrimEnd() + "`n"
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$payload = @{
    hookSpecificOutput = @{
        hookEventName     = $Event
        additionalContext = $text
    }
}
[Console]::Out.Write(($payload | ConvertTo-Json -Compress -Depth 3))
exit 0
