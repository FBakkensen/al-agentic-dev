#Requires -Version 7.2

BeforeAll {
    $script:ValidatorPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Validate-Skills.ps1')).Path
    . $script:ValidatorPath

    function New-SkillsRoot {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [hashtable]$Files
        )

        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        foreach ($relativePath in $Files.Keys) {
            $path = Join-Path $Root $relativePath
            New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($path)) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $Files[$relativePath] -Encoding utf8
        }

        return $Root
    }

    function New-SkillContent {
        param(
            [string]$Name = 'demo',
            [string]$Body = 'Name the outcome.'
        )

        return @"
---
name: $Name
description: "Do the thing. Use when a task is at phase: implemented."
---

# $Name

$Body
"@
    }

    function New-StyleContent {
        param(
            [string]$Frontmatter = "name: AL`ndescription: Speak BC and the interview-diagram rule.`nkeep-coding-instructions: true"
        )

        return "---`n$Frontmatter`n---`n`n# Speak BC`n"
    }

    function New-OutputStylesRoot {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [hashtable]$Files = @{ 'AL.md' = (New-StyleContent) }
        )

        return New-SkillsRoot -Root $Root -Files $Files
    }

    function New-PluginManifest {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [string[]]$Dependencies = @()
        )

        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($Path)) -Force | Out-Null
        @{ name = 'al-agentic-dev'; version = '0.9.0'; dependencies = @($Dependencies) } |
            ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding utf8
        return $Path
    }

    function Invoke-SkillValidator {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [string]$OutputStylesRoot = (New-OutputStylesRoot -Root "$Root-styles"),

            [string]$PluginManifest
        )

        $validation = @{ SkillsRoot = $Root; OutputStylesRoot = $OutputStylesRoot }
        if ($PluginManifest) {
            $validation.PluginManifest = $PluginManifest
        }
        $output = @(
            & {
                Invoke-SkillsValidation @validation -ErrorAction Continue
            } *>&1
        )
        $exitCode = [int]$output[-1]
        $text = if ($output.Count -gt 1) {
            @($output[0..($output.Count - 2)] | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        } else {
            ''
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Text     = $text
        }
    }

    function Invoke-SkillValidatorProcess {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [switch]$DefaultOutputStylesRoot,

            [string]$PluginManifest
        )

        $arguments = @('-NoProfile', '-File', $script:ValidatorPath, '-SkillsRoot', $Root)
        if (-not $DefaultOutputStylesRoot) {
            $arguments += @('-OutputStylesRoot', (New-OutputStylesRoot -Root "$Root-styles"))
        }
        if ($PluginManifest) {
            $arguments += @('-PluginManifest', $PluginManifest)
        }
        $output = & pwsh @arguments 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
}

