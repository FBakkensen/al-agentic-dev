#Requires -Version 7.2

<#
.SYNOPSIS
    A fixture tool cache for Pester: a compiler sentinel whose `al` command is a stub that answers
    `IsSymbolOnly`, so a test never needs a provisioned AL compiler.

.DESCRIPTION
    Get-LatestCompilerInfo reads <tool cache root>/al/sentinel.json and checks that the stable
    channel's command and alc files exist. The stub is a script: `al IsSymbolOnly <path>` prints
    `Extension is symbol-only: True` for a file name in the stub's list and `False` for any other,
    as AL CLI 30.0 does, and exits 0. Any other command exits 1, so a run that reaches the compile
    step fails there and never builds.

    Point ALBT_TOOL_CACHE_ROOT at the returned folder. Import it from a test's BeforeAll. Its file
    name does not end in .Tests.ps1, so Pester does not run it.
#>

Set-StrictMode -Version Latest

function New-FixtureToolCache {
    <#
    .SYNOPSIS
        Writes a tool cache holding a stub `al` command, and returns the tool cache root.
    .PARAMETER SymbolOnly
        File names the stub reports as symbols-only.
    .PARAMETER Output
        Replaces the stub's IsSymbolOnly output, for a command that gives no answer.
    .PARAMETER ExitCode
        The exit code of the stub's IsSymbolOnly answer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [string[]]$SymbolOnly = @(),
        [string]$Output,
        [int]$ExitCode = 0
    )

    $alDir = Join-Path $Root 'al'
    $stableRoot = Join-Path $alDir 'stable'
    $alcDir = Join-Path $stableRoot 'alc'
    New-Item -ItemType Directory -Path $alcDir -Force | Out-Null

    $names = ($SymbolOnly | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', '
    $outputLine = if ($PSBoundParameters.ContainsKey('Output')) {
        "'" + ($Output -replace "'", "''") + "'"
    } else {
        '"Extension is symbol-only: $symbolOnly"'
    }
    $stub = @(
        '$symbolOnlyNames = @(' + $names + ')'
        'if ($args[0] -ne ''IsSymbolOnly'') { ''stub al: only IsSymbolOnly is available''; exit 1 }'
        '$symbolOnly = $symbolOnlyNames -contains (Split-Path -Path $args[1] -Leaf)'
        $outputLine
        "exit $ExitCode"
    ) -join "`n"

    $commandPath = Join-Path $stableRoot 'al.ps1'
    $alcPath = Join-Path $alcDir 'alc.exe'
    Set-Content -LiteralPath $commandPath -Value $stub -Encoding UTF8
    Set-Content -LiteralPath $alcPath -Value 'stub' -Encoding UTF8

    [ordered]@{
        schemaVersion   = 2
        stableMajor     = 17
        prereleaseMajor = 0
        channels        = [ordered]@{
            stable = [ordered]@{ root = $stableRoot; commandPath = $commandPath; alcPath = $alcPath; version = '17.0.0.0' }
        }
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $alDir 'sentinel.json') -Encoding UTF8

    return $Root
}

Export-ModuleMember -Function @(
    'New-FixtureToolCache'
)
