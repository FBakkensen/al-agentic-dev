#requires -Version 7.2

<#
.SYNOPSIS
    AL Source Reader Module

.DESCRIPTION
    The one place al-build reads AL text. The module check and the namespace
    pass both read through it, so what the pass writes is what the gate reads.
    Read-AlSource is the entry: it scans a file once and returns the namespace
    and using statements and the objects with their procedures. It takes text,
    never a path; each caller keeps its own file acquisition and its own errors.
    Get-AlToken is the readable token stream for the readers that need every
    name; Read-AlSource walks the same token pattern without building a record
    per token, because the gate reads every file of an app twice.
#>

Set-StrictMode -Version Latest

# AL object keyword -> whether the object has an ID, and the CodeCop file-name
# type (Best practices for AL, "File naming"). reportextension follows the page's
# <FullTypeName>Ext notation; entitlement is not in the type map, so its file keeps its name.
$script:ObjectTypes = @{
    table                  = @{ HasId = $true;  FileType = 'Table' }
    tableextension         = @{ HasId = $true;  FileType = 'TableExt' }
    page                   = @{ HasId = $true;  FileType = 'Page' }
    pageextension          = @{ HasId = $true;  FileType = 'PageExt' }
    pagecustomization      = @{ HasId = $false; FileType = 'PageCust' }
    codeunit               = @{ HasId = $true;  FileType = 'Codeunit' }
    report                 = @{ HasId = $true;  FileType = 'Report' }
    reportextension        = @{ HasId = $true;  FileType = 'ReportExt' }
    xmlport                = @{ HasId = $true;  FileType = 'Xmlport' }
    query                  = @{ HasId = $true;  FileType = 'Query' }
    enum                   = @{ HasId = $true;  FileType = 'Enum' }
    enumextension          = @{ HasId = $true;  FileType = 'EnumExt' }
    controladdin           = @{ HasId = $false; FileType = 'ControlAddin' }
    profile                = @{ HasId = $false; FileType = 'Profile' }
    interface              = @{ HasId = $false; FileType = 'Interface' }
    permissionset          = @{ HasId = $true;  FileType = 'PermissionSet' }
    permissionsetextension = @{ HasId = $true;  FileType = 'PermissionSetExt' }
    entitlement            = @{ HasId = $false; FileType = $null }
}

# The word before a name (Record Customer) or before :: (Database::Customer) that fixes its object type.
$script:TypeAfterKeyword = @{
    record = 'table'; tabledata = 'table'; codeunit = 'codeunit'; page = 'page'; testpage = 'page'; report = 'report'; query = 'query'
    xmlport = 'xmlport'; enum = 'enum'; interface = 'interface'; controladdin = 'controladdin'; permissionset = 'permissionset'
}
$script:TypeBeforeColons = @{
    database = 'table'; table = 'table'; codeunit = 'codeunit'; page = 'page'; report = 'report'; query = 'query'
    xmlport = 'xmlport'; enum = 'enum'; interface = 'interface'; controladdin = 'controladdin'; permissionset = 'permissionset'; profile = 'profile'
}

$script:AccessWords = 'local', 'internal', 'protected'

