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

    function New-ALRunnerCoberturaFile {
        <#
            .SYNOPSIS
            Writes a Cobertura file shaped like al-runner's --coverage-out output:
            one package, repo-relative forward-slash class filenames spanning the
            main app and the test app. Calc.Codeunit.al lines 4,5,8,9 (all hit
            except line 5), T.Table.al line 5, and two test-app lines that the
            main-app result must exclude.
        #>
        param(
            [string]$OutputPath = (Join-Path $TestDrive 'al-runner-cobertura.xml')
        )

        Set-FileContent -Path $OutputPath -Content @'
<?xml version="1.0" encoding="utf-8"?>
<coverage line-rate="0.7143" branch-rate="0" lines-covered="5" lines-valid="7" branches-covered="0" branches-valid="0" complexity="0" version="al-runner" timestamp="0">
  <sources><source>.</source></sources>
  <packages>
    <package name="al-source" line-rate="0.7143" branch-rate="0" complexity="0">
      <classes>
        <class name="Calc" filename="app/src/Calc.Codeunit.al" line-rate="0.75" branch-rate="0" complexity="0">
          <methods />
          <lines>
            <line number="4" hits="3" />
            <line number="5" hits="0" />
            <line number="8" hits="1" />
            <line number="9" hits="1" />
          </lines>
        </class>
        <class name="T" filename="app/src/T.Table.al" line-rate="1" branch-rate="0" complexity="0">
          <methods />
          <lines>
            <line number="5" hits="1" />
          </lines>
        </class>
        <class name="CalcTest" filename="test/src/CalcTest.Codeunit.al" line-rate="0.5" branch-rate="0" complexity="0">
          <methods />
          <lines>
            <line number="4" hits="1" />
            <line number="9" hits="0" />
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
'@
        $OutputPath
    }
}

Describe 'Write-ALRunnerCoverageArtifacts' {
    BeforeAll {
        $script:FixtureRepoRoot = Join-Path $TestDrive 'repo'
        New-ALRunnerCoverageFixtureRepo -RepoRoot $script:FixtureRepoRoot
        $script:CoberturaFile = New-ALRunnerCoberturaFile
        $script:OutputDirectory = Join-Path $TestDrive 'coverage'

        $script:Result = Write-ALRunnerCoverageArtifacts -CoberturaFile $script:CoberturaFile `
            -RepoRoot $script:FixtureRepoRoot `
            -MainAppPath (Join-Path $script:FixtureRepoRoot 'app') `
            -OutputDirectory $script:OutputDirectory
        [xml]$script:Cobertura = Get-Content -LiteralPath $script:Result.CoberturaPath
    }

    It 'returns no per-test path — the al-runner CLI exposes no per-test attribution' {
        $script:Result.PerTestPath | Should -BeNullOrEmpty
    }

    It 'keeps only main-app classes in the written Cobertura' {
        $filenames = @($script:Cobertura.SelectNodes('//class') | ForEach-Object { $_.GetAttribute('filename') })
        $filenames | Should -Not -Contain 'test/src/CalcTest.Codeunit.al'
        $filenames | Should -Contain 'app/src/Calc.Codeunit.al'
        $filenames | Should -Contain 'app/src/T.Table.al'
    }

    It 'computes main-app-only LineRate as covered/valid rounded to 4 decimals' {
        $script:Result.LinesValid | Should -Be 5
        $script:Result.LinesCovered | Should -Be 4
        $script:Result.LineRate | Should -Be 0.8
        $script:Cobertura.coverage.'lines-valid' | Should -Be '5'
    }

    It 'lists the zero-hit line' {
        $lines = $script:Cobertura.coverage.packages.package.classes.class |
            Where-Object { $_.filename -eq 'app/src/Calc.Codeunit.al' } |
            Select-Object -ExpandProperty lines |
            Select-Object -ExpandProperty line
        ($lines | Where-Object number -eq '5').hits | Should -Be '0'
        ($lines | Where-Object number -eq '4').hits | Should -Be '3'
    }

    It 'produces byte-identical artifacts across two runs over the same Cobertura' {
        $secondResult = Write-ALRunnerCoverageArtifacts -CoberturaFile $script:CoberturaFile `
            -RepoRoot $script:FixtureRepoRoot `
            -MainAppPath (Join-Path $script:FixtureRepoRoot 'app') `
            -OutputDirectory (Join-Path $TestDrive 'coverage-2')

        $first = [System.IO.File]::ReadAllBytes($script:Result.CoberturaPath)
        $second = [System.IO.File]::ReadAllBytes($secondResult.CoberturaPath)
        [System.Convert]::ToBase64String($first) | Should -Be ([System.Convert]::ToBase64String($second))
    }
}

Describe 'Write-ALRunnerCoverageArtifacts failure paths' {
    BeforeAll {
        $script:FailFixtureRepoRoot = Join-Path $TestDrive 'fail-repo'
        New-ALRunnerCoverageFixtureRepo -RepoRoot $script:FailFixtureRepoRoot
        $script:FailMainAppPath = Join-Path $script:FailFixtureRepoRoot 'app'
    }

    It 'throws naming the Cobertura path when al-runner wrote none' {
        $missing = Join-Path $TestDrive 'never-written.xml'
        { Write-ALRunnerCoverageArtifacts -CoberturaFile $missing -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -OutputDirectory (Join-Path $TestDrive 'out-missing') } |
            Should -Throw "*$missing*"
    }

    It 'throws naming the Cobertura path when the file is not valid XML' {
        $malformed = Join-Path $TestDrive 'malformed.xml'
        Set-FileContent -Path $malformed -Content '<coverage><packages>'
        { Write-ALRunnerCoverageArtifacts -CoberturaFile $malformed -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -OutputDirectory (Join-Path $TestDrive 'out-malformed') } |
            Should -Throw "*$malformed*"
    }

    It 'throws naming the file when a covered main-app file cannot be parsed' {
        Set-FileContent -Path (Join-Path $script:FailMainAppPath 'src' 'NotAlObject.txt') -Content "just some text`nwith no object declaration`n"
        $cobertura = Join-Path $TestDrive 'unparsable.xml'
        Set-FileContent -Path $cobertura -Content @'
<?xml version="1.0" encoding="utf-8"?>
<coverage line-rate="1" lines-covered="1" lines-valid="1"><packages><package name="al-source"><classes>
<class name="x" filename="app/src/NotAlObject.txt"><lines><line number="1" hits="1" /></lines></class>
</classes></package></packages></coverage>
'@
        { Write-ALRunnerCoverageArtifacts -CoberturaFile $cobertura -RepoRoot $script:FailFixtureRepoRoot `
                -MainAppPath $script:FailMainAppPath -OutputDirectory (Join-Path $TestDrive 'out-unparsable') } |
            Should -Throw "*NotAlObject.txt*"
    }
}