Describe 'Validate-Skills structure checks' -Tag 'Unit' {
    It 'passes a well-formed skills root' {
        $body = @'
Read [FORMAT.md](FORMAT.md) before writing, and see https://example.test/docs.

```markdown
[Escapes the folder](../other/SKILL.md)
```

Name the outcome, then /al-build.
'@
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'good') -Files @{
            'demo/SKILL.md'     = (New-SkillContent -Body $body)
            'demo/FORMAT.md'    = '# Format'
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -Body 'Run scripts/test.ps1 and provision.ps1.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'All skills validated successfully'
    }

    It 'fails when SKILL.md is missing' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'no-skill-md') -Files @{
            'demo/NOTES-FORMAT.md' = '# Notes format'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo: SKILL\.md is missing'
    }

    It 'fails when the frontmatter block does not parse' -TestCases @(
        @{ Case = 'no-delimiters'; Content = "# demo`n`nNo frontmatter at all." }
        @{ Case = 'unclosed'; Content = "---`nname: demo`ndescription: `"Do the thing.`"`n`n# demo" }
    ) {
        param($Case, $Content)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "frontmatter-$Case") -Files @{
            'demo/SKILL.md' = $Content
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'frontmatter block does not parse'
    }

    It 'fails when the frontmatter carries unknown, missing, or duplicate keys' -TestCases @(
        @{ Case = 'extra'; Frontmatter = "name: demo`ndescription: `"Do the thing.`"`nallowed-tools: read" }
        @{ Case = 'missing'; Frontmatter = 'name: demo' }
        @{ Case = 'duplicate'; Frontmatter = "name: demo`nname: demo`ndescription: `"Do the thing.`"" }
    ) {
        param($Case, $Frontmatter)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "keys-$Case") -Files @{
            'demo/SKILL.md' = "---`n$Frontmatter`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'frontmatter keys must be name and description'
    }

    It 'fails when a frontmatter key differs from the lowercase key only by case' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'keys-case') -Files @{
            'demo/SKILL.md' = "---`nname: demo`nDescription: `"Use when a task is at phase: implemented.`"`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'frontmatter keys must be name and description'
    }

    It 'fails when a skill carries disable-model-invocation' -TestCases @(
        @{ Case = 'flag-true'; Flag = 'true' }
        @{ Case = 'flag-false'; Flag = 'false' }
    ) {
        param($Case, $Flag)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "flag-$Case") -Files @{
            'demo/SKILL.md' = "---`nname: demo`ndescription: `"Do the thing.`"`ndisable-model-invocation: $Flag`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'all skills are model-invocable; remove disable-model-invocation'
    }

    It 'fails when the name does not match the folder name' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'name-mismatch') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Name 'al-demo')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "name 'al-demo' does not match the folder name"
    }

    It 'fails when the name breaks the spec format' -TestCases @(
        @{ Case = 'uppercase'; Name = 'Demo'; Folder = 'Demo' }
        @{ Case = 'double-hyphen'; Name = 'de--mo'; Folder = 'de--mo' }
        @{ Case = 'trailing-hyphen'; Name = 'demo-'; Folder = 'demo-' }
        @{ Case = 'too-long'; Name = ('a' * 65); Folder = ('a' * 65) }
    ) {
        param($Case, $Name, $Folder)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "name-spec-$Case") -Files @{
            "$Folder/SKILL.md" = (New-SkillContent -Name $Name)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'must be 1-64 characters of lowercase letters, digits, and single hyphens'
    }

    It 'fails when the name matches the folder name only by case' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'name-case') -Files @{
            'Al-Demo/SKILL.md' = (New-SkillContent -Name 'al-demo')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "name 'al-demo' does not match the folder name"
    }

    It 'fails when the description is missing, empty, or a block scalar' -TestCases @(
        @{ Case = 'empty'; Description = '' }
        @{ Case = 'quoted-empty'; Description = '""' }
        @{ Case = 'folded-block'; Description = ">-`n  Use when a task lands." }
        @{ Case = 'literal-block'; Description = "|`n  Use when a task lands." }
    ) {
        param($Case, $Description)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "description-$Case") -Files @{
            'demo/SKILL.md' = "---`nname: demo`ndescription: $Description`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'description must be a non-empty single-line value'
    }

    It 'fails when the description exceeds 1024 characters' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'description-long') -Files @{
            'demo/SKILL.md' = "---`nname: demo`ndescription: $('x' * 1025)`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'description exceeds 1024 characters'
    }

    It 'fails when a description carrying a colon is unquoted' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'unquoted-description') -Files @{
            'demo/SKILL.md' = "---`nname: demo`ndescription: Use when a task is at phase: implemented.`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'description contains a colon and must be quoted'
    }
}

