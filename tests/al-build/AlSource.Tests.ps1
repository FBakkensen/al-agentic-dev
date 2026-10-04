#Requires -Version 7.2

# Drives the AL source reader directly: the tokenizer, the blanked text, and
# Read-AlSource's namespace, using, object, and procedure model. The module check
# and the namespace pass both read AL through it, so each case here names a
# construct they must agree on.

BeforeAll {
    $script:ScriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $script:ScriptsDir 'al-source.psm1') -Force -DisableNameChecking

    # Joins lines with LF so a case reads as the file it stands for.
    function Join-Line {
        param([string[]]$Line)
        return ($Line -join "`n") + "`n"
    }

    function Read-Procedure {
        param([string[]]$Line)
        $text = Join-Line (@('codeunit 50100 Host', '{') + $Line + @('}'))
        return @((Read-AlSource -Text $text).Objects[0].Procedures)
    }
}

Describe 'Get-AlToken' {
    It 'sets comments, strings, quoted identifiers, numbers, identifiers, and punctuation apart' {
        $text = Join-Line @(
            '// note',
            'codeunit 50100 "Post Sales" { x := ''a''; }'
        )

        $tokens = @(Get-AlToken -Text $text)

        ($tokens | ForEach-Object Kind) -join ',' | Should -Be 'comment,ident,number,qident,punct,ident,string,punct,punct'
        ($tokens | Where-Object Kind -eq 'qident').Value | Should -Be 'Post Sales'
    }

    It 'does not let a quote inside a comment or a preprocessor line open a string' {
        $text = Join-Line @(
            '// it''s a comment',
            '#region Customer''s code',
            'codeunit 50100 Posting'
        )

        $kinds = @(Get-AlToken -Text $text | ForEach-Object Kind)

        $kinds | Should -Not -Contain 'string'
        ($kinds | Where-Object { $_ -eq 'ident' }).Count | Should -Be 2
    }

    It 'does not let a comment marker inside a string open a comment' {
        $tokens = @(Get-AlToken -Text "Url := 'http://example.test'; Next := 1;")

        @($tokens | Where-Object Kind -eq 'comment').Count | Should -Be 0
        ($tokens | Where-Object Kind -eq 'string').Text | Should -Be "'http://example.test'"
    }

    It 'places a preprocessor token at its #, not at the indent before it' {
        $tokens = @(Get-AlToken -Text "x`n    #if CLEAN`n")

        $directive = $tokens | Where-Object Kind -eq 'directive'
        $directive.Index | Should -Be 6
        $directive.Length | Should -Be 9
    }

    It 'reads an identifier with a non-ASCII letter as one token' {
        $tokens = @(Get-AlToken -Text 'codeunit 50100 Størrelse')

        $tokens[2].Value | Should -Be 'Størrelse'
    }
}

