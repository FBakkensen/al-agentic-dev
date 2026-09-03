#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:ModulePath = Join-Path $script:RepoRoot 'skills' 'al-build' 'scripts' 'alrunner-coverage.psm1'
    Import-Module $script:ModulePath -Force -DisableNameChecking

    function New-AppJson {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$Name,

            [int]$From = 50000,

            [int]$To = 59999
        )

        $directory = Split-Path -Path $Path -Parent
        New-Item -ItemType Directory -Path $directory -Force | Out-Null

        [ordered]@{
            id          = [guid]::NewGuid().ToString()
            name        = $Name
            publisher   = 'ALRunnerCoverage Tests'
            version     = '1.0.0.0'
            platform    = '1.0.0.0'
            application = '1.0.0.0'
            runtime     = '15.0'
            idRanges    = @(
                [ordered]@{ from = $From; to = $To }
            )
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8
    }

    function Set-FileContent {
        param(
            [Parameter(Mandatory)]
            [string]$Path,

            [Parameter(Mandatory)]
            [string]$Content
        )

        $directory = Split-Path -Path $Path -Parent
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
    }

    function New-ALRunnerCoverageFixtureRepo {
        <#
            .SYNOPSIS
            Synthesizes a fake repo under $TestDrive matching small-summary.json:
            main app 'app' (Calc.Codeunit.al, T.Table.al) and test app 'test'
            (CalcTest.Codeunit.al, app.json idRanges covering 50150).
        #>
        param(
            [Parameter(Mandatory)]
            [string]$RepoRoot
        )

        New-AppJson -Path (Join-Path $RepoRoot 'app' 'app.json') -Name 'Main App' -From 50000 -To 50099
        Set-FileContent -Path (Join-Path $RepoRoot 'app' 'src' 'Calc.Codeunit.al') -Content @'
codeunit 50100 "Calc"
{
    trigger OnRun()
    begin
    end;

    procedure Add(a: Integer; b: Integer): Integer
    begin
        exit(a + b);
    end;
}
'@
        Set-FileContent -Path (Join-Path $RepoRoot 'app' 'src' 'T.Table.al') -Content @'
table 50101 "T"
{
    fields
    {
        field(1; "No."; Code[20])
        {
        }
    }
}
'@

        New-AppJson -Path (Join-Path $RepoRoot 'test' 'app.json') -Name 'Unit Tests' -From 50100 -To 50199
        Set-FileContent -Path (Join-Path $RepoRoot 'test' 'src' 'CalcTest.Codeunit.al') -Content @'
codeunit 50150 "CalcTest"
{
    [Test]
    procedure A()
    begin
    end;

    [Test]
    procedure B()
    begin
    end;
}
'@
    }

    function New-ALRunnerCoverageSummaryFile {
        <#
            .SYNOPSIS
            Loads the checked-in small-summary.json fixture, substitutes the
            __REPOROOT__ placeholder with the given (forward-slash) repo root, and
            writes the result to $TestDrive/summary.json.
        #>
        param(
            [Parameter(Mandatory)]
            [string]$RepoRoot,

            [string]$OutputPath = (Join-Path $TestDrive 'summary.json')
        )

        $fixturePath = Join-Path $script:RepoRoot 'tests' 'al-build' 'fixtures' 'alrunner-summary' 'small-summary.json'
        $forwardSlashRoot = $RepoRoot -replace '\\', '/'
        $content = (Get-Content -LiteralPath $fixturePath -Raw) -replace '__REPOROOT__', $forwardSlashRoot
        Set-Content -LiteralPath $OutputPath -Value $content -Encoding utf8
        $OutputPath
    }
}

