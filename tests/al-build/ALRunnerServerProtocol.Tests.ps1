#Requires -Version 7.2

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'alrunner-server.psm1') -Force -DisableNameChecking
}
Describe 'New-ALRunnerRunTestsRequest' {
    It 'emits coverage fields only when asked' {
        $r = New-ALRunnerRunTestsRequest -SourcePaths @('C:\a') | ConvertFrom-Json
        $r.command | Should -Be 'runTests'
        $r.PSObject.Properties.Name | Should -Not -Contain 'coverage'
        $r2 = New-ALRunnerRunTestsRequest -SourcePaths @('C:\a') -Coverage -PerTestCoverage | ConvertFrom-Json
        $r2.coverage | Should -BeTrue
        $r2.perTestCoverage | Should -BeTrue
    }
}
Describe 'Read-ALRunnerRunTestsResponse' {
    It 'parses a stream and lands the summary on disk' {
        $ndjson = @(
            '{"type":"test","name":"Codeunit50100.A","status":"pass","durationMs":3}'
            '{"type":"test","name":"Codeunit50100.B","status":"fail","durationMs":2,"message":"boom"}'
            '{"type":"summary","exitCode":1,"passed":1,"failed":1,"errors":0,"total":2,"cached":true,"wallSeconds":1.5,"protocolVersion":2}'
        ) -join "`n"
        $summaryPath = Join-Path $TestDrive 'summary.json'
        $r = Read-ALRunnerRunTestsResponse -Reader ([IO.StringReader]::new($ndjson)) -SummaryPath $summaryPath
        $r.Passed | Should -BeFalse
        $r.Total | Should -Be 2
        $r.Tests[1].Message | Should -Be 'boom'
        (Get-Content $summaryPath -Raw) | Should -Match '"protocolVersion":2'
    }
    It 'throws on a server error line' {
        $reader = [IO.StringReader]::new('{"error":"missing sourcePaths"}')
        { Read-ALRunnerRunTestsResponse -Reader $reader -SummaryPath (Join-Path $TestDrive 's.json') } | Should -Throw '*missing sourcePaths*'
    }
    It 'throws carrying the raw error line verbatim' {
        $reader = [IO.StringReader]::new('{"error":"missing sourcePaths"}')
        { Read-ALRunnerRunTestsResponse -Reader $reader -SummaryPath (Join-Path $TestDrive 's.json') } | Should -Throw '*{"error":"missing sourcePaths"}*'
    }
    It 'throws when the stream ends before a summary' {
        $reader = [IO.StringReader]::new('{"type":"test","name":"Codeunit1.A","status":"pass","durationMs":1}')
        { Read-ALRunnerRunTestsResponse -Reader $reader -SummaryPath (Join-Path $TestDrive 's.json') } | Should -Throw '*before summary*'
    }
    It 'parses a multi-megabyte summary line via JsonDocument without truncation' {
        # Synthesize ~5-10 MB of perTestCoverage so the summary line itself is large
        # enough to exercise the FileStream-backed JsonDocument parse path rather
        # than a small in-memory fixture.
        $entryCount = 25000
        $entries = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $entryCount; $i++) {
            $entries.Add('{"test":"Codeunit50100.Method' + $i + '","coverage":[{"file":"C:/app/src/Calc.Codeunit.al","statements":[{"id":1,"scope":"Calc.OnRun","line":4,"column":5,"endLine":4,"endColumn":10,"hits":1},{"id":2,"scope":"Calc.OnRun","line":5,"column":5,"endLine":5,"endColumn":10,"hits":0}]}]}')
        }
        $perTestCoverageJson = '[' + ($entries -join ',') + ']'
        $summaryLine = '{"type":"summary","exitCode":0,"passed":' + $entryCount + ',"failed":0,"errors":0,"total":' + $entryCount + ',"cached":false,"wallSeconds":12.5,"protocolVersion":2,"coverage":[],"perTestCoverage":' + $perTestCoverageJson + '}'
        $summaryLine.Length | Should -BeGreaterThan 5000000

        $ndjson = $summaryLine
        $summaryPath = Join-Path $TestDrive 'large-summary.json'
        $r = Read-ALRunnerRunTestsResponse -Reader ([IO.StringReader]::new($ndjson)) -SummaryPath $summaryPath

        $r.Passed | Should -BeTrue
        $r.Total | Should -Be $entryCount
        $r.WallSeconds | Should -Be 12.5
        (Get-Item -LiteralPath $summaryPath).Length | Should -BeGreaterThan 5000000
    }
    It 'throws naming the summary path on a malformed summary line' {
        $ndjson = '{"type":"summary","exitCode":0,"total":1,'
        $summaryPath = Join-Path $TestDrive 'malformed-summary.json'
        { Read-ALRunnerRunTestsResponse -Reader ([IO.StringReader]::new($ndjson)) -SummaryPath $summaryPath } | Should -Throw "*$summaryPath*"
    }
}
Describe 'Write-ALRunnerJUnit' {
    It 'groups by codeunit and escapes messages' {
        $tests = @(
            [pscustomobject]@{ Name = 'Codeunit50100.A'; Status = 'pass'; DurationMs = 3; Message = $null }
            [pscustomobject]@{ Name = 'Codeunit50100.B'; Status = 'fail'; DurationMs = 2; Message = 'x < y & "z"' }
        )
        $path = Join-Path $TestDrive 'junit.xml'
        Write-ALRunnerJUnit -Tests $tests -Path $path
        [xml]$x = Get-Content $path
        $x.testsuites.tests | Should -Be '2'
        $x.testsuites.testsuite.name | Should -Be 'Codeunit50100'
        ($x.testsuites.testsuite.testcase | Where-Object name -eq 'B').failure.message | Should -Be 'x < y & "z"'
    }
    It 'marks a skipped test with a skipped child element and a skipped count' {
        $tests = @(
            [pscustomobject]@{ Name = 'Codeunit50100.A'; Status = 'pass'; DurationMs = 3; Message = $null }
            [pscustomobject]@{ Name = 'Codeunit50100.C'; Status = 'skipped'; DurationMs = 0; Message = $null }
        )
        $path = Join-Path $TestDrive 'junit-skipped.xml'
        Write-ALRunnerJUnit -Tests $tests -Path $path
        [xml]$x = Get-Content $path
        $x.testsuites.skipped | Should -Be '1'
        $x.testsuites.testsuite.skipped | Should -Be '1'
        $skippedCase = $x.testsuites.testsuite.testcase | Where-Object name -eq 'C'
        $skippedCase.SelectSingleNode('skipped') | Should -Not -BeNullOrEmpty
    }
}
