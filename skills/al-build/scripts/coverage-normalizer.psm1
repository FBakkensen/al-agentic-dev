#Requires -Version 7.2

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ObjectTypeDefinitions = @{
    1  = [pscustomobject]@{ CanonicalName = 'Table'; DeclarationType = 'table' }
    3  = [pscustomobject]@{ CanonicalName = 'Report'; DeclarationType = 'report' }
    5  = [pscustomobject]@{ CanonicalName = 'Codeunit'; DeclarationType = 'codeunit' }
    6  = [pscustomobject]@{ CanonicalName = 'XMLport'; DeclarationType = 'xmlport' }
    8  = [pscustomobject]@{ CanonicalName = 'Page'; DeclarationType = 'page' }
    9  = [pscustomobject]@{ CanonicalName = 'Query'; DeclarationType = 'query' }
    14 = [pscustomobject]@{ CanonicalName = 'PageExtension'; DeclarationType = 'pageextension' }
    15 = [pscustomobject]@{ CanonicalName = 'TableExtension'; DeclarationType = 'tableextension' }
    16 = [pscustomobject]@{ CanonicalName = 'Enum'; DeclarationType = 'enum' }
    17 = [pscustomobject]@{ CanonicalName = 'EnumExtension'; DeclarationType = 'enumextension' }
    18 = [pscustomobject]@{ CanonicalName = 'Profile'; DeclarationType = 'profile' }
    19 = [pscustomobject]@{ CanonicalName = 'ProfileExtension'; DeclarationType = 'profileextension' }
    20 = [pscustomobject]@{ CanonicalName = 'PermissionSet'; DeclarationType = 'permissionset' }
    21 = [pscustomobject]@{ CanonicalName = 'PermissionSetExtension'; DeclarationType = 'permissionsetextension' }
    22 = [pscustomobject]@{ CanonicalName = 'ReportExtension'; DeclarationType = 'reportextension' }
}
$script:DeclarationTypeToObjectTypeCode = @{}
foreach ($objectTypeCode in @($script:ObjectTypeDefinitions.Keys | Sort-Object)) {
    $definition = $script:ObjectTypeDefinitions[$objectTypeCode]
    $script:DeclarationTypeToObjectTypeCode[$definition.DeclarationType] = [int]$objectTypeCode
}
$script:SupportedObjectTypePattern = (
    @($script:DeclarationTypeToObjectTypeCode.Keys | Sort-Object Length -Descending) -join '|'
)
$script:SupportedDeclarationPattern = '^\s*(?<type>' + $script:SupportedObjectTypePattern + ')\s+(?<id>\d+)\s+(?<name>"(?:""|[^"])+?"|[A-Za-z_][A-Za-z0-9_]*)\s*(?<suffix>.*)$'
$script:UnsafeSupportedDeclarationPattern = '^\s*(?<type>' + $script:SupportedObjectTypePattern + ')\s+\d+\b'
$script:SupportedLineTypeCodes = @(0, 1, 2, 3)
$script:SupportedCoverageStatusCodes = @(0, 1, 2, 3)

function ConvertFrom-AlIdentifier {
    param(
        [Parameter(Mandatory)]
        [string]$Token
    )

    if ($Token.StartsWith('"', [System.StringComparison]::Ordinal) -and
        $Token.EndsWith('"', [System.StringComparison]::Ordinal)) {
        return $Token.Substring(1, $Token.Length - 2).Replace('""', '"')
    }

    $Token
}