Describe 'Validate-Skills link checks' -Tag 'Unit' {
    It 'fails on a link that leaves the skill folder' -TestCases @(
        @{ Case = 'parent'; Target = '../al-build/SKILL.md' }
        @{ Case = 'absolute'; Target = '/skills/demo/FORMAT.md' }
        @{ Case = 'deep-escape'; Target = 'nested/../../outside.md' }
    ) {
        param($Case, $Target)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "link-$Case") -Files @{
            'demo/SKILL.md'  = (New-SkillContent -Body "See [Format]($Target).")
            'demo/FORMAT.md' = '# Format'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'link leaves the skill folder'
    }

    It 'fails on a link that uses backslashes' -TestCases @(
        @{ Case = 'parent-escape'; Target = '..\other\SECRET.md' }
        @{ Case = 'resolvable-sibling'; Target = 'sub\FORMAT.md' }
    ) {
        param($Case, $Target)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "backslash-$Case") -Files @{
            'demo/SKILL.md'      = (New-SkillContent -Body "See [Format]($Target).")
            'demo/sub/FORMAT.md' = '# Format'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'link uses backslashes; use forward slashes'
    }

    It 'accepts an angle-bracket link target containing spaces' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'angle-spaces') -Files @{
            'demo/SKILL.md'     = (New-SkillContent -Body 'See [Format](<my format.md>).')
            'demo/my format.md' = '# Format'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'fails on an angle-bracket link target that does not exist, naming the whole target' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'angle-missing') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'See [Format](<my format.md>).')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'link target does not exist: my format\.md'
    }

    It 'fails on a link whose target does not exist' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'link-absent') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'See [Format](TASK-FORMAT.md).')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'link target does not exist: TASK-FORMAT\.md'
    }

    It 'checks links in sibling files, not only in SKILL.md' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'link-sibling-file') -Files @{
            'demo/SKILL.md'  = (New-SkillContent -Body 'See [Format](FORMAT.md).')
            'demo/FORMAT.md' = '# Format' + [Environment]::NewLine + 'Back to [the skill](../demo/SKILL.md).'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/FORMAT\.md: link leaves the skill folder'
    }

    It 'ignores a link inside a fenced block and flags the same link outside it' {
        $fenced = @'
```markdown
[Hidden](hidden-missing.md)
```
'@
        $fencedRoot = New-SkillsRoot -Root (Join-Path $TestDrive 'fence-hidden') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $fenced)
        }
        $plainRoot = New-SkillsRoot -Root (Join-Path $TestDrive 'fence-plain') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body '[Hidden](hidden-missing.md)')
        }

        (Invoke-SkillValidator -Root $fencedRoot).ExitCode | Should -Be 0

        $plain = Invoke-SkillValidator -Root $plainRoot
        $plain.ExitCode | Should -Be 1
        $plain.Text | Should -Match 'link target does not exist: hidden-missing\.md'
    }

    It 'closes a fenced block only on a run at least as long as its opener' {
        $nested = @'
````markdown
```
[Inner](inner-missing.md)
```
[Between](between-missing.md)
````

[After](after-missing.md)
'@
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'fence-nested') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $nested)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'after-missing\.md'
        $result.Text | Should -Not -Match 'inner-missing\.md'
        $result.Text | Should -Not -Match 'between-missing\.md'
    }
}

