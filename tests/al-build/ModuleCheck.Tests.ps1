#Requires -Version 7.2

# Drives the module check through its single entry, Invoke-ModuleCheck, on small
# git repositories of AL files built in TestDrive. Each rule owns a Context.

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'module-check.psm1') -Force -DisableNameChecking

    # Writes the files (repo-relative path -> content) into a fresh git repository,
    # commits them as the base, and returns the repository root.
    function New-ModuleFixtureRepo {
        param([Parameter(Mandatory)][hashtable]$Files)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        foreach ($relative in $Files.Keys) {
            $path = Join-Path $root $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $Files[$relative]
        }
        & git -C $root init --quiet 2>&1 | Out-Null
        & git -C $root add -A 2>&1 | Out-Null
        & git -C $root -c user.name=fixture -c user.email=fixture@example.com commit --quiet -m base 2>&1 | Out-Null
        return $root
    }

    function Invoke-FixtureCheck {
        param(
            [Parameter(Mandatory)][string]$Root,
            [string]$RootNamespace = 'Contoso.Sales',
            [string]$AppDir = 'app',
            [string[]]$TestAppDirs = @('test')
        )
        Invoke-ModuleCheck -RepoRoot $Root -BaseRef 'HEAD' -RootNamespace $RootNamespace `
            -AppDir (Join-Path $Root $AppDir) -TestAppDirs @($TestAppDirs | ForEach-Object { Join-Path $Root $_ })
    }

    function New-AlFile {
        param([string]$Namespace, [string]$Object = 'codeunit 50100 Posting')
        $header = if ($Namespace) { "namespace $Namespace;`n`n" } else { '' }
        return "${header}${Object}`n{`n}`n"
    }
}

