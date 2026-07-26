#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $script:PluginRoot = Join-Path $script:RepoRoot 'plugins\al-agentic-dev'
    $script:AgentsRoot = Join-Path $script:PluginRoot 'agents'
    $script:SkillsRoot = Join-Path $script:PluginRoot 'skills'
    $script:ReferencePath = Join-Path $script:PluginRoot 'references\review-lenses.md'
    $script:ReferenceText = Get-Content -LiteralPath $script:ReferencePath -Raw

    $script:Modes = @('code-review', 'refactor', 'architecture', 'test-spec', 'verification-plan')
    $script:InvocationErrorLine = 'LENS INVOCATION ERROR: missing or unrecognised Mode'
    $script:PerfSkipLine = 'perf scan skipped: al-performance MCP not available'

    # Agents in the al-review-* name family that are not lenses: they take no Mode,
    # carry no sentinel, and never reach the judge. Named here so the membership
    # checks below stay exhaustive over the lenses themselves.
    $script:NonLensReviewAgents = @('al-review-judge', 'al-review-red')

    # The membership table in review-lenses.md is the single source of truth for
    # which lens runs in which mode. Parse it rather than restating it here.
    function Get-LensMembership {
        $membership = [ordered]@{}
        foreach ($line in ($script:ReferenceText -split "`r?`n")) {
            $match = [regex]::Match($line, '^\|\s*`(?<lens>al-review-[a-z]+)`\s*\|(?<cells>.*)\|\s*$')
            if (-not $match.Success) { continue }

            $cells = @($match.Groups['cells'].Value -split '\|' | ForEach-Object { $_.Trim() })
            if (@($cells | Where-Object { $_ -ne '' -and $_ -ne 'x' }).Count -gt 0) { continue }
            if ($cells.Count -ne $script:Modes.Count) {
                throw "Membership row for $($match.Groups['lens'].Value) has $($cells.Count) mode cells, expected $($script:Modes.Count)"
            }

            $modes = @()
            for ($i = 0; $i -lt $cells.Count; $i++) {
                if ($cells[$i] -eq 'x') { $modes += $script:Modes[$i] }
            }

            $membership[$match.Groups['lens'].Value] = $modes
        }

        return $membership
    }

    function Get-LensSentinels {
        $sentinels = [ordered]@{}
        foreach ($line in ($script:ReferenceText -split "`r?`n")) {
            $match = [regex]::Match($line, '^\|\s*`(?<lens>al-review-[a-z]+)`\s*\|\s*`(?<sentinel>[A-Z][A-Z\- ]+)`\s*\|\s*$')
            if ($match.Success) { $sentinels[$match.Groups['lens'].Value] = $match.Groups['sentinel'].Value }
        }

        return $sentinels
    }

    $script:Membership = Get-LensMembership
    $script:Sentinels = Get-LensSentinels
}

Describe 'Review lens membership matrix' {
    It 'parses eleven lenses out of the reference' {
        $script:Membership.Keys.Count | Should -Be 11
    }

    It 'ships one agent file per lens in the matrix, and no lens outside it' {
        $onDisk = @(
            Get-ChildItem -LiteralPath $script:AgentsRoot -File -Filter 'al-review-*.agent.md' |
                ForEach-Object { $_.Name -replace '\.agent\.md$', '' } |
                Where-Object { $script:NonLensReviewAgents -notcontains $_ } |
                Sort-Object
        )

        ($onDisk -join ',') | Should -Be (($script:Membership.Keys | Sort-Object) -join ',')
    }

    It 'holds the per-gate lens counts the gates spawn' {
        $expected = @{
            'code-review'       = 6
            'refactor'          = 5
            'architecture'      = 5
            'test-spec'         = 5
            'verification-plan' = 3
        }

        foreach ($mode in $script:Modes) {
            $count = @($script:Membership.Keys | Where-Object { $script:Membership[$_] -contains $mode }).Count
            $count | Should -Be $expected[$mode] -Because "$mode runs $($expected[$mode]) lenses"
        }
    }

    It 'names every mode of its own row in each lens body' {
        foreach ($lens in $script:Membership.Keys) {
            $body = Get-Content -LiteralPath (Join-Path $script:AgentsRoot "$lens.agent.md") -Raw
            if ($body -match 'every mode') { continue }

            foreach ($mode in $script:Membership[$lens]) {
                $body | Should -Match "``$mode``" -Because "$lens runs in $mode"
            }
        }
    }

    It 'never names a mode outside its own row as a rule heading' {
        foreach ($lens in $script:Membership.Keys) {
            $body = Get-Content -LiteralPath (Join-Path $script:AgentsRoot "$lens.agent.md") -Raw
            foreach ($mode in $script:Modes) {
                if ($script:Membership[$lens] -contains $mode) { continue }
                $body | Should -Not -Match "\*\*``$mode``" -Because "$lens does not run in $mode"
            }
        }
    }
}