Describe 'Validate-Skills script-path checks' -Tag 'Unit' {
    It 'fails when a skill outside al-build names a script' -TestCases @(
        @{ Case = 'ps1'; Body = 'Run test.ps1 to gate the change.'; Expected = 'test\.ps1' }
        @{ Case = 'scripts-path'; Body = 'Entry points live in scripts/ for this skill.'; Expected = 'scripts/' }
        @{ Case = 'fenced-ps1'; Body = "``````powershell`npwsh provision.ps1`n``````"; Expected = 'provision\.ps1' }
    ) {
        param($Case, $Body, $Expected)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "script-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "names a script outside al-build: $Expected"
    }

    It 'catches a script mention in any casing' -TestCases @(
        @{ Case = 'upper-ps1'; Body = 'Run Provision.PS1 to refresh the environment.'; Expected = 'Provision\.PS1' }
        @{ Case = 'upper-scripts'; Body = 'Entry points live in Scripts/ for this skill.'; Expected = 'Scripts/' }
    ) {
        param($Case, $Body, $Expected)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "script-case-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "names a script outside al-build: $Expected"
    }

    It 'exempts script-shaped segments inside URLs' {
        $body = 'See https://github.com/org/repo/tree/main/scripts/ and https://example.test/tools/foo.ps1 for background.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'script-url') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'accepts a folder name that merely contains scripts/ outside al-build' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'script-substring') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Notes land under postscripts/archive/ in the repo.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'exempts al-build by folder, not by content' {
        $body = 'Run scripts/test.ps1 for the gate.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'script-exemption') -Files @{
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -Body $body)
            'demo/SKILL.md'     = (New-SkillContent -Body $body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/SKILL\.md: names a script outside al-build'
        $result.Text | Should -Not -Match 'al-build/SKILL\.md: names a script'
    }

    It 'exempts the knowledge-index generator in al-clone-bcquality only' {
        $body = 'Run pwsh .bcquality/tools/Build-KnowledgeIndex.ps1 from the clone root.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'script-named-exemption') -Files @{
            'al-clone-bcquality/SKILL.md' = (New-SkillContent -Name 'al-clone-bcquality' -Body $body)
            'demo/SKILL.md'               = (New-SkillContent -Body $body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/SKILL\.md: names a script outside al-build'
        $result.Text | Should -Not -Match 'al-clone-bcquality/SKILL\.md: names a script'
    }

    It 'holds an exempted skill to its own approved script list' -TestCases @(
        @{ Case = 'other-script'; Body = 'Run pwsh .bcquality/tools/Test-ReviewFixtures.ps1 as well.'; Expected = '\.bcquality/tools/Test-ReviewFixtures\.ps1' }
        @{ Case = 'other-casing'; Body = 'Run pwsh .bcquality/tools/build-knowledgeindex.ps1 as well.'; Expected = '\.bcquality/tools/build-knowledgeindex\.ps1' }
        @{ Case = 'other-folder'; Body = 'Run pwsh other/Build-KnowledgeIndex.ps1 as well.'; Expected = 'other/Build-KnowledgeIndex\.ps1' }
        @{ Case = 'bare-name'; Body = 'Run pwsh Build-KnowledgeIndex.ps1 as well.'; Expected = 'Build-KnowledgeIndex\.ps1' }
        @{ Case = 'scripts-smuggle'; Body = 'Run pwsh scripts/Build-KnowledgeIndex.ps1 as well.'; Expected = 'scripts/Build-KnowledgeIndex\.ps1' }
        @{ Case = 'scripts-path'; Body = 'Entry points live in scripts/ for this skill.'; Expected = 'scripts/' }
    ) {
        param($Case, $Body, $Expected)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "script-exempt-$Case") -Files @{
            'al-clone-bcquality/SKILL.md' = (New-SkillContent -Name 'al-clone-bcquality' -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "names a script outside al-build: $Expected"
    }
}

Describe 'Validate-Skills state-home checks' -Tag 'Unit' {
    It 'fails when a skill body states a lifecycle field' -TestCases @(
        @{ Case = 'status'; Body = 'Flip `status: done` when the gate is green.'; Expected = "status:" }
        @{ Case = 'phase'; Body = 'Stamp `phase: refined` on the task.'; Expected = "phase:" }
        @{ Case = 'blocked-on'; Body = 'Write blocked-on: with the reason.'; Expected = "blocked-on:" }
        @{ Case = 'review'; Body = 'Add `review: clean` to the last task.'; Expected = "review:" }
        @{ Case = 'tier'; Body = 'Stamp `tier: frontier` on the task.'; Expected = "tier:" }
        @{ Case = 'green-gate'; Body = 'Stamp `green-gate: full` after the clean build.'; Expected = "green-gate:" }
    ) {
        param($Case, $Body, $Expected)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "lifecycle-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "states the lifecycle field '$Expected'; task-state ceremony is retired"
    }

    It 'fails when a sibling file states a lifecycle field' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'lifecycle-sibling') -Files @{
            'demo/SKILL.md'  = (New-SkillContent -Body 'See [Format](FORMAT.md).')
            'demo/FORMAT.md' = '# Format' + [Environment]::NewLine + 'The task lands at status: open.'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "demo/FORMAT\.md: states the lifecycle field 'status:'"
    }

    It 'fails when a skill body states a work-item transition' -TestCases @(
        @{ Case = 'resolved'; Body = 'Move the work item to State: Resolved when the gate is green.'; Expected = 'State: Resolved' }
        @{ Case = 'lowercase-field'; Body = 'Set state: Blocked while the edge is open.'; Expected = 'state: Blocked' }
        @{ Case = 'closed'; Body = 'The run ends at State: Closed.'; Expected = 'State: Closed' }
    ) {
        param($Case, $Body, $Expected)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "ado-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "states the work-item transition '$Expected'; task-state ceremony is retired"
    }

    It 'fails on work-item transitions in every folder, the old state home included' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ado-home') -Files @{
            'al-routing/SKILL.md' = (New-SkillContent -Name 'al-routing' -Body 'Move the work item to State: Resolved, then State: Closed.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "states the work-item transition 'State: Resolved'"
    }

    It 'accepts a state token bound to no work-item value' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ado-prose') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Name the state: of the run, then the open moves.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'fails on lifecycle fields in every folder, the old state home included' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'lifecycle-home') -Files @{
            'al-routing/SKILL.md' = (New-SkillContent -Name 'al-routing' -Body 'Stamp `status: done` and `phase: mutated` in one edit.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "states the lifecycle field 'status:'"
    }

    It 'ignores a lifecycle-shaped token in SKILL.md frontmatter' {
        # The default fixture description contains "phase: implemented"; only the body is scanned.
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'lifecycle-frontmatter') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Name the outcome.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }
}