Describe 'Invoke-ModuleCheck' {
    Context 'rule 1' {
        It 'passes files whose namespace is the root plus their folder path below src' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al'          = New-AlFile 'Contoso.Sales.Posting'
                'app/src/Posting/Internal/Rules.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting.Internal' 'codeunit 50101 Rules'
                'app/src/Root.Codeunit.al'                  = New-AlFile 'Contoso.Sales' 'codeunit 50102 Root'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
            @($result.Warnings).Count | Should -Be 0
        }

        It 'fails a file with no namespace, naming the file, the declaration line, and the namespace to add' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = "// header comment`ncodeunit 50100 Posting`n{`n}`n"
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $violation = $result.Violations[0]
            $violation.File | Should -Be 'app/src/Posting/Post.Codeunit.al'
            $violation.Line | Should -Be 2
            $violation.Message | Should -Match ([regex]::Escape('namespace Contoso.Sales.Posting;'))
        }

        It 'fails a file whose folder path disagrees with its namespace, naming both fixes' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = New-AlFile 'Contoso.Sales.Shipping'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $violation = $result.Violations[0]
            $violation.File | Should -Be 'app/src/Posting/Post.Codeunit.al'
            $violation.Line | Should -Be 1
            $violation.Message | Should -Match ([regex]::Escape('Contoso.Sales.Posting'))
            $violation.Message | Should -Match ([regex]::Escape('app/src/Shipping'))
        }

        It 'treats the app folder as the source root when the app has no src folder' {
            $root = New-ModuleFixtureRepo @{
                'app/Posting/Post.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting'
                'app/Bad.Codeunit.al'          = New-AlFile 'Contoso.Sales.Posting' 'codeunit 50101 Bad'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'app/Bad.Codeunit.al'
        }

        It 'expects test apps under the root namespace plus .Test' {
            $root = New-ModuleFixtureRepo @{
                'test/src/Posting/PostTest.Codeunit.al'  = New-AlFile 'Contoso.Sales.Test.Posting' 'codeunit 50200 PostTest'
                'test/src/Shipping/ShipTest.Codeunit.al' = New-AlFile 'Contoso.Sales.Shipping' 'codeunit 50201 ShipTest'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $violation = $result.Violations[0]
            $violation.File | Should -Be 'test/src/Shipping/ShipTest.Codeunit.al'
            $violation.Message | Should -Match ([regex]::Escape('Contoso.Sales.Test.Shipping'))
        }

        It 'fails a file that sits outside the src folder of an app that has one' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting'
                'app/Stray.Codeunit.al'            = New-AlFile 'Contoso.Sales' 'codeunit 50101 Stray'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'app/Stray.Codeunit.al'
            $result.Violations[0].Message | Should -Match ([regex]::Escape('app/src'))
        }

        It 'ignores a namespace mentioned in a comment and reads the real declaration' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = "// namespace Wrong.Place;`n/* namespace Also.Wrong; */`nnamespace Contoso.Sales.Posting;`ncodeunit 50100 Posting`n{`n}`n"
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
        }

        It 'reads the namespace after a line comment that mentions the start of a block comment' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = "// see /* the design notes`nnamespace Contoso.Sales.Posting;`ncodeunit 50100 Posting`n{`n}`n"
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
        }

        It 'fails a folder that is not a single AL identifier and suggests no namespace built from it' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Sales Order/Post.Codeunit.al' = New-AlFile 'Contoso.Sales.Order'
                'app/src/Sales.Order/Ship.Codeunit.al' = New-AlFile 'Contoso.Sales.Order' 'codeunit 50101 Ship'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 2
            $byFile = @{}
            $result.Violations | ForEach-Object { $byFile[$_.File] = $_ }
            $byFile['app/src/Sales Order/Post.Codeunit.al'].Message | Should -Match ([regex]::Escape("Folder 'Sales Order'"))
            $byFile['app/src/Sales.Order/Ship.Codeunit.al'].Message | Should -Match ([regex]::Escape("Folder 'Sales.Order'"))
            $result.Violations | ForEach-Object { $_.Message | Should -Not -Match 'namespace Contoso' }
        }

        It 'compares namespaces and folders without regard to case and ignores quoted identifiers' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = New-AlFile 'contoso.sales."Posting"'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
        }

        It 'skips hidden folders such as .alpackages' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al'  = New-AlFile 'Contoso.Sales.Posting'
                'app/.alpackages/Dump.Codeunit.al' = New-AlFile ''
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
        }

        It 'reports one violation naming moduleGate.rootNamespace when the root namespace is empty' {
            $root = New-ModuleFixtureRepo @{
                'al-build.json'                    = "{`n  `"moduleGate`": {`n    `"enabled`": true,`n    `"rootNamespace`": `"`"`n  }`n}`n"
                'app/src/Posting/Post.Codeunit.al' = New-AlFile ''
            }

            $result = Invoke-FixtureCheck -Root $root -RootNamespace ''

            @($result.Violations).Count | Should -Be 1
            $violation = $result.Violations[0]
            $violation.File | Should -Be 'al-build.json'
            $violation.Line | Should -Be 4
            $violation.Message | Should -Match ([regex]::Escape('moduleGate.rootNamespace'))
        }

        It 'checks every test app and leaves a test app nested in the main app folder to its own root' {
            $root = New-ModuleFixtureRepo @{
                'src/Posting/Post.Codeunit.al'       = New-AlFile 'Contoso.Sales.Posting'
                'test/src/Posting/T.Codeunit.al'     = New-AlFile 'Contoso.Sales.Test.Posting' 'codeunit 50200 T'
                'test2/Bad.Codeunit.al'              = New-AlFile ''
            }

            $result = Invoke-FixtureCheck -Root $root -AppDir '.' -TestAppDirs @('test', 'test2')

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'test2/Bad.Codeunit.al'
        }

        It 'reports no skipped rules while the base resolves' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Post.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting'
            }

            @((Invoke-FixtureCheck -Root $root).SkippedRules).Count | Should -Be 0
        }
    }
}

Describe 'ConvertTo-ModuleGateBlock' {
    It 'carries only the flag when the gate is off' {
        $block = ConvertTo-ModuleGateBlock -Enabled $false -Result $null

        $block.enabled | Should -BeFalse
        $block.Keys | Should -Not -Contain 'violations'
    }

    It 'carries violations, warnings, and skipped rules when the gate is on' {
        $result = [pscustomobject]@{
            Violations   = @([pscustomobject]@{ Rule = 1; File = 'app/A.al'; Line = 3; Message = 'Add a namespace.' })
            Warnings     = @()
            SkippedRules = @()
        }

        $block = ConvertTo-ModuleGateBlock -Enabled $true -Result $result

        $block.enabled | Should -BeTrue
        @($block.violations).Count | Should -Be 1
        $block.violations[0].file | Should -Be 'app/A.al'
        $block.violations[0].line | Should -Be 3
        $block.violations[0].rule | Should -Be 1
        @($block.warnings).Count | Should -Be 0
        @($block.skippedRules).Count | Should -Be 0
    }
}

Describe 'Invoke-ModuleCheck rule 3' {
    BeforeAll {
        $script:PostingFile = 'app/src/Posting/Post.Codeunit.al'

        function Invoke-FixtureGit {
            param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$Arguments)
            $output = & git -C $Root -c user.name=fixture -c user.email=fixture@example.com @Arguments 2>&1
            if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
        }

        function Write-FixtureFile {
            param([string]$Root, [string]$Relative, $Content)
            $path = Join-Path $Root $Relative
            if ($null -eq $Content) {
                Remove-Item -LiteralPath $path -Force
                return
            }
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $Content
        }

        # A base commit on main, then the change on a feature branch: committed by
        # default, left in the working tree with -Uncommitted. A $null value deletes.
        function New-Rule3Repo {
            param([Parameter(Mandatory)][hashtable]$Base, [hashtable]$Change = @{}, [switch]$Uncommitted)

            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            Invoke-FixtureGit $root @('init', '--quiet', '-b', 'main')
            foreach ($relative in $Base.Keys) { Write-FixtureFile $root $relative $Base[$relative] }
            Invoke-FixtureGit $root @('add', '-A')
            Invoke-FixtureGit $root @('commit', '--quiet', '-m', 'base')
            if ($Change.Count -gt 0) {
                Invoke-FixtureGit $root @('checkout', '--quiet', '-b', 'feature')
                foreach ($relative in $Change.Keys) { Write-FixtureFile $root $relative $Change[$relative] }
                if (-not $Uncommitted) {
                    Invoke-FixtureGit $root @('add', '-A')
                    Invoke-FixtureGit $root @('commit', '--quiet', '-m', 'change')
                }
            }
            return $root
        }

        function Invoke-Rule3Check {
            param([Parameter(Mandatory)][string]$Root, [AllowEmptyString()][string]$BaseRef = 'main')
            Invoke-ModuleCheck -RepoRoot $Root -BaseRef $BaseRef -RootNamespace 'Contoso.Sales' `
                -AppDir (Join-Path $Root 'app') -TestAppDirs @(Join-Path $Root 'test')
        }

        function Get-Rule3 {
            param($Items)
            @($Items | Where-Object { $_.Rule -eq 3 })
        }

        function Get-LineOf {
            param([string]$Root, [string]$Relative, [string]$Pattern)
            (Select-String -LiteralPath (Join-Path $Root $Relative) -Pattern $Pattern -SimpleMatch | Select-Object -First 1).LineNumber
        }

        # The open-code codeunit every case changes: a public procedure, a local
        # helper, and an event subscriber.
        function New-PostingAl {
            param(
                [string]$Namespace = 'Contoso.Sales.Posting',
                [string]$Header = 'codeunit 50100 Posting',
                [string]$PostSignature = 'procedure Post()',
                [string]$PostBody = "Message('posted');",
                [string]$HelperSignature = 'local procedure Helper(Amount: Decimal)',
                [string]$Extra = ''
            )
            $namespaceLine = if ($Namespace) { "namespace $Namespace;`n`n" } else { '' }
            return @"
${namespaceLine}$Header
{
    $PostSignature
    begin
        $PostBody
    end;

    $HelperSignature
    begin
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertSalesHeader()
    begin
    end;
$Extra}
"@
        }

        function Get-BaseFiles {
            @{
                $script:PostingFile                          = New-PostingAl
                'app/src/Pricing/Price.Codeunit.al'          = New-AlFile 'Contoso.Sales.Pricing' 'codeunit 50110 Pricing'
                'app/src/Pricing/Internal/Rules.Codeunit.al' = New-AlFile 'Contoso.Sales.Pricing.Internal' 'codeunit 50111 "Pricing Rules"'
                'test/src/Posting/PostTest.Codeunit.al'      = New-AlFile 'Contoso.Sales.Test.Posting' 'codeunit 50200 PostTest'
            }
        }
    }

    Context 'what fails' {
        It 'fails a new object in open code, naming the file, the line, and the move' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Posting/Extra.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting' 'codeunit 50101 Extra'
            }

            $result = Invoke-Rule3Check -Root $root

            $found = Get-Rule3 $result.Violations
            $found.Count | Should -Be 1
            $found[0].File | Should -Be 'app/src/Posting/Extra.Codeunit.al'
            $found[0].Line | Should -Be 3
            $found[0].Message | Should -Match 'codeunit 50101 Extra'
            $found[0].Message | Should -Match 'Place the new code in a module'
            @($result.SkippedRules).Count | Should -Be 0
        }

        It 'fails a new object in a file that declares no namespace' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/Loose.Codeunit.al' = New-AlFile '' 'codeunit 50101 Loose'
            }

            (Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).File | Should -Be 'app/Loose.Codeunit.al'
        }

        It 'fails a new object that has no ID, such as an interface' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Posting/IPoster.Interface.al' = New-AlFile 'Contoso.Sales.Posting' 'interface "IPoster"'
            }

            (Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 1
        }

        It 'fails a new public procedure on an existing object, at the procedure line' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -Extra "`n    procedure Ship()`n    begin`n    end;`n"
            }

            $found = Get-Rule3 (Invoke-Rule3Check -Root $root).Violations

            $found.Count | Should -Be 1
            $found[0].File | Should -Be $script:PostingFile
            $found[0].Line | Should -Be (Get-LineOf $root $script:PostingFile 'procedure Ship()')
            $found[0].Message | Should -Match "'Ship'"
            $found[0].Message | Should -Match 'Place the new code in a module'
        }

        It 'fails a new internal or protected procedure, since a procedure is callable unless local' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -Extra "`n    internal procedure Ship()`n    begin`n    end;`n`n    protected procedure Bill()`n    begin`n    end;`n"
            }

            (Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 2
        }

        It 'fails an added overload and names the overload line' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -Extra "`n    procedure Post(Reason: Text)`n    begin`n    end;`n"
            }

            $found = Get-Rule3 (Invoke-Rule3Check -Root $root).Violations

            $found.Count | Should -Be 1
            $found[0].Line | Should -Be (Get-LineOf $root $script:PostingFile 'procedure Post(Reason: Text)')
        }

        It 'fails a new event subscriber even though it is local' {
            $subscriber = "`n    [EventSubscriber(ObjectType::Codeunit, Codeunit::`"Sales-Post`", 'OnAfterPostSalesDoc', '', false, false)]`n    local procedure OnAfterPostSalesDoc()`n    begin`n    end;`n"
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -Extra $subscriber
            }

            $result = Invoke-Rule3Check -Root $root

            $found = Get-Rule3 $result.Violations
            $found.Count | Should -Be 1
            $found[0].Message | Should -Match 'event subscriber'
            $found[0].Line | Should -Be (Get-LineOf $root $script:PostingFile 'local procedure OnAfterPostSalesDoc')
            @(Get-Rule3 $result.Warnings).Count | Should -Be 0
        }

        It 'fails an event subscriber attribute added to an existing procedure' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = (New-PostingAl) -replace '    local procedure Helper', "    [EventSubscriber(ObjectType::Table, Database::`"Sales Line`", 'OnAfterInsertEvent', '', false, false)]`n    local procedure Helper"
            }

            $found = Get-Rule3 (Invoke-Rule3Check -Root $root).Violations

            $found.Count | Should -Be 1
            $found[0].Message | Should -Match 'event subscriber'
        }

        It 'fails an existing local procedure made callable' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -HelperSignature 'procedure Helper(Amount: Decimal)'
            }

            $found = Get-Rule3 (Invoke-Rule3Check -Root $root).Violations

            $found.Count | Should -Be 1
            $found[0].Line | Should -Be (Get-LineOf $root $script:PostingFile 'procedure Helper')
            $found[0].Message | Should -Match "'Helper'"
            $found[0].Message | Should -Match 'local'
            $found[0].Message | Should -Match 'Place the new code in a module'
        }

        It 'treats a test app as open code too' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'test/src/Posting/ShipTest.Codeunit.al' = New-AlFile 'Contoso.Sales.Test.Posting' 'codeunit 50201 ShipTest'
            }

            $found = Get-Rule3 (Invoke-Rule3Check -Root $root).Violations

            $found.Count | Should -Be 1
            $found[0].File | Should -Be 'test/src/Posting/ShipTest.Codeunit.al'
        }

        It 'sees a change that is still in the working tree' {
            $root = New-Rule3Repo -Uncommitted -Base (Get-BaseFiles) -Change @{
                'app/src/Posting/Extra.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting' 'codeunit 50101 Extra'
            }

            (Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 1
        }
    }

    Context 'what warns' {
        It 'warns on a new local procedure and does not fail it' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -Extra "`n    local procedure Round(Amount: Decimal)`n    begin`n    end;`n"
            }

            $result = Invoke-Rule3Check -Root $root

            @(Get-Rule3 $result.Violations).Count | Should -Be 0
            $found = Get-Rule3 $result.Warnings
            $found.Count | Should -Be 1
            $found[0].File | Should -Be $script:PostingFile
            $found[0].Line | Should -Be (Get-LineOf $root $script:PostingFile 'local procedure Round')
            $found[0].Message | Should -Match "'Round'"
            $found[0].Message | Should -Match 'module'
        }
    }

    Context 'what passes' {
        It 'passes silently when only the inside of an existing procedure changes' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -PostBody "Message('posted');`n        Message('twice');"
            }

            $result = Invoke-Rule3Check -Root $root

            @(Get-Rule3 $result.Violations).Count | Should -Be 0
            @(Get-Rule3 $result.Warnings).Count | Should -Be 0
            @($result.SkippedRules).Count | Should -Be 0
        }

        It 'passes a changed parameter list as the same procedure' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -PostSignature 'procedure Post(Reason: Text)' -HelperSignature 'local procedure Helper(Amount: Decimal; Currency: Code[10])'
            }

            $result = Invoke-Rule3Check -Root $root

            @(Get-Rule3 $result.Violations).Count | Should -Be 0
            @(Get-Rule3 $result.Warnings).Count | Should -Be 0
        }

        It 'passes a moved and renamed object, identified by type and ID' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile                 = $null
                'app/src/Shipping/Ship.Codeunit.al' = New-PostingAl -Namespace 'Contoso.Sales.Shipping' -Header 'codeunit 50100 "Ship Orders"'
            }

            $result = Invoke-Rule3Check -Root $root

            @(Get-Rule3 $result.Violations).Count | Should -Be 0
            @(Get-Rule3 $result.Warnings).Count | Should -Be 0
        }

        It 'passes an object that moves to another file with its procedures' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile                  = $null
                'app/src/Posting/Poster.Codeunit.al' = New-PostingAl
            }

            @(Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 0
        }

        It 'exempts new code in a module root and in its .Internal' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Pricing/Quote.Codeunit.al'          = New-AlFile 'Contoso.Sales.Pricing' 'codeunit 50112 Quote'
                'app/src/Pricing/Internal/Round.Codeunit.al' = New-AlFile 'Contoso.Sales.Pricing.Internal' 'codeunit 50113 Round'
                'app/src/Pricing/Price.Codeunit.al'          = "namespace Contoso.Sales.Pricing;`n`ncodeunit 50110 Pricing`n{`n    procedure Price()`n    begin`n    end;`n`n    local procedure Round()`n    begin`n    end;`n}`n"
            }

            $result = Invoke-Rule3Check -Root $root

            @(Get-Rule3 $result.Violations).Count | Should -Be 0
            @(Get-Rule3 $result.Warnings).Count | Should -Be 0
        }

        It 'treats a namespace below .Internal as inside the module' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Pricing/Internal/Deep/Round.Codeunit.al' = New-AlFile 'Contoso.Sales.Pricing.Internal.Deep' 'codeunit 50113 Round'
            }

            @(Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 0
        }

        It 'treats a child of a module root as open code unless it is a module itself' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Pricing/Tiers/Tier.Codeunit.al' = New-AlFile 'Contoso.Sales.Pricing.Tiers' 'codeunit 50114 Tier'
            }

            @(Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 1
        }

        It 'reads only real declarations, not procedures in comments or strings' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                $script:PostingFile = New-PostingAl -PostBody "// procedure Ship()`n        /* procedure Bill() */`n        Message('procedure Cancel()');"
            }

            $result = Invoke-Rule3Check -Root $root

            @(Get-Rule3 $result.Violations).Count | Should -Be 0
            @(Get-Rule3 $result.Warnings).Count | Should -Be 0
        }

        It 'matches quoted procedure names by their text' {
            $base = Get-BaseFiles
            $base[$script:PostingFile] = New-PostingAl -Extra "`n    procedure `"Post Order`"()`n    begin`n    end;`n"
            $root = New-Rule3Repo -Base $base -Change @{
                $script:PostingFile = New-PostingAl -PostBody "Message('changed');" -Extra "`n    procedure `"Post Order`"()`n    begin`n    end;`n"
            }

            @(Get-Rule3 (Invoke-Rule3Check -Root $root).Violations).Count | Should -Be 0
        }

        It 'leaves the working tree and the index as it found them' {
            $root = New-Rule3Repo -Uncommitted -Base (Get-BaseFiles) -Change @{
                'app/src/Posting/Extra.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting' 'codeunit 50101 Extra'
            }
            $before = (& git -C $root status --porcelain) -join "`n"
            $head = & git -C $root rev-parse HEAD

            Invoke-Rule3Check -Root $root | Out-Null

            ((& git -C $root status --porcelain) -join "`n") | Should -Be $before
            (& git -C $root rev-parse HEAD) | Should -Be $head
        }
    }

    Context 'when no base resolves' {
        It 'reports rule 3 as skipped, with the reason, and never as passed, when there is no base ref' {
            $root = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Posting/Extra.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting' 'codeunit 50101 Extra'
            }

            $result = Invoke-Rule3Check -Root $root -BaseRef ''

            @($result.SkippedRules).Count | Should -Be 1
            $result.SkippedRules[0] | Should -Match '^Rule 3 skipped: '
            $result.SkippedRules[0] | Should -Match 'default branch'
            @(Get-Rule3 $result.Violations).Count | Should -Be 0
        }

        It 'reports rule 3 as skipped when the base ref names nothing' {
            $root = New-Rule3Repo -Base (Get-BaseFiles)

            $result = Invoke-Rule3Check -Root $root -BaseRef 'origin/main'

            @($result.SkippedRules).Count | Should -Be 1
            $result.SkippedRules[0] | Should -Match ([regex]::Escape('origin/main'))
        }

        It 'reports rule 3 as skipped when HEAD and the base share no history' {
            $root = New-Rule3Repo -Base (Get-BaseFiles)
            Invoke-FixtureGit $root @('checkout', '--quiet', '--orphan', 'unrelated')
            Invoke-FixtureGit $root @('commit', '--quiet', '--allow-empty', '-m', 'unrelated')

            $result = Invoke-Rule3Check -Root $root

            @($result.SkippedRules).Count | Should -Be 1
            $result.SkippedRules[0] | Should -Match 'merge base'
        }

        It 'says so when a shallow history is the reason' {
            $origin = New-Rule3Repo -Base (Get-BaseFiles) -Change @{
                'app/src/Posting/Extra.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting' 'codeunit 50101 Extra'
            }
            $url = "file:///$($origin -replace '\\', '/')"
            $clone = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            & git clone --quiet --depth 1 --branch feature $url $clone 2>&1 | Out-Null
            & git -C $clone fetch --quiet --depth 1 origin main:refs/remotes/origin/main 2>&1 | Out-Null

            $result = Invoke-Rule3Check -Root $clone -BaseRef 'origin/main'

            @($result.SkippedRules).Count | Should -Be 1
            $result.SkippedRules[0] | Should -Match 'shallow'
        }
    }
}

Describe 'Get-DefaultBranchRef' {
    It 'returns the remote default branch a clone points at' {
        $origin = New-ModuleFixtureRepo @{ 'app/A.al' = 'x' }
        $branch = (& git -C $origin symbolic-ref --short HEAD)
        $clone = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        & git clone --quiet "file:///$($origin -replace '\\', '/')" $clone 2>&1 | Out-Null

        Get-DefaultBranchRef -RepoRoot $clone | Should -Be "origin/$branch"
    }

    It 'returns nothing when the repository has no remote default branch' {
        $root = New-ModuleFixtureRepo @{ 'app/A.al' = 'x' }

        Get-DefaultBranchRef -RepoRoot $root | Should -BeNullOrEmpty
    }

    It 'returns nothing outside a git repository' {
        Get-DefaultBranchRef -RepoRoot $TestDrive | Should -BeNullOrEmpty
    }
}
