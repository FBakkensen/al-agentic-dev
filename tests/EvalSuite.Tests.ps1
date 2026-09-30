#Requires -Version 7.2

BeforeDiscovery {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Skills = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'skills') -Directory | ForEach-Object { @{ Skill = $_.Name } })
    $script:Cases = @(
        Get-ChildItem -LiteralPath (Join-Path $repoRoot 'evals') -Recurse -Filter 'prompt.md' -File -ErrorAction SilentlyContinue |
            Where-Object { [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName) -notmatch '^evals[\\/]results[\\/]' } |
            ForEach-Object { @{ Case = $_.Directory.Name; Path = $_.FullName } }
    )
}

BeforeAll {
    $script:EvalRoot = Join-Path $PSScriptRoot '..' 'evals'
}

Describe 'Trigger eval suite' -Tag 'Unit' {
    It 'has a trigger case for <Skill> whose Skill grader names it' -TestCases $script:Skills {
        param($Skill)

        $grader = Join-Path $script:EvalRoot $Skill 'graders' 'skill-fired.md'
        $grader | Should -Exist
        $text = Get-Content -LiteralPath $grader -Raw
        $text | Should -Match '(?m)^type: tool_used$'
        $text | Should -Match '(?m)^tool: Skill$'
        $text | Should -Match ([regex]::Escape("(?:al-agentic-dev:)?$Skill`""))
    }

    It 'loads this plugin and every Base plugin copy, grants Skill, and leaves model unset, in <Case>' -TestCases $script:Cases {
        param($Case, $Path)

        $frontmatter = [regex]::Match((Get-Content -LiteralPath $Path -Raw), '(?s)\A---\r?\n(.*?)\r?\n---').Groups[1].Value
        $frontmatter | Should -Match ([regex]::Escape('plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]'))
        $frontmatter | Should -Match ([regex]::Escape('allowed_tools: [Read, Glob, Grep, Skill]'))
        $frontmatter | Should -Not -Match '(?m)^model:'
    }
}