Describe 'Validate-Skills skill-reference checks' -Tag 'Unit' {
    It 'fails when a body names a skill that has no folder' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ref-missing') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Name the outcome, then /al-nonexistent.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'names a skill that has no folder: /al-nonexistent'
    }

    It 'accepts a reference to an existing skill' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ref-existing') -Files @{
            'demo/SKILL.md'     = (New-SkillContent -Body 'Run the gate with /al-build.')
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -Body 'Run scripts/test.ps1.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'ignores skill-shaped tokens inside paths and filenames' {
        $body = 'Read .output/TestResults/<dir>/al-runner.xml and artifacts/al-thing/notes.md for context.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ref-path') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'resolves a generic skill name with no al- prefix' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ref-generic') -Files @{
            'demo/SKILL.md'       = (New-SkillContent -Body 'Hand the open PR to /babysit-pr.')
            'babysit-pr/SKILL.md' = (New-SkillContent -Name 'babysit-pr')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'leaves a generic non-folder slash token unflagged' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ref-generic-unknown') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'The platform exposes /usage and /feedback commands.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }
}

Describe 'Validate-Skills harness checks' -Tag 'Unit' {
    It 'fails a harness-neutral leftover in a skill body' -TestCases @(
        @{ Case = 'conditional'; Body = 'If your harness supports subagents, these parallelize in full-capability subagents; otherwise apply them in one pass.' }
        @{ Case = 'casing'; Body = 'Whatever browser capability the Harness offers.' }
        @{ Case = 'compound'; Body = 'No harness-specific frontmatter belongs here.' }
    ) {
        param($Case, $Body)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "harness-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'uses harness-conditional phrasing'
    }

    It 'fails a harness leftover in a sibling file' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'harness-sibling') -Files @{
            'demo/SKILL.md'  = (New-SkillContent -Body 'See [Format](FORMAT.md).')
            'demo/FORMAT.md' = '# Format' + [Environment]::NewLine + 'Adapt this to your harness.'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/FORMAT\.md: uses harness-conditional phrasing'
    }

    It 'passes the same rule phrased without the token' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'harness-inverted') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'These parallelize in full-capability subagents.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }
}

