#Requires -Version 7.2

# Drives the namespace pass through its single entry, Invoke-NamespaceMap, on a
# fixture app built in TestDrive. The pass is proven by what lands on disk:
# namespace and using lines, folders, file names, and bytes left alone.

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    $script:ScriptsDir = $scriptsDir.Path
    Import-Module (Join-Path $scriptsDir 'namespace-map.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'module-check.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking

    # Writes the files (repo-relative path -> content) as UTF-8, optionally with a BOM, and returns the repository root.
    function New-FixtureRepo {
        param([Parameter(Mandatory)][hashtable]$Files, [switch]$Bom)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        foreach ($relative in $Files.Keys) {
            $path = Join-Path $root $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            [System.IO.File]::WriteAllBytes($path, ([System.Text.UTF8Encoding]::new($Bom.IsPresent)).GetPreamble() + [System.Text.UTF8Encoding]::new($false).GetBytes([string]$Files[$relative]))
        }
        return $root
    }

    function Write-Map {
        param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object[]]$Entries)
        $path = Join-Path $Root 'namespace-map.json'
        Set-Content -LiteralPath $path -Value (ConvertTo-Json -InputObject @($Entries) -Depth 4) -Encoding utf8
        return $path
    }

    function Get-Entry {
        param([string]$Type, [int]$Id, [string]$Name, [string]$Namespace)
        return [ordered]@{ type = $Type; id = $Id; name = $Name; namespace = $Namespace }
    }

    Add-Type -AssemblyName System.IO.Compression

    # Writes a symbol package: a NAVX header in front of a zip holding SymbolReference.json, whose
    # objects (Namespace, Kind such as Tables or Codeunits, Name) sit in the nested namespace tree
    # the compiler writes. Namespace '' puts an object at the root.
    function New-SymbolPackage {
        param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$FileName, [Parameter(Mandatory)][object[]]$Objects)

        $newNode = { param($Name) [ordered]@{ Name = $Name; Namespaces = [System.Collections.Generic.List[object]]::new() } }
        $root = & $newNode 'root'
        $id = 0
        foreach ($object in $Objects) {
            $node = $root
            foreach ($segment in @($object.Namespace -split '\.' | Where-Object { $_ })) {
                $child = $node.Namespaces | Where-Object { $_.Name -eq $segment } | Select-Object -First 1
                if (-not $child) { $child = & $newNode $segment; $node.Namespaces.Add($child) }
                $node = $child
            }
            if (-not $node.Contains($object.Kind)) { $node[$object.Kind] = [System.Collections.Generic.List[object]]::new() }
            $id++
            $node[$object.Kind].Add([ordered]@{ Id = $id; Name = $object.Name })
        }
        $root['Name'] = $FileName
        $json = ConvertTo-Json -InputObject $root -Depth 30

        $zip = [System.IO.MemoryStream]::new()
        $archive = [System.IO.Compression.ZipArchive]::new($zip, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        $writer = [System.IO.StreamWriter]::new($archive.CreateEntry('SymbolReference.json').Open(), [System.Text.UTF8Encoding]::new($true))
        try { $writer.Write($json) } finally { $writer.Dispose(); $archive.Dispose() }
        $header = [byte[]]::new(40)
        [System.Text.Encoding]::ASCII.GetBytes('NAVX').CopyTo($header, 0)
        [BitConverter]::GetBytes([int]40).CopyTo($header, 4)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $Dir $FileName), $header + $zip.ToArray())
    }

    # The dependency symbols most tests resolve against: Base App-like objects, a codeunit name two
    # packages put in different namespaces, and one object with no namespace.
    function New-BaseSymbols {
        $dir = Join-Path $TestDrive ('symbols-' + [guid]::NewGuid().ToString('N'))
        New-SymbolPackage -Dir $dir -FileName 'Microsoft.BaseApplication.app' -Objects @(
            @{ Namespace = 'Microsoft.Sales.Customer'; Kind = 'Tables'; Name = 'Customer' }
            @{ Namespace = 'Microsoft.Sales.Document'; Kind = 'Tables'; Name = 'Sales Header' }
            @{ Namespace = 'Microsoft.Sales.Document'; Kind = 'EnumTypes'; Name = 'Sales Document Type' }
            @{ Namespace = 'Microsoft.Sales.Posting'; Kind = 'Codeunits'; Name = 'Sales-Post' }
            @{ Namespace = 'Microsoft.Inventory.Item'; Kind = 'Tables'; Name = 'Item' }
            @{ Namespace = 'System.Tools.A'; Kind = 'Codeunits'; Name = 'Dup Tool' }
            @{ Namespace = ''; Kind = 'Codeunits'; Name = 'Global Helper' }
        )
        New-SymbolPackage -Dir $dir -FileName 'Vendor.Tools.app' -Objects @(
            @{ Namespace = 'System.Tools.B'; Kind = 'Codeunits'; Name = 'Dup Tool' }
        )
        return $dir
    }

    $script:Symbols = New-BaseSymbols

    # Relative path -> hash for every file, plus every directory, so an untouched tree compares equal.
    function Get-TreeSnapshot {
        param([Parameter(Mandatory)][string]$Root)
        $items = Get-ChildItem -LiteralPath $Root -Recurse -Force
        $lines = foreach ($item in $items) {
            $relative = [System.IO.Path]::GetRelativePath($Root, $item.FullName) -replace '\\', '/'
            if ($item.PSIsContainer) { "dir  $relative" } else { "file $relative $((Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash)" }
        }
        return (@($lines) | Sort-Object) -join "`n"
    }

    function Read-Text {
        param([Parameter(Mandatory)][string]$Path)
        return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    }

    # Applies the map (entries) to the fixture and asserts the pass throws the message and the tree is byte-identical.
    function Assert-RefusedUntouched {
        param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object[]]$Entries, [Parameter(Mandatory)][string]$Message, [string]$RootNamespace = 'Contoso.Sales', [string]$AppDir = 'app')
        $mapPath = Write-Map -Root $Root -Entries $Entries
        $before = Get-TreeSnapshot -Root $Root
        { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $Root $AppDir) -RootNamespace $RootNamespace } | Should -Throw -ExpectedMessage $Message
        Get-TreeSnapshot -Root $Root | Should -BeExactly $before
    }

    $script:PostSales = "// Posts a sales document.`r`ncodeunit 50100 `"Post Sales`"`r`n{`r`n    var`r`n        SalesRules: Codeunit `"Sales Rules`";`r`n        SalesLog: Record `"Sales Log`";`r`n        Note: Label 'Sales Rules decide';`r`n`r`n    procedure Post()`r`n    begin`r`n        // Sales Rules are consulted first`r`n        SalesRules.Check();`r`n        SalesLog.Insert();`r`n    end;`r`n}`r`n"
    $script:SalesRules = "codeunit 50101 `"Sales Rules`"`r`n{`r`n    Access = Internal;`r`n`r`n    procedure Check()`r`n    begin`r`n    end;`r`n}`r`n"
    $script:SalesLog = "table 50102 `"Sales Log`"`r`n{`r`n    Access = Public;`r`n    fields`r`n    {`r`n        field(1; `"Entry No.`"; Integer) { }`r`n    }`r`n}`r`n"
    $script:LogExt = "pageextension 50103 `"Sales Log Ext`" extends `"Customer Card`"`r`n{`r`n    layout`r`n    {`r`n    }`r`n}`r`n"

    function New-SalesApp {
        return New-FixtureRepo -Bom -Files @{
            'app/src/Codeunits/COD50100.PostSales.al' = $script:PostSales
            'app/src/Codeunits/COD50101.SalesRules.al' = $script:SalesRules
            'app/src/Tables/TAB50102.SalesLog.al'     = $script:SalesLog
            'app/src/Pages/PAG50103.LogExt.al'        = $script:LogExt
        }
    }

    function New-SalesMap {
        param([Parameter(Mandatory)][string]$Root)
        return Write-Map -Root $Root -Entries @(
            (Get-Entry 'codeunit' 50100 'Post Sales' 'Contoso.Sales'),
            (Get-Entry 'codeunit' 50101 'Sales Rules' 'Contoso.Sales.Rules'),
            (Get-Entry 'table' 50102 'Sales Log' 'Contoso.Sales.Logging'),
            (Get-Entry 'pageextension' 50103 'Sales Log Ext' 'Contoso.Sales.Logging')
        )
    }
}

Describe 'Invoke-NamespaceMap' {
    Context 'a reviewed map applied to a fixture app' {
        BeforeAll {
            $script:Root = New-SalesApp
            $mapPath = New-SalesMap -Root $script:Root
            $script:Result = Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $script:Root 'app') -RootNamespace 'Contoso.Sales'
        }

        It 'moves each file to the folder its namespace names below src and gives it the CodeCop file name' {
            $app = Join-Path $script:Root 'app' 'src'
            Test-Path -LiteralPath (Join-Path $app 'PostSales.Codeunit.al') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $app 'Rules' 'SalesRules.Codeunit.al') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $app 'Logging' 'SalesLog.Table.al') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $app 'Logging' 'SalesLogExt.PageExt.al') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $app 'Codeunits') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $app 'Tables') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $app 'Pages') | Should -BeFalse
        }

        It 'writes the namespace line and only the using lines whose objects the file names in code' {
            $postSales = Read-Text (Join-Path $script:Root 'app' 'src' 'PostSales.Codeunit.al')
            $expected = "// Posts a sales document.`r`nnamespace Contoso.Sales;`r`n`r`nusing Contoso.Sales.Logging;`r`nusing Contoso.Sales.Rules;`r`n`r`n" + $script:PostSales.Substring("// Posts a sales document.`r`n".Length)
            $postSales | Should -BeExactly $expected

            $rules = Read-Text (Join-Path $script:Root 'app' 'src' 'Rules' 'SalesRules.Codeunit.al')
            $rules | Should -BeExactly ("namespace Contoso.Sales.Rules;`r`n`r`n" + $script:SalesRules)

            $log = Read-Text (Join-Path $script:Root 'app' 'src' 'Logging' 'SalesLog.Table.al')
            $log | Should -BeExactly ("namespace Contoso.Sales.Logging;`r`n`r`n" + $script:SalesLog)
        }

        It 'changes nothing else in a file: the BOM, the line endings, and every access line survive' {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path $script:Root 'app' 'src' 'Rules' 'SalesRules.Codeunit.al'))
            $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
            (Read-Text (Join-Path $script:Root 'app' 'src' 'Rules' 'SalesRules.Codeunit.al')) | Should -Match 'Access = Internal;'
            (Read-Text (Join-Path $script:Root 'app' 'src' 'Logging' 'SalesLog.Table.al')) | Should -Match 'Access = Public;'
            (Read-Text (Join-Path $script:Root 'app' 'src' 'Logging' 'SalesLog.Table.al')) | Should -Not -Match "(?<!`r)`n"
        }

        It 'passes rule 1 of the module check' {
            $check = Invoke-ModuleCheck -RepoRoot $script:Root -RootNamespace 'Contoso.Sales' -AppDir (Join-Path $script:Root 'app')
            @($check.Violations).Count | Should -Be 0
        }

        It 'reports one record per file' {
            @($script:Result.Files).Count | Should -Be 4
        }
    }

    Context 'a map that cannot be applied' {
        BeforeAll {
            $script:Full = @(
                (Get-Entry 'codeunit' 50100 'Post Sales' 'Contoso.Sales'),
                (Get-Entry 'codeunit' 50101 'Sales Rules' 'Contoso.Sales.Rules'),
                (Get-Entry 'table' 50102 'Sales Log' 'Contoso.Sales.Logging'),
                (Get-Entry 'pageextension' 50103 'Sales Log Ext' 'Contoso.Sales.Logging')
            )
        }

        It 'refuses an object the app does not have, naming the app object with that ID' {
            $entries = @($script:Full | Where-Object { $_.id -ne 50101 }) + (Get-Entry 'codeunit' 50101 'Sales Rule' 'Contoso.Sales.Rules')
            Assert-RefusedUntouched -Root (New-SalesApp) -Entries $entries -Message '*codeunit 50101 Sales Rule names an object the app does not have*codeunit 50101 is named Sales Rules*'
        }

        It 'refuses an app object the map leaves out' {
            Assert-RefusedUntouched -Root (New-SalesApp) -Entries @($script:Full | Where-Object { $_.id -ne 50102 }) -Message '*table 50102 Sales Log in src/Tables/TAB50102.SalesLog.al is missing from the map*'
        }

        It 'refuses two files sent to one path' {
            $root = New-FixtureRepo -Files @{
                'app/src/A.al' = "codeunit 50100 `"Sales-Rules`"`n{`n}`n"
                'app/src/B.al' = "codeunit 50101 `"Sales Rules`"`n{`n}`n"
            }
            Assert-RefusedUntouched -Root $root -Message '*A.al, src/B.al all go to src/Rules/SalesRules.Codeunit.al*' -Entries @(
                (Get-Entry 'codeunit' 50100 'Sales-Rules' 'Contoso.Sales.Rules'),
                (Get-Entry 'codeunit' 50101 'Sales Rules' 'Contoso.Sales.Rules')
            )
        }

        It 'refuses a file that declares no object' {
            $root = New-FixtureRepo -Files @{
                'app/src/A.al'     = "codeunit 50100 `"Sales Rules`"`n{`n}`n"
                'app/src/Empty.al' = '// nothing here'
            }
            Assert-RefusedUntouched -Root $root -Message '*src/Empty.al declares no AL object*' -Entries @((Get-Entry 'codeunit' 50100 'Sales Rules' 'Contoso.Sales.Rules'))
        }

        It 'refuses a target held by a file outside the app''s .al set' {
            $root = New-FixtureRepo -Files @{
                'app/A.al'                        = "codeunit 50100 `"Sales Rules`"`n{`n}`n"
                'app/test/SalesRules.Codeunit.al' = "codeunit 50200 `"Other`"`n{`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'Sales Rules' 'Contoso.Sales.test'))
            $before = Get-TreeSnapshot -Root $root
            { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' -ExcludeDirs @((Join-Path $root 'app' 'test')) } |
                Should -Throw -ExpectedMessage '*test/SalesRules.Codeunit.al already exists and is not one of the app''s .al files*'
            Get-TreeSnapshot -Root $root | Should -BeExactly $before
        }

        It 'refuses <Label>' -TestCases @(
            @{ Label = 'a namespace outside the root'; Namespace = 'Fabrikam.Sales'; Message = "*has namespace 'Fabrikam.Sales'*" }
            @{ Label = 'a namespace that merely starts like the root'; Namespace = 'Contoso.SalesExtra.Rules'; Message = "*has namespace 'Contoso.SalesExtra.Rules'*" }
            @{ Label = 'a namespace that is not a dotted AL identifier'; Namespace = 'Contoso.Sales.Post Rules'; Message = "*has namespace 'Contoso.Sales.Post Rules'*" }
            @{ Label = 'a namespace with an empty segment'; Namespace = 'Contoso.Sales..Rules'; Message = "*has namespace 'Contoso.Sales..Rules'*" }
            @{ Label = 'a segment that starts with a digit'; Namespace = 'Contoso.Sales.2Rules'; Message = "*has namespace 'Contoso.Sales.2Rules'*" }
        ) {
            $entries = @($script:Full | Where-Object { $_.id -ne 50101 }) + (Get-Entry 'codeunit' 50101 'Sales Rules' $Namespace)
            Assert-RefusedUntouched -Root (New-SalesApp) -Entries $entries -Message $Message
        }

        It 'refuses a bad entry: <Label>' -TestCases @(
            @{ Label = 'an unknown type'; Entry = [ordered]@{ type = 'widget'; id = 1; name = 'X'; namespace = 'Contoso.Sales' }; Message = "*type 'widget', which is not an AL object type*" }
            @{ Label = 'a string id'; Entry = [ordered]@{ type = 'codeunit'; id = '50100'; name = 'X'; namespace = 'Contoso.Sales' }; Message = "*has id '50100'*" }
            @{ Label = 'an interface with an id'; Entry = [ordered]@{ type = 'interface'; id = 5; name = 'X'; namespace = 'Contoso.Sales' }; Message = '*has no ID; use 0*' }
            @{ Label = 'a missing name'; Entry = [ordered]@{ type = 'codeunit'; id = 7; namespace = 'Contoso.Sales' }; Message = '*has no name*' }
        ) {
            Assert-RefusedUntouched -Root (New-SalesApp) -Entries (@($script:Full) + $Entry) -Message $Message
        }

        It 'refuses an entry listed twice' {
            Assert-RefusedUntouched -Root (New-SalesApp) -Entries (@($script:Full) + (Get-Entry 'codeunit' 50100 'POST SALES' 'Contoso.Sales')) -Message '*codeunit 50100 POST SALES appears twice*'
        }

        It 'refuses a root namespace that is not a dotted AL identifier' {
            Assert-RefusedUntouched -Root (New-SalesApp) -Entries $script:Full -RootNamespace 'Contoso Sales' -Message "*Root namespace 'Contoso Sales' is not a dotted AL identifier*"
        }

        It 'refuses a file that already has a namespace, so a second run changes nothing' {
            $root = New-SalesApp
            $mapPath = New-SalesMap -Root $root
            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null
            $before = Get-TreeSnapshot -Root $root
            { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' } | Should -Throw -ExpectedMessage '*already has a namespace statement*'
            Get-TreeSnapshot -Root $root | Should -BeExactly $before
        }

        It 'refuses a file that holds objects the map sends to different namespaces' {
            $root = New-FixtureRepo -Files @{ 'app/src/Both.al' = "codeunit 50100 One`n{`n}`n`ncodeunit 50101 Two`n{`n}`n" }
            Assert-RefusedUntouched -Root $root -Message '*holds objects the map sends to different namespaces (Contoso.Sales.A, Contoso.Sales.B)*' -Entries @(
                (Get-Entry 'codeunit' 50100 'One' 'Contoso.Sales.A'),
                (Get-Entry 'codeunit' 50101 'Two' 'Contoso.Sales.B')
            )
        }

        It 'refuses a file that is not UTF-8' {
            $root = New-FixtureRepo -Files @{ 'app/src/A.al' = "codeunit 50100 One`n{`n}`n" }
            [System.IO.File]::WriteAllBytes((Join-Path $root 'app' 'src' 'A.al'), [byte[]]@(0x63, 0x6F, 0x64, 0x65, 0x75, 0x6E, 0x69, 0x74, 0x20, 0xE6, 0xF8))
            Assert-RefusedUntouched -Root $root -Message '*A.al is not valid UTF-8*' -Entries @((Get-Entry 'codeunit' 50100 'One' 'Contoso.Sales'))
        }

        It 'reports every problem in one error' {
            $root = New-SalesApp
            $mapPath = Write-Map -Root $root -Entries @(
                (Get-Entry 'codeunit' 50100 'Post Sales' 'Fabrikam'),
                (Get-Entry 'codeunit' 50999 'Ghost' 'Contoso.Sales')
            )
            $message = $null
            try { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' } catch { $message = $_.Exception.Message }
            $message | Should -Match 'nothing was written'
            $message | Should -Match "has namespace 'Fabrikam'"
            $message | Should -Match 'Ghost names an object the app does not have'
            $message | Should -Match 'Sales Rules in src/Codeunits/COD50101.SalesRules.al is missing from the map'
        }

        It 'refuses a map file that is missing, not JSON, or not an array' {
            $root = New-SalesApp
            $app = Join-Path $root 'app'
            { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath (Join-Path $root 'absent.json') -AppDir $app -RootNamespace 'Contoso.Sales' } | Should -Throw -ExpectedMessage '*does not exist*'
            Set-Content -LiteralPath (Join-Path $root 'bad.json') -Value '[ {'
            { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath (Join-Path $root 'bad.json') -AppDir $app -RootNamespace 'Contoso.Sales' } | Should -Throw -ExpectedMessage '*is not valid JSON*'
            Set-Content -LiteralPath (Join-Path $root 'obj.json') -Value '{ "type": "codeunit" }'
            { Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath (Join-Path $root 'obj.json') -AppDir $app -RootNamespace 'Contoso.Sales' } | Should -Throw -ExpectedMessage '*is not a JSON array*'
        }
    }

    Context 'using lines' {
        It 'adds a using only for objects the file names in code, once per namespace, sorted, never its own namespace' {
            $root = New-FixtureRepo -Files @{
                'app/src/Use.al'      = "codeunit 50100 Consumer`n{`n    var`n        A: Codeunit Zeta;`n        B: Codeunit `"Alpha Two`";`n        C: Codeunit `"Alpha One`";`n        D: Codeunit Sibling;`n        Text: Label 'Ghost Named';`n        Note: Label 'it''s Ghost Named';`n    // Ghost Named`n    /* Ghost Named */`n    procedure P()`n    begin`n        A.Run();`n        Rec.`"Ghost Named`" := 1;`n    end;`n}`n"
                'app/src/Zeta.al'     = "codeunit 50101 Zeta`n{`n}`n"
                'app/src/AlphaTwo.al' = "codeunit 50102 `"Alpha Two`"`n{`n}`n"
                'app/src/AlphaOne.al' = "codeunit 50103 `"Alpha One`"`n{`n}`n"
                'app/src/Sibling.al'  = "codeunit 50104 Sibling`n{`n}`n"
                'app/src/Ghost.al'    = "codeunit 50105 `"Ghost Named`"`n{`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @(
                (Get-Entry 'codeunit' 50100 'Consumer' 'Contoso.Sales.Use'),
                (Get-Entry 'codeunit' 50101 'Zeta' 'Contoso.Sales.Zeta'),
                (Get-Entry 'codeunit' 50102 'Alpha Two' 'Contoso.Sales.Alpha'),
                (Get-Entry 'codeunit' 50103 'Alpha One' 'Contoso.Sales.Alpha'),
                (Get-Entry 'codeunit' 50104 'Sibling' 'Contoso.Sales.Use'),
                (Get-Entry 'codeunit' 50105 'Ghost Named' 'Contoso.Sales.Ghost')
            )

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            $text = Read-Text (Join-Path $root 'app' 'src' 'Use' 'Consumer.Codeunit.al')
            $text | Should -BeLike "namespace Contoso.Sales.Use;`n`nusing Contoso.Sales.Alpha;`nusing Contoso.Sales.Zeta;`n`ncodeunit 50100 Consumer*"
        }

        It 'takes the type a Record, Codeunit::, or Database:: context fixes, and every type for a bare name' {
            $root = New-FixtureRepo -Files @{
                'app/src/Typed.al' = "codeunit 50100 Typed`n{`n    var`n        Cust: Record Shared;`n}`n"
                'app/src/Bare.al'  = "page 50101 Bare`n{`n    SourceTable = Shared;`n}`n"
                'app/src/Tab.al'   = "table 50102 Shared`n{`n}`n"
                'app/src/Cod.al'   = "codeunit 50103 Shared`n{`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @(
                (Get-Entry 'codeunit' 50100 'Typed' 'Contoso.Sales.Use'),
                (Get-Entry 'page' 50101 'Bare' 'Contoso.Sales.Use'),
                (Get-Entry 'table' 50102 'Shared' 'Contoso.Sales.Data'),
                (Get-Entry 'codeunit' 50103 'Shared' 'Contoso.Sales.Logic')
            )

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            (Read-Text (Join-Path $root 'app' 'src' 'Use' 'Typed.Codeunit.al')) | Should -BeLike "namespace Contoso.Sales.Use;`n`nusing Contoso.Sales.Data;`n`ncodeunit*"
            (Read-Text (Join-Path $root 'app' 'src' 'Use' 'Bare.Page.al')) | Should -BeLike "namespace Contoso.Sales.Use;`n`nusing Contoso.Sales.Data;`nusing Contoso.Sales.Logic;`n`npage*"
        }
    }

    Context 'dependency symbols' {
        It 'writes a using for the namespace each named dependency object lives in, and none for an object with no namespace' {
            $root = New-FixtureRepo -Files @{
                'app/src/Use.al' = "codeunit 50100 Consumer`n{`n    var`n        Header: Record `"Sales Header`";`n        DocType: Enum `"Sales Document Type`";`n        Post: Codeunit `"Sales-Post`";`n        Helper: Codeunit `"Global Helper`";`n        Cust: Record Customer;`n`n    procedure P()`n    begin`n        Rec.Get(Database::Item);`n    end;`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'Consumer' 'Contoso.Sales'))

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            (Read-Text (Join-Path $root 'app' 'src' 'Consumer.Codeunit.al')) |
                Should -BeLike "namespace Contoso.Sales;`n`nusing Microsoft.Inventory.Item;`nusing Microsoft.Sales.Customer;`nusing Microsoft.Sales.Document;`nusing Microsoft.Sales.Posting;`n`ncodeunit 50100 Consumer*"
        }

        It 'refuses a reference its context types that resolves to two namespaces, naming the file, the reference, and both' {
            $root = New-FixtureRepo -Files @{ 'app/src/Use.al' = "codeunit 50100 Consumer`n{`n    var`n        Tool: Codeunit `"Dup Tool`";`n}`n" }
            Assert-RefusedUntouched -Root $root -Message '*src/Use.al references codeunit Dup Tool, which resolves to System.Tools.A, System.Tools.B*' -Entries @((Get-Entry 'codeunit' 50100 'Consumer' 'Contoso.Sales'))
        }

        It 'refuses a typed reference that resolves to the app''s own object and a dependency''s in another namespace' {
            $root = New-FixtureRepo -Files @{
                'app/src/Use.al' = "codeunit 50100 Consumer`n{`n    var`n        Cust: Record Customer;`n}`n"
                'app/src/Own.al' = "table 50101 Customer`n{`n}`n"
            }
            Assert-RefusedUntouched -Root $root -Message '*references table Customer, which resolves to Contoso.Sales.Data, Microsoft.Sales.Customer*' -Entries @(
                (Get-Entry 'codeunit' 50100 'Consumer' 'Contoso.Sales.Use'),
                (Get-Entry 'table' 50101 'Customer' 'Contoso.Sales.Data')
            )
        }

        It 'lets the file''s own namespace win a name a dependency also has' {
            $root = New-FixtureRepo -Files @{
                'app/src/Use.al' = "codeunit 50100 Consumer`n{`n    var`n        Tool: Codeunit `"Dup Tool`";`n}`n"
                'app/src/Own.al' = "codeunit 50101 `"Dup Tool`"`n{`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'Consumer' 'Contoso.Sales'), (Get-Entry 'codeunit' 50101 'Dup Tool' 'Contoso.Sales'))

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            (Read-Text (Join-Path $root 'app' 'src' 'Consumer.Codeunit.al')) | Should -BeLike "namespace Contoso.Sales;`n`ncodeunit 50100 Consumer*"
        }

        It 'refuses to run with no symbols, naming provision.ps1, and leaves the tree alone' -TestCases @(
            @{ Label = 'a missing folder'; Dir = 'absent' }
            @{ Label = 'a folder with no .app'; Dir = 'empty' }
        ) {
            $root = New-SalesApp
            New-Item -ItemType Directory -Path (Join-Path $root 'empty') | Out-Null
            $mapPath = New-SalesMap -Root $root
            $before = Get-TreeSnapshot -Root $root
            { Invoke-NamespaceMap -SymbolDir (Join-Path $root $Dir) -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' } |
                Should -Throw -ExpectedMessage '*No dependency symbols*run provision.ps1*'
            Get-TreeSnapshot -Root $root | Should -BeExactly $before
        }

        It 'refuses a symbol package that is not a .app file' {
            $root = New-SalesApp
            $symbols = Join-Path $root 'symbols'
            New-Item -ItemType Directory -Path $symbols | Out-Null
            Set-Content -LiteralPath (Join-Path $symbols 'Broken.app') -Value 'not a package'
            $mapPath = New-SalesMap -Root $root
            $before = Get-TreeSnapshot -Root $root
            { Invoke-NamespaceMap -SymbolDir $symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' } |
                Should -Throw -ExpectedMessage '*Broken.app is not a .app file*'
            Get-TreeSnapshot -Root $root | Should -BeExactly $before
        }
    }

    Context 'what stands above the object' {
        It 'puts the namespace above attributes and /// documentation and below other header comments' {
            $root = New-FixtureRepo -Files @{
                'app/src/Doc.al' = "// header`n/// <summary>`n/// Does it.`n/// </summary>`n[Obsolete('x', '1.0')]`ncodeunit 50100 Documented`n{`n}`n"
                'app/src/Tab.al' = "// other header`n[InherentPermissions(PermissionObjectType::TableData, Database::Customer, 'r')]`ntable 50101 Attributed`n{`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'Documented' 'Contoso.Sales'), (Get-Entry 'table' 50101 'Attributed' 'Contoso.Sales'))

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            (Read-Text (Join-Path $root 'app' 'src' 'Documented.Codeunit.al')) |
                Should -BeExactly "// header`nnamespace Contoso.Sales;`n`n/// <summary>`n/// Does it.`n/// </summary>`n[Obsolete('x', '1.0')]`ncodeunit 50100 Documented`n{`n}`n"
            (Read-Text (Join-Path $root 'app' 'src' 'Attributed.Table.al')) |
                Should -BeExactly "// other header`nnamespace Contoso.Sales;`n`nusing Microsoft.Sales.Customer;`n`n[InherentPermissions(PermissionObjectType::TableData, Database::Customer, 'r')]`ntable 50101 Attributed`n{`n}`n"
        }
    }

    Context 'the apply-namespace-map.ps1 entry point' {
        BeforeAll {
            # Runs the script as a process in the repository with HOME set to the fixture's, so the
            # symbol cache it reads is the one the test wrote.
            function Invoke-Entry {
                param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$MapPath, [string[]]$Extra = @())
                $previousHome = $env:HOME
                $env:HOME = Join-Path $Root 'home'
                Push-Location $Root
                try {
                    $output = & pwsh -NoProfile -File (Join-Path $script:ScriptsDir 'apply-namespace-map.ps1') -MapPath $MapPath -RootNamespace 'Contoso.Sales' @Extra 2>&1 | Out-String
                    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
                } finally {
                    Pop-Location
                    $env:HOME = $previousHome
                }
            }

            # The sales app with an app.json, a git repository, and its dependency symbols in the cache
            # folder provision.ps1 fills: <HOME>/.bc-symbol-cache/<checkout>/<publisher>/<name>/<id>.
            function New-ProvisionedSalesApp {
                param([switch]$WithConfig, [switch]$WithoutSymbols)
                $root = New-SalesApp
                Set-Content -LiteralPath (Join-Path $root 'app' 'app.json') -Value '{ "id": "11111111-2222-3333-4444-555555555555", "name": "Sales", "publisher": "Contoso" }'
                if ($WithConfig) { Set-Content -LiteralPath (Join-Path $root 'al-build.json') -Value '{ "appDir": "app", "testApps": ["test"] }' }
                & git -C $root init --quiet 2>&1 | Out-Null
                if (-not $WithoutSymbols) {
                    $previousHome = $env:HOME
                    $env:HOME = Join-Path $root 'home'
                    Push-Location $root
                    try {
                        $cache = Join-Path (Get-SymbolCacheRoot) 'Contoso' 'Sales' '11111111-2222-3333-4444-555555555555'
                    } finally {
                        Pop-Location
                        $env:HOME = $previousHome
                    }
                    New-Item -ItemType Directory -Path $cache -Force | Out-Null
                    Copy-Item -Path (Join-Path $script:Symbols '*.app') -Destination $cache
                    Set-Content -LiteralPath (Join-Path $cache 'symbols.lock.json') -Value '{}'
                }
                return $root
            }
        }

        It 'exits 0 and organizes the app from al-build.json''s appDir' {
            $root = New-ProvisionedSalesApp -WithConfig
            $result = Invoke-Entry -Root $root -MapPath (New-SalesMap -Root $root)

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'Applied the namespace map: 4 files organized'
            Test-Path -LiteralPath (Join-Path $root 'app' 'src' 'Rules' 'SalesRules.Codeunit.al') | Should -BeTrue
        }

        It 'takes -AppDir without an al-build.json' {
            $root = New-ProvisionedSalesApp
            $result = Invoke-Entry -Root $root -MapPath (New-SalesMap -Root $root) -Extra @('-AppDir', 'app')

            $result.ExitCode | Should -Be 0
            Test-Path -LiteralPath (Join-Path $root 'app' 'src' 'Rules' 'SalesRules.Codeunit.al') | Should -BeTrue
        }

        It 'exits 1 with the problems named and the tree untouched when the map is wrong' {
            $root = New-ProvisionedSalesApp -WithConfig
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'Post Sales' 'Contoso.Sales'))
            $before = Get-TreeSnapshot -Root $root

            $result = Invoke-Entry -Root $root -MapPath $mapPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'is missing from the map'
            Get-TreeSnapshot -Root $root | Should -BeExactly $before
        }

        It 'exits 1 naming provision.ps1 when the symbols were never downloaded' {
            $root = New-ProvisionedSalesApp -WithConfig -WithoutSymbols
            $mapPath = New-SalesMap -Root $root
            $before = Get-TreeSnapshot -Root $root

            $result = Invoke-Entry -Root $root -MapPath $mapPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'provision\.ps1'
            Get-TreeSnapshot -Root $root | Should -BeExactly $before
        }
    }

    Context 'layout' {
        It 'puts files in the app folder when it has no src, and keeps an LF file without a BOM as it was' {
            $root = New-FixtureRepo -Files @{ 'app/Old/Thing.al' = "// header`ncodeunit 50100 `"My-Thing 2`"`n{`n}`n" }
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'My-Thing 2' 'Contoso.Sales.Things'))

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            $target = Join-Path $root 'app' 'Things' 'MyThing2.Codeunit.al'
            (Read-Text $target) | Should -BeExactly "// header`nnamespace Contoso.Sales.Things;`n`ncodeunit 50100 `"My-Thing 2`"`n{`n}`n"
            [System.IO.File]::ReadAllBytes($target)[0] | Should -Be ([byte][char]'/')
            Test-Path -LiteralPath (Join-Path $root 'app' 'Old') | Should -BeFalse
            @((Invoke-ModuleCheck -RepoRoot $root -RootNamespace 'Contoso.Sales' -AppDir (Join-Path $root 'app')).Violations).Count | Should -Be 0
        }

        It 'names every type by the CodeCop type map and keeps the name of an entitlement and of a file with several objects' {
            $root = New-FixtureRepo -Files @{
                'app/src/1.al' = "interface `"Posting Rule`"`n{`n}`n"
                'app/src/2.al' = "reportextension 50100 `"Sales Report Ext`" extends `"Standard Sales - Invoice`"`n{`n}`n"
                'app/src/3.al' = "entitlement `"My Ent`"`n{`n}`n"
                'app/src/4.al' = "codeunit 50101 One`n{`n}`n`ncodeunit 50102 Two`n{`n}`n"
                'app/src/5.al' = "enumextension 50103 `"Status Ext`" extends `"Sales Document Status`"`n{`n}`n"
                'app/src/6.al' = "permissionsetextension 50104 `"Perm Ext`" extends `"D365 BASIC`"`n{`n}`n"
            }
            $mapPath = Write-Map -Root $root -Entries @(
                (Get-Entry 'interface' 0 'Posting Rule' 'Contoso.Sales'),
                (Get-Entry 'reportextension' 50100 'Sales Report Ext' 'Contoso.Sales'),
                (Get-Entry 'entitlement' 0 'My Ent' 'Contoso.Sales'),
                (Get-Entry 'codeunit' 50101 'One' 'Contoso.Sales'),
                (Get-Entry 'codeunit' 50102 'Two' 'Contoso.Sales'),
                (Get-Entry 'enumextension' 50103 'Status Ext' 'Contoso.Sales'),
                (Get-Entry 'permissionsetextension' 50104 'Perm Ext' 'Contoso.Sales')
            )

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' | Out-Null

            $names = Get-ChildItem -LiteralPath (Join-Path $root 'app' 'src') -File | ForEach-Object Name | Sort-Object { $_.ToLowerInvariant() }
            ($names -join ',') | Should -BeExactly '3.al,4.al,PermExt.PermissionSetExt.al,PostingRule.Interface.al,SalesReportExt.ReportExt.al,StatusExt.EnumExt.al'
        }

        It 'leaves a test app inside the app folder, dot-folders, and files it does not own alone' {
            $root = New-FixtureRepo -Files @{
                'app/src/A.al'         = "codeunit 50100 One`n{`n}`n"
                'app/test/T.al'        = "codeunit 50200 Tests`n{`n}`n"
                'app/.alpackages/P.al' = "codeunit 50300 Pkg`n{`n}`n"
                'app/readme.md'        = '# readme'
            }
            $mapPath = Write-Map -Root $root -Entries @((Get-Entry 'codeunit' 50100 'One' 'Contoso.Sales'))
            $before = Get-TreeSnapshot -Root (Join-Path $root 'app' 'test')

            Invoke-NamespaceMap -SymbolDir $script:Symbols -MapPath $mapPath -AppDir (Join-Path $root 'app') -RootNamespace 'Contoso.Sales' -ExcludeDirs @((Join-Path $root 'app' 'test')) | Out-Null

            Get-TreeSnapshot -Root (Join-Path $root 'app' 'test') | Should -BeExactly $before
            Test-Path -LiteralPath (Join-Path $root 'app' '.alpackages' 'P.al') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $root 'app' 'readme.md') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $root 'app' 'src' 'One.Codeunit.al') | Should -BeTrue
        }
    }
}
