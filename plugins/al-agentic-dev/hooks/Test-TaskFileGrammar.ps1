#Requires -Version 7.2
<#
.SYNOPSIS
    Checks per-task file bodies against the shape rules in references/task-grammar.md.

.DESCRIPTION
    Parses the body of one or more `NNN-T-MMM-<slug>.md` task files and reports every
    departure from the grammar: heading level, section order, required sections and
    fields, case header form, field order, value separators, inline comments, table
    column contracts, and coverage cross-references.

    Emits one line per finding as `<file>:<line> [<rule>] <message>`. Exit code is 1
    when any finding is reported and 0 otherwise, so a caller can gate on it.

.PARAMETER Path
    Task files, or folders to scan for `NNN-T-MMM-*.md`. Defaults to the current directory.

.PARAMETER IncludeDone
    Also check tasks at `status: done`. Those may predate the grammar, so they are
    skipped by default.

.EXAMPLE
    ./Test-TaskFileGrammar.ps1 -Path specs/035-charge-validation/tasks
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Path = @('.'),

    [switch] $IncludeDone
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# --- the grammar, in declaration order -------------------------------------------------

$script:Sections = @(
    @{ Name = 'Acceptance Intent';        Form = 'labeled'; Kinds = @('technical');           Required = $false }
    @{ Name = 'New and Modified Objects'; Form = 'heading'; Kinds = @('technical');           Required = $true;  AllowsNone = $true }
    @{ Name = 'Contract notes';           Form = 'labeled'; Kinds = @('technical', 'verify'); Required = $false }
    @{ Name = 'Out of automated reach';   Form = 'labeled'; Kinds = @('technical');           Required = $false }
    @{ Name = 'Expected Behaviors';       Form = 'heading'; Kinds = @('technical');           Required = $false }
    @{ Name = 'Decision Matrix';          Form = 'heading'; Kinds = @('technical');           Required = $false }
    @{ Name = 'AAA Cases';                Form = 'heading'; Kinds = @('technical');           Required = $true }
    @{ Name = 'Journey Examples';         Form = 'heading'; Kinds = @('verify');              Required = $false }
    @{ Name = 'Contract Examples';        Form = 'heading'; Kinds = @('verify');              Required = $false }
    @{ Name = 'Exploration Charters';     Form = 'heading'; Kinds = @('verify');              Required = $false }
    @{ Name = 'Partial-run record';       Form = 'labeled'; Kinds = @('verify');              Required = $false }
    @{ Name = 'Closeout';                 Form = 'labeled'; Kinds = @('technical', 'verify'); Required = $false }
    @{ Name = 'Mutation verdict';         Form = 'labeled'; Kinds = @('technical');           Required = $false }
)
$script:SectionOrder = @($script:Sections | ForEach-Object { $_.Name })

# Case shapes, keyed by the section that holds them. Scalars come first, then the blocks.
$script:CaseShapes = @{
    'AAA Cases'            = @{ Scalars = @('Scope', 'Covers');          Blocks = @('Arrange', 'Act', 'Assert');       Header = 'procedure'; Scopes = @('Unit', 'Integration') }
    'Journey Examples'     = @{ Scalars = @('Scope', 'Record', 'Role');  Blocks = @('Action', 'Observable Checks');    Header = 'V';         Scopes = @('E2E') }
    'Contract Examples'    = @{ Scalars = @('Scope', 'Client');          Blocks = @('Action', 'Observable Checks');    Header = 'C';         Scopes = @('Contract') }
    'Exploration Charters' = @{ Scalars = @('Scope', 'Charter');         Blocks = @('Prompts');                        Header = 'X';         Scopes = @('Exploration') }
}

$script:Findings = [System.Collections.Generic.List[pscustomobject]]::new()
$script:CurrentFile = ''

function Add-Finding {
    param([int] $Line, [string] $Rule, [string] $Message)
    $script:Findings.Add([pscustomobject]@{
            File    = $script:CurrentFile
            Line    = $Line
            Rule    = $Rule
            Message = $Message
        })
}

# --- parsing ---------------------------------------------------------------------------

function Read-Frontmatter {
    param([string[]] $Lines)

    $map = @{}
    if ($Lines.Count -eq 0 -or $Lines[0].Trim() -ne '---') { return $map }
    for ($i = 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq '---') { break }
        if ($Lines[$i] -match '^([A-Za-z_-]+):\s*(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() }
    }
    return $map
}