Describe 'Get-AlBlankedText' {
    It 'blanks comments and string literals, and keeps every offset, line, and quoted identifier' {
        $text = Join-Line @(
            'codeunit 50100 "Post Sales" // trailing',
            '{ /* block',
            'two lines */ x := ''it''''s''; }'
        )

        $blanked = Get-AlBlankedText -Text $text

        $blanked.Length | Should -Be $text.Length
        ($blanked -split "`n").Count | Should -Be ($text -split "`n").Count
        $blanked | Should -Match '"Post Sales"'
        $blanked | Should -Not -Match 'trailing|block|two lines'
        $blanked.Contains("it''s") | Should -BeFalse
        $blanked.IndexOf('x :=') | Should -Be $text.IndexOf('x :=')
    }

    It 'treats a comment marker inside a string as text and an apostrophe inside a comment as nothing' {
        $text = "// it's`nUrl := 'a//b'; y := 2;"

        $blanked = Get-AlBlankedText -Text $text

        $blanked | Should -Match 'y := 2;'
        $blanked | Should -Not -Match 'a//b'
    }
}

Describe 'Read-AlSource namespace and using' {
    It 'reads the namespace, its line, and the using lines in order' {
        $text = Join-Line @(
            '// header',
            'namespace Contoso.Sales.Posting;',
            '',
            'using Contoso.Sales;',
            'using System.Utilities;',
            '',
            'codeunit 50100 Posting',
            '{',
            '}'
        )

        $source = Read-AlSource -Text $text

        $source.Namespace | Should -Be 'Contoso.Sales.Posting'
        $source.NamespaceLine | Should -Be 2
        @($source.Usings | ForEach-Object Name) | Should -Be @('Contoso.Sales', 'System.Utilities')
        @($source.Usings | ForEach-Object Line) | Should -Be @(4, 5)
        $source.FirstObjectLine | Should -Be 7
    }

    It 'drops the quotes around a namespace segment and keeps the words inside' {
        $source = Read-AlSource -Text (Join-Line @('namespace Contoso."Sales Posting";', 'codeunit 50100 Posting', '{', '}'))

        $source.Namespace | Should -Be 'Contoso.Sales Posting'
    }

    It 'ignores a namespace statement in a comment or a string' {
        $text = Join-Line @(
            '// namespace Fake.One;',
            '/* namespace Fake.Two; */',
            'codeunit 50100 Posting',
            '{',
            '    Text := ''namespace Fake.Three;'';',
            '}'
        )

        $source = Read-AlSource -Text $text

        $source.Namespace | Should -BeNullOrEmpty
        $source.HeaderWord | Should -BeNullOrEmpty
    }

    It 'reads a namespace after a line comment that mentions the start of a block comment' {
        $source = Read-AlSource -Text (Join-Line @('// see /* later', 'namespace Contoso.Sales;', 'codeunit 50100 Posting', '{', '}'))

        $source.Namespace | Should -Be 'Contoso.Sales'
        $source.NamespaceLine | Should -Be 2
    }

    It 'reports no namespace for a file without one, and the line of its first object' {
        $source = Read-AlSource -Text (Join-Line @('// header', '', 'codeunit 50100 Posting', '{', '}'))

        $source.Namespace | Should -BeNullOrEmpty
        $source.HeaderWord | Should -BeNullOrEmpty
        $source.FirstObjectLine | Should -Be 3
    }

    It 'names the last header statement the file starts with' {
        $withUsing = Read-AlSource -Text (Join-Line @('using Contoso.Sales;', 'codeunit 50100 Posting', '{', '}'))
        $withBoth = Read-AlSource -Text (Join-Line @('namespace Contoso.Sales;', 'using System.Utilities;', 'codeunit 50100 Posting', '{', '}'))

        $withUsing.HeaderWord | Should -Be 'using'
        $withUsing.Namespace | Should -BeNullOrEmpty
        $withBoth.HeaderWord | Should -Be 'using'
        $withBoth.Namespace | Should -Be 'Contoso.Sales'
    }

    It 'counts only a namespace that comes before the first object' {
        $text = Join-Line @('codeunit 50100 Posting', '{', '}', 'namespace Late.One;')

        (Read-AlSource -Text $text).Namespace | Should -BeNullOrEmpty
    }
}

Describe 'Read-AlSource objects' {
    It 'reads type, ID, name, and the line of the keyword' {
        $text = Join-Line @(
            'namespace Contoso.Sales;',
            '',
            'table 50102 "Sales Log"',
            '{',
            '}',
            '',
            'Codeunit 50103 Poster',
            '{',
            '}'
        )

        $objects = @((Read-AlSource -Text $text).Objects)

        $objects.Count | Should -Be 2
        $objects[0].Type | Should -Be 'table'
        $objects[0].Id | Should -Be 50102
        $objects[0].Name | Should -Be 'Sales Log'
        $objects[0].NameText | Should -Be '"Sales Log"'
        $objects[0].Line | Should -Be 3
        $objects[1].Keyword | Should -Be 'Codeunit'
        $objects[1].Type | Should -Be 'codeunit'
        $objects[1].Line | Should -Be 7
    }

    It 'reads an object that has no ID by its name' {
        $text = Join-Line @('interface "IPoster"', '{', '}', 'entitlement Plan', '{', '}', 'controladdin Chart', '{', '}')

        $objects = @((Read-AlSource -Text $text).Objects)

        @($objects | ForEach-Object Type) | Should -Be @('interface', 'entitlement', 'controladdin')
        @($objects | ForEach-Object Name) | Should -Be @('IPoster', 'Plan', 'Chart')
        @($objects | ForEach-Object Id) | Should -Be @(0, 0, 0)
    }

    It 'reads an extension object by its own name, not the object it extends' {
        $objects = @((Read-AlSource -Text (Join-Line @('tableextension 50100 "Customer Ext" extends Customer', '{', '}'))).Objects)

        $objects.Count | Should -Be 1
        $objects[0].Name | Should -Be 'Customer Ext'
    }

    It 'starts an object at the attributes above it while its line stays the keyword line' {
        $text = Join-Line @(
            'namespace Contoso.Sales;',
            '',
            '[Obsolete(''use the new one'')]',
            '[NonDebuggable]',
            'codeunit 50100 Posting',
            '{',
            '}'
        )

        $object = (Read-AlSource -Text $text).Objects[0]

        $object.Line | Should -Be 5
        $object.StartIndex | Should -Be $text.IndexOf('[Obsolete')
        $object.KeywordIndex | Should -Be $text.IndexOf('codeunit')
    }

    It 'starts an object at its keyword when no attribute sits above it' {
        $text = Join-Line @('codeunit 50100 Posting', '{', '}')

        (Read-AlSource -Text $text).Objects[0].StartIndex | Should -Be 0
    }

    It 'keeps an attribute of the previous object off the next one' {
        $text = Join-Line @('[Obsolete(''x'')]', 'codeunit 50100 One', '{', '}', 'codeunit 50101 Two', '{', '}')

        $objects = @((Read-AlSource -Text $text).Objects)

        $objects[1].StartIndex | Should -Be $text.IndexOf('codeunit 50101')
    }

    It 'reads an attribute whose argument holds a closing bracket' {
        $text = Join-Line @('[Obsolete(''use [Poster] instead'')]', 'codeunit 50100 Posting', '{', '}')

        $object = (Read-AlSource -Text $text).Objects[0]

        $object.Name | Should -Be 'Posting'
        $object.StartIndex | Should -Be 0
    }

    It 'sees no object in a comment, a string, or a keyword without its ID' {
        $text = Join-Line @(
            '// codeunit 50100 InComment',
            '/* table 50101 InBlock */',
            'codeunit NoId',
            '{',
            '    Text := ''page 50102 InString'';',
            '}'
        )

        @((Read-AlSource -Text $text).Objects).Count | Should -Be 0
    }

    It 'reads text that is not AL as a source with nothing in it' {
        foreach ($text in @('', '{{ not al ;; "unterminated', "'unterminated string")) {
            $source = Read-AlSource -Text $text

            @($source.Objects).Count | Should -Be 0
            $source.Namespace | Should -BeNullOrEmpty
            $source.FirstObjectLine | Should -Be 1
        }
    }

    It 'lists the offsets of the declared names, so a reference scan can skip them' {
        $text = Join-Line @('codeunit 50100 Posting', '{', '}')

        (Read-AlSource -Text $text).Objects[0].NameIndex | Should -Be $text.IndexOf('Posting')
    }
}

Describe 'Read-AlSource procedures' {
    It 'reads a public procedure with its name, parameter list, and line' {
        $text = Join-Line @(
            'codeunit 50100 Host',
            '{',
            '    procedure Post(var Header: Record "Sales Header"; Amount: Decimal): Boolean',
            '    begin',
            '    end;',
            '}'
        )

        $procedure = (Read-AlSource -Text $text).Objects[0].Procedures[0]

        $procedure.Name | Should -Be 'Post'
        $procedure.Access | Should -Be 'public'
        $procedure.Signature | Should -Be 'var header: record "sales header"; amount: decimal'
        $procedure.Line | Should -Be 3
        $procedure.IsSubscriber | Should -BeFalse
    }

    It 'reads local, internal, and protected as the access' {
        $procedures = Read-Procedure @(
            '    local procedure A()', '    begin', '    end;',
            '    internal procedure B()', '    begin', '    end;',
            '    protected procedure C()', '    begin', '    end;',
            '    PROCEDURE D()', '    begin', '    end;'
        )

        @($procedures | ForEach-Object Access) | Should -Be @('local', 'internal', 'protected', 'public')
    }

    It 'reads local on its own line before procedure' {
        $procedures = Read-Procedure @(
            '    local',
            '    procedure Hidden()',
            '    begin',
            '    end;'
        )

        $procedures[0].Access | Should -Be 'local'
        $procedures[0].Line | Should -Be 4
    }

    It 'reads an access word separated from procedure by a comment' {
        $procedures = Read-Procedure @('    local /* helper */ procedure Hidden()', '    begin', '    end;')

        $procedures[0].Access | Should -Be 'local'
    }

    It 'keeps overloads apart by their parameter lists' {
        $procedures = Read-Procedure @(
            '    procedure Post(Header: Record "Sales Header")', '    begin', '    end;',
            '    procedure Post(Header: Record "Sales Header"; Print: Boolean)', '    begin', '    end;'
        )

        $procedures.Count | Should -Be 2
        @($procedures | ForEach-Object Name) | Should -Be @('Post', 'Post')
        $procedures[0].Signature | Should -Not -Be $procedures[1].Signature
        @($procedures | ForEach-Object Line) | Should -Be @(3, 6)
    }

    It 'normalizes the parameter list: case, spacing, and comments' {
        $procedures = Read-Procedure @(
            '    procedure Post(',
            '        Header : Record   Customer; // the header',
            '        Amount: Decimal)',
            '    begin',
            '    end;'
        )

        $procedures[0].Signature | Should -Be 'header : record customer; amount: decimal'
    }

    It 'ends the parameter list at the closing parenthesis outside a quoted identifier' {
        $procedures = Read-Procedure @('    procedure Post(Header: Record "Header (old)"; Amount: Decimal)', '    begin', '    end;')

        $procedures[0].Signature | Should -Be 'header: record "header (old)"; amount: decimal'
    }

    It 'flags an event subscriber, local or not' {
        $procedures = Read-Procedure @(
            '    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", ''OnBeforePost'', '''', false, false)]',
            '    local procedure OnBeforePost()', '    begin', '    end;',
            '    [Scope(''OnPrem'')]',
            '    procedure Plain()', '    begin', '    end;'
        )

        $procedures[0].IsSubscriber | Should -BeTrue
        $procedures[0].Access | Should -Be 'local'
        $procedures[1].IsSubscriber | Should -BeFalse
    }

    It 'flags an event subscriber whose attribute argument holds a closing bracket' {
        $procedures = Read-Procedure @(
            '    [EventSubscriber(ObjectType::Table, Database::Customer, ''OnAfter]Thing'', '''', false, false)]',
            '    local procedure OnAfterThing()', '    begin', '    end;'
        )

        $procedures[0].IsSubscriber | Should -BeTrue
    }

    It 'flags an event subscriber whose attribute names an object with a closing bracket in its name' {
        $procedures = Read-Procedure @(
            '    [EventSubscriber(ObjectType::Table, Database::"Sales ] Line", ''OnAfterInsert'', '''', false, false)]',
            '    local procedure OnAfterInsertLine()', '    begin', '    end;'
        )

        $procedures[0].IsSubscriber | Should -BeTrue
    }

    It 'flags an event subscriber behind another attribute' {
        $procedures = Read-Procedure @(
            '    [EventSubscriber(ObjectType::Table, Database::Customer, ''OnAfterInsert'', '''', false, false)]',
            '    [Obsolete(''x'')]',
            '    local procedure OnAfterInsert()', '    begin', '    end;'
        )

        $procedures[0].IsSubscriber | Should -BeTrue
    }

    It 'leaves an attribute of an earlier member off a procedure with none' {
        $procedures = Read-Procedure @(
            '    var',
            '        Count: Integer;',
            '    [EventSubscriber(ObjectType::Table, Database::Customer, ''OnAfterInsert'', '''', false, false)]',
            '    local procedure First()', '    begin', '    end;',
            '    procedure Second()', '    begin', '    end;'
        )

        $procedures[0].IsSubscriber | Should -BeTrue
        $procedures[1].IsSubscriber | Should -BeFalse
    }

    It 'reads a quoted procedure name by its text' {
        $procedures = Read-Procedure @('    procedure "Post It"()', '    begin', '    end;')

        $procedures[0].Name | Should -Be 'Post It'
        $procedures[0].Signature | Should -Be ''
    }

    It 'gives each object the procedures between its keyword and the next object' {
        $text = Join-Line @(
            'codeunit 50100 One', '{', '    procedure A()', '    begin', '    end;', '}',
            'codeunit 50101 Two', '{', '    procedure B()', '    begin', '    end;', '    procedure C()', '    begin', '    end;', '}'
        )

        $objects = @((Read-AlSource -Text $text).Objects)

        @($objects[0].Procedures | ForEach-Object Name) | Should -Be @('A')
        @($objects[1].Procedures | ForEach-Object Name) | Should -Be @('B', 'C')
    }

    It 'reads the members of an interface' {
        $text = Join-Line @('interface "IPoster"', '{', '    procedure Post(Amount: Decimal): Boolean;', '}')

        $procedures = @((Read-AlSource -Text $text).Objects[0].Procedures)

        $procedures.Count | Should -Be 1
        $procedures[0].Name | Should -Be 'Post'
        $procedures[0].Access | Should -Be 'public'
    }

    It 'reads no procedure in a comment, a string, or after a dot' {
        $procedures = Read-Procedure @(
            '    // procedure InComment()',
            '    /* procedure InBlock() */',
            '    procedure Real()',
            '    begin',
            '        Text := ''procedure InString()'';',
            '        Other.procedure Member();',
            '    end;'
        )

        @($procedures | ForEach-Object Name) | Should -Be @('Real')
    }
}

