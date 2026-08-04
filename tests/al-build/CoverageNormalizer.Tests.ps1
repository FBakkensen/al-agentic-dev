#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:ModulePath = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts' 'coverage-normalizer.psm1'
    $script:LiveFixtureRoot = Join-Path $PSScriptRoot 'fixtures' 'code-coverage-live'
    Import-Module $script:ModulePath -Force -DisableNameChecking

    function Set-FileContent {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$Content
        )

        $directory = Split-Path -Path $Path -Parent
        if ($directory) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
    }

    function New-AppJson {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$Id,

            [Parameter(Mandatory)]
            [string]$Name,

            [int]$From = 50000,

            [int]$To = 59999
        )

        [ordered]@{
            id = $Id
            name = $Name
            publisher = 'Coverage Normalizer Tests'
            version = '1.0.0.0'
            platform = '1.0.0.0'
            application = '1.0.0.0'
            runtime = '15.0'
            idRanges = @(
                [ordered]@{
                    from = $From
                    to = $To
                }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8
    }

    function New-CoverageRow {
        param(
            [Parameter(Mandatory)]
            [int]$ObjectTypeCode,

            [Parameter(Mandatory)]
            [string]$ObjectTypeName,

            [Parameter(Mandatory)]
            [int]$ObjectId,

            [Parameter(Mandatory)]
            [int]$LineNumber,

            [Parameter(Mandatory)]
            [int]$LineTypeCode,

            [Parameter(Mandatory)]
            [string]$LineTypeName,

            [Parameter(Mandatory)]
            [int]$CoverageStatusCode,

            [Parameter(Mandatory)]
            [string]$CoverageStatusName,

            [Parameter(Mandatory)]
            [int]$HitCount,

            [Parameter(Mandatory)]
            [string]$SourceLine
        )

        [ordered]@{
            ObjectTypeCode = $ObjectTypeCode
            ObjectTypeName = $ObjectTypeName
            ObjectId = $ObjectId
            LineNumber = $LineNumber
            LineTypeCode = $LineTypeCode
            LineTypeName = $LineTypeName
            CoverageStatusCode = $CoverageStatusCode
            CoverageStatusName = $CoverageStatusName
            HitCount = $HitCount
            SourceLine = $SourceLine
        }
    }

    function New-CoveragePayloadXml {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Rows
        )

        $builder = [System.Text.StringBuilder]::new()
        $null = $builder.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
        $null = $builder.AppendLine('<CodeCoverage SchemaVersion="1">')
        foreach ($row in $Rows) {
            $null = $builder.AppendLine('  <CoverageLine>')
            foreach ($fieldName in @(
                'ObjectTypeCode',
                'ObjectTypeName',
                'ObjectId',
                'LineNumber',
                'LineTypeCode',
                'LineTypeName',
                'CoverageStatusCode',
                'CoverageStatusName',
                'HitCount',
                'SourceLine'
            )) {
                $value = [System.Security.SecurityElement]::Escape([string]$row[$fieldName])
                $null = $builder.AppendLine("    <$fieldName>$value</$fieldName>")
            }
            $null = $builder.AppendLine('  </CoverageLine>')
        }
        $null = $builder.AppendLine('</CodeCoverage>')
        $builder.ToString()
    }

    function New-RawCollection {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$TestApp,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Payloads
        )

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        $manifestPayloads = [System.Collections.Generic.List[object]]::new()

        for ($index = 0; $index -lt $Payloads.Count; $index++) {
            $payload = $Payloads[$index]
            $order = $index + 1
            $fileName = 'payload-{0:d4}.xml' -f $order
            New-CoveragePayloadXml -Rows $payload.Rows |
                Set-Content -LiteralPath (Join-Path $Path $fileName) -Encoding utf8
            $manifestPayloads.Add([ordered]@{
                order = $order
                testCodeunitId = [int]$payload.TestCodeunitId
                testMethod = [string]$payload.TestMethod
                file = $fileName
            })
        }

        [ordered]@{
            schemaVersion = 1
            testApp = $TestApp
            junitTestCount = [Math]::Max(1, $Payloads.Count)
            payloadCount = $Payloads.Count
            drainResponseCount = $Payloads.Count + 2
            terminalDoneCount = 2
            doneValue = 'Done.'
            payloads = @($manifestPayloads)
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (
            Join-Path $Path 'manifest.json'
        ) -Encoding utf8
    }

    function New-SyntheticWorkspace {
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [hashtable]$MainFiles,

            [Parameter(Mandatory)]
            [hashtable]$TestFiles,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Payloads,

            [string]$CollectionName = 'synthetic',

            [string]$TestAppDirectoryName = $CollectionName,

            [string]$ManifestTestAppName = $TestAppDirectoryName
        )

        $root = Join-Path $TestDrive $Name
        $mainPath = Join-Path $root 'main'
        $testPath = Join-Path $root $TestAppDirectoryName
        $rawRoot = Join-Path $root 'raw'
        $collectionPath = Join-Path $rawRoot $CollectionName
        $outputPath = Join-Path $root '.output' 'TestResults' 'coverage' 'per-test.jsonl'

        New-Item -ItemType Directory -Path $mainPath, $testPath, $rawRoot -Force | Out-Null
        New-AppJson -Path (Join-Path $mainPath 'app.json') `
            -Id '11111111-1111-1111-1111-111111111111' `
            -Name 'Synthetic Main'
        New-AppJson -Path (Join-Path $testPath 'app.json') `
            -Id '22222222-2222-2222-2222-222222222222' `
            -Name 'Synthetic Test' `
            -From 60000 -To 69999

        foreach ($entry in $MainFiles.GetEnumerator()) {
            Set-FileContent -Path (Join-Path $mainPath $entry.Key) -Content $entry.Value
        }
        foreach ($entry in $TestFiles.GetEnumerator()) {
            Set-FileContent -Path (Join-Path $testPath $entry.Key) -Content $entry.Value
        }

        New-RawCollection -Path $collectionPath -TestApp $ManifestTestAppName -Payloads $Payloads

        [pscustomobject]@{
            RepoRoot = $root
            MainAppPath = $mainPath
            TestAppPath = $testPath
            RawRootPath = $rawRoot
            CollectionPath = $collectionPath
            OutputPath = $outputPath
        }
    }

    function New-MixedMainSource {
@'
namespace Test.Normalizer;

/* leading block comment
   still comment */
codeunit 50100 "Quoted Utility"
{
    procedure Run(): Integer
    begin
        exit(1);
    end;
}

// declaration separator
pageextension 50101 CustomerCardExt extends "Customer Card"
{
    trigger OnOpenPage()
    begin
        Message('Opened');
    end;
}
'@
    }

    function New-SyntheticTestSource {
        param([string]$CodeunitName = 'Normalizer Tests')
@"
namespace Test.Normalizer;

codeunit 60100 "$CodeunitName"
{
    Subtype = Test;

    [Test]
    procedure CoversMixedObjects()
    begin
    end;
}
"@
    }

    function New-LongLineMainSource {
        param(
            [Parameter(Mandatory)]
            [string]$PayloadText
        )
@"
namespace Test.Normalizer;

codeunit 50110 "Long Line Utility"
{
    procedure LongLine()
    begin
        Message('$PayloadText');
    end;
}
"@
    }

    function Get-JsonLines {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        @(
            Get-Content -LiteralPath $Path |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    function New-MergedLiveWorkspace {
        $root = Join-Path $TestDrive 'merged-live'
        $mainPath = Join-Path $root 'main'
        $testPath = Join-Path $root 'live-merged'
        $rawRoot = Join-Path $root 'raw'
        $collectionPath = Join-Path $rawRoot 'live-merged'
        $outputPath = Join-Path $root '.output' 'TestResults' 'coverage' 'per-test.jsonl'

        Copy-Item -LiteralPath (Join-Path $script:LiveFixtureRoot 'main') -Destination $mainPath -Recurse -Force
        New-Item -ItemType Directory -Path (Join-Path $testPath 'src'), $collectionPath -Force | Out-Null
        New-AppJson -Path (Join-Path $testPath 'app.json') `
            -Id '33333333-3333-3333-3333-333333333333' `
            -Name 'Merged Live Tests' `
            -From 74101 -To 74102
        Copy-Item -LiteralPath (Join-Path $script:LiveFixtureRoot 'test-pass' 'src' 'PassingTests.Codeunit.al') `
            -Destination (Join-Path $testPath 'src' 'PassingTests.Codeunit.al') -Force
        Copy-Item -LiteralPath (Join-Path $script:LiveFixtureRoot 'test-fail' 'src' 'FailingTests.Codeunit.al') `
            -Destination (Join-Path $testPath 'src' 'FailingTests.Codeunit.al') -Force

        Copy-Item -LiteralPath (Join-Path $script:LiveFixtureRoot 'raw' 'test-pass' 'payload-0001.xml') `
            -Destination (Join-Path $collectionPath 'payload-0001.xml') -Force
        Copy-Item -LiteralPath (Join-Path $script:LiveFixtureRoot 'raw' 'test-fail' 'payload-0001.xml') `
            -Destination (Join-Path $collectionPath 'payload-0002.xml') -Force

        [ordered]@{
            schemaVersion = 1
            testApp = 'live-merged'
            junitTestCount = 2
            payloadCount = 2
            drainResponseCount = 4
            terminalDoneCount = 2
            doneValue = 'Done.'
            payloads = @(
                [ordered]@{
                    order = 1
                    testCodeunitId = 74101
                    testMethod = 'PassingTest'
                    file = 'payload-0001.xml'
                }
                [ordered]@{
                    order = 2
                    testCodeunitId = 74102
                    testMethod = 'IntentionalFailureAfterMainCode'
                    file = 'payload-0002.xml'
                }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (
            Join-Path $collectionPath 'manifest.json'
        ) -Encoding utf8

        [pscustomobject]@{
            RepoRoot = $root
            MainAppPath = $mainPath
            TestAppPath = $testPath
            RawRootPath = $rawRoot
            OutputPath = $outputPath
        }
    }
}