function Get-BodyToken {
    <#
        Classifies every column-0 line outside fenced blocks. Rule 3 lives here: a block
        runs to the next `## ` heading or `<Label>:` line, so those are the only tokens
        that close one. Bullets open with `-` and table rows with `|`.
    #>
    param([string[]] $Lines)

    $tokens = [System.Collections.Generic.List[hashtable]]::new()
    $inFence = $false

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }

        if ($line -match '^(#{1,6})\s+(.*?)\s*$') {
            $tokens.Add(@{ Type = 'heading'; Level = $Matches[1].Length; Text = $Matches[2]; Name = $Matches[2]; Value = ''; Line = $i + 1 })
        }
        elseif ($line -match '^([A-Z][A-Za-z0-9 /-]*):\s*(.*?)\s*$') {
            $tokens.Add(@{ Type = 'label'; Name = $Matches[1]; Text = $Matches[1]; Value = $Matches[2]; Line = $i + 1 })
        }
        elseif ($line -match '^\s*-\s+\S') {
            $tokens.Add(@{ Type = 'bullet'; Name = ''; Text = $line.Trim(); Value = ''; Line = $i + 1 })
        }
        elseif ($line -match '^\|') {
            $cells = @(($line.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() })
            $tokens.Add(@{ Type = 'row'; Name = ''; Text = $line.Trim(); Value = ''; Cells = $cells; Line = $i + 1 })
        }
    }
    return $tokens
}

function Get-SectionSpan {
    param($Seen, [int] $Index, [int] $FileEnd)

    $start = $Seen[$Index].Token.Line
    $end = if ($Index + 1 -lt $Seen.Count) { $Seen[$Index + 1].Token.Line } else { $FileEnd }
    return @{ Start = $start; End = $end }
}

# --- checks ----------------------------------------------------------------------------

function Test-Sections {
    param($Tokens, [string] $Kind, [int] $ContainerLine, [int] $FileEnd)

    $seen = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($t in $Tokens) {
        if ($t.Type -notin @('heading', 'label')) { continue }
        $spec = $script:Sections | Where-Object { $_.Name -eq $t.Name } | Select-Object -First 1
        if (-not $spec) { continue }

        if ($spec.Form -eq 'heading') {
            $isNoneForm = $spec.ContainsKey('AllowsNone') -and $t.Type -eq 'label' -and $t.Value -eq 'none'
            if ($t.Type -ne 'heading' -and -not $isNoneForm) {
                Add-Finding $t.Line 'rule-2' "``$($t.Name)`` is a section heading, not a labeled line."
                continue
            }
            if ($t.Type -eq 'heading' -and $t.Level -ne 2) {
                Add-Finding $t.Line 'rule-1' "``$($t.Name)`` is at H$($t.Level); sections are ``##``."
            }
        }
        elseif ($t.Type -eq 'heading') {
            Add-Finding $t.Line 'rule-2' "``$($t.Name)`` is a bare labeled line, not a heading."
        }

        if ($spec.Kinds -notcontains $Kind) {
            Add-Finding $t.Line 'rule-5' "``$($t.Name)`` does not belong on a ``kind: $Kind`` task."
        }
        $seen.Add(@{ Spec = $spec; Token = $t })
    }

    for ($i = 1; $i -lt $seen.Count; $i++) {
        $here = $script:SectionOrder.IndexOf($seen[$i].Spec.Name)
        $prev = $script:SectionOrder.IndexOf($seen[$i - 1].Spec.Name)
        if ($here -lt $prev) {
            Add-Finding $seen[$i].Token.Line 'rule-4' "``$($seen[$i].Spec.Name)`` sorts before ``$($seen[$i-1].Spec.Name)`` in the declared order."
        }
    }

    $names = @($seen | ForEach-Object { $_.Spec.Name })
    foreach ($spec in $script:Sections | Where-Object { $_.Required -and $_.Kinds -contains $Kind }) {
        if ($names -notcontains $spec.Name) {
            Add-Finding $ContainerLine 'rule-5' "required section ``$($spec.Name)`` is absent."
        }
    }

    # A section carrying the `: none` form must be one or the other: entries under the
    # heading, or the labeled line. An empty heading is neither.
    for ($i = 0; $i -lt $seen.Count; $i++) {
        if (-not $seen[$i].Spec.ContainsKey('AllowsNone')) { continue }
        if ($seen[$i].Token.Type -ne 'heading') { continue }
        $span = Get-SectionSpan -Seen $seen -Index $i -FileEnd $FileEnd
        $entries = @($Tokens | Where-Object { $_.Type -eq 'bullet' -and $_.Line -gt $span.Start -and $_.Line -lt $span.End })
        if ($entries.Count -eq 0) {
            Add-Finding $seen[$i].Token.Line 'rule-5' "``$($seen[$i].Spec.Name)`` carries neither entries nor the ``: none`` line."
        }
    }

    if ($Kind -eq 'technical') {
        $coverage = @($names | Where-Object { $_ -in @('Expected Behaviors', 'Decision Matrix') })
        if ($coverage.Count -eq 0) {
            Add-Finding $ContainerLine 'rule-5' 'no coverage table: one of `Expected Behaviors` or `Decision Matrix` is required.'
        }
        elseif ($coverage.Count -gt 1) {
            Add-Finding $ContainerLine 'rule-5' 'both coverage tables present; exactly one is allowed.'
        }
    }
    else {
        $examples = @($names | Where-Object { $_ -in @('Journey Examples', 'Contract Examples') })
        if ($examples.Count -eq 0) {
            Add-Finding $ContainerLine 'rule-5' 'no example section: a verify plan carries `Journey Examples`, `Contract Examples`, or both.'
        }
    }

    return , $seen
}