Describe 'Review lens return contract' {
    It 'registers a unique sentinel for every lens' {
        $script:Sentinels.Keys.Count | Should -Be 11
        ($script:Sentinels.Values | Sort-Object -Unique).Count | Should -Be 11
        ($script:Sentinels.Keys | Sort-Object) -join ',' | Should -Be (($script:Membership.Keys | Sort-Object) -join ',')
    }

    It 'carries its own sentinel and the shared reference in each lens body' {
        foreach ($lens in $script:Membership.Keys) {
            $body = Get-Content -LiteralPath (Join-Path $script:AgentsRoot "$lens.agent.md") -Raw
            $body | Should -Match ([regex]::Escape($script:Sentinels[$lens]))
            $body | Should -Match 'references/review-lenses\.md'
        }
    }

    It 'states the exact invocation-error line in every lens and in the reference' {
        $script:ReferenceText | Should -Match ([regex]::Escape($script:InvocationErrorLine))

        foreach ($lens in $script:Membership.Keys) {
            $body = Get-Content -LiteralPath (Join-Path $script:AgentsRoot "$lens.agent.md") -Raw
            $body | Should -Match ([regex]::Escape($script:InvocationErrorLine)) -Because "$lens must fail closed on a bad mode"
        }
    }

    It 'keeps the performance skip line on the perf lens and both calling skills' {
        $carriers = @(
            (Join-Path $script:AgentsRoot 'al-review-perf.agent.md'),
            (Join-Path $script:SkillsRoot 'al-code-review\SKILL.md'),
            (Join-Path $script:SkillsRoot 'al-refactor\SKILL.md')
        )

        foreach ($path in $carriers) {
            Get-Content -LiteralPath $path -Raw | Should -Match ([regex]::Escape($script:PerfSkipLine))
        }
    }
}

Describe 'Review gate wiring' {
    BeforeAll {
        # One entry per wired gate skill. A skill whose branches review different
        # artifacts declares every mode it drives; the lens set it must name is the
        # union of those columns.
        $script:Gates = [ordered]@{
            'al-code-review' = @('code-review')
            'al-refactor'    = @('refactor')
            'al-refine'      = @('test-spec', 'verification-plan')
        }
    }

    It 'spawns exactly the matrix lens set from each wired gate' {
        foreach ($skill in $script:Gates.Keys) {
            $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot "$skill\SKILL.md") -Raw
            $named = @(
                [regex]::Matches($body, '`(al-review-[a-z]+)`') |
                    ForEach-Object { $_.Groups[1].Value } |
                    Where-Object { $script:NonLensReviewAgents -notcontains $_ } |
                    Select-Object -Unique |
                    Sort-Object
            )

            $modes = $script:Gates[$skill]
            $expected = @(
                $script:Membership.Keys |
                    Where-Object { @($script:Membership[$_] | Where-Object { $modes -contains $_ }).Count -gt 0 } |
                    Sort-Object
            )
            ($named -join ',') | Should -Be ($expected -join ',') -Because "/$skill runs the $($modes -join ' + ') column"
        }
    }

    It 'declares the mode on every lens and judge invocation' {
        foreach ($skill in $script:Gates.Keys) {
            $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot "$skill\SKILL.md") -Raw
            foreach ($mode in $script:Gates[$skill]) {
                $body | Should -Match "Mode: $mode" -Because "/$skill declares $mode"
            }
        }
    }
}

Describe 'Plan-gate stop shape' {
    It 'homes the dispositions and the plugin-gap record in the shared reference' {
        $script:ReferenceText | Should -Match 'A blocking finding on a plan'

        foreach ($token in @('self-resolvable', 'upstream', 'Plugin gap:', 'Let through:', 'Would have caught it:')) {
            $script:ReferenceText | Should -Match ([regex]::Escape($token)) -Because "the stop shape carries $token"
        }
    }

    It 'points the refine gate at that home rather than forking it' {
        $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-refine\SKILL.md') -Raw
        $body | Should -Match 'A blocking finding on a plan'
        $body | Should -Not -Match ([regex]::Escape('Plugin gap:'))
    }

    It 'keeps the retired rubber-duck consult out of the refine gate' {
        $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-refine\SKILL.md') -Raw
        $body | Should -Not -Match 'rubber-duck'
    }
}

Describe 'Judge mode fence' {
    BeforeAll {
        $script:JudgeBody = Get-Content -LiteralPath (Join-Path $script:AgentsRoot 'al-review-judge.agent.md') -Raw
    }

    It 'fences the three extra rules on the declared code-review mode' {
        $script:JudgeBody | Should -Match '`code-review` mode only'
        $script:JudgeBody | Should -Match 'Mode: code-review'
    }

    It 'no longer fences on a lens name prefix' {
        $script:JudgeBody | Should -Not -Match 'al-review-cr-'
        $script:JudgeBody | Should -Not -Match 'al-review-refactor-'
    }

    It 'fails closed on a missing mode' {
        $script:JudgeBody | Should -Match 'JUDGE INVOCATION ERROR: missing or unrecognised Mode'
    }
}

Describe 'Retired gate-scoped lens names' {
    It 'survives nowhere in the marketplace' {
        $files = @(
            Get-ChildItem -LiteralPath $script:PluginRoot -Recurse -File -Include '*.md', '*.json'
            Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'scripts') -File -Filter '*.ps1'
            Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'tests') -Recurse -File -Filter '*.ps1'
        )

        $hits = @($files | Select-String -Pattern 'al-review-(cr|refactor)-' | Where-Object {
                $_.Path -notlike '*ReviewLenses.Tests.ps1'
            })

        $hits | Should -BeNullOrEmpty
    }
}