Describe 'Write-BcCoveragePerTestJsonl' {
    It 'emits exact schema-v1 JSONL with deterministic ordering and property order' {
        $workspace = New-SyntheticWorkspace -Name 'exact-jsonl' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeeinheit' -ObjectId 50100 `
                        -LineNumber 0 -LineTypeCode 0 -LineTypeName 'Object' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Non Applicable' `
                        -HitCount 0 -SourceLine 'Codeunit Quoted Utility (50100)')
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeeinheit' -ObjectId 50100 `
                        -LineNumber 7 -LineTypeCode 1 -LineTypeName 'Auslöser/Funktion' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Nicht anwendbar' `
                        -HitCount 0 -SourceLine '    procedure Run(): Integer')
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeeinheit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Abgedeckt' `
                        -HitCount 2 -SourceLine '        exit(1);')
                    (New-CoverageRow -ObjectTypeCode 14 -ObjectTypeName 'SeitenErweiterung' -ObjectId 50101 `
                        -LineNumber 0 -LineTypeCode 0 -LineTypeName 'Object' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Nicht anwendbar' `
                        -HitCount 0 -SourceLine 'PageExtension CustomerCardExt (50101)')
                    (New-CoverageRow -ObjectTypeCode 14 -ObjectTypeName 'SeitenErweiterung' -ObjectId 50101 `
                        -LineNumber 16 -LineTypeCode 1 -LineTypeName 'Auslöser/Funktion' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Nicht anwendbar' `
                        -HitCount 0 -SourceLine '    trigger OnOpenPage()')
                    (New-CoverageRow -ObjectTypeCode 14 -ObjectTypeName 'SeitenErweiterung' -ObjectId 50101 `
                        -LineNumber 18 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 3 -CoverageStatusName 'Teilweise abgedeckt' `
                        -HitCount 1 -SourceLine "        Message('Opened');")
                )
            }
        )

        Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
            -MainAppPath $workspace.MainAppPath `
            -TestAppPath $workspace.TestAppPath `
            -RawCollectionPath $workspace.CollectionPath `
            -OutputPath $workspace.OutputPath | Out-Null

        Get-JsonLines -Path $workspace.OutputPath | Should -Be @(
            '{"schemaVersion":1,"recordType":"source","sourcePath":"main/src/MixedObjects.al","objectType":"Codeunit","objectName":"Quoted Utility","lineNumber":9}'
            '{"schemaVersion":1,"recordType":"source","sourcePath":"main/src/MixedObjects.al","objectType":"PageExtension","objectName":"CustomerCardExt","lineNumber":18}'
            '{"schemaVersion":1,"recordType":"hit","sourcePath":"main/src/MixedObjects.al","objectType":"Codeunit","objectName":"Quoted Utility","lineNumber":9,"testApp":"synthetic","testCodeunitId":60100,"testCodeunitName":"Normalizer Tests","testProcedure":"CoversMixedObjects","hitCount":2}'
            '{"schemaVersion":1,"recordType":"hit","sourcePath":"main/src/MixedObjects.al","objectType":"PageExtension","objectName":"CustomerCardExt","lineNumber":18,"testApp":"synthetic","testCodeunitId":60100,"testCodeunitName":"Normalizer Tests","testProcedure":"CoversMixedObjects","hitCount":1}'
        )
    }

    It 'normalizes the merged live fixture and filters foreign objects out of the public universe' {
        $workspace = New-MergedLiveWorkspace

        Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
            -MainAppPath $workspace.MainAppPath `
            -TestAppPath $workspace.TestAppPath `
            -RawCollectionPath $workspace.RawRootPath `
            -OutputPath $workspace.OutputPath | Out-Null

        $lines = Get-JsonLines -Path $workspace.OutputPath
        $records = @($lines | ForEach-Object { $_ | ConvertFrom-Json })
        $sourceRecords = @($records | Where-Object { $_.recordType -eq 'source' })
        $hitRecords = @($records | Where-Object { $_.recordType -eq 'hit' })

        $sourceRecords.Count | Should -Be 8
        $hitRecords.Count | Should -Be 8
        @($sourceRecords.sourcePath | Select-Object -Unique) |
            Should -Be @('main/src/CoverageSpine.Codeunit.al')
        @($sourceRecords.lineNumber | Sort-Object) | Should -Be @(9, 10, 11, 12, 13, 20, 21, 22)
        @($hitRecords.lineNumber | Sort-Object) | Should -Be @(9, 9, 10, 10, 12, 12, 13, 13)
        @($hitRecords.testCodeunitName | Select-Object -Unique | Sort-Object) |
            Should -Be @('Live Coverage Fail Tests', 'Live Coverage Pass Tests')
        @($hitRecords | Where-Object { $_.lineNumber -eq 11 }).Count | Should -Be 0
        ($lines -join "`n") | Should -Not -Match '"objectId"|\"sourceLine\"'
    }

    It 'accepts a 250-character SourceLine prefix for long physical source lines' {
        $longPayloadText = 'X' * 280
        $mainSource = New-LongLineMainSource -PayloadText $longPayloadText
        $messageLine = [regex]::Split($mainSource, '\r\n|\n|\r')[6]
        $workspace = New-SyntheticWorkspace -Name 'long-source-line' -MainFiles @{
            'src\LongLine.Codeunit.al' = $mainSource
        } -TestFiles @{
            'src\LongLineTests.Codeunit.al' = @"
namespace Test.Normalizer;

codeunit 60110 "Long Line Tests"
{
    Subtype = Test;

    [Test]
    procedure CoversLongLine()
    begin
    end;
}
"@
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60110
                TestMethod = 'CoversLongLine'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Kodeneinheit' -ObjectId 50110 `
                        -LineNumber 0 -LineTypeCode 0 -LineTypeName 'Objekt' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Nicht anwendbar' `
                        -HitCount 0 -SourceLine 'Codeunit Long Line Utility (50110)')
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Kodeneinheit' -ObjectId 50110 `
                        -LineNumber 5 -LineTypeCode 1 -LineTypeName 'Auslöser/Funktion' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Nicht anwendbar' `
                        -HitCount 0 -SourceLine '    procedure LongLine()')
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Kodeneinheit' -ObjectId 50110 `
                        -LineNumber 7 -LineTypeCode 3 -LineTypeName 'Codezeile' `
                        -CoverageStatusCode 3 -CoverageStatusName 'Teilweise abgedeckt' `
                        -HitCount 7 -SourceLine $messageLine.Substring(0, 250))
                )
            }
        )

        Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
            -MainAppPath $workspace.MainAppPath `
            -TestAppPath $workspace.TestAppPath `
            -RawCollectionPath $workspace.CollectionPath `
            -OutputPath $workspace.OutputPath | Out-Null

        Get-JsonLines -Path $workspace.OutputPath | Should -Be @(
            '{"schemaVersion":1,"recordType":"source","sourcePath":"main/src/LongLine.Codeunit.al","objectType":"Codeunit","objectName":"Long Line Utility","lineNumber":7}'
            '{"schemaVersion":1,"recordType":"hit","sourcePath":"main/src/LongLine.Codeunit.al","objectType":"Codeunit","objectName":"Long Line Utility","lineNumber":7,"testApp":"synthetic","testCodeunitId":60110,"testCodeunitName":"Long Line Tests","testProcedure":"CoversLongLine","hitCount":7}'
        )
    }

    It 'fails at the issue 77 aggregation boundary when raw coverage contains multiple test-app collections' {
        {
            Write-BcCoveragePerTestJsonl -RepoRoot $script:RepoRoot `
                -MainAppPath (Join-Path $script:LiveFixtureRoot 'main') `
                -TestAppPath (Join-Path $script:LiveFixtureRoot 'test-pass') `
                -RawCollectionPath (Join-Path $script:LiveFixtureRoot 'raw') `
                -OutputPath (Join-Path $TestDrive 'multi-app' 'per-test.jsonl')
        } | Should -Throw '*Issue 77*'
    }

    It 'fails when the collection repeats the same test identity' {
        $workspace = New-SyntheticWorkspace -Name 'duplicate-identity' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' `
                        -HitCount 0 -SourceLine '        exit(1);')
                )
            }
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' `
                        -HitCount 0 -SourceLine '        exit(1);')
                )
            }
        )

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*duplicate test identity*'
    }

    It 'fails when one payload repeats the same raw source key' {
        $workspace = New-SyntheticWorkspace -Name 'duplicate-raw-key' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Covered' `
                        -HitCount 1 -SourceLine '        exit(1);')
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Covered' `
                        -HitCount 1 -SourceLine '        exit(1);')
                )
            }
        )

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*duplicate raw source key*'
    }

    It 'fails when payload universes differ after foreign-object filtering' {
        $workspace = New-SyntheticWorkspace -Name 'universe-mismatch' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
            'src\SecondTests.Codeunit.al' = (New-SyntheticTestSource -CodeunitName 'Second Tests').Replace('codeunit 60100', 'codeunit 60101').Replace('procedure CoversMixedObjects()', 'procedure CoversSecondObject()')
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Covered' `
                        -HitCount 1 -SourceLine '        exit(1);')
                )
            }
            [pscustomobject]@{
                TestCodeunitId = 60101
                TestMethod = 'CoversSecondObject'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 14 -ObjectTypeName 'PageExtension' -ObjectId 50101 `
                        -LineNumber 18 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Covered' `
                        -HitCount 1 -SourceLine "        Message('Opened');")
                )
            }
        )

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*executable-line universe*'
    }

    It 'fails when code-row status semantics contradict the hit count' {
        $workspace = New-SyntheticWorkspace -Name 'status-mismatch' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Covered' `
                        -HitCount 0 -SourceLine '        exit(1);')
                )
            }
        )

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*marked covered/partially covered but has HitCount 0*'
    }

    It 'fails when manifest.testApp does not match the supplied test app directory leaf' {
        $workspace = New-SyntheticWorkspace -Name 'manifest-testapp-mismatch' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' `
                        -HitCount 0 -SourceLine '        exit(1);')
                )
            }
        ) -TestAppDirectoryName 'expected-test-app' -ManifestTestAppName 'different-test-app'

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*does not match test app directory leaf*'
    }

    It 'fails when raw coverage uses an unsupported object type code' {
        $workspace = New-SyntheticWorkspace -Name 'unsupported-object-type' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 99 -ObjectTypeName 'LokalisierterTyp' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Abgedeckt' `
                        -HitCount 1 -SourceLine '        exit(1);')
                )
            }
        )

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*unsupported object type code*'
    }

    It 'fails with a precise diagnostic when an AL declaration cannot be indexed safely' {
        $workspace = New-SyntheticWorkspace -Name 'unsafe-declaration' -MainFiles @{
            'src\Broken.al' = @'
namespace Test.Normalizer;

codeunit 50100
"Broken Declaration"
{
}
'@
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 3 -LineTypeCode 1 -LineTypeName 'Trigger/Function' `
                        -CoverageStatusCode 0 -CoverageStatusName 'Non Applicable' `
                        -HitCount 0 -SourceLine 'codeunit 50100')
                )
            }
        )

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*cannot be indexed safely*'
    }

    It 'preserves the previous output and leaves no temp file behind when normalization fails' {
        $workspace = New-SyntheticWorkspace -Name 'atomic-failure' -MainFiles @{
            'src\MixedObjects.al' = New-MixedMainSource
        } -TestFiles @{
            'src\NormalizerTests.Codeunit.al' = New-SyntheticTestSource
        } -Payloads @(
            [pscustomobject]@{
                TestCodeunitId = 60100
                TestMethod = 'CoversMixedObjects'
                Rows = @(
                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 `
                        -LineNumber 9 -LineTypeCode 3 -LineTypeName 'Code' `
                        -CoverageStatusCode 2 -CoverageStatusName 'Covered' `
                        -HitCount 1 -SourceLine '        exit(99);')
                )
            }
        )

        New-Item -ItemType Directory -Path (Split-Path $workspace.OutputPath -Parent) -Force | Out-Null
        'unchanged' | Set-Content -LiteralPath $workspace.OutputPath -Encoding utf8

        {
            Write-BcCoveragePerTestJsonl -RepoRoot $workspace.RepoRoot `
                -MainAppPath $workspace.MainAppPath `
                -TestAppPath $workspace.TestAppPath `
                -RawCollectionPath $workspace.CollectionPath `
                -OutputPath $workspace.OutputPath
        } | Should -Throw '*does not match the indexed source line exactly*'

        (Get-Content -LiteralPath $workspace.OutputPath -Raw).Trim() | Should -Be 'unchanged'
        @(
            Get-ChildItem -LiteralPath (Split-Path $workspace.OutputPath -Parent) -File |
                Where-Object { $_.Name -like 'per-test.jsonl.*.tmp' }
        ).Count | Should -Be 0
    }
}
