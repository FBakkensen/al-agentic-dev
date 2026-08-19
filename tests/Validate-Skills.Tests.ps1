#Requires -Version 7.2

BeforeAll {
    $script:ValidatorPath = (Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Validate-Skills.ps1')).Path

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
            [string]$Body = 'Name the outcome.',
            [string]$QuestionRule = 'Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.',
            [switch]$ModelInvocable,
            [switch]$WithoutQuestionRule
        )

        $flagLine = if ($ModelInvocable) { '' } else { "disable-model-invocation: true`n" }
        $questionLine = if ($WithoutQuestionRule) { '' } else { "$QuestionRule`n`n" }
        return @"
---
name: $Name
description: "Do the thing. Use when a task is at phase: implemented."
$flagLine---

# $Name

$questionLine
$Body
"@
    }

    function New-AgentContent {
        param(
            [string]$Name = 'review-lens',
            [string]$Description = '"Reads a diff with one lens. Use when: a review fans out."',
            [string]$Tools = '["grep", "view"]',
            [string]$Model = 'pinned-model-1',
            [string]$Body = 'Apply the lens and return findings.'
        )

        return @"
---
name: $Name
description: $Description
tools: $Tools
model: $Model
---

$Body
"@
    }

    function Invoke-SkillValidator {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [string]$AgentsRoot
        )

        if (-not $AgentsRoot) { $AgentsRoot = Join-Path $Root '_no-agents' }
        $output = & pwsh -NoProfile -File $script:ValidatorPath -SkillsRoot $Root -AgentsRoot $AgentsRoot 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Text     = (@($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        }
    }
}

