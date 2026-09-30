#Requires -Version 7.2
<#
.SYNOPSIS
    The one <ns>:<skill> tokenizer, shared by the skills gate and the Base plugin drift check.
.DESCRIPTION
    Dot-source it. Get-NamespacedSkillReference emits every <ns>:<skill> candidate outside
    fenced blocks; each caller decides which namespaces count as references.
#>

function Get-NamespacedSkillReference {
    <#
    .SYNOPSIS
        Emits every <ns>:<skill> candidate outside fenced blocks; the caller filters namespaces.
    .DESCRIPTION
        Each candidate carries Namespace, Skill, Line, and Slash, true when a '/' leads it.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $pattern = '(?<![\w./:@-])(?<slash>/)?(?<ns>[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*):(?<skill>[A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)*)(?![\w-])'
    $fenceChar = ''
    $fenceLength = 0
    $lineNumber = 0
    foreach ($line in ($Text -split '\r?\n')) {
        $lineNumber++
        $run = [regex]::Match($line, '^\s*(?<fence>`{3,}|~{3,})')
        if ($run.Success) {
            $fence = $run.Groups['fence'].Value
            if ($fenceLength -eq 0) {
                $fenceChar = $fence[0]
                $fenceLength = $fence.Length
                continue
            } elseif ($fence[0] -eq $fenceChar -and $fence.Length -ge $fenceLength) {
                $fenceLength = 0
                continue
            }
        }
        if ($fenceLength -gt 0) { continue }
        foreach ($match in [regex]::Matches($line, $pattern)) {
            [pscustomobject]@{
                Namespace = $match.Groups['ns'].Value
                Skill     = $match.Groups['skill'].Value
                Line      = $lineNumber
                Slash     = $match.Groups['slash'].Success
            }
        }
    }
}