Describe 'Write-ALRunnerCoverageArtifacts' {
    BeforeAll {
        $script:FixtureRepoRoot = Join-Path $TestDrive 'repo'
        New-ALRunnerCoverageFixtureRepo -RepoRoot $script:FixtureRepoRoot
        $script:SummaryFile = New-ALRunnerCoverageSummaryFile -RepoRoot $script:FixtureRepoRoot
        $script:OutputDirectory = Join-Path $TestDrive 'coverage'

        $script:Result = Write-ALRunnerCoverageArtifacts -SummaryFile $script:SummaryFile `
            -RepoRoot $script:FixtureRepoRoot `
            -MainAppPath (Join-Path $script:FixtureRepoRoot 'app') `
            -TestApps @((Join-Path $script:FixtureRepoRoot 'test')) `
            -OutputDirectory $script:OutputDirectory

        $script:PerTestLines = Get-Content -LiteralPath $script:Result.PerTestPath | ForEach-Object { $_ | ConvertFrom-Json }
    }

    It 'excludes non-main-app files from source records' {
        $script:PerTestLines | Where-Object kind -eq 'source' | ForEach-Object {
            $_.sourcePath | Should -Not -Match 'test/src'
        }
        (@($script:PerTestLines | Where-Object kind -eq 'source')).Count | Should -Be 5
    }

    It 'emits hit records with testApp, testCodeunit, and testProcedure resolved' {
        $hits = @($script:PerTestLines | Where-Object kind -eq 'hit')
        $hits.Count | Should -Be 5
        foreach ($hit in $hits) {
            $hit.testApp | Should -Be 'test'
            $hit.testCodeunit | Should -Be 'Codeunit50150'
        }
        ($hits | Where-Object testProcedure -eq 'A').Count | Should -Be 3
        ($hits | Where-Object testProcedure -eq 'B').Count | Should -Be 2
    }

    It 'shows both tests overlapping on Calc.Codeunit.al line 4' {
        $overlap = @($script:PerTestLines | Where-Object { $_.kind -eq 'hit' -and $_.lineNumber -eq 4 })
        $overlap.Count | Should -Be 2
        ($overlap | Where-Object testProcedure -eq 'A').hits | Should -Be 2
        ($overlap | Where-Object testProcedure -eq 'B').hits | Should -Be 1
    }

    It 'computes LineRate as covered/valid rounded to 4 decimals' {
        $script:Result.LinesValid | Should -Be 5
        $script:Result.LinesCovered | Should -Be 4
        $script:Result.LineRate | Should -Be 0.8
    }

    It 'produces byte-identical artifacts across two runs over the same summary' {
        $secondOutputDirectory = Join-Path $TestDrive 'coverage-2'
        $secondResult = Write-ALRunnerCoverageArtifacts -SummaryFile $script:SummaryFile `
            -RepoRoot $script:FixtureRepoRoot `
            -MainAppPath (Join-Path $script:FixtureRepoRoot 'app') `
            -TestApps @((Join-Path $script:FixtureRepoRoot 'test')) `
            -OutputDirectory $secondOutputDirectory

        $firstPerTestBytes = [System.IO.File]::ReadAllBytes($script:Result.PerTestPath)
        $secondPerTestBytes = [System.IO.File]::ReadAllBytes($secondResult.PerTestPath)
        [System.Convert]::ToBase64String($firstPerTestBytes) | Should -Be ([System.Convert]::ToBase64String($secondPerTestBytes))

        $firstCoberturaBytes = [System.IO.File]::ReadAllBytes($script:Result.CoberturaPath)
        $secondCoberturaBytes = [System.IO.File]::ReadAllBytes($secondResult.CoberturaPath)
        [System.Convert]::ToBase64String($firstCoberturaBytes) | Should -Be ([System.Convert]::ToBase64String($secondCoberturaBytes))
    }

    It 'writes valid Cobertura XML listing a zero-hit line' {
        [xml]$cobertura = Get-Content -LiteralPath $script:Result.CoberturaPath
        $cobertura.coverage.'lines-valid' | Should -Be '5'
        $lines = $cobertura.coverage.packages.package.classes.class |
            Where-Object { $_.filename -eq 'app/src/Calc.Codeunit.al' } |
            Select-Object -ExpandProperty lines |
            Select-Object -ExpandProperty line
        ($lines | Where-Object number -eq '5').hits | Should -Be '0'
    }
}

