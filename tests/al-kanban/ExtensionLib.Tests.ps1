#Requires -Version 7.2

<#
.SYNOPSIS
    Runs the al-kanban extension's node:test suite through the repo's Pester gate.
.DESCRIPTION
    Thin wrapper: the actual assertions live in
    plugins/al-agentic-dev/extensions/al-kanban/lib.test.mjs (zero-dependency
    node:test). This file exists so `Invoke-Pester -Path tests` enforces them.
#>

Describe 'al-kanban extension lib (node:test)' {
    It 'passes the node --test suite for lib.mjs' {
        $node = Get-Command node -ErrorAction SilentlyContinue
        if (-not $node) {
            throw 'node is required to run the al-kanban extension tests but was not found on PATH'
        }
        $testFile = Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'extensions' 'al-kanban' 'lib.test.mjs'
        $output = & node --test $testFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
