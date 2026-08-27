#Requires -Version 7.2

BeforeAll {
function Test-LiveCoverageFixtureMetadata {
    param(
        [Parameter(Mandatory)]
        [psobject]$Metadata
    )

    $requiredFields = @(
        'schemaVersion',
        'bcArtifactUrl',
        'bcVersion',
        'bcContainerHelperVersion',
        'helperAppId',
        'helperAppVersion',
        'rawXmlSchemaVersion',
        'lineNumberBase',
        'lineMatches',
        'capturedAtUtc',
        'sanitization',
        'generatedObjectIds',
        'testApps',
        'expectedJUnitVerdict',
        'terminalDrain'
    )
    foreach ($field in $requiredFields) {
        if (-not $Metadata.PSObject.Properties[$field]) {
            throw "Live coverage fixture metadata is missing '$field'."
        }
    }

    if ($Metadata.schemaVersion -ne 1 -or $Metadata.rawXmlSchemaVersion -ne 1) {
        throw 'Live coverage fixture metadata has an unsupported schema version.'
    }
    try {
        $artifactUri = [uri]$Metadata.bcArtifactUrl
        $null = [version]$Metadata.bcVersion
        $null = [version]$Metadata.bcContainerHelperVersion
        $null = [guid]$Metadata.helperAppId
        $null = [version]$Metadata.helperAppVersion
        $null = [datetimeoffset]::Parse([string]$Metadata.capturedAtUtc)
    } catch {
        throw "Live coverage fixture metadata has an invalid identity, version, URL, or timestamp: $($_.Exception.Message)"
    }
    if (-not $artifactUri.IsAbsoluteUri -or $artifactUri.Scheme -ne 'https' -or
        $artifactUri.AbsolutePath -notmatch "/$([regex]::Escape($Metadata.bcVersion))/w1$") {
        throw 'Live coverage fixture metadata has an invalid BC artifact URL.'
    }
    if ($Metadata.lineNumberBase -ne 1 -or @($Metadata.lineMatches).Count -lt 2) {
        throw 'Live coverage fixture metadata does not record the proven 1-based line result.'
    }
    foreach ($lineMatch in @($Metadata.lineMatches)) {
        foreach ($field in @('objectId', 'sourceLine', 'returnedLineNumber', 'physicalOneBasedLine')) {
            if (-not $lineMatch.PSObject.Properties[$field]) {
                throw "Live coverage fixture metadata line match is missing '$field'."
            }
        }
    }
    foreach ($field in @(
        'rule',
        'replacement',
        'sanitizedForeignSourceLineCount',
        'runtimeRawWasModified'
    )) {
        if (-not $Metadata.sanitization.PSObject.Properties[$field]) {
            throw "Live coverage fixture metadata sanitization is missing '$field'."
        }
    }
    if ($Metadata.sanitization.rule -ne
        'Only SourceLine values belonging to objects outside the generated fixture apps are replaced.' -or
        $Metadata.sanitization.replacement -ne '[sanitized]' -or
        [int]$Metadata.sanitization.sanitizedForeignSourceLineCount -lt 0 -or
        $Metadata.sanitization.runtimeRawWasModified -ne $false) {
        throw 'Live coverage fixture metadata has an invalid sanitization rule.'
    }
    if (@($Metadata.generatedObjectIds).Count -lt 3 -or
        @($Metadata.testApps).Count -lt 2 -or
        $Metadata.expectedJUnitVerdict -ne 'red' -or
        $Metadata.terminalDrain.sentinel -ne 'Done.' -or
        $Metadata.terminalDrain.requiredConsecutiveResponses -ne 2) {
        throw 'Live coverage fixture metadata is incomplete.'
    }

    $true
}

function Resolve-LiveCoverageLineNumberBase {
    param(
        [Parameter(Mandatory)]
        [int[]]$Offsets
    )

    $uniqueOffsets = @($Offsets | Select-Object -Unique)
    if ($uniqueOffsets.Count -ne 1) {
        throw 'Live coverage fixture line-number offsets must have one unique value.'
    }

    $offset = [int]$uniqueOffsets[0]
    if ($offset -notin @(-1, 0)) {
        throw "Live coverage fixture line-number offset must be -1 or 0, but was '$offset'."
    }

    if ($offset -eq -1) {
        return 0
    }
    1
}

function Read-LiveCoverageFixtureMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $metadata = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Live coverage fixture metadata '$Path' is invalid JSON: $($_.Exception.Message)"
    }
    Test-LiveCoverageFixtureMetadata -Metadata $metadata | Out-Null
    $metadata
}

    $script:FixtureRoot = Join-Path $PSScriptRoot 'fixtures' 'code-coverage-live'
    $script:Metadata = Read-LiveCoverageFixtureMetadata -Path (
        Join-Path $script:FixtureRoot 'metadata.json'
    )
    $script:HelperManifest = Get-Content -LiteralPath (
        Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'code-coverage-helper' 'app.json'
    ) -Raw | ConvertFrom-Json
    Import-Module (
        Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'coverage-runtime.psm1'
    ) -Force -DisableNameChecking
    $script:Manifests = @{}
    $script:PayloadPaths = [System.Collections.Generic.List[string]]::new()
    $script:Records = [System.Collections.Generic.List[object]]::new()

    foreach ($testApp in @('test-pass', 'test-fail')) {
        $rawRoot = Join-Path $script:FixtureRoot 'raw' $testApp
        $script:Manifests[$testApp] = Get-Content -LiteralPath (
            Join-Path $rawRoot 'manifest.json'
        ) -Raw | ConvertFrom-Json
        foreach ($payload in Get-ChildItem -LiteralPath $rawRoot -Filter 'payload-*.xml' -File) {
            $script:PayloadPaths.Add($payload.FullName)
            [xml]$document = Get-Content -LiteralPath $payload.FullName -Raw
            foreach ($record in @($document.CodeCoverage.CoverageLine)) {
                $script:Records.Add([pscustomobject]@{
                    TestApp = $testApp
                    ObjectTypeCode = [string]$record.ObjectTypeCode
                    ObjectTypeName = [string]$record.ObjectTypeName
                    ObjectId = [int]$record.ObjectId
                    LineNumber = [int]$record.LineNumber
                    LineTypeCode = [string]$record.LineTypeCode
                    LineTypeName = [string]$record.LineTypeName
                    CoverageStatusCode = [string]$record.CoverageStatusCode
                    CoverageStatusName = [string]$record.CoverageStatusName
                    HitCount = [int]$record.HitCount
                    SourceLine = [string]$record.SourceLine
                })
            }
        }
    }
}