Describe 'Validate-Skills delegation checks' -Tag 'Unit' {
    It 'passes ▶ lines in the grammar, a code-span ▶, and a fenced ▶' {
        $body = @'
Before changing a test:

▶ haiku · /al-build gate on the slice → summary.json verdict, exact red cause

1. ▶ sonnet · /al-implement with the work item → red evidence, green gate line, files touched

- ▶ opus · judge the two module boundaries → the chosen boundary with its reason

   ▶ haiku · /al-build gate on the synced tree → summary.json verdict

For each step report `▶ <business action>` and the observed result.

```text
▶ anything goes inside a fence
```
'@
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'delegation-good') -Files @{
            'demo/SKILL.md'        = (New-SkillContent -Body $body)
            'al-build/SKILL.md'    = (New-SkillContent -Name 'al-build')
            'al-implement/SKILL.md' = (New-SkillContent -Name 'al-implement')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'fails a ▶ line outside the grammar' -TestCases @(
        @{ Case = 'tier-vehicle'; Line = '▶ mechanical · task · run the gate → verdict' }
        @{ Case = 'half-task'; Line = '▶ sonnet · task · run the gate → verdict' }
        @{ Case = 'half-session'; Line = '▶ haiku · session · /al-implement with the work item → branch' }
        @{ Case = 'unknown-model'; Line = '▶ gpt-5 · run the gate → verdict' }
        @{ Case = 'model-case'; Line = '▶ Sonnet · run the gate → verdict' }
        @{ Case = 'return'; Line = '▶ haiku · run the gate' }
        @{ Case = 'prose'; Line = 'Then ▶ the worker runs the gate.' }
        @{ Case = 'colon'; Line = '▶ haiku: run the gate → verdict' }
    ) {
        param($Case, $Line)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "delegation-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Line)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $expected = "demo/SKILL.md: ▶ line outside the delegation grammar '▶ <model> · <brief> → <return>' with model opus, sonnet, or haiku: $Line"
        $result.Text | Should -Match ([regex]::Escape($expected))
    }

    It 'fails a ▶ line that runs on fable' {
        $line = '▶ fable · judge the two module boundaries → the chosen boundary'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'delegation-fable') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $line)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("demo/SKILL.md: ▶ line runs on fable, which bills usage credits; delegate on opus, sonnet, or haiku: $line"))
        $result.Text | Should -Not -Match 'outside the delegation grammar'
    }

    It 'fails a ▶ line outside the grammar in a sibling file' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'delegation-sibling') -Files @{
            'demo/SKILL.md'  = (New-SkillContent -Body 'See [Format](FORMAT.md).')
            'demo/FORMAT.md' = '# Format' + [Environment]::NewLine + '▶ run it'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $expected = "demo/FORMAT.md: ▶ line outside the delegation grammar '▶ <model> · <brief> → <return>' with model opus, sonnet, or haiku: ▶ run it"
        $result.Text | Should -Match ([regex]::Escape($expected))
    }
}

Describe 'Validate-Skills namespace checks' -Tag 'Unit' {
    BeforeAll {
        $script:Manifest = New-PluginManifest -Path (Join-Path $TestDrive 'manifest' 'plugin.json') -Dependencies @(
            'mattpocock-skills@claude-plugins-official'
            'bcquality'
        )
    }

    It 'passes a reference whose namespace a dependency declares' -TestCases @(
        @{ Case = 'marketplace-form'; Body = 'Deep questions go to /mattpocock-skills:research.' }
        @{ Case = 'bare-name-form'; Body = 'Standards come from /bcquality:al-code-review.' }
        @{ Case = 'no-slash'; Body = 'The entry skill is mattpocock-skills:to-spec.' }
    ) {
        param($Case, $Body)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "ns-declared-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root -PluginManifest $script:Manifest

        $result.ExitCode | Should -Be 0
    }

    It 'passes a colon token that is not a skill reference' -TestCases @(
        @{ Case = 'file-line'; Body = 'Return the precedent table with file:line for every row.' }
        @{ Case = 'env-span'; Body = 'Set `$env:PUPPETEER_EXECUTABLE_PATH` before the render.' }
        @{ Case = 'built-in'; Body = 'Run /simplify, then /code-review on the diff.' }
        @{ Case = 'fenced'; Body = "``````text`n/superpowers:code-review`nal-agentic-dev:al-build`n``````" }
    ) {
        param($Case, $Body)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "ns-plain-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Body)
        }

        $result = Invoke-SkillValidator -Root $root -PluginManifest $script:Manifest

        $result.ExitCode | Should -Be 0
    }

    It 'fails a slash reference whose namespace no dependency declares' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ns-undeclared') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Hand the diff to /superpowers:code-review.')
        }

        $result = Invoke-SkillValidator -Root $root -PluginManifest $script:Manifest

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("demo/SKILL.md: /superpowers:code-review names 'superpowers', which no plugin manifest dependency declares"))
    }

    It 'fails an undeclared slash reference in the description' {
        $content = (New-SkillContent) -replace 'Do the thing\.', 'Runs beside /superpowers:code-review.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ns-description') -Files @{
            'demo/SKILL.md' = $content
        }

        $result = Invoke-SkillValidator -Root $root -PluginManifest $script:Manifest

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("demo/SKILL.md: /superpowers:code-review names 'superpowers'"))
    }

    It 'fails our own namespace, with or without a slash, and reports it once' -TestCases @(
        @{ Case = 'slash'; Token = '/al-agentic-dev:al-build' }
        @{ Case = 'bare'; Token = 'al-agentic-dev:al-build' }
    ) {
        param($Case, $Token)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "ns-own-$Case") -Files @{
            'demo/SKILL.md'     = (New-SkillContent -Body "Run the gate with $Token.")
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build')
        }

        $result = Invoke-SkillValidator -Root $root -PluginManifest $script:Manifest

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape('demo/SKILL.md: al-agentic-dev:al-build names our own skill; write it bare: /al-build'))
        @([regex]::Matches($result.Text, 'FAIL: ')).Count | Should -Be 1
    }

    It 'fails when the plugin manifest does not exist' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ns-no-manifest') -Files @{
            'demo/SKILL.md' = (New-SkillContent)
        }
        $missing = Join-Path $TestDrive 'absent' 'plugin.json'

        $result = Invoke-SkillValidator -Root $root -PluginManifest $missing

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("plugin manifest not found: $missing"))
    }

    It 'passes a well-formed root against a fixture manifest with no dependencies' {
        $manifest = New-PluginManifest -Path (Join-Path $TestDrive 'manifest-empty' 'plugin.json')
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'ns-empty-manifest') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Return file:line for every row.')
        }

        $result = Invoke-SkillValidator -Root $root -PluginManifest $manifest

        $result.ExitCode | Should -Be 0
    }
}