Describe 'Get-AlNameReference' {
    BeforeAll {
        function Read-Reference {
            param([string[]]$Line)
            $text = Join-Line (@('codeunit 50100 Host', '{') + $Line + @('}'))
            return @(Get-AlNameReference -Source (Read-AlSource -Text $text) -Text $text)
        }
    }

    It 'sets the object type when the word before a name fixes it' {
        $references = Read-Reference @(
            '    var',
            '        Cust: Record Customer;',
            '        Poster: Codeunit "Sales Poster";',
            '    begin',
            '        Page.Run(Page::"Customer Card");',
            '        Value := Database::"Sales Log";',
            '    end;'
        )

        ($references | Where-Object Name -eq 'customer').Type | Should -Be 'table'
        ($references | Where-Object Name -eq 'sales poster').Type | Should -Be 'codeunit'
        ($references | Where-Object Name -eq 'customer card').Type | Should -Be 'page'
        ($references | Where-Object Name -eq 'sales log').Type | Should -Be 'table'
    }

    It 'leaves out member accesses, the declared name, and the type words' {
        $references = Read-Reference @('    begin', '        Cust.Get(Customer."No.");', '    end;')

        @($references | ForEach-Object Name) | Should -Not -Contain 'host'
        @($references | ForEach-Object Name) | Should -Not -Contain 'get'
        @($references | ForEach-Object Name) | Should -Not -Contain 'no.'
        @($references | ForEach-Object Name) | Should -Contain 'customer'
    }

    It 'keeps the display text of the name as written' {
        $references = Read-Reference @('    var', '        Cust: Record "Sales Header";')

        ($references | Where-Object Name -eq 'sales header').Display | Should -Be 'Sales Header'
    }
}

