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

        It 'reports no skipped rules while only rule 1 exists' {
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