Describe 'Live BC code coverage fixture' -Tag 'LiveFixture' {
    It 'records the live environment and helper contract without host details' {
        Test-LiveCoverageFixtureMetadata -Metadata $script:Metadata | Should -BeTrue
        $script:Metadata.schemaVersion | Should -Be 1
        $script:Metadata.bcArtifactUrl | Should -Match (
            "/$([regex]::Escape($script:Metadata.bcVersion))/w1$"
        )
        [version]$script:Metadata.bcContainerHelperVersion | Should -BeGreaterOrEqual '1.0'
        $script:Metadata.helperAppId | Should -Be $script:HelperManifest.id
        $script:Metadata.helperAppVersion | Should -Be $script:HelperManifest.version
        $script:Metadata.rawXmlSchemaVersion | Should -Be 1
        $script:Metadata.expectedJUnitVerdict | Should -Be 'red'
        $script:Metadata.terminalDrain.sentinel | Should -Be 'Done.'
        $script:Metadata.terminalDrain.requiredConsecutiveResponses | Should -Be 2
        { [datetimeoffset]::Parse($script:Metadata.capturedAtUtc) } | Should -Not -Throw

        $fixtureText = Get-ChildItem -LiteralPath $script:FixtureRoot -Recurse -File |
            ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
        ($fixtureText -join "`n") |
            Should -Not -Match '(?i)([A-Z]:\\|AppData|ProgramData|al-build-coverage-spine|cov-[0-9a-f]{10}|P@ssw0rd)'
        ($fixtureText -join "`n") | Should -Not -Match (
            '(?i)"(?:credential|password|username|machinePath|containerName|' +
            'hostName|hostDetails|computerName)"\s*:'
        )
    }

    It 'rejects malformed or incomplete fixture metadata' {
        $invalidJsonPath = Join-Path $TestDrive 'invalid-metadata.json'
        '{' | Set-Content -LiteralPath $invalidJsonPath
        {
            Read-LiveCoverageFixtureMetadata -Path $invalidJsonPath
        } | Should -Throw '*is invalid JSON*'

        foreach ($field in @(
            'schemaVersion',
            'bcArtifactUrl',
            'bcVersion',
            'bcContainerHelperVersion',
            'helperAppId',
            'helperAppVersion',
            'rawXmlSchemaVersion',
            'lineNumberBase',
            'lineMatches',
            'capturedAtUtc',
            'sanitization',
            'generatedObjectIds',
            'testApps',
            'expectedJUnitVerdict',
            'terminalDrain'
        )) {
            $incomplete = $script:Metadata | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            $incomplete.PSObject.Properties.Remove($field)
            {
                Test-LiveCoverageFixtureMetadata -Metadata $incomplete
            } | Should -Throw "*missing '$field'*"
        }
    }

    It 'contains separate complete collections for the passing and failing tests' {
        $totalTests = 0
        $identities = [System.Collections.Generic.List[string]]::new()
        foreach ($testApp in @('test-pass', 'test-fail')) {
            $manifest = $script:Manifests[$testApp]
            $payloads = @(Get-ChildItem -LiteralPath (
                Join-Path $script:FixtureRoot 'raw' $testApp
            ) -Filter 'payload-*.xml' -File)

            $manifest.testApp | Should -Be $testApp
            $manifest.payloadCount | Should -Be $payloads.Count
            $manifest.payloadCount | Should -BeGreaterThan 0
            $manifest.terminalDoneCount | Should -Be 2
            $manifest.doneValue | Should -Be 'Done.'
            $manifest.drainResponseCount | Should -BeGreaterOrEqual 3
            $manifest.payloads.file | Should -Be $payloads.Name
            $totalTests += [int]$manifest.junitTestCount
            foreach ($payload in $manifest.payloads) {
                $identities.Add("$($payload.testCodeunitId):$($payload.testMethod)")
            }
            Test-BcCoverageCollection -Path (
                Join-Path $script:FixtureRoot 'raw' $testApp
            ) -ExpectedTestApp $testApp | Should -BeTrue
        }

        $totalTests | Should -BeGreaterOrEqual 2
        @($identities | Select-Object -Unique).Count | Should -Be 2
        $script:Manifests['test-pass'].payloads[0].testCodeunitId | Should -Be 74101
        $script:Manifests['test-pass'].payloads[0].testMethod | Should -Be 'PassingTest'
        $script:Manifests['test-fail'].payloads[0].testCodeunitId | Should -Be 74102
        $script:Manifests['test-fail'].payloads[0].testMethod |
            Should -Be 'IntentionalFailureAfterMainCode'
        $passingSource = Get-Content -LiteralPath (
            Join-Path $script:FixtureRoot 'test-pass' 'src' 'PassingTests.Codeunit.al'
        ) -Raw
        $passingSource | Should -Match (
            'Result := CoverageSpine\.CoveredPath\(false\);\s+' +
            'if Result <> 42 then\s+Error'
        )
        $failingSource = Get-Content -LiteralPath (
            Join-Path $script:FixtureRoot 'test-fail' 'src' 'FailingTests.Codeunit.al'
        ) -Raw
        $failingSource | Should -Match (
            'Result := CoverageSpine\.CoveredPath\(false\);[\s\S]+' +
            "Error\('Intentional issue 75 live proof failure\.'\);"
        )
    }

    It 'pins the raw schema, numeric enum codes, and distinct per-test payloads' {
        foreach ($payloadPath in $script:PayloadPaths) {
            { Test-BcCoveragePayload -Path $payloadPath } | Should -Not -Throw
        }
        @($script:Records | Where-Object {
            [string]::IsNullOrWhiteSpace($_.LineTypeName)
        }).Count | Should -Be 0

        (Get-FileHash -LiteralPath $script:PayloadPaths[0]).Hash |
            Should -Not -Be (Get-FileHash -LiteralPath $script:PayloadPaths[1]).Hash

        @($script:Records.ObjectTypeCode | Select-Object -Unique) | Should -Be @('5')
        @($script:Records.ObjectTypeName | Select-Object -Unique) | Should -Be @('Codeunit')
        @($script:Records | Group-Object LineTypeCode | Sort-Object Name |
            ForEach-Object {
                "$($_.Name):$(@($_.Group.LineTypeName | Select-Object -Unique) -join ',')"
            }) | Should -Be @(
                '0:Object',
                '1:Trigger/Function',
                '2:Empty',
                '3:Code'
            )
        @($script:Records | Group-Object CoverageStatusCode | Sort-Object Name |
            ForEach-Object {
                "$($_.Name):$(@($_.Group.CoverageStatusName | Select-Object -Unique) -join ',')"
            }) | Should -Be @(
                '0:Non Applicable',
                '1:Not Covered',
                '2:Covered'
            )
    }

    It 'contains the complete main-app denominator and Test Runner records' {
        @($script:Records | Where-Object {
            $_.ObjectId -eq 74100 -and $_.LineTypeCode -eq '3' -and
            $_.CoverageStatusCode -eq '2' -and $_.HitCount -gt 0
        }).Count | Should -BeGreaterThan 0
        @($script:Records | Where-Object {
            $_.ObjectId -eq 74100 -and $_.LineTypeCode -eq '3' -and
            $_.CoverageStatusCode -eq '1' -and $_.HitCount -eq 0
        }).Count | Should -BeGreaterThan 0
        $script:Records.ObjectId | Should -Contain 74100
        $script:Records.ObjectId | Should -Contain 130454
    }

    It 'redacts only foreign source lines and records the exact sanitization count' {
        $generatedIds = @($script:Metadata.generatedObjectIds | ForEach-Object { [int]$_ })
        $foreign = @($script:Records | Where-Object { $_.ObjectId -notin $generatedIds })
        $generated = @($script:Records | Where-Object { $_.ObjectId -in $generatedIds })

        @($foreign | Where-Object { $_.SourceLine -ne '[sanitized]' }).Count | Should -Be 0
        @($generated | Where-Object { $_.SourceLine -eq '[sanitized]' }).Count | Should -Be 0
        $script:Metadata.sanitization.sanitizedForeignSourceLineCount |
            Should -Be $foreign.Count
        $script:Metadata.sanitization.replacement | Should -Be '[sanitized]'
        $script:Metadata.sanitization.runtimeRawWasModified | Should -BeFalse
    }

    It 'rejects a uniform impossible line-number shift' {
        {
            Resolve-LiveCoverageLineNumberBase -Offsets @(5, 5)
        } | Should -Throw '*must be -1 or 0*'
    }

    It 'derives the recorded line-number base from committed physical AL lines' {
        $sourceLines = @(Get-Content -LiteralPath (
            Join-Path $script:FixtureRoot 'main' 'src' 'CoverageSpine.Codeunit.al'
        ))
        $matches = @($script:Metadata.lineMatches)
        $matches.Count | Should -BeGreaterOrEqual 2
        $offsets = foreach ($match in $matches) {
            $physicalLine = [int]$match.physicalOneBasedLine
            $sourceLines[$physicalLine - 1].Trim() | Should -Be $match.sourceLine
            @($script:Records | Where-Object {
                $_.ObjectId -eq [int]$match.objectId -and
                $_.LineNumber -eq [int]$match.returnedLineNumber -and
                $_.SourceLine.Trim() -eq $match.sourceLine
            }).Count | Should -BeGreaterThan 0
            [int]$match.returnedLineNumber - $physicalLine
        }

        $derivedBase = Resolve-LiveCoverageLineNumberBase -Offsets $offsets
        $derivedBase | Should -Be $script:Metadata.lineNumberBase
    }
}