function Test-Cases {
    param($Tokens, $Seen, [int] $FileEnd)

    for ($s = 0; $s -lt $Seen.Count; $s++) {
        $shape = $script:CaseShapes[$Seen[$s].Spec.Name]
        if (-not $shape) { continue }

        $span = Get-SectionSpan -Seen $Seen -Index $s -FileEnd $FileEnd
        $scoped = @($Tokens | Where-Object { $_.Line -gt $span.Start -and $_.Line -lt $span.End })
        $headers = @($scoped | Where-Object { $_.Type -eq 'heading' })
        $expected = @($shape.Scalars) + @($shape.Blocks)

        $handles = @($headers | ForEach-Object {
                if ($shape.Header -eq 'procedure') { $_.Text } else { ($_.Text -split '\s+', 2)[0] }
            })
        foreach ($dupe in ($handles | Group-Object | Where-Object { $_.Count -gt 1 })) {
            $at = $headers | Where-Object { $_.Text -eq $dupe.Name -or $_.Text -like "$($dupe.Name) *" } | Select-Object -Last 1
            Add-Finding $at.Line 'rule-6' "``$($dupe.Name)`` is used by $($dupe.Count) cases in ``$($Seen[$s].Spec.Name)``; a handle names one case."
        }

        for ($i = 0; $i -lt $headers.Count; $i++) {
            $h = $headers[$i]
            if ($h.Level -ne 3) {
                Add-Finding $h.Line 'rule-1' "case header ``$($h.Text)`` is at H$($h.Level); cases are ``###``."
            }
            if ($shape.Header -eq 'procedure') {
                if ($h.Text -notmatch '^[A-Z][A-Za-z0-9]*$') {
                    Add-Finding $h.Line 'rule-6' "case header ``$($h.Text)`` is not a bare AL test procedure name."
                }
            }
            elseif ($h.Text -notmatch "^$($shape.Header)\d+\s+\S") {
                Add-Finding $h.Line 'rule-6' "example header ``$($h.Text)`` does not open with its ``$($shape.Header)#`` id."
            }

            $to = if ($i + 1 -lt $headers.Count) { $headers[$i + 1].Line } else { $span.End }
            $fields = @($scoped | Where-Object { $_.Type -eq 'label' -and $_.Line -gt $h.Line -and $_.Line -lt $to })
            $fieldNames = @($fields | ForEach-Object { $_.Name })

            foreach ($f in $fields) {
                if ($f.Value -match '\s#\s') {
                    Add-Finding $f.Line 'rule-10' "``$($f.Name):`` carries an inline comment."
                }
                if ($f.Name -eq 'Procedure' -or $f.Name -eq $h.Text) {
                    Add-Finding $f.Line 'rule-7' "``$($f.Name):`` restates the case header; the header is the name."
                }
            }

            foreach ($required in $expected) {
                if ($fieldNames -notcontains $required) {
                    Add-Finding $h.Line 'rule-5' "case ``$($h.Text)`` has no ``$required``."
                }
            }

            $present = @($fieldNames | Where-Object { $expected -contains $_ })
            for ($k = 1; $k -lt $present.Count; $k++) {
                if ($expected.IndexOf($present[$k]) -lt $expected.IndexOf($present[$k - 1])) {
                    Add-Finding $h.Line 'rule-8' "case ``$($h.Text)``: ``$($present[$k])`` precedes ``$($present[$k-1])``."
                }
            }

            foreach ($blockName in $shape.Blocks) {
                $block = $fields | Where-Object { $_.Name -eq $blockName } | Select-Object -First 1
                if (-not $block) { continue }
                $after = $fields | Where-Object { $_.Line -gt $block.Line } | Select-Object -First 1
                $blockEnd = if ($after) { $after.Line } else { $to }
                $bullets = @($scoped | Where-Object { $_.Type -eq 'bullet' -and $_.Line -gt $block.Line -and $_.Line -lt $blockEnd })
                if ($bullets.Count -eq 0) {
                    Add-Finding $block.Line 'rule-5' "``$blockName`` in ``$($h.Text)`` has no bullets."
                }
            }

            $scope = $fields | Where-Object { $_.Name -eq 'Scope' } | Select-Object -First 1
            if ($scope -and $shape.Scopes -notcontains $scope.Value) {
                Add-Finding $scope.Line 'rule-5' "``Scope: $($scope.Value)`` is not valid in ``$($Seen[$s].Spec.Name)``."
            }

            $covers = $fields | Where-Object { $_.Name -eq 'Covers' } | Select-Object -First 1
            if ($covers -and $covers.Value -match ',') {
                Add-Finding $covers.Line 'rule-9' '`Covers:` separates multiple ids with `; `, not a comma.'
            }
        }
    }
}