Describe 'Validate-Skills structure checks' {
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
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -ModelInvocable -Body 'Run scripts/test.ps1 and provision.ps1.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'All skills validated successfully'
    }

    It 'fails when SKILL.md is missing' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'no-skill-md') -Files @{
            'demo/RECORDING-FORMAT.md' = '# Recording format'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo: SKILL\.md is missing'
    }

    It 'fails when a skill omits the plain-text question rule' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'no-question-rule') -Files @{
            'demo/SKILL.md'     = (New-SkillContent -WithoutQuestionRule)
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -ModelInvocable)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/SKILL\.md: missing the required plain-text question rule'
    }

    It 'fails the pre-ban question rule even in a former transition folder' {
        $legacy = 'Ask every question in the reply itself, as plain text — never through a question or elicitation tool.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'legacy-transition') -Files @{
            'al-scope/SKILL.md' = (New-SkillContent -Name 'al-scope' -QuestionRule $legacy)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'al-scope/SKILL\.md: missing the required plain-text question rule'
    }

    It 'fails the pre-ban question rule outside the transition folders' {
        $legacy = 'Ask every question in the reply itself, as plain text — never through a question or elicitation tool.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'legacy-elsewhere') -Files @{
            'demo/SKILL.md' = (New-SkillContent -QuestionRule $legacy)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/SKILL\.md: missing the required plain-text question rule'
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
        $result.Text | Should -Match 'frontmatter keys must be name, description, and optionally disable-model-invocation'
    }

    It 'fails when a frontmatter key differs from the lowercase key only by case' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'keys-case') -Files @{
            'demo/SKILL.md' = "---`nname: demo`nDescription: `"Use when a task is at phase: implemented.`"`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'frontmatter keys must be name, description, and optionally disable-model-invocation'
    }

    It 'fails when a skill omits disable-model-invocation' -TestCases @(
        @{ Case = 'missing-flag'; Frontmatter = "name: demo`ndescription: `"Do the thing.`"" }
        @{ Case = 'flag-false'; Frontmatter = "name: demo`ndescription: `"Do the thing.`"`ndisable-model-invocation: false" }
    ) {
        param($Case, $Frontmatter)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "flag-$Case") -Files @{
            'demo/SKILL.md' = "---`n$Frontmatter`n---`n`n# demo`n"
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'disable-model-invocation: true is required'
    }

    It 'fails when a model-invocable skill carries disable-model-invocation' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'flag-on-exception') -Files @{
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'al-build is model-invocable; remove disable-model-invocation'
    }

    It 'accepts a verbatim port without the question rule' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'port-question-rule') -Files @{
            'wait-what/SKILL.md' = (New-SkillContent -Name 'wait-what' -WithoutQuestionRule)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'accepts the harness token inside a verbatim port only' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'port-harness') -Files @{
            'unslop/SKILL.md' = (New-SkillContent -Name 'unslop' -ModelInvocable -WithoutQuestionRule -Body 'Cut harness (as metaphor) from prose.')
            'demo/SKILL.md'   = (New-SkillContent -Body 'Cut harness metaphors.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/SKILL\.md: uses harness-conditional phrasing'
        $result.Text | Should -Not -Match 'unslop/SKILL\.md: uses harness-conditional phrasing'
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

Describe 'Validate-Skills link checks' {
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

Describe 'Validate-Skills script-path checks' {
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

    It 'accepts pagescripts/ outside al-build' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'script-pagescripts') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'Recordings land under pagescripts/recordings/ in the repo.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'exempts al-build by folder, not by content' {
        $body = 'Run scripts/test.ps1 for the gate.'
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'script-exemption') -Files @{
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -ModelInvocable -Body $body)
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

Describe 'Validate-Skills state-home checks' {
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

Describe 'Validate-Skills skill-reference checks' {
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
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build' -ModelInvocable -Body 'Run scripts/test.ps1.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'ignores skill-shaped tokens inside paths and filenames' {
        $body = 'Read .output/TestResults/<dir>/al-runner.xml and pagescripts/al-thing/notes.md for context.'
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

Describe 'Validate-Skills harness checks' {
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

    It 'passes the Copilot-first phrasing of the same rule' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'harness-inverted') -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body 'These parallelize in full-capability subagents; when subagents are unavailable, apply them in one pass.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }
}

Describe 'Validate-Skills agent checks' {
    BeforeAll {
        function New-AgentsRoot {
            param(
                [Parameter(Mandatory = $true)][string]$Root,
                [Parameter(Mandatory = $true)][hashtable]$Files
            )

            New-Item -ItemType Directory -Path $Root -Force | Out-Null
            foreach ($relativePath in $Files.Keys) {
                Set-Content -LiteralPath (Join-Path $Root $relativePath) -Value $Files[$relativePath] -Encoding utf8
            }
            return $Root
        }

        function New-AgentFixture {
            param(
                [Parameter(Mandatory = $true)][string]$Case,
                [Parameter(Mandatory = $true)][hashtable]$AgentFiles
            )

            $skills = New-SkillsRoot -Root (Join-Path $TestDrive "agent-$Case-skills") -Files @{
                'demo/SKILL.md' = (New-SkillContent)
            }
            $agents = New-AgentsRoot -Root (Join-Path $TestDrive "agent-$Case-agents") -Files $AgentFiles
            return Invoke-SkillValidator -Root $skills -AgentsRoot $agents
        }
    }

    It 'passes a well-formed agent' {
        $result = New-AgentFixture -Case 'good' -AgentFiles @{
            'review-lens.agent.md' = (New-AgentContent)
        }

        $result.ExitCode | Should -Be 0
        $result.Text | Should -Match 'OK: agents/review-lens\.agent\.md'
    }

    It 'passes a block-list tools value' {
        $content = "---`nname: review-lens`ndescription: `"Reads a diff with one lens.`"`ntools:`n  - grep`n  - view`nmodel: pinned-model-1`n---`n`nApply the lens."
        $result = New-AgentFixture -Case 'block-tools' -AgentFiles @{
            'review-lens.agent.md' = $content
        }

        $result.ExitCode | Should -Be 0
    }

    It 'passes when the agents folder is absent or holds no agent files' {
        $skills = New-SkillsRoot -Root (Join-Path $TestDrive 'agent-none-skills') -Files @{
            'demo/SKILL.md' = (New-SkillContent)
        }
        $keeper = New-AgentsRoot -Root (Join-Path $TestDrive 'agent-none-agents') -Files @{ '.gitkeep' = '' }

        (Invoke-SkillValidator -Root $skills).ExitCode | Should -Be 0
        (Invoke-SkillValidator -Root $skills -AgentsRoot $keeper).ExitCode | Should -Be 0
    }

    It 'fails when the frontmatter block does not parse' {
        $result = New-AgentFixture -Case 'unparsed' -AgentFiles @{
            'review-lens.agent.md' = "# review-lens`n`nNo frontmatter at all."
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'agents/review-lens\.agent\.md: frontmatter block does not parse'
    }

    It 'fails on unknown, missing, or duplicate frontmatter keys' -TestCases @(
        @{ Case = 'unknown'; Frontmatter = "name: review-lens`ndescription: `"Reads a diff.`"`ntools: [grep]`nmodel: m`nagent_type: custom" }
        @{ Case = 'missing-tools'; Frontmatter = "name: review-lens`ndescription: `"Reads a diff.`"`nmodel: m" }
        @{ Case = 'missing-model'; Frontmatter = "name: review-lens`ndescription: `"Reads a diff.`"`ntools: [grep]" }
        @{ Case = 'duplicate'; Frontmatter = "name: review-lens`nname: review-lens`ndescription: `"Reads a diff.`"`ntools: [grep]`nmodel: m" }
    ) {
        param($Case, $Frontmatter)

        $result = New-AgentFixture -Case "keys-$Case" -AgentFiles @{
            'review-lens.agent.md' = "---`n$Frontmatter`n---`n`nApply the lens."
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'frontmatter keys must be exactly name, description, tools, and model'
    }

    It 'fails when the name does not match the file name stem' {
        $result = New-AgentFixture -Case 'stem' -AgentFiles @{
            'review-lens.agent.md' = (New-AgentContent -Name 'other-lens')
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "name 'other-lens' does not match the file name stem 'review-lens'"
    }

    It 'fails when the model pin is empty' -TestCases @(
        @{ Case = 'blank'; Model = '""' }
        @{ Case = 'quoted-blank'; Model = "''" }
    ) {
        param($Case, $Model)

        $result = New-AgentFixture -Case "model-$Case" -AgentFiles @{
            'review-lens.agent.md' = (New-AgentContent -Model $Model)
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'model must be a non-empty pin'
    }

    It 'fails when tools is empty' -TestCases @(
        @{ Case = 'empty-list'; Tools = '[]' }
        @{ Case = 'blank'; Tools = '""' }
    ) {
        param($Case, $Tools)

        $result = New-AgentFixture -Case "tools-$Case" -AgentFiles @{
            'review-lens.agent.md' = (New-AgentContent -Tools $Tools)
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'tools must be a non-empty list'
    }

    It 'fails an unquoted description carrying a colon' {
        $result = New-AgentFixture -Case 'desc-colon' -AgentFiles @{
            'review-lens.agent.md' = (New-AgentContent -Description 'Reads a diff. Use when: a review fans out.')
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'description contains a colon and must be quoted'
    }

    It 'fails a harness leftover in an agent body' {
        $result = New-AgentFixture -Case 'harness' -AgentFiles @{
            'review-lens.agent.md' = (New-AgentContent -Body 'Adapt to whatever harness runs you.')
        }

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'agents/review-lens\.agent\.md: uses harness-conditional phrasing'
    }
}

Describe 'Validate-Skills reporting' {
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