# One left-to-right pass, so whichever of a comment, a string, or a preprocessor line opens first wins.
$script:TokenPattern = [regex]::new(
    '(?m)^[ \t]*#[^\r\n]*|//[^\r\n]*|/\*.*?\*/|@?''(?:[^''\r\n]|'''')*''|"[^"\r\n]*"|\d+|[^\W\d]\w*|::|[{};.\[\]]',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::Compiled)

# After a procedure's name: the opening parenthesis, past any comment; then the parameter list up to the first
# closing parenthesis outside a quoted identifier, a string, or a comment.
$script:OpenParenthesisPattern = [regex]::new('\G(?:\s|/\*.*?\*/|//[^\r\n]*)*\(', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:ParameterPattern = [regex]::new(
    '\G(?:"[^"\r\n]*"|//[^\r\n]*|/\*.*?\*/|''(?:[^''\r\n]|'''')*''|[^)"/'']|[/''])*',
    [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:CommentOrStringStart = [char[]]@('/', "'", '#')
$script:NewlinePattern = [regex]::new('\n', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:NonNewline = [regex]::new('[^\r\n]', [System.Text.RegularExpressions.RegexOptions]::Compiled)

# =============================================================================
# Tokens and blanked text
# =============================================================================

function Get-AlToken {
    <#
    .SYNOPSIS
        Split AL text into tokens, setting comments, strings, and directives apart.
    .DESCRIPTION
        One left-to-right pass, so a quote inside a comment or a preprocessor line
        never opens a string. Kinds: comment, directive, string, qident, number,
        ident, punct. Value is the identifier without its quotes. Index and Length
        locate the token in the text, a directive's leading indent excluded.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    foreach ($match in $script:TokenPattern.Matches($Text)) {
        $value = $match.Value
        $index = $match.Index
        $first = $value[0]
        $length = $value.Length
        if ($first -eq ' ' -or $first -eq "`t") {
            $trimmed = $value.TrimStart()
            $index += $length - $trimmed.Length
            $length = $trimmed.Length
            $first = '#'
        }
        $kind = switch ($first) {
            '#' { 'directive' }
            '/' { 'comment' }
            '@' { 'string' }
            '''' { 'string' }
            '"' { 'qident' }
            default {
                if ([char]::IsDigit($first)) { 'number' }
                elseif ('{};.[]:'.Contains($first)) { 'punct' }
                else { 'ident' }
            }
        }
        $inner = if ($kind -eq 'qident') { $value.Substring(1, $value.Length - 2) } else { $value }
        [pscustomobject]@{ Kind = $kind; Text = $value; Value = $inner; Index = $index; Length = $length }
    }
}

function Get-AlBlankedText {
    <#
    .SYNOPSIS
        The text with comments, preprocessor lines, and string literals blanked.
    .DESCRIPTION
        Every offset and line break is kept, and quoted identifiers stay.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $builder = [System.Text.StringBuilder]::new($Text.Length)
    $position = 0
    foreach ($item in Get-AlToken -Text $Text) {
        if ($item.Kind -ne 'comment' -and $item.Kind -ne 'directive' -and $item.Kind -ne 'string') { continue }
        [void]$builder.Append($Text, $position, $item.Index - $position)
        $blank = $Text.Substring($item.Index, $item.Length)
        [void]$builder.Append($(if ($blank.Contains("`n")) { $script:NonNewline.Replace($blank, ' ') } else { [string]::new(' ', $item.Length) }))
        $position = $item.Index + $item.Length
    }
    [void]$builder.Append($Text, $position, $Text.Length - $position)
    return $builder.ToString()
}

function Get-AlLineNumber {
    <#
    .SYNOPSIS
        The 1-based line of an offset in a source Read-AlSource returned.
    #>
    param(
        [Parameter(Mandatory)]$Source,
        [Parameter(Mandatory)][int]$Index
    )

    $position = [array]::BinarySearch($Source.NewlineOffsets, $Index)
    if ($position -lt 0) { $position = -bnot $position }
    return $position + 1
}

function Get-AlObjectType {
    <#
    .SYNOPSIS
        Object keyword -> HasId and FileType, for every object type AL declares.
    #>
    param()

    return $script:ObjectTypes
}

# =============================================================================
# The source model
# =============================================================================

function Read-AlSource {
    <#
    .SYNOPSIS
        Read one file's text: header statements, objects, and procedures.
    .DESCRIPTION
        Returns:
        - Namespace, NamespaceLine, NamespaceStart, NamespaceEnd: the namespace
          statement before the first object ($null and 1 when there is none) and
          the offsets it spans. Quotes around a segment are dropped.
        - Usings: Name and Line of each using statement, in order.
        - HeaderWord: namespace or using, whichever the file's last header
          statement starts with, or $null.
        - Objects: Keyword (as written), Type, Id (0 without one), Name, NameText
          (as written, quotes kept), NameIndex, KeywordIndex, StartIndex (the
          leading attributes' first bracket, else the keyword), Line (of the
          keyword), and Procedures.
        - Procedures: Name, Access (local, internal, protected, or public),
          Signature (the parameter list, lower case, spaces collapsed), Line,
          and IsSubscriber (an EventSubscriber attribute sits on it).
        - FirstObjectLine: the line of the first object, 1 when there is none.
        Only a word outside braces and brackets can start a header statement or
        an object. A procedure belongs to the object declared before it.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$Text)

    if ($null -eq $Text) { $Text = '' }

    $lineBreaks = $script:NewlinePattern.Matches($Text)
    $source = [pscustomobject]@{
        Namespace       = $null
        NamespaceLine   = 1
        NamespaceStart  = -1
        NamespaceEnd    = -1
        Usings          = [System.Collections.Generic.List[object]]::new()
        HeaderWord      = $null
        Objects         = $null
        FirstObjectLine = 1
        NewlineOffsets  = $(if ($lineBreaks.Count -gt 0) { [int[]]$lineBreaks.Index } else { [int[]]@() })
    }

    $significant = @(Get-SignificantMatch -Text $Text)

    $objects = [System.Collections.Generic.List[object]]::new()
    $current = $null
    $depth = 0
    $bracket = 0
    $attributeStart = -1
    $previous = [char]0
    $count = $significant.Count
    for ($i = 0; $i -lt $count; $i++) {
        $match = $significant[$i]
        $first = $Text[$match.Index]

        if ($first -eq '_' -or [char]::IsLetter($first)) {
            if ($match.Length -eq 9 -and $match.Value -ieq 'procedure') {
                if ($current -and $previous -ne '.') {
                    $procedure = Read-ProcedureDeclaration -Token $significant -Position $i -Text $Text -Source $source
                    if ($procedure) { $current.Procedures.Add($procedure) }
                }
            } elseif ($depth -eq 0 -and $bracket -eq 0 -and ($previous -eq [char]0 -or $previous -eq '}' -or $previous -eq ';' -or $previous -eq ']')) {
                $word = $match.Value.ToLowerInvariant()
                if ($word -eq 'namespace' -or $word -eq 'using') {
                    $source.HeaderWord = $word
                    $statement = Read-HeaderStatement -Token $significant -Position $i
                    if ($statement) {
                        if ($word -eq 'using') {
                            $source.Usings.Add([pscustomobject]@{ Name = $statement.Name; Line = Get-AlLineNumber -Source $source -Index $match.Index })
                        } elseif ($objects.Count -eq 0 -and $null -eq $source.Namespace) {
                            $source.Namespace = $statement.Name
                            $source.NamespaceLine = Get-AlLineNumber -Source $source -Index $match.Index
                            $source.NamespaceStart = $match.Index
                            $source.NamespaceEnd = $statement.EndIndex
                        }
                    }
                } elseif ($script:ObjectTypes.ContainsKey($word)) {
                    $object = Read-ObjectDeclaration -Token $significant -Position $i -Word $word
                    if ($object) {
                        $object.StartIndex = if ($attributeStart -ge 0) { $attributeStart } else { $match.Index }
                        $object.Line = Get-AlLineNumber -Source $source -Index $match.Index
                        $objects.Add($object)
                        $current = $object
                    }
                }
            }
        } elseif ($first -eq '{') { $depth++ }
        elseif ($first -eq '}') { $depth--; if ($depth -eq 0) { $attributeStart = -1 } }
        elseif ($first -eq ';') { if ($depth -eq 0) { $attributeStart = -1 } }
        elseif ($first -eq '[') { if ($depth -eq 0) { if ($bracket -eq 0 -and $attributeStart -lt 0) { $attributeStart = $match.Index }; $bracket++ } }
        elseif ($first -eq ']') { if ($depth -eq 0) { $bracket-- } }
        $previous = $first
    }
    $source.Objects = $objects.ToArray()
    if ($objects.Count -gt 0) { $source.FirstObjectLine = $objects[0].Line }
    return $source
}

function Get-SignificantMatch {
    # The token matches that are not comments or preprocessor lines. Collected as pipeline output:
    # a method call per match costs ten times what the match did.
    param([string]$Text)

    foreach ($match in $script:TokenPattern.Matches($Text)) {
        $first = $Text[$match.Index]
        if ($first -ne '/' -and $first -ne '#' -and $first -ne ' ' -and $first -ne "`t") { $match }
    }
}

function Test-NameValue {
    # Whether a token's text is an identifier or a quoted identifier.
    param([string]$Value)

    $first = $Value[0]
    return $first -eq '"' -or $first -eq '_' -or [char]::IsLetter($first)
}

function ConvertTo-NameText {
    # An identifier's name: a quoted identifier without its quotes.
    param([string]$Value)

    if ($Value[0] -eq '"') { return $Value.Substring(1, $Value.Length - 2) }
    return $Value
}

function Read-HeaderStatement {
    # `namespace A.B;` or `using A.B;` from the keyword at Position; $null when the tokens are not a statement.
    param([object]$Token, [int]$Position)

    $name = [System.Text.StringBuilder]::new()
    for ($j = $Position + 1; $j -lt $Token.Count; $j++) {
        $value = $Token[$j].Value
        if ($value -eq '.' -or (Test-NameValue -Value $value)) {
            [void]$name.Append((ConvertTo-NameText -Value $value))
        } elseif ($value -eq ';' -and $name.Length -gt 0) {
            return [pscustomobject]@{ Name = $name.ToString(); EndIndex = $Token[$j].Index }
        } else {
            return $null
        }
    }
    return $null
}

function Read-ObjectDeclaration {
    # `codeunit 50100 "Name"` or, for an object with no ID, `interface "Name"`; $null when the tokens are neither.
    param([object]$Token, [int]$Position, [string]$Word)

    $keyword = $Token[$Position]
    $id = 0
    $nameMatch = $null
    if ($script:ObjectTypes[$Word].HasId) {
        if ($Position + 2 -lt $Token.Count -and [char]::IsDigit($Token[$Position + 1].Value[0]) -and (Test-NameValue -Value $Token[$Position + 2].Value)) {
            $id = [long]$Token[$Position + 1].Value
            $nameMatch = $Token[$Position + 2]
        }
    } elseif ($Position + 1 -lt $Token.Count -and (Test-NameValue -Value $Token[$Position + 1].Value)) {
        $nameMatch = $Token[$Position + 1]
    }
    if (-not $nameMatch) { return $null }

    return [pscustomobject]@{
        Keyword      = $keyword.Value
        Type         = $Word
        Id           = $id
        Name         = ConvertTo-NameText -Value $nameMatch.Value
        NameText     = $nameMatch.Value
        NameIndex    = $nameMatch.Index
        KeywordIndex = $keyword.Index
        StartIndex   = $keyword.Index
        Line         = 1
        Procedures   = [System.Collections.Generic.List[object]]::new()
    }
}

function Read-ParameterList {
    # The text between the parentheses that follow a procedure name at Start, or $null when none follow.
    # Matches run on a window of the text: a regex call on the whole file costs the length of the file.
    param([string]$Text, [int]$Start)

    $remaining = $Text.Length - $Start
    foreach ($window in 2048, $remaining) {
        $window = [Math]::Min($window, $remaining)
        $slice = $Text.Substring($Start, $window)
        $truncated = $window -lt $remaining
        $open = $script:OpenParenthesisPattern.Match($slice)
        if (-not $open.Success) {
            if ($truncated) { continue }
            return $null
        }
        $inner = $slice.Substring($open.Length)
        $parameters = $script:ParameterPattern.Match($inner)
        if ($parameters.Length -ge $inner.Length) {
            if ($truncated) { continue }
            return $null
        }
        if ($inner[$parameters.Length] -ne ')') { return $null }
        return $parameters.Value
    }
    return $null
}

function Read-ProcedureDeclaration {
    # `[attributes] [local|internal|protected] procedure Name(parameters)` from the keyword at Position;
    # $null when no parameter list follows the name.
    param([object]$Token, [int]$Position, [string]$Text, $Source)

    $keyword = $Token[$Position]
    if ($Position + 1 -ge $Token.Count -or -not (Test-NameValue -Value $Token[$Position + 1].Value)) { return $null }
    $nameMatch = $Token[$Position + 1]

    $parameterList = Read-ParameterList -Text $Text -Start ($nameMatch.Index + $nameMatch.Length)
    if ($null -eq $parameterList) { return $null }

    $access = 'public'
    $end = $Position - 1
    if ($end -ge 0 -and $Token[$end].Value -in $script:AccessWords) {
        $access = $Token[$end].Value.ToLowerInvariant()
        $end--
    }

    $isSubscriber = $false
    while ($end -ge 0 -and $Token[$end].Value -eq ']') {
        $nesting = 0
        $start = $end
        for ($k = $end - 1; $k -ge 0; $k--) {
            $bracket = $Token[$k].Value
            if ($bracket -eq ']') { $nesting++ }
            elseif ($bracket -eq '[') {
                if ($nesting -eq 0) { $start = $k; break }
                $nesting--
            }
        }
        if ($start -eq $end) { break }
        for ($k = $start + 1; $k -lt $end; $k++) {
            if ($Token[$k].Value -ieq 'EventSubscriber') { $isSubscriber = $true; break }
        }
        $end = $start - 1
    }

    return [pscustomobject]@{
        Name         = ConvertTo-NameText -Value $nameMatch.Value
        Access       = $access
        Signature    = ($(if ($parameterList.IndexOfAny($script:CommentOrStringStart) -ge 0) { Get-AlBlankedText -Text $parameterList } else { $parameterList }) -replace '\s+', ' ').Trim().ToLowerInvariant()
        Line         = Get-AlLineNumber -Source $Source -Index $keyword.Index
        IsSubscriber = $isSubscriber
    }
}

# =============================================================================
# Names the file uses
# =============================================================================

function Get-AlNameReference {
    <#
    .SYNOPSIS
        The object names a file mentions, with the object type its context fixes.
    .DESCRIPTION
        Identifiers and quoted identifiers, except member accesses after a dot, the
        declared object names, and the type words (Record, Database::) that
        introduce a name. Type is set when the word before a name fixes it.
        Takes the text and the Read-AlSource result for it. Returns Name (lower
        case), Display (as written), and Type.
    #>
    param(
        [Parameter(Mandatory)]$Source,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )

    $declarations = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($object in $Source.Objects) { [void]$declarations.Add($object.NameIndex) }

    $significant = @(Get-AlToken -Text $Text | Where-Object { $_.Kind -ne 'comment' -and $_.Kind -ne 'directive' })
    $references = [System.Collections.Generic.Dictionary[string, object]]::new()
    for ($i = 0; $i -lt $significant.Count; $i++) {
        $token = $significant[$i]
        if ($token.Kind -notin 'ident', 'qident' -or $declarations.Contains($token.Index)) { continue }
        $one = if ($i -ge 1) { $significant[$i - 1] } else { $null }
        $two = if ($i -ge 2) { $significant[$i - 2] } else { $null }
        $next = if ($i + 1 -lt $significant.Count) { $significant[$i + 1] } else { $null }
        if ($one -and $one.Text -eq '.') { continue }

        $word = $token.Value.ToLowerInvariant()
        $isTypeWord = $token.Kind -eq 'ident' -and ($script:TypeAfterKeyword.ContainsKey($word) -or $script:TypeBeforeColons.ContainsKey($word))
        if ($isTypeWord -and $next -and ($next.Text -eq '::' -or $next.Kind -in 'ident', 'qident')) { continue }

        $type = $null
        if ($one -and $one.Text -eq '::' -and $two -and $two.Kind -eq 'ident') { $type = $script:TypeBeforeColons[$two.Text.ToLowerInvariant()] }
        elseif ($one -and $one.Kind -eq 'ident') { $type = $script:TypeAfterKeyword[$one.Text.ToLowerInvariant()] }
        $key = "$type|$word"
        if (-not $references.ContainsKey($key)) {
            $references[$key] = [pscustomobject]@{ Name = $word; Display = $token.Value; Type = $type }
        }
    }
    return @($references.Values)
}

function Get-AlQualifiedName {
    <#
    .SYNOPSIS
        Every dotted name a file writes, outside comments, strings, and the
        namespace statement.
    .DESCRIPTION
        A name is identifiers and quoted identifiers joined by dots with no
        space between them. Takes the text and the Read-AlSource result for it.
        Returns Segments (a quoted segment without its quotes) and Line. A
        using statement's name counts.
    #>
    param(
        [Parameter(Mandatory)]$Source,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )

    $significant = @(Get-SignificantMatch -Text $Text)
    $count = $significant.Count
    $i = 0
    while ($i -lt $count) {
        $token = $significant[$i]
        $first = $Text[$token.Index]
        if (-not ($first -eq '_' -or $first -eq '"' -or [char]::IsLetterOrDigit($first)) -or
            ($token.Index -ge $Source.NamespaceStart -and $token.Index -le $Source.NamespaceEnd)) {
            $i++
            continue
        }

        # A run: names joined by dots with nothing between them.
        $j = $i
        $end = $token.Index + $token.Length
        while ($j + 2 -lt $count) {
            $dot = $significant[$j + 1]
            $next = $significant[$j + 2]
            if ($dot.Index -ne $end -or $dot.Length -ne 1 -or $Text[$dot.Index] -ne '.' -or $next.Index -ne $end + 1) { break }
            $nextFirst = $Text[$next.Index]
            if (-not ($nextFirst -eq '_' -or $nextFirst -eq '"' -or [char]::IsLetterOrDigit($nextFirst))) { break }
            $end = $next.Index + $next.Length
            $j += 2
        }
        if ($j -gt $i -and -not [char]::IsDigit($first)) {
            [pscustomobject]@{
                Segments = [string[]]@(for ($k = $i; $k -le $j; $k += 2) { ConvertTo-NameText -Value $significant[$k].Value })
                Line     = Get-AlLineNumber -Source $Source -Index $token.Index
            }
        }
        $i = $j + 1
    }
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    'Get-AlToken'
    'Get-AlBlankedText'
    'Get-AlLineNumber'
    'Get-AlObjectType'
    'Read-AlSource'
    'Get-AlNameReference'
    'Get-AlQualifiedName'
)