Describe 'Write-ALRunnerCoverageArtifacts failure paths' {
    BeforeAll {
        $script:FailFixtureRepoRoot = Join-Path $TestDrive 'fail-repo'
        New-ALRunnerCoverageFixtureRepo -RepoRoot $script:FailFixtureRepoRoot
        $script:FailMainAppPath = Join-Path $script:FailFixtureRepoRoot 'app'
        $script:FailTestApps = @((Join-Path $script:FailFixtureRepoRoot 'test'))
    }

    It 'throws naming the missing field when coverage is absent' {
        $summaryPath = Join-Path $TestDrive 'summary-no-coverage.json'
        [ordered]@{ exitCode = 0; perTestCoverage = @() } | ConvertTo-Json | Set-Content -LiteralPath $summaryPath -Encoding utf8

        { Write-ALRunnerCoverageArtifacts -SummaryFile $summaryPath -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -TestApps $script:FailTestApps `
                -OutputDirectory (Join-Path $TestDrive 'out-no-coverage') } |
            Should -Throw "*'coverage'*"
    }

    It 'throws naming the missing field when perTestCoverage is absent' {
        $summaryPath = Join-Path $TestDrive 'summary-no-pertest.json'
        [ordered]@{ exitCode = 0; coverage = @() } | ConvertTo-Json | Set-Content -LiteralPath $summaryPath -Encoding utf8

        { Write-ALRunnerCoverageArtifacts -SummaryFile $summaryPath -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -TestApps $script:FailTestApps `
                -OutputDirectory (Join-Path $TestDrive 'out-no-pertest') } |
            Should -Throw "*'perTestCoverage'*"
    }

    It 'throws naming the file when a covered main-app file cannot be parsed' {
        $unparsableFile = Join-Path $script:FailMainAppPath 'src' 'NotAlObject.txt'
        Set-FileContent -Path $unparsableFile -Content "just some text`nwith no object declaration`n"
        $forwardSlashFile = $unparsableFile -replace '\\', '/'

        $summaryPath = Join-Path $TestDrive 'summary-unparsable.json'
        [ordered]@{
            exitCode        = 0
            coverage        = @(
                [ordered]@{
                    file       = $forwardSlashFile
                    statements = @([ordered]@{ id = 1; scope = 'x'; line = 1; column = 1; endLine = 1; endColumn = 5; hits = 1 })
                }
            )
            perTestCoverage = @()
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8

        { Write-ALRunnerCoverageArtifacts -SummaryFile $summaryPath -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -TestApps $script:FailTestApps `
                -OutputDirectory (Join-Path $TestDrive 'out-unparsable') } |
            Should -Throw "*NotAlObject.txt*"
    }

    It 'throws naming the summary path when the summary file is not valid JSON' {
        $summaryPath = Join-Path $TestDrive 'summary-malformed.json'
        Set-Content -LiteralPath $summaryPath -Value '{"exitCode":0,"coverage":[' -Encoding utf8

        { Write-ALRunnerCoverageArtifacts -SummaryFile $summaryPath -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -TestApps $script:FailTestApps `
                -OutputDirectory (Join-Path $TestDrive 'out-malformed') } |
            Should -Throw "*$summaryPath*"
    }
}

Describe 'Write-ALRunnerCoverageArtifacts with a large perTestCoverage payload' {
    BeforeAll {
        $script:LargeRepoRoot = Join-Path $TestDrive 'large-repo'
        New-ALRunnerCoverageFixtureRepo -RepoRoot $script:LargeRepoRoot
        $forwardSlashRoot = $script:LargeRepoRoot -replace '\\', '/'

        # Synthesize ~5-10 MB of perTestCoverage entries so the summary file itself
        # is large enough to exercise the FileStream-backed JsonDocument parse path
        # rather than a small checked-in fixture.
        $script:EntryCount = 25000
        $perTestEntries = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $script:EntryCount; $i++) {
            $perTestEntries.Add(
                '{"test":"Codeunit50150.A","coverage":[{"file":"' + $forwardSlashRoot + '/app/src/Calc.Codeunit.al","statements":[{"id":1,"scope":"Calc.OnRun","line":4,"column":5,"endLine":4,"endColumn":10,"hits":1}]}]}'
            )
        }
        $summaryContent = '{"exitCode":0,"coverage":[{"file":"' + $forwardSlashRoot + '/app/src/Calc.Codeunit.al","statements":[{"id":1,"scope":"Calc.OnRun","line":4,"column":5,"endLine":4,"endColumn":10,"hits":1}]}],"perTestCoverage":[' + ($perTestEntries -join ',') + ']}'
        $summaryContent.Length | Should -BeGreaterThan 5000000

        $script:LargeSummaryFile = Join-Path $TestDrive 'large-summary.json'
        [System.IO.File]::WriteAllText($script:LargeSummaryFile, $summaryContent, [System.Text.UTF8Encoding]::new($false))

        $script:LargeOutputDirectory = Join-Path $TestDrive 'large-coverage'
        $script:LargeResult = Write-ALRunnerCoverageArtifacts -SummaryFile $script:LargeSummaryFile `
            -RepoRoot $script:LargeRepoRoot `
            -MainAppPath (Join-Path $script:LargeRepoRoot 'app') `
            -TestApps @((Join-Path $script:LargeRepoRoot 'test')) `
            -OutputDirectory $script:LargeOutputDirectory
    }

    It 'aggregates the large perTestCoverage payload without truncation' {
        $script:LargeResult.LinesValid | Should -Be 1
        $script:LargeResult.LinesCovered | Should -Be 1

        $perTestLines = Get-Content -LiteralPath $script:LargeResult.PerTestPath | ForEach-Object { $_ | ConvertFrom-Json }
        $hits = @($perTestLines | Where-Object kind -eq 'hit')
        $hits.Count | Should -Be $script:EntryCount
        ($hits | Measure-Object -Property hits -Sum).Sum | Should -Be $script:EntryCount
    }
}