function Test-Coverage {
    param($Tokens, $Seen, [string] $Kind, [int] $FileEnd)

    if ($Kind -ne 'technical') { return }

    $rowIds = [System.Collections.Generic.List[string]]::new()
    $claims = [System.Collections.Generic.List[hashtable]]::new()

    for ($s = 0; $s -lt $Seen.Count; $s++) {
        if ($Seen[$s].Spec.Name -notin @('Expected Behaviors', 'Decision Matrix')) { continue }
        $span = Get-SectionSpan -Seen $Seen -Index $s -FileEnd $FileEnd
        $rows = @($Tokens | Where-Object { $_.Type -eq 'row' -and $_.Line -gt $span.Start -and $_.Line -lt $span.End })
        if ($rows.Count -lt 3) {
            Add-Finding $span.Start 'table' "``$($Seen[$s].Spec.Name)`` carries no rows."
            continue
        }

        $header = $rows[0].Cells
        if ($Seen[$s].Spec.Name -eq 'Expected Behaviors') {
            if (($header -join '|') -ne 'ID|Expected Behavior|Covered By') {
                Add-Finding $rows[0].Line 'table' '`Expected Behaviors` columns are exactly `ID | Expected Behavior | Covered By`.'
            }
        }
        else {
            if ($header[0] -ne 'Case') { Add-Finding $rows[0].Line 'table' '`Decision Matrix` first column is `Case`.' }
            if ($header[-1] -ne 'Covered By') { Add-Finding $rows[0].Line 'table' '`Decision Matrix` last column is `Covered By`.' }
        }

        foreach ($row in $rows[2..($rows.Count - 1)]) {
            if ($row.Cells.Count -ne $header.Count) { continue }
            $id = $row.Cells[0]
            if ($id -notmatch '^[BR]\d+$') {
                Add-Finding $row.Line 'table' "coverage id ``$id`` is not ``B#`` or ``R#``."
                continue
            }
            if ($rowIds -contains $id) {
                Add-Finding $row.Line 'coverage' "coverage id ``$id`` is used by more than one row."
            }
            $rowIds.Add($id)

            $cell = $row.Cells[$row.Cells.Count - 1]
            if (-not $cell) {
                Add-Finding $row.Line 'coverage' "row ``$id`` carries no ``Covered By``."
                continue
            }
            if ($cell -match ',') {
                Add-Finding $row.Line 'rule-9' "row ``$id`` separates procedures with a comma; use ``; ``."
            }
            foreach ($proc in $cell -split ';') {
                $p = $proc.Trim().Trim('`')
                if ($p) { $claims.Add(@{ Id = $id; Procedure = $p; Line = $row.Line }) }
            }
        }
    }

    $caseIndex = -1
    for ($s = 0; $s -lt $Seen.Count; $s++) { if ($Seen[$s].Spec.Name -eq 'AAA Cases') { $caseIndex = $s; break } }
    if ($caseIndex -lt 0) { return }

    $span = Get-SectionSpan -Seen $Seen -Index $caseIndex -FileEnd $FileEnd
    $headers = @($Tokens | Where-Object { $_.Type -eq 'heading' -and $_.Line -gt $span.Start -and $_.Line -lt $span.End })
    $caseNames = @($headers | ForEach-Object { $_.Text })

    foreach ($claim in $claims) {
        if ($caseNames -notcontains $claim.Procedure) {
            Add-Finding $claim.Line 'coverage' "row ``$($claim.Id)`` names ``$($claim.Procedure)``, which no ``AAA Cases`` header defines."
        }
    }

    for ($i = 0; $i -lt $headers.Count; $i++) {
        $to = if ($i + 1 -lt $headers.Count) { $headers[$i + 1].Line } else { $span.End }
        $covers = $Tokens | Where-Object { $_.Type -eq 'label' -and $_.Name -eq 'Covers' -and $_.Line -gt $headers[$i].Line -and $_.Line -lt $to } | Select-Object -First 1
        if (-not $covers) { continue }
        foreach ($id in $covers.Value -split ';') {
            $trimmed = $id.Trim().Trim('`')
            if ($trimmed -and $rowIds -notcontains $trimmed) {
                Add-Finding $covers.Line 'coverage' "``Covers: $trimmed`` names no row in the coverage table."
            }
        }
    }
}

