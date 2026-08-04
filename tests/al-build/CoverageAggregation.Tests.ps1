#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:ModulePath = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts' 'coverage-normalizer.psm1'
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
            publisher = 'Coverage Aggregation Tests'
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
            [string]$HitCount,

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

    function Get-LineNumberOf {
        param(
            [Parameter(Mandatory)]
            [string]$Text,

            [Parameter(Mandatory)]
            [string]$Literal
        )

        $lines = [regex]::Split($Text, '\r\n|\n|\r')
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index].Contains($Literal)) {
                return $index + 1
            }
        }
        throw "Literal '$Literal' not found in supplied text."
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

    function New-SingleLineMainSource {
        param(
            [int]$CodeunitId = 50100,

            [string]$CodeunitName = 'Solo Codeunit'
        )
@"
namespace Test.Aggregation;

codeunit $CodeunitId "$CodeunitName"
{
    procedure Run()
    begin
        Message('x');
    end;
}
"@
    }

    function New-SingleLineTestSource {
        param(
            [Parameter(Mandatory)]
            [int]$CodeunitId,

            [Parameter(Mandatory)]
            [string]$CodeunitName,

            [Parameter(Mandatory)]
            [string]$ProcedureName
        )
@"
namespace Test.Aggregation;

codeunit $CodeunitId "$CodeunitName"
{
    Subtype = Test;

    [Test]
    procedure $ProcedureName()
    begin
    end;
}
"@
    }

    function New-TwoObjectMainSource {
@'
namespace Test.Aggregation;

codeunit 50200 "Alpha Codeunit"
{
    procedure Run()
    begin
        Message('a');
        Message('b');
    end;
}

codeunit 50201 "Beta Codeunit"
{
    procedure Run()
    begin
        Message('c');
        Message('d');
    end;
}
'@
    }

    function New-AggregationWorkspace {
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [hashtable]$MainFiles,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Apps,

            [AllowEmptyCollection()]
            [string[]]$ExtraCollectionDirNames = @()
        )

        $root = Join-Path $TestDrive $Name
        $mainPath = Join-Path $root 'main'
        $rawRoot = Join-Path $root 'raw'
        $outputDirectory = Join-Path $root '.output' 'TestResults' 'coverage'

        New-Item -ItemType Directory -Path $mainPath, $rawRoot -Force | Out-Null
        New-AppJson -Path (Join-Path $mainPath 'app.json') `
            -Id '11111111-1111-1111-1111-111111111111' `
            -Name 'Aggregation Main'
        foreach ($entry in $MainFiles.GetEnumerator()) {
            Set-FileContent -Path (Join-Path $mainPath $entry.Key) -Content $entry.Value
        }

        $testAppPaths = [System.Collections.Generic.List[string]]::new()
        foreach ($app in $Apps) {
            $testPath = Join-Path $root $app.DirName
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            New-AppJson -Path (Join-Path $testPath 'app.json') `
                -Id ([guid]::NewGuid().ToString()) `
                -Name $app.AppName
            foreach ($entry in $app.TestFiles.GetEnumerator()) {
                Set-FileContent -Path (Join-Path $testPath $entry.Key) -Content $entry.Value
            }

            if (-not $app.SkipCollection) {
                $collectionDirName = if ($app.CollectionDirName) { $app.CollectionDirName } else { $app.DirName }
                New-RawCollection -Path (Join-Path $rawRoot $collectionDirName) `
                    -TestApp $collectionDirName -Payloads $app.Payloads
            }

            $testAppPaths.Add($testPath)
        }

        foreach ($extraDirName in $ExtraCollectionDirNames) {
            New-RawCollection -Path (Join-Path $rawRoot $extraDirName) -TestApp $extraDirName -Payloads @(
                [pscustomobject]@{
                    TestCodeunitId = 90000
                    TestMethod = 'Unclaimed'
                    Rows = @()
                }
            )
        }

        [pscustomobject]@{
            RepoRoot = $root
            MainAppPath = $mainPath
            TestAppPaths = @($testAppPaths)
            RawRootPath = $rawRoot
            OutputDirectory = $outputDirectory
        }
    }
}

Describe 'Write-BcCoverageArtifacts' {
    Context 'two-app aggregation with overlapping and partial hits' {
        BeforeAll {
            $script:mainSource = New-TwoObjectMainSource
            $script:lineA = Get-LineNumberOf -Text $script:mainSource -Literal "Message('a');"
            $script:lineB = Get-LineNumberOf -Text $script:mainSource -Literal "Message('b');"
            $script:lineC = Get-LineNumberOf -Text $script:mainSource -Literal "Message('c');"
            $script:lineD = Get-LineNumberOf -Text $script:mainSource -Literal "Message('d');"

            function script:New-TotalsApps {
                @(
                    [pscustomobject]@{
                        DirName = 'test-alpha'
                        AppName = 'Alpha Test Suite'
                        TestFiles = @{
                            'src\AlphaTests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60200 -CodeunitName 'Alpha Tests' -ProcedureName 'CoversAlpha')
                        }
                        Payloads = @(
                            [pscustomobject]@{
                                TestCodeunitId = 60200
                                TestMethod = 'CoversAlpha'
                                Rows = @(
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50200 -LineNumber $script:lineA -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 2 -SourceLine "        Message('a');")
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50200 -LineNumber $script:lineB -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' -HitCount 0 -SourceLine "        Message('b');")
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50201 -LineNumber $script:lineC -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('c');")
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50201 -LineNumber $script:lineD -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' -HitCount 0 -SourceLine "        Message('d');")
                                )
                            }
                        )
                    }
                    [pscustomobject]@{
                        DirName = 'test-beta'
                        AppName = 'Beta Test Suite'
                        TestFiles = @{
                            'src\BetaTests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60201 -CodeunitName 'Beta Tests' -ProcedureName 'CoversBeta')
                        }
                        Payloads = @(
                            [pscustomobject]@{
                                TestCodeunitId = 60201
                                TestMethod = 'CoversBeta'
                                Rows = @(
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50200 -LineNumber $script:lineA -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' -HitCount 0 -SourceLine "        Message('a');")
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50200 -LineNumber $script:lineB -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 1 -CoverageStatusName 'Not Covered' -HitCount 0 -SourceLine "        Message('b');")
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50201 -LineNumber $script:lineC -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 3 -SourceLine "        Message('c');")
                                    (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50201 -LineNumber $script:lineD -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 5 -SourceLine "        Message('d');")
                                )
                            }
                        )
                    }
                )
            }

            $script:workspace = New-AggregationWorkspace -Name 'totals' -MainFiles @{
                'src\Objects.al' = $script:mainSource
            } -Apps (New-TotalsApps)

            $script:result = Write-BcCoverageArtifacts -RepoRoot $script:workspace.RepoRoot `
                -MainAppPath $script:workspace.MainAppPath `
                -TestAppPaths $script:workspace.TestAppPaths `
                -RawCollectionPath $script:workspace.RawRootPath `
                -OutputDirectory $script:workspace.OutputDirectory

            $script:jsonLines = Get-JsonLines -Path $script:result.PerTestPath
            $script:records = @($script:jsonLines | ForEach-Object { $_ | ConvertFrom-Json })
            [xml]$script:cobertura = Get-Content -LiteralPath $script:result.CoberturaPath -Raw
        }

        It 'produces one source record per universe line and one hit record per test/line pair' {
            $sourceRecords = @($script:records | Where-Object { $_.recordType -eq 'source' })
            $hitRecords = @($script:records | Where-Object { $_.recordType -eq 'hit' })

            $sourceRecords.Count | Should -Be 4
            $hitRecords.Count | Should -Be 4
        }

        It 'writes the actual app.json name into hit records, not the raw collection directory leaf' {
            $hitRecords = @($script:records | Where-Object { $_.recordType -eq 'hit' })
            @($hitRecords.testApp | Sort-Object -Unique) | Should -Be @('Alpha Test Suite', 'Beta Test Suite')
            $hitRecords | Where-Object { $_.testApp -eq 'test-alpha' -or $_.testApp -eq 'test-beta' } | Should -BeNullOrEmpty
        }

        It 'aggregates overlapping hits in Cobertura with Int64-safe summation' {
            $lineNodes = @($script:cobertura.coverage.packages.package.classes.class.lines.line)
            $byNumber = @{}
            foreach ($node in $lineNodes) {
                $byNumber[[int]$node.number] = [int64]$node.hits
            }
            $byNumber[[int]$script:lineA] | Should -Be 2
            $byNumber[[int]$script:lineB] | Should -Be 0
            $byNumber[[int]$script:lineC] | Should -Be 4
            $byNumber[[int]$script:lineD] | Should -Be 5
        }

        It 'reports root, package, and per-class rates/totals that agree' {
            $coverageNode = $script:cobertura.coverage
            $packageNode = $coverageNode.packages.package
            $classNodes = @($packageNode.classes.class)

            [int]$coverageNode.'lines-valid' | Should -Be 4
            [int]$coverageNode.'lines-covered' | Should -Be 3
            $coverageNode.'line-rate' | Should -Be '0.750000'
            $packageNode.'lines-valid' | Should -Be $coverageNode.'lines-valid'
            $packageNode.'lines-covered' | Should -Be $coverageNode.'lines-covered'
            $packageNode.'line-rate' | Should -Be $coverageNode.'line-rate'

            $classNodes.Count | Should -Be 2
            ([int]$classNodes[0].'lines-valid' + [int]$classNodes[1].'lines-valid') | Should -Be ([int]$coverageNode.'lines-valid')
            ([int]$classNodes[0].'lines-covered' + [int]$classNodes[1].'lines-covered') | Should -Be ([int]$coverageNode.'lines-covered')

            $alphaClass = $classNodes | Where-Object { $_.name -eq 'type=Codeunit;name=Alpha Codeunit' }
            $betaClass = $classNodes | Where-Object { $_.name -eq 'type=Codeunit;name=Beta Codeunit' }
            $alphaClass.'line-rate' | Should -Be '0.500000'
            $betaClass.'line-rate' | Should -Be '1.000000'
        }

        It 'names the single package after the main app and each class after its AL object' {
            $packageNode = $script:cobertura.coverage.packages.package
            $packageNode.name | Should -Be 'app=Aggregation Main'
            @($packageNode.classes.class.name | Sort-Object) | Should -Be @(
                'type=Codeunit;name=Alpha Codeunit',
                'type=Codeunit;name=Beta Codeunit'
            )
            @($packageNode.classes.class.filename | Select-Object -Unique) | Should -Be @('main/src/Objects.al')
        }

        It 'carries zero branch data at every level and omits methods and conditions' {
            $coverageNode = $script:cobertura.coverage
            $coverageNode.'branch-rate' | Should -Be '0.000000'
            $coverageNode.'branches-covered' | Should -Be '0'
            $coverageNode.'branches-valid' | Should -Be '0'
            $coverageNode.complexity | Should -Be '0'
            $coverageNode.timestamp | Should -Be '0'

            foreach ($classNode in @($coverageNode.packages.package.classes.class)) {
                $classNode.'branch-rate' | Should -Be '0.000000'
                $classNode.methods.ChildNodes.Count | Should -Be 0
                foreach ($lineNode in @($classNode.lines.line)) {
                    $lineNode.branch | Should -Be 'false'
                    $lineNode.PSObject.Properties['condition-coverage'] | Should -BeNullOrEmpty
                }
            }
            (Select-Xml -Xml $script:cobertura -XPath '//condition') | Should -BeNullOrEmpty
        }

        It 'returns PerTest tracking-mode metrics matching the written artifacts' {
            $script:result.TrackingMode | Should -Be 'PerTest'
            $script:result.LinesValid | Should -Be 4
            $script:result.LinesCovered | Should -Be 3
            [double]$script:result.LineRate | Should -Be 0.75
            (Test-Path -LiteralPath $script:result.PerTestPath -PathType Leaf) | Should -BeTrue
            (Test-Path -LiteralPath $script:result.CoberturaPath -PathType Leaf) | Should -BeTrue
        }

        It 'serializes per-test.jsonl and cobertura.xml as UTF-8 without BOM and with LF line endings' {
            foreach ($path in @($script:result.PerTestPath, $script:result.CoberturaPath)) {
                $bytes = [System.IO.File]::ReadAllBytes($path)
                ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
                $text = [System.Text.Encoding]::UTF8.GetString($bytes)
                $text.Contains("`r") | Should -BeFalse
            }
        }
    }

    Context 'deterministic ordering independent of configured TestAppPaths order' {
        It 'produces byte-identical output regardless of test app partition order' {
            $mainSource = New-TwoObjectMainSource
            $lineA = Get-LineNumberOf -Text $mainSource -Literal "Message('a');"
            $lineC = Get-LineNumberOf -Text $mainSource -Literal "Message('c');"

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-alpha'
                    AppName = 'Alpha Test Suite'
                    TestFiles = @{
                        'src\AlphaTests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60200 -CodeunitName 'Alpha Tests' -ProcedureName 'CoversAlpha')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60200
                            TestMethod = 'CoversAlpha'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50200 -LineNumber $lineA -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 2 -SourceLine "        Message('a');")
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50201 -LineNumber $lineC -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('c');")
                            )
                        }
                    )
                }
                [pscustomobject]@{
                    DirName = 'test-beta'
                    AppName = 'Beta Test Suite'
                    TestFiles = @{
                        'src\BetaTests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60201 -CodeunitName 'Beta Tests' -ProcedureName 'CoversBeta')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60201
                            TestMethod = 'CoversBeta'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50200 -LineNumber $lineA -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 4 -SourceLine "        Message('a');")
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50201 -LineNumber $lineC -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 3 -SourceLine "        Message('c');")
                            )
                        }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'order-independence' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            $forwardOutput = Join-Path $workspace.OutputDirectory 'forward'
            $reverseOutput = Join-Path $workspace.OutputDirectory 'reverse'

            $reversedTestAppPaths = @($workspace.TestAppPaths)
            [array]::Reverse($reversedTestAppPaths)

            Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                -OutputDirectory $forwardOutput | Out-Null
            Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                -TestAppPaths $reversedTestAppPaths `
                -RawCollectionPath $workspace.RawRootPath -OutputDirectory $reverseOutput | Out-Null

            $forwardJsonlHash = (Get-FileHash -LiteralPath (Join-Path $forwardOutput 'per-test.jsonl') -Algorithm SHA256).Hash
            $reverseJsonlHash = (Get-FileHash -LiteralPath (Join-Path $reverseOutput 'per-test.jsonl') -Algorithm SHA256).Hash
            $forwardXmlHash = (Get-FileHash -LiteralPath (Join-Path $forwardOutput 'cobertura.xml') -Algorithm SHA256).Hash
            $reverseXmlHash = (Get-FileHash -LiteralPath (Join-Path $reverseOutput 'cobertura.xml') -Algorithm SHA256).Hash

            $forwardJsonlHash | Should -Be $reverseJsonlHash
            $forwardXmlHash | Should -Be $reverseXmlHash
        }
    }

    Context 'XML escaping of AL object names' {
        It 'escapes ampersands in class names and recovers the original name on parse' {
            $mainSource = @'
namespace Test.Aggregation;

codeunit 50300 "A & B"
{
    procedure Run()
    begin
        Message('x');
    end;
}
'@
            $lineX = Get-LineNumberOf -Text $mainSource -Literal "Message('x');"

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-escape'
                    AppName = 'Escape Test Suite'
                    TestFiles = @{
                        'src\EscapeTests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60300 -CodeunitName 'Escape Tests' -ProcedureName 'CoversEscape')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60300
                            TestMethod = 'CoversEscape'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50300 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('x');")
                            )
                        }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'xml-escaping' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            $result = Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                -OutputDirectory $workspace.OutputDirectory

            $rawText = Get-Content -LiteralPath $result.CoberturaPath -Raw
            $rawText | Should -Match '&amp;'
            $rawText | Should -Not -Match '(?<!&amp;)A & B'

            [xml]$parsed = $rawText
            $classNode = $parsed.coverage.packages.package.classes.class
            $classNode.name | Should -Be 'type=Codeunit;name=A & B'
        }
    }

    Context 'red paths' {
        It 'fails when configured test apps expose different executable-line universes' {
            $mainA = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo A'
            $lineXa = Get-LineNumberOf -Text $mainA -Literal "Message('x');"

            $mainSource = @'
namespace Test.Aggregation;

codeunit 50100 "Solo A"
{
    procedure Run()
    begin
        Message('x');
    end;
}

codeunit 50101 "Solo B"
{
    procedure Run()
    begin
        Message('y');
    end;
}
'@
            $lineY = Get-LineNumberOf -Text $mainSource -Literal "Message('y');"

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-mismatch-a'
                    AppName = 'Mismatch Suite A'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Mismatch Tests A' -ProcedureName 'CoversA')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60100
                            TestMethod = 'CoversA'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineXa -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('x');")
                            )
                        }
                    )
                }
                [pscustomobject]@{
                    DirName = 'test-mismatch-b'
                    AppName = 'Mismatch Suite B'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60101 -CodeunitName 'Mismatch Tests B' -ProcedureName 'CoversB')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60101
                            TestMethod = 'CoversB'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50101 -LineNumber $lineY -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('y');")
                            )
                        }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'universe-mismatch-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            {
                Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                    -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                    -OutputDirectory $workspace.OutputDirectory
            } | Should -Throw '*executable-line universe*'
        }

        It 'fails when two configured test apps report the same test identity' {
            $mainSource = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo Duplicate'
            $lineX = Get-LineNumberOf -Text $mainSource -Literal "Message('x');"
            $sharedRows = @(
                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('x');")
            )

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-dup-a'
                    AppName = 'Shared Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Shared Tests' -ProcedureName 'CoversShared')
                    }
                    Payloads = @(
                        [pscustomobject]@{ TestCodeunitId = 60100; TestMethod = 'CoversShared'; Rows = $sharedRows }
                    )
                }
                [pscustomobject]@{
                    DirName = 'test-dup-b'
                    AppName = 'Shared Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Shared Tests' -ProcedureName 'CoversShared')
                    }
                    Payloads = @(
                        [pscustomobject]@{ TestCodeunitId = 60100; TestMethod = 'CoversShared'; Rows = $sharedRows }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'duplicate-identity-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            {
                Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                    -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                    -OutputDirectory $workspace.OutputDirectory
            } | Should -Throw '*duplicate test identity*'
        }

        It 'fails when a configured test app collection has zero payloads' {
            $mainSource = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo Zero'

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-zero'
                    AppName = 'Zero Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Zero Tests' -ProcedureName 'CoversZero')
                    }
                    Payloads = @()
                }
            )

            $workspace = New-AggregationWorkspace -Name 'zero-payload-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            {
                Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                    -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                    -OutputDirectory $workspace.OutputDirectory
            } | Should -Throw '*zero payloads*'
        }

        It 'fails when a configured test app has no matching raw collection folder' {
            $mainSource = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo Missing'
            $lineX = Get-LineNumberOf -Text $mainSource -Literal "Message('x');"
            $rows = @(
                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('x');")
            )

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-present'
                    AppName = 'Present Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Present Tests' -ProcedureName 'CoversPresent')
                    }
                    Payloads = @(
                        [pscustomobject]@{ TestCodeunitId = 60100; TestMethod = 'CoversPresent'; Rows = $rows }
                    )
                }
                [pscustomobject]@{
                    DirName = 'test-absent'
                    AppName = 'Absent Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60101 -CodeunitName 'Absent Tests' -ProcedureName 'CoversAbsent')
                    }
                    Payloads = @()
                    SkipCollection = $true
                }
            )

            $workspace = New-AggregationWorkspace -Name 'missing-collection-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            {
                Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                    -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                    -OutputDirectory $workspace.OutputDirectory
            } | Should -Throw '*is missing collection folder(s)*test-absent*'
        }

        It 'fails when the raw collection root has an unconfigured collection folder' {
            $mainSource = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo Extra'
            $lineX = Get-LineNumberOf -Text $mainSource -Literal "Message('x');"
            $rows = @(
                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('x');")
            )

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-only'
                    AppName = 'Only Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Only Tests' -ProcedureName 'CoversOnly')
                    }
                    Payloads = @(
                        [pscustomobject]@{ TestCodeunitId = 60100; TestMethod = 'CoversOnly'; Rows = $rows }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'extra-collection-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps -ExtraCollectionDirNames @('test-unclaimed')

            {
                Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                    -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                    -OutputDirectory $workspace.OutputDirectory
            } | Should -Throw '*unconfigured collection folder(s)*test-unclaimed*'
        }

        It 'fails when a payload file is malformed XML' {
            $mainSource = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo Malformed'
            $lineX = Get-LineNumberOf -Text $mainSource -Literal "Message('x');"
            $rows = @(
                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 1 -SourceLine "        Message('x');")
            )

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-malformed'
                    AppName = 'Malformed Suite'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Malformed Tests' -ProcedureName 'CoversMalformed')
                    }
                    Payloads = @(
                        [pscustomobject]@{ TestCodeunitId = 60100; TestMethod = 'CoversMalformed'; Rows = $rows }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'malformed-payload-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            $payloadPath = Join-Path $workspace.RawRootPath 'test-malformed' 'payload-0001.xml'
            'not xml at all <<<' | Set-Content -LiteralPath $payloadPath -Encoding utf8

            {
                Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                    -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                    -OutputDirectory $workspace.OutputDirectory
            } | Should -Throw '*not valid XML*'
        }

        It 'fails when Int64 hit summation crosses the Int32 boundary and still reports the exact sum' {
            $mainSource = New-SingleLineMainSource -CodeunitId 50100 -CodeunitName 'Solo Int64'
            $lineX = Get-LineNumberOf -Text $mainSource -Literal "Message('x');"

            $apps = @(
                [pscustomobject]@{
                    DirName = 'test-int64-a'
                    AppName = 'Int64 Suite A'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60100 -CodeunitName 'Int64 Tests A' -ProcedureName 'CoversInt64A')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60100
                            TestMethod = 'CoversInt64A'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 2147483647 -SourceLine "        Message('x');")
                            )
                        }
                    )
                }
                [pscustomobject]@{
                    DirName = 'test-int64-b'
                    AppName = 'Int64 Suite B'
                    TestFiles = @{
                        'src\Tests.Codeunit.al' = (New-SingleLineTestSource -CodeunitId 60101 -CodeunitName 'Int64 Tests B' -ProcedureName 'CoversInt64B')
                    }
                    Payloads = @(
                        [pscustomobject]@{
                            TestCodeunitId = 60101
                            TestMethod = 'CoversInt64B'
                            Rows = @(
                                (New-CoverageRow -ObjectTypeCode 5 -ObjectTypeName 'Codeunit' -ObjectId 50100 -LineNumber $lineX -LineTypeCode 3 -LineTypeName 'Code' -CoverageStatusCode 2 -CoverageStatusName 'Covered' -HitCount 10 -SourceLine "        Message('x');")
                            )
                        }
                    )
                }
            )

            $workspace = New-AggregationWorkspace -Name 'int64-overflow-agg' -MainFiles @{
                'src\Objects.al' = $mainSource
            } -Apps $apps

            $result = Write-BcCoverageArtifacts -RepoRoot $workspace.RepoRoot -MainAppPath $workspace.MainAppPath `
                -TestAppPaths $workspace.TestAppPaths -RawCollectionPath $workspace.RawRootPath `
                -OutputDirectory $workspace.OutputDirectory

            [xml]$cobertura = Get-Content -LiteralPath $result.CoberturaPath -Raw
            $lineNode = $cobertura.coverage.packages.package.classes.class.lines.line
            $lineNode.hits | Should -Be '2147483657'

            $jsonLines = Get-JsonLines -Path $result.PerTestPath
            $hitRecords = @($jsonLines | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.recordType -eq 'hit' })
            @($hitRecords.hitCount | Sort-Object) | Should -Be @(10, 2147483647)
        }
    }
}