Describe 'Validate-Skills output-style checks' -Tag 'Unit' {
    BeforeAll {
        $script:StyleSkills = New-SkillsRoot -Root (Join-Path $TestDrive 'style-skills') -Files @{
            'demo/SKILL.md' = (New-SkillContent)
        }
    }

    It 'passes a valid AL style' {
        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive 'style-good')

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'OK: output-styles/AL\.md'
    }

    It 'fails a style whose name is not exactly AL' -TestCases @(
        @{ Case = 'lowercase'; Frontmatter = "name: al`ndescription: Speak BC.`nkeep-coding-instructions: true"; Found = 'al' }
        @{ Case = 'mixed'; Frontmatter = "name: Al`ndescription: Speak BC.`nkeep-coding-instructions: true"; Found = 'Al' }
        @{ Case = 'missing'; Frontmatter = "description: Speak BC.`nkeep-coding-instructions: true"; Found = '' }
        @{ Case = 'key-case'; Frontmatter = "Name: AL`ndescription: Speak BC.`nkeep-coding-instructions: true"; Found = '' }
    ) {
        param($Case, $Frontmatter, $Found)

        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive "style-name-$Case") -Files @{
            'AL.md' = (New-StyleContent -Frontmatter $Frontmatter)
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("output-styles/AL.md: name '$Found' must be exactly 'AL'"))
    }

    It 'fails a style whose name is not a single string' -TestCases @(
        @{ Case = 'sequence'; Value = '[AL]' }
        @{ Case = 'mapping'; Value = '{ AL: true }' }
    ) {
        param($Case, $Value)

        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive "style-name-type-$Case") -Files @{
            'AL.md' = (New-StyleContent -Frontmatter "name: $Value`ndescription: Speak BC.`nkeep-coding-instructions: true")
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("output-styles/AL.md: name '' must be exactly 'AL'"))
    }

    It 'fails a style whose keep-coding-instructions is not true' -TestCases @(
        @{ Case = 'false'; Frontmatter = "name: AL`ndescription: Speak BC.`nkeep-coding-instructions: false" }
        @{ Case = 'missing'; Frontmatter = "name: AL`ndescription: Speak BC." }
    ) {
        param($Case, $Frontmatter)

        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive "style-keep-$Case") -Files @{
            'AL.md' = (New-StyleContent -Frontmatter $Frontmatter)
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape('output-styles/AL.md: keep-coding-instructions must be true'))
    }

    It 'fails a style that carries force-for-plugin' -TestCases @(
        @{ Value = 'true' }
        @{ Value = 'false' }
    ) {
        param($Value)

        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive "style-force-$Value") -Files @{
            'AL.md' = (New-StyleContent -Frontmatter "name: AL`ndescription: Speak BC.`nkeep-coding-instructions: true`nforce-for-plugin: $Value")
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match ([regex]::Escape("output-styles/AL.md: force-for-plugin overrides the developer's own output style; remove it"))
    }

    It 'fails a style whose frontmatter block does not parse' {
        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive 'style-unparsed') -Files @{
            'AL.md' = "# Speak BC`n`nNo frontmatter."
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'output-styles/AL\.md: frontmatter block does not parse'
    }

    It 'fails a style whose frontmatter YAML does not parse' -TestCases @(
        @{ Case = 'flow'; Frontmatter = "name: AL`nkeep-coding-instructions: true`nbroken: [" }
        @{ Case = 'quote'; Frontmatter = "name: AL`nkeep-coding-instructions: true`ndescription: `"Speak BC" }
        @{ Case = 'name-next-line'; Frontmatter = "name:`nAL`ndescription: Speak BC.`nkeep-coding-instructions: true" }
        @{ Case = 'keep-next-line'; Frontmatter = "name: AL`ndescription: Speak BC.`nkeep-coding-instructions:`ntrue" }
    ) {
        param($Case, $Frontmatter)

        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive "style-yaml-$Case") -Files @{
            'AL.md' = (New-StyleContent -Frontmatter $Frontmatter)
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'output-styles/AL\.md: frontmatter YAML does not parse'
    }

    It 'accepts quoted values and a folded multi-line description' {
        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive 'style-yaml-good') -Files @{
            'AL.md' = (New-StyleContent -Frontmatter "name: `"AL`"`ndescription: >-`n  Speak BC: vocabulary,`n  and diagrams.`nkeep-coding-instructions: true")
        }

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 0
    }

    It 'fails when the style location holds no style named AL' -TestCases @(
        @{ Case = 'empty'; Files = @{ 'README.txt' = 'not a style' } }
        @{ Case = 'renamed'; Files = @{ 'BC.md' = "---`nname: BC`ndescription: Speak BC.`nkeep-coding-instructions: true`n---`n" } }
    ) {
        param($Case, $Files)

        $styles = New-OutputStylesRoot -Root (Join-Path $TestDrive "style-none-$Case") -Files $Files

        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot $styles

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'output-styles holds no style named AL'
    }

    It 'fails when the style location is missing' {
        $result = Invoke-SkillValidator -Root $script:StyleSkills -OutputStylesRoot (Join-Path $TestDrive 'style-absent')

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'output-styles holds no style named AL'
    }
}

Describe 'Validate-Skills reporting' -Tag 'Unit' {
    It 'reports every violation, not only the first' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'many-violations') -Files @{
            'alpha/SKILL.md' = (New-SkillContent -Name 'wrong-name' -Body 'See [Format](FORMAT.md).')
            'beta/NOTES.md'  = '# Notes'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "name 'wrong-name' does not match the folder name"
        $result.Text | Should -Match 'alpha/SKILL\.md: link target does not exist: FORMAT\.md'
        $result.Text | Should -Match 'beta: SKILL\.md is missing'
    }
}