Describe 'Get-AlQualifiedName' {
    It 'finds a dotted name and its line' {
        $text = Join-Line @(
            'namespace Contoso.Sales;',
            'using Contoso.Posting.Internal;',
            'codeunit 50100 Host',
            '{',
            '    procedure Run()',
            '    begin',
            '        Contoso.Posting.Internal.Rules.Check();',
            '    end;',
            '}'
        )

        $names = @(Get-AlQualifiedName -Source (Read-AlSource -Text $text) -Text $text)

        ($names | Where-Object Line -eq 2).Segments -join '.' | Should -Be 'Contoso.Posting.Internal'
        ($names | Where-Object Line -eq 7).Segments -join '.' | Should -Be 'Contoso.Posting.Internal.Rules.Check'
    }

    It 'skips the namespace statement, comments, and strings' {
        $text = Join-Line @(
            'namespace Contoso.Posting.Internal;',
            'codeunit 50100 Host',
            '{',
            '    // Contoso.Posting.Internal.Comment',
            '    Text := ''Contoso.Posting.Internal.String'';',
            '}'
        )

        @(Get-AlQualifiedName -Source (Read-AlSource -Text $text) -Text $text).Count | Should -Be 0
    }

    It 'reads a quoted segment as one segment' {
        $text = Join-Line @('codeunit 50100 Host', '{', '    Value := Contoso."Sales Posting".Internal.Check;', '}')

        $names = @(Get-AlQualifiedName -Source (Read-AlSource -Text $text) -Text $text)

        $names[0].Segments | Should -Be @('Contoso', 'Sales Posting', 'Internal', 'Check')
    }

    It 'reads a name that follows a string holding a comment marker' {
        $text = Join-Line @('codeunit 50100 Host', '{', '    Value := ''//'' + Contoso.Internal.Check;', '}')

        $names = @(Get-AlQualifiedName -Source (Read-AlSource -Text $text) -Text $text)

        $names[0].Segments -join '.' | Should -Be 'Contoso.Internal.Check'
    }

    It 'does not join names across whitespace' {
        $text = Join-Line @('codeunit 50100 Host', '{', '    Value := Contoso . Internal;', '}')

        @(Get-AlQualifiedName -Source (Read-AlSource -Text $text) -Text $text).Count | Should -Be 0
    }
}