function Test-TaskFile {
    param([string] $FilePath, [bool] $WithDone)

    $lines = [System.IO.File]::ReadAllLines($FilePath)
    $script:CurrentFile = Split-Path $FilePath -Leaf

    $fm = Read-Frontmatter -Lines $lines
    $kind = if ($fm.ContainsKey('kind')) { $fm['kind'] } else { '' }
    $status = if ($fm.ContainsKey('status')) { $fm['status'] } else { '' }

    if ($kind -notin @('technical', 'verify')) { return }   # ops kinds carry a description only
    if ($status -eq 'done' -and -not $WithDone) { return }  # may predate the grammar

    $tokens = Get-BodyToken -Lines $lines
    $container = if ($kind -eq 'technical') { 'Test Specification' } else { 'Verification Plan' }
    $containerToken = $tokens | Where-Object { $_.Type -eq 'label' -and $_.Name -eq $container } | Select-Object -First 1
    if (-not $containerToken) { return }                    # not yet refined

    $body = @($tokens | Where-Object { $_.Line -gt $containerToken.Line })
    $fileEnd = $lines.Count + 1

    $seen = Test-Sections -Tokens $body -Kind $kind -ContainerLine $containerToken.Line -FileEnd $fileEnd
    if ($seen.Count -eq 0) { return }
    Test-Cases -Tokens $body -Seen $seen -FileEnd $fileEnd
    Test-Coverage -Tokens $body -Seen $seen -Kind $kind -FileEnd $fileEnd
}

# --- entry point -----------------------------------------------------------------------

$targets = [System.Collections.Generic.List[string]]::new()
foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p -PathType Container) {
        Get-ChildItem -LiteralPath $p -Filter '*.md' -File |
            Where-Object { $_.Name -match '^\d{3}-T-\d{3}-' } |
            ForEach-Object { $targets.Add($_.FullName) }
    }
    elseif (Test-Path -LiteralPath $p -PathType Leaf) {
        $targets.Add((Resolve-Path -LiteralPath $p).Path)
    }
}

foreach ($t in $targets) { Test-TaskFile -FilePath $t -WithDone $IncludeDone.IsPresent }

foreach ($f in $script:Findings) { '{0}:{1} [{2}] {3}' -f $f.File, $f.Line, $f.Rule, $f.Message }
exit ([int]($script:Findings.Count -gt 0))