Describe 'Validate-Skills process wrapper' -Tag 'Process' {
    It 'returns zero for a valid skill root' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'process-good') -Files @{
            'demo/SKILL.md' = (New-SkillContent)
        }

        (Invoke-SkillValidatorProcess -Root $root).ExitCode | Should -Be 0
    }

    It 'returns nonzero for an invalid skill root' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'process-bad') -Files @{
            'demo/NOTES.md' = '# Missing SKILL.md'
        }

        (Invoke-SkillValidatorProcess -Root $root).ExitCode | Should -Be 1
    }

    It 'validates the repository output-styles folder by default' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'process-default-styles') -Files @{
            'demo/SKILL.md' = (New-SkillContent)
        }

        $result = Invoke-SkillValidatorProcess -Root $root -DefaultOutputStylesRoot

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'OK: output-styles/AL\.md'
    }

    It 'reads the namespaces from the plugin manifest it is given' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'process-manifest') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Deep questions go to /mattpocock-skills:research.')
        }
        $declared = New-PluginManifest -Path (Join-Path $TestDrive 'process-declared' 'plugin.json') -Dependencies @('mattpocock-skills@claude-plugins-official')
        $empty = New-PluginManifest -Path (Join-Path $TestDrive 'process-empty' 'plugin.json')

        (Invoke-SkillValidatorProcess -Root $root -PluginManifest $declared).ExitCode | Should -Be 0
        (Invoke-SkillValidatorProcess -Root $root -PluginManifest $empty).ExitCode | Should -Be 1
    }
}
