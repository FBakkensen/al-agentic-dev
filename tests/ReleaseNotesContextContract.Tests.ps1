#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:ReleaseNotes = Get-Content -LiteralPath (Join-Path $repoRoot 'plugins\release-notes\skills\release-notes\SKILL.md') -Raw
}

Describe 'Release-notes context ownership contract' {
    It 'keeps the summary, todo list, and final output in main context' {
        $script:ReleaseNotes | Should -Match ([regex]::Escape('Main context holds only the summary, todo list, and final output.'))
        $script:ReleaseNotes | Should -Match ([regex]::Escape('Keep the summary, todo list, and final markdown in main context;'))
    }
}