Describe 'Get-AlObjectType' {
    It 'says which object types carry an ID and the file type CodeCop names' {
        $types = Get-AlObjectType

        $types['codeunit'].HasId | Should -BeTrue
        $types['codeunit'].FileType | Should -Be 'Codeunit'
        $types['interface'].HasId | Should -BeFalse
        $types['pagecustomization'].HasId | Should -BeFalse
        $types['entitlement'].FileType | Should -BeNullOrEmpty
    }
}

Describe 'the al-build modules loaded together' {
    It 'exports no function name from more than one of al-source, module-check, and namespace-map' {
        $names = foreach ($module in 'al-source', 'module-check', 'namespace-map') {
            Import-Module (Join-Path $script:ScriptsDir "$module.psm1") -Force -DisableNameChecking
            Get-Command -Module $module -CommandType Function | ForEach-Object Name
        }

        @($names).Count | Should -BeGreaterThan 3
        $repeated = @($names | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
        $repeated | Should -BeNullOrEmpty
    }

    It 'defines no function name in more than one of the three modules, exported or not' {
        $defined = foreach ($module in 'al-source', 'module-check', 'namespace-map') {
            $path = Join-Path $script:ScriptsDir "$module.psm1"
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
            $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
                ForEach-Object { $_.Name }
        }

        $repeated = @($defined | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
        $repeated | Should -BeNullOrEmpty
    }
}
