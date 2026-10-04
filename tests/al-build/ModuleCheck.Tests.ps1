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

    Context 'rule 2' {
        BeforeAll {
            # The module Contoso.Sales.Posting with an .Internal folder, and a sibling module that can be made to reach in.
            function New-InternalModuleFiles {
                param([hashtable]$Extra = @{})
                $files = @{
                    'app/src/Posting/Post.Codeunit.al'           = New-AlFile 'Contoso.Sales.Posting'
                    'app/src/Posting/Internal/Rules.Codeunit.al' = New-AlFile 'Contoso.Sales.Posting.Internal' 'codeunit 50101 Rules'
                }
                foreach ($key in $Extra.Keys) { $files[$key] = $Extra[$key] }
                return $files
            }
            function New-ReachingFile {
                param([string]$Namespace, [string]$Using = '', [string]$Body = '', [string]$Object = 'codeunit 50102 Ship')
                $usingBlock = if ($Using) { "$Using`n`n" } else { '' }
                return "namespace $Namespace;`n`n${usingBlock}${Object}`n{`n$Body}`n"
            }
        }

        It 'fails a using of another module''s .Internal, naming the file, the line, and the module''s interface folder' {
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Shipping/Ship.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Shipping' 'using Contoso.Sales.Posting.Internal;'
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $violation = $result.Violations[0]
            $violation.Rule | Should -Be 2
            $violation.File | Should -Be 'app/src/Shipping/Ship.Codeunit.al'
            $violation.Line | Should -Be 3
            $violation.Message | Should -Match ([regex]::Escape('Contoso.Sales.Posting.Internal'))
            $violation.Message | Should -Match ([regex]::Escape('app/src/Posting'))
        }

        It 'fails a qualified name into another module''s .Internal' {
            $body = "    procedure Run()`n    var`n        Rules: Codeunit Contoso.Sales.Posting.Internal.Rules;`n    begin`n    end;`n"
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Shipping/Ship.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Shipping' -Body $body
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'app/src/Shipping/Ship.Codeunit.al'
            $result.Violations[0].Line | Should -Be 7
            $result.Violations[0].Message | Should -Match ([regex]::Escape('app/src/Posting'))
        }

        It 'fails a qualified name written with quoted identifiers' {
            $body = "    procedure Run()`n    var`n        Rules: Codeunit Contoso.Sales.`"Posting`".Internal.`"Rules Helper`";`n    begin`n    end;`n"
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Shipping/Ship.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Shipping' -Body $body
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].Line | Should -Be 7
        }

        It 'fails a test app that reaches into a module''s .Internal' {
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'test/src/Posting/PostTest.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Test.Posting' 'using Contoso.Sales.Posting.Internal;' -Object 'codeunit 50200 PostTest'
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'test/src/Posting/PostTest.Codeunit.al'
            $result.Violations[0].Line | Should -Be 3
            $result.Violations[0].Message | Should -Match ([regex]::Escape('app/src/Posting'))
        }

        It 'passes the module''s own root namespace, its .Internal, and anything below .Internal' {
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Posting/Post.Codeunit.al'               = New-ReachingFile 'Contoso.Sales.Posting' 'using Contoso.Sales.Posting.Internal;' -Object 'codeunit 50100 Posting'
                'app/src/Posting/Internal/Rules.Codeunit.al'     = New-ReachingFile 'Contoso.Sales.Posting.Internal' 'using Contoso.Sales.Posting.Internal.Deep;' -Object 'codeunit 50101 Rules'
                'app/src/Posting/Internal/Deep/Deep.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Posting.Internal.Deep' 'using Contoso.Sales.Posting.Internal;' -Object 'codeunit 50103 Deep'
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
        }

        It 'does not count the namespace declaration of a file inside .Internal as a reference' {
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles)

            @((Invoke-FixtureCheck -Root $root).Violations).Count | Should -Be 0
        }

        It 'passes a reference that appears only in a comment or a string' {
            $body = "    // see Contoso.Sales.Posting.Internal.Rules`n    /* using Contoso.Sales.Posting.Internal; */`n    procedure Run()`n    begin`n        Message('Contoso.Sales.Posting.Internal.Rules // not a comment');`n    end;`n"
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Shipping/Ship.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Shipping' -Body $body
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 0
        }

        It 'reports a reference that follows a string holding a comment marker' {
            $body = "    procedure Run()`n    begin`n        Message('http://example.com'); Rules.Run(Contoso.Sales.Posting.Internal.Rules);`n    end;`n"
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Shipping/Ship.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Shipping' -Body $body
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].Line | Should -Be 7
        }

        It 'ignores a dotted name that is not a namespace of the repository' {
            $body = "    procedure Run()`n    begin`n        Rec.Internal.Run();`n    end;`n"
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Shipping/Ship.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Shipping' -Body $body
            })

            @((Invoke-FixtureCheck -Root $root).Violations).Count | Should -Be 0
        }

        It 'fails a parent namespace and passes a namespace that only shares the Internal prefix' {
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Root.Codeunit.al'                        = New-ReachingFile 'Contoso.Sales' 'using Contoso.Sales.Posting.Internal;' -Object 'codeunit 50104 Root'
                'app/src/Posting/InternalAudit/Audit.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Posting.InternalAudit' 'using Contoso.Sales.Posting.InternalAudit;' -Object 'codeunit 50105 Audit'
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'app/src/Root.Codeunit.al'
        }

        It 'fails a file in a sub-namespace of the module, which is not the module''s root or its .Internal' {
            $root = New-ModuleFixtureRepo (New-InternalModuleFiles @{
                'app/src/Posting/Validation/Check.Codeunit.al' = New-ReachingFile 'Contoso.Sales.Posting.Validation' 'using Contoso.Sales.Posting.Internal;' -Object 'codeunit 50106 Check'
            })

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].File | Should -Be 'app/src/Posting/Validation/Check.Codeunit.al'
        }

        It 'matches a module whose namespace has a quoted segment with a space' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Posting/Internal/Rules.Codeunit.al' = New-AlFile 'Contoso.Sales."Posting Area".Internal' 'codeunit 50101 Rules'
                'app/src/Shipping/Ship.Codeunit.al'          = New-ReachingFile 'Contoso.Sales.Shipping' 'using Contoso.Sales."Posting Area".Internal;'
            }

            $result = Invoke-FixtureCheck -Root $root

            $rule2 = @($result.Violations | Where-Object { $_.Rule -eq 2 })
            $rule2.Count | Should -Be 1
            $rule2[0].File | Should -Be 'app/src/Shipping/Ship.Codeunit.al'
        }

        It 'names the app source root as the interface folder of the root namespace''s module' {
            $root = New-ModuleFixtureRepo @{
                'app/src/Internal/Rules.Codeunit.al' = New-AlFile 'Contoso.Sales.Internal' 'codeunit 50101 Rules'
                'app/src/Posting/Post.Codeunit.al'   = New-ReachingFile 'Contoso.Sales.Posting' 'using Contoso.Sales.Internal;' -Object 'codeunit 50100 Posting'
            }

            $result = Invoke-FixtureCheck -Root $root

            @($result.Violations).Count | Should -Be 1
            $result.Violations[0].Message | Should -Match 'app/src(?![/\w])'
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