function Normalize-AlDeclarationType {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    ($Name -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

function Get-CoverageObjectTypeDefinition {
    param(
        [Parameter(Mandatory)]
        [int]$Code,

        [string]$DiagnosticName,

        [string]$PayloadPath
    )

    if ($script:ObjectTypeDefinitions.ContainsKey($Code)) {
        return $script:ObjectTypeDefinitions[$Code]
    }

    if ($PayloadPath) {
        throw "Coverage payload '$PayloadPath' has unsupported object type code '${Code}:$DiagnosticName'."
    }

    throw "Unsupported coverage object type code '$Code'."
}

function Get-CoverageObjectTypeCodeForDeclaration {
    param(
        [Parameter(Mandatory)]
        [string]$DeclarationType
    )

    $normalized = Normalize-AlDeclarationType -Name $DeclarationType
    if (-not $script:DeclarationTypeToObjectTypeCode.ContainsKey($normalized)) {
        throw "Unsupported AL declaration type '$DeclarationType'."
    }

    [int]$script:DeclarationTypeToObjectTypeCode[$normalized]
}

function Split-TextLines {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    [regex]::Split($Text, '\r\n|\n|\r')
}

function Remove-AlCommentsPreserveLayout {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $builder = [System.Text.StringBuilder]::new($Text.Length)
    $mode = 'Normal'

    for ($index = 0; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

        switch ($mode) {
            'Normal' {
                if ($character -eq '/' -and $next -eq '/') {
                    $null = $builder.Append(' ')
                    $null = $builder.Append(' ')
                    $index++
                    $mode = 'LineComment'
                    continue
                }
                if ($character -eq '/' -and $next -eq '*') {
                    $null = $builder.Append(' ')
                    $null = $builder.Append(' ')
                    $index++
                    $mode = 'BlockComment'
                    continue
                }
                if ($character -eq '''') {
                    $null = $builder.Append($character)
                    $mode = 'SingleQuote'
                    continue
                }
                if ($character -eq '"') {
                    $null = $builder.Append($character)
                    $mode = 'DoubleQuote'
                    continue
                }
                $null = $builder.Append($character)
            }
            'LineComment' {
                if ($character -eq "`r" -or $character -eq "`n") {
                    $null = $builder.Append($character)
                    $mode = 'Normal'
                } else {
                    $null = $builder.Append(' ')
                }
            }
            'BlockComment' {
                if ($character -eq '*' -and $next -eq '/') {
                    $null = $builder.Append(' ')
                    $null = $builder.Append(' ')
                    $index++
                    $mode = 'Normal'
                } elseif ($character -eq "`r" -or $character -eq "`n") {
                    $null = $builder.Append($character)
                } else {
                    $null = $builder.Append(' ')
                }
            }
            'SingleQuote' {
                $null = $builder.Append($character)
                if ($character -eq '''') {
                    if ($next -eq '''') {
                        $null = $builder.Append($next)
                        $index++
                    } else {
                        $mode = 'Normal'
                    }
                }
            }
            'DoubleQuote' {
                $null = $builder.Append($character)
                if ($character -eq '"') {
                    if ($next -eq '"') {
                        $null = $builder.Append($next)
                        $index++
                    } else {
                        $mode = 'Normal'
                    }
                }
            }
        }
    }

    $builder.ToString()
}

function Resolve-RepoRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $Path).Replace('\', '/')
    if ($relative.StartsWith('..', [System.StringComparison]::Ordinal)) {
        throw "Source file '$Path' is outside repo root '$RepoRoot'."
    }

    $relative
}

function Get-AlObjectIndex {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$AppPath,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $appManifestPath = Join-Path $AppPath 'app.json'
    if (-not (Test-Path -LiteralPath $appManifestPath -PathType Leaf)) {
        throw "$Label '$AppPath' has no app.json."
    }

    $index = @{}
    $sourceFiles = @(
        Get-ChildItem -LiteralPath $AppPath -Recurse -File -Filter '*.al' |
            Where-Object { $_.FullName -notmatch '[\\/]\.alpackages([\\/]|$)' } |
            Sort-Object FullName
    )
    if ($sourceFiles.Count -eq 0) {
        throw "$Label '$AppPath' contains no AL source files."
    }

    foreach ($sourceFile in $sourceFiles) {
        $text = [System.IO.File]::ReadAllText($sourceFile.FullName)
        $sanitized = Remove-AlCommentsPreserveLayout -Text $text
        $rawLines = Split-TextLines -Text $text
        $sanitizedLines = Split-TextLines -Text $sanitized

        if ($rawLines.Count -ne $sanitizedLines.Count) {
            throw "AL source '$($sourceFile.FullName)' could not preserve line layout during comment stripping."
        }

        for ($lineIndex = 0; $lineIndex -lt $sanitizedLines.Count; $lineIndex++) {
            $lineNumber = $lineIndex + 1
            $sanitizedLine = $sanitizedLines[$lineIndex]
            $rawLine = $rawLines[$lineIndex].TrimEnd()

            if ($sanitizedLine -match $script:UnsafeSupportedDeclarationPattern -and
                $sanitizedLine -notmatch $script:SupportedDeclarationPattern) {
                throw "$Label source '$($sourceFile.FullName)' has a declaration on line $lineNumber that cannot be indexed safely: $rawLine"
            }

            $match = [regex]::Match(
                $sanitizedLine,
                $script:SupportedDeclarationPattern,
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
            if (-not $match.Success) {
                continue
            }

            $objectTypeCode = Get-CoverageObjectTypeCodeForDeclaration -DeclarationType $match.Groups['type'].Value
            $objectTypeDefinition = Get-CoverageObjectTypeDefinition -Code $objectTypeCode
            $objectId = [int]$match.Groups['id'].Value
            $objectName = ConvertFrom-AlIdentifier -Token $match.Groups['name'].Value
            $key = "$objectTypeCode|$objectId"

            if ($index.ContainsKey($key)) {
                $existing = $index[$key]
                throw "$Label '$AppPath' declares $($match.Groups['type'].Value) $objectId more than once: '$($existing.SourcePath)' line $($existing.DeclarationLineNumber) and '$(
                    Resolve-RepoRelativePath -RepoRoot $RepoRoot -Path $sourceFile.FullName
                )' line $lineNumber."
            }

            $index[$key] = [pscustomobject]@{
                Key                   = $key
                ObjectTypeCode        = $objectTypeCode
                ObjectType            = $objectTypeDefinition.CanonicalName
                ObjectId              = $objectId
                ObjectName            = $objectName
                SourcePath            = Resolve-RepoRelativePath -RepoRoot $RepoRoot -Path $sourceFile.FullName
                FilePath              = $sourceFile.FullName
                DeclarationLineNumber = $lineNumber
                Lines                 = $rawLines
            }
        }
    }

    if ($index.Count -eq 0) {
        throw "$Label '$AppPath' contains no indexable AL object declarations."
    }

    $index
}

function Resolve-CoverageCollectionPath {
    param(
        [Parameter(Mandatory)]
        [string]$RawCollectionPath
    )

    $manifestPath = Join-Path $RawCollectionPath 'manifest.json'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        return $RawCollectionPath
    }

    $collections = @(
        Get-ChildItem -LiteralPath $RawCollectionPath -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') -PathType Leaf } |
            Sort-Object Name
    )
    if ($collections.Count -eq 0) {
        throw "Coverage raw collection '$RawCollectionPath' does not contain a manifest.json or any test-app collection folders."
    }
    if ($collections.Count -gt 1) {
        throw "Coverage normalization supports exactly one configured container test app. Found [$(@($collections | ForEach-Object Name) -join ', ')]. Issue 77 owns multi-app aggregation."
    }

    $collections[0].FullName
}

function Read-CoverageCollectionManifest {
    param(
        [Parameter(Mandatory)]
        [string]$CollectionPath
    )

    $manifestPath = Join-Path $CollectionPath 'manifest.json'
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    } catch {
        throw "Coverage manifest '$manifestPath' is invalid: $($_.Exception.Message)"
    }

    foreach ($fieldName in @(
        'schemaVersion',
        'testApp',
        'junitTestCount',
        'payloadCount',
        'drainResponseCount',
        'terminalDoneCount',
        'doneValue',
        'payloads'
    )) {
        if (-not $manifest.PSObject.Properties[$fieldName]) {
            throw "Coverage manifest '$manifestPath' is missing required field '$fieldName'."
        }
    }
    if ([int]$manifest.schemaVersion -ne 1) {
        throw "Coverage manifest '$manifestPath' does not declare supported schemaVersion 1."
    }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.testApp)) {
        throw "Coverage manifest '$manifestPath' has no testApp value."
    }
    if ([int]$manifest.junitTestCount -le 0) {
        throw "Coverage manifest '$manifestPath' has no positive JUnit test count."
    }
    if ([int]$manifest.terminalDoneCount -ne 2 -or [string]$manifest.doneValue -ne 'Done.') {
        throw "Coverage manifest '$manifestPath' does not prove two consecutive 'Done.' responses."
    }

    $payloads = @($manifest.payloads)
    if ([int]$manifest.payloadCount -ne $payloads.Count) {
        throw "Coverage manifest '$manifestPath' payload count does not match its entries."
    }
    if ($payloads.Count -eq 0) {
        throw "Coverage collection '$CollectionPath' contains zero payloads."
    }
    if ([int]$manifest.drainResponseCount -lt ($payloads.Count + 2)) {
        throw "Coverage manifest '$manifestPath' has an invalid drain response count."
    }

    $identities = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    for ($index = 0; $index -lt $payloads.Count; $index++) {
        $payload = $payloads[$index]
        $expectedOrder = $index + 1
        foreach ($fieldName in @('order', 'testCodeunitId', 'testMethod', 'file')) {
            if (-not $payload.PSObject.Properties[$fieldName]) {
                throw "Coverage manifest '$manifestPath' entry $expectedOrder is missing required field '$fieldName'."
            }
        }
        if ([int]$payload.order -ne $expectedOrder) {
            throw "Coverage manifest '$manifestPath' is not sequential at entry $expectedOrder."
        }
        if ([int]$payload.testCodeunitId -le 0 -or
            [string]::IsNullOrWhiteSpace([string]$payload.testMethod)) {
            throw "Coverage manifest '$manifestPath' has an incomplete test identity at entry $expectedOrder."
        }

        $identity = "$($manifest.testApp)|$([int]$payload.testCodeunitId)|$([string]$payload.testMethod)"
        if (-not $identities.Add($identity)) {
            throw "Coverage collection '$CollectionPath' contains duplicate test identity '$identity'."
        }

        $payloadPath = Join-Path $CollectionPath $payload.file
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw "Coverage payload '$payloadPath' is missing."
        }
    }

    [pscustomobject]@{
        CollectionPath = $CollectionPath
        ManifestPath   = $manifestPath
        TestApp        = [string]$manifest.testApp
        Payloads       = $payloads
    }
}

function Read-CoveragePayloadRows {
    param(
        [Parameter(Mandatory)]
        [string]$PayloadPath
    )

    try {
        [xml]$document = Get-Content -LiteralPath $PayloadPath -Raw
    } catch {
        throw "Coverage payload '$PayloadPath' is not valid XML: $($_.Exception.Message)"
    }

    $root = $document.DocumentElement
    if (-not $root -or $root.LocalName -ne 'CodeCoverage') {
        throw "Coverage payload '$PayloadPath' has unexpected root '$($root.LocalName)'."
    }
    if (-not $root.HasAttribute('SchemaVersion') -or $root.GetAttribute('SchemaVersion') -ne '1') {
        throw "Coverage payload '$PayloadPath' does not declare supported SchemaVersion 1."
    }

    $records = @($root.ChildNodes | Where-Object { $_.LocalName -eq 'CoverageLine' })
    if ($records.Count -eq 0) {
        throw "Coverage payload '$PayloadPath' contains no coverage records."
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $rawKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $requiredFields = @(
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
    )

    foreach ($record in $records) {
        $fields = @{}
        foreach ($fieldName in $requiredFields) {
            $field = @($record.ChildNodes | Where-Object { $_.LocalName -eq $fieldName })[0]
            if (-not $field) {
                throw "Coverage payload '$PayloadPath' record is missing '$fieldName'."
            }
            $fields[$fieldName] = [string]$field.InnerText
        }

        foreach ($numericField in @(
            'ObjectTypeCode',
            'ObjectId',
            'LineNumber',
            'LineTypeCode',
            'CoverageStatusCode',
            'HitCount'
        )) {
            $numericValue = 0
            if (-not [int]::TryParse($fields[$numericField], [ref]$numericValue)) {
                throw "Coverage payload '$PayloadPath' record field '$numericField' is not an integer."
            }
            $fields[$numericField] = $numericValue
        }

        $objectTypeDefinition = Get-CoverageObjectTypeDefinition `
            -Code $fields.ObjectTypeCode `
            -DiagnosticName $fields.ObjectTypeName `
            -PayloadPath $PayloadPath
        if ($fields.LineTypeCode -notin $script:SupportedLineTypeCodes) {
            throw "Coverage payload '$PayloadPath' has unsupported line type code '$($fields.LineTypeCode):$($fields.LineTypeName)'."
        }
        if ($fields.CoverageStatusCode -notin $script:SupportedCoverageStatusCodes) {
            throw "Coverage payload '$PayloadPath' has unsupported coverage status code '$($fields.CoverageStatusCode):$($fields.CoverageStatusName)'."
        }
        if ($fields.ObjectId -le 0 -or $fields.LineNumber -lt 0) {
            throw "Coverage payload '$PayloadPath' has invalid object or line numbers."
        }

        switch ($fields.LineTypeCode) {
            0 {
                if ($fields.LineNumber -ne 0 -or
                    $fields.CoverageStatusCode -ne 0 -or
                    $fields.HitCount -ne 0) {
                    throw "Coverage payload '$PayloadPath' object row '$($fields.ObjectTypeName) $($fields.ObjectId)' has invalid line/status semantics."
                }
            }
            1 {
                if ($fields.LineNumber -le 0 -or
                    $fields.CoverageStatusCode -ne 0 -or
                    $fields.HitCount -ne 0) {
                    throw "Coverage payload '$PayloadPath' trigger/function row '$($fields.ObjectTypeName) $($fields.ObjectId)' line $($fields.LineNumber) has invalid status semantics."
                }
            }
            2 {
                if ($fields.LineNumber -le 0 -or
                    $fields.CoverageStatusCode -ne 0 -or
                    $fields.HitCount -ne 0) {
                    throw "Coverage payload '$PayloadPath' empty row '$($fields.ObjectTypeName) $($fields.ObjectId)' line $($fields.LineNumber) has invalid status semantics."
                }
            }
            3 {
                if ($fields.LineNumber -le 0) {
                    throw "Coverage payload '$PayloadPath' code row '$($fields.ObjectTypeName) $($fields.ObjectId)' has invalid physical line number $($fields.LineNumber)."
                }
                if ($fields.CoverageStatusCode -eq 1 -and $fields.HitCount -ne 0) {
                    throw "Coverage payload '$PayloadPath' code row '$($fields.ObjectTypeName) $($fields.ObjectId)' line $($fields.LineNumber) is marked Not Covered but has HitCount $($fields.HitCount)."
                }
                if ($fields.CoverageStatusCode -in @(2, 3) -and $fields.HitCount -le 0) {
                    throw "Coverage payload '$PayloadPath' code row '$($fields.ObjectTypeName) $($fields.ObjectId)' line $($fields.LineNumber) is marked covered/partially covered but has HitCount $($fields.HitCount)."
                }
                if ($fields.CoverageStatusCode -notin @(1, 2, 3)) {
                    throw "Coverage payload '$PayloadPath' code row '$($fields.ObjectTypeName) $($fields.ObjectId)' line $($fields.LineNumber) has invalid status code '$($fields.CoverageStatusCode):$($fields.CoverageStatusName)'."
                }
            }
        }

        $rowKey = "{0}|{1}|{2}" -f (
            [int]$fields.ObjectTypeCode
        ), $fields.ObjectId, $fields.LineNumber
        if (-not $rawKeys.Add($rowKey)) {
            throw "Coverage payload '$PayloadPath' contains duplicate raw source key '$($fields.ObjectTypeName) $($fields.ObjectId) line $($fields.LineNumber)'."
        }

        $rows.Add([pscustomobject]@{
            ObjectTypeCode = [int]$fields.ObjectTypeCode
            ObjectType     = $objectTypeDefinition.CanonicalName
            ObjectTypeName = $fields.ObjectTypeName
            ObjectId       = [int]$fields.ObjectId
            LineNumber     = [int]$fields.LineNumber
            LineTypeCode   = [int]$fields.LineTypeCode
            HitCount       = [int]$fields.HitCount
            SourceLine     = $fields.SourceLine
        })
    }

    $rows.ToArray()
}

function Assert-IndexedSourceLine {
    param(
        [Parameter(Mandatory)]
        $Row,

        [Parameter(Mandatory)]
        $IndexedObject,

        [Parameter(Mandatory)]
        [string]$PayloadPath
    )

    if ($Row.LineNumber -le 0) {
        return
    }
    if ($Row.LineNumber -gt $IndexedObject.Lines.Count) {
        throw "Coverage payload '$PayloadPath' line $($Row.LineNumber) for '$($IndexedObject.SourcePath)' is outside the indexed source file."
    }

    $actualLine = [string]$IndexedObject.Lines[$Row.LineNumber - 1]
    $expectedSourceLine = if ($actualLine.Length -gt 250) {
        $actualLine.Substring(0, 250)
    } else {
        $actualLine
    }

    if ($Row.SourceLine -ne $expectedSourceLine) {
        throw "Coverage payload '$PayloadPath' line $($Row.LineNumber) for '$($IndexedObject.SourcePath)' does not match the indexed source line exactly. Expected '$expectedSourceLine'; found '$($Row.SourceLine)'."
    }
}

function Format-UniverseItem {
    param(
        [Parameter(Mandatory)]
        $Item
    )

    "$($Item.SourcePath):$($Item.LineNumber) [$($Item.ObjectType) $($Item.ObjectName)]"
}

function Compare-CoverageUniverses {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Baseline,

        [Parameter(Mandatory)]
        [hashtable]$Current,

        [Parameter(Mandatory)]
        [string]$BaselinePayloadPath,

        [Parameter(Mandatory)]
        [string]$CurrentPayloadPath
    )

    $baselineKeys = @($Baseline.Keys | Sort-Object)
    $currentKeys = @($Current.Keys | Sort-Object)
    if (($baselineKeys -join "`n") -eq ($currentKeys -join "`n")) {
        return
    }

    $missing = foreach ($key in $baselineKeys) {
        if (-not $Current.ContainsKey($key)) {
            Format-UniverseItem -Item $Baseline[$key]
        }
    }
    $extra = foreach ($key in $currentKeys) {
        if (-not $Baseline.ContainsKey($key)) {
            Format-UniverseItem -Item $Current[$key]
        }
    }

    throw "Coverage payload '$CurrentPayloadPath' does not match the executable-line universe established by '$BaselinePayloadPath'. Missing [$($missing -join '; ')]; extra [$($extra -join '; ')]."
}

function Get-SourceSortKey {
    param(
        [Parameter(Mandatory)]
        $Record
    )

    '{0}|{1:d10}|{2}|{3}' -f $Record.sourcePath.ToLowerInvariant(),
        [int]$Record.lineNumber,
        $Record.objectType.ToLowerInvariant(),
        $Record.objectName.ToLowerInvariant()
}

function Get-HitSortKey {
    param(
        [Parameter(Mandatory)]
        $Record
    )

    '{0}|{1}|{2}|{3:d10}|{4}|{5}' -f (Get-SourceSortKey -Record $Record),
        $Record.testApp.ToLowerInvariant(),
        $Record.testCodeunitName.ToLowerInvariant(),
        [int]$Record.testCodeunitId,
        $Record.testProcedure.ToLowerInvariant(),
        [int]$Record.hitCount
}

function Write-BcCoveragePerTestJsonl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$MainAppPath,

        [Parameter(Mandatory)]
        [string]$TestAppPath,

        [Parameter(Mandatory)]
        [string]$RawCollectionPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $resolvedMainAppPath = (Resolve-Path -LiteralPath $MainAppPath).Path
    $resolvedTestAppPath = (Resolve-Path -LiteralPath $TestAppPath).Path
    $resolvedRawCollectionPath = (Resolve-Path -LiteralPath $RawCollectionPath).Path

    $mainIndex = Get-AlObjectIndex -RepoRoot $resolvedRepoRoot -AppPath $resolvedMainAppPath -Label 'Main app'
    $testIndex = Get-AlObjectIndex -RepoRoot $resolvedRepoRoot -AppPath $resolvedTestAppPath -Label 'Test app'
    $collectionPath = Resolve-CoverageCollectionPath -RawCollectionPath $resolvedRawCollectionPath
    $collection = Read-CoverageCollectionManifest -CollectionPath $collectionPath
    $expectedTestApp = Split-Path -Path $resolvedTestAppPath -Leaf
    if ($collection.TestApp -ne $expectedTestApp) {
        throw "Coverage manifest '$($collection.ManifestPath)' testApp '$($collection.TestApp)' does not match test app directory leaf '$expectedTestApp'."
    }

    $baselineUniverse = $null
    $baselinePayloadPath = $null
    $hitRecords = [System.Collections.Generic.List[object]]::new()

    foreach ($payloadEntry in @($collection.Payloads | Sort-Object order)) {
        $payloadPath = Join-Path $collection.CollectionPath $payloadEntry.file
        $rows = Read-CoveragePayloadRows -PayloadPath $payloadPath

        $testCodeunitKey = '{0}|{1}' -f (
            Get-CoverageObjectTypeCodeForDeclaration -DeclarationType 'codeunit'
        ), [int]$payloadEntry.testCodeunitId
        if (-not $testIndex.ContainsKey($testCodeunitKey)) {
            throw "Coverage collection '$($collection.CollectionPath)' cannot resolve test codeunit ID $([int]$payloadEntry.testCodeunitId) from test app '$resolvedTestAppPath'."
        }
        $testCodeunit = $testIndex[$testCodeunitKey]
        $payloadUniverse = @{}

        foreach ($row in $rows) {
            $mainObjectKey = '{0}|{1}' -f $row.ObjectTypeCode, $row.ObjectId
            if (-not $mainIndex.ContainsKey($mainObjectKey)) {
                continue
            }

            $mainObject = $mainIndex[$mainObjectKey]
            Assert-IndexedSourceLine -Row $row -IndexedObject $mainObject -PayloadPath $payloadPath

            if ($row.LineTypeCode -ne 3) {
                continue
            }

            $universeKey = "$mainObjectKey|$($row.LineNumber)"
            $payloadUniverse[$universeKey] = [pscustomobject]@{
                sourcePath = $mainObject.SourcePath
                objectType = $mainObject.ObjectType
                objectName = $mainObject.ObjectName
                lineNumber = [int]$row.LineNumber
            }

            if ($row.HitCount -gt 0) {
                $hitRecords.Add([ordered]@{
                    schemaVersion    = 1
                    recordType       = 'hit'
                    sourcePath       = $mainObject.SourcePath
                    objectType       = $mainObject.ObjectType
                    objectName       = $mainObject.ObjectName
                    lineNumber       = [int]$row.LineNumber
                    testApp          = $collection.TestApp
                    testCodeunitId   = [int]$payloadEntry.testCodeunitId
                    testCodeunitName = $testCodeunit.ObjectName
                    testProcedure    = [string]$payloadEntry.testMethod
                    hitCount         = [int]$row.HitCount
                })
            }
        }

        if ($payloadUniverse.Count -eq 0) {
            throw "Coverage payload '$payloadPath' contains no main-app code rows after foreign-object filtering."
        }

        if (-not $baselineUniverse) {
            $baselineUniverse = $payloadUniverse
            $baselinePayloadPath = $payloadPath
        } else {
            Compare-CoverageUniverses -Baseline $baselineUniverse -Current $payloadUniverse `
                -BaselinePayloadPath $baselinePayloadPath -CurrentPayloadPath $payloadPath
        }
    }

    $sourceRecords = foreach ($entry in @($baselineUniverse.Values | Sort-Object {
        Get-SourceSortKey -Record $_
    })) {
        [ordered]@{
            schemaVersion = 1
            recordType    = 'source'
            sourcePath    = $entry.sourcePath
            objectType    = $entry.objectType
            objectName    = $entry.objectName
            lineNumber    = [int]$entry.lineNumber
        }
    }

    $orderedHitRecords = @($hitRecords | Sort-Object {
        Get-HitSortKey -Record $_
    })
    $jsonLines = foreach ($record in @($sourceRecords) + @($orderedHitRecords)) {
        ($record | ConvertTo-Json -Compress)
    }

    $outputDirectory = Split-Path -Path $OutputPath -Parent
    if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
        throw "Output path '$OutputPath' must include a parent directory."
    }
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

    $tempPath = Join-Path $outputDirectory (
        '{0}.{1}.tmp' -f [System.IO.Path]::GetFileName($OutputPath),
        [guid]::NewGuid().ToString('N')
    )

    try {
        [System.IO.File]::WriteAllText(
            $tempPath,
            (($jsonLines -join [System.Environment]::NewLine) + [System.Environment]::NewLine),
            [System.Text.UTF8Encoding]::new($false)
        )

        if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
            [System.IO.File]::Replace($tempPath, $OutputPath, $null)
        } else {
            [System.IO.File]::Move($tempPath, $OutputPath)
        }
    } catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -Confirm:$false
        }
        throw
    } finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -Confirm:$false
        }
    }

    $OutputPath
}

Export-ModuleMember -Function @(
    'Write-BcCoveragePerTestJsonl'
)
