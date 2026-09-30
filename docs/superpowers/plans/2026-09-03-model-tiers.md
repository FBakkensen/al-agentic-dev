# Model Tiers and Step-Level Delegation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Fable 5.1 lead orchestrates cheaper models through three named tiers (`frontier`, `execution`, `mechanical`) that a user config file names, the sessionStart hook injects, `/al-setup-models` writes, and every delegating skill reaches through one `▶` line per step.

**Architecture:** `skills/al-setup-models/models.default.json` is the single shipped default; the hook (`hooks.json`, bash and PowerShell bodies) reads `~/.copilot/al-agentic-dev/models.json`, falls back per tier to those defaults, and injects a `# Model tiers` block between Reply shape and Speak BC. Skills carry `▶ <tier> · <vehicle> · <brief> → <return>` lines at the steps they delegate; `scripts/Validate-Skills.ps1` enforces the grammar, bans model names in skills, and validates the defaults file. Agents keep pins that a Pester test holds equal to the default tier models.

**Tech Stack:** PowerShell 7.2+ (`#Requires -Version 7.2`), Pester 5, bash (hook body), JSON, Markdown skills.

**Spec:** `docs/superpowers/specs/2026-09-03-model-tiers-design.md` — every task below cites the decision it implements. Read it first.

## Global Constraints

- One package, version `3.1.0` → `4.0.0` in `plugin.json` and `.github/plugin/marketplace.json` (`metadata.version` and `plugins[0].version`). No phases.
- Tiers and shipped defaults, exact: `frontier` = `claude-fable-5.1` / `high`; `execution` = `gpt-5.6-sol` / `medium`; `mechanical` = `gpt-5.6-luna` / `max`.
- User file path: `~/.copilot/al-agentic-dev/models.json`, shape `{"version":1,"tiers":{"frontier":{"model":…,"effort":…},"execution":{…},"mechanical":{…}}}`.
- Fallback line, exact: `Defaults in use — run /al-setup-models to set your models.` (absent or unparseable file) and `Defaults in use for <tier, tier> — run /al-setup-models to set your models.` (some tiers missing or broken).
- `▶` grammar, exact regex the gate applies to every prose line (outside fences and code spans) that contains `▶`: `^\s*(?:[-*]|\d+\.)?\s*▶ (frontier|execution|mechanical) · (task|session) · .+ → .+$`. Separator is ` · ` (U+00B7 with spaces), arrow is ` → ` (U+2192), lede is `▶` (U+25B6).
- No model name from `models.default.json` appears in any `skills/**/*.md` — the gate fails it. A skill names a tier, never a model.
- Unattended line, exact: `You run unattended; the user cannot answer mid-task. Proceed on every reversible step the User Story already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.`
- Question rule, exact, in every authored SKILL.md: `Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.`
- SKILL.md body ≤ 60 lines (`al-build` 80). Replace prose with `▶` lines; do not append.
- Skill frontmatter: only `name` and `description`. No `.ps1` or `scripts/` outside `skills/al-build/`. No links leaving the skill folder. No `harness`. No lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`) — write `tier ·`, never `tier:`.
- Pinned strings other tests assert (keep verbatim while editing): al-implement `Name /al-refactor as the next move`, `proof-preserving reshapes before new expectations or production changes`, `require its current scope green`, `rerun the gate green`, `Every new or materially reshaped automated proof earns a red`, `inject one compiling fault`, `connected-object change map`, `every changed production object`, `simple module may need the implementation map but no Original User Story Level 2`, and no `Tidy:`; al-orchestrate `Launch a fresh /al-refactor child stacked on the implementation branch` and no `Tidy: none`; al-refactor `` `Tidy: none` or the exact reshapes ``, `Compare the landed tests with the accepted proof map`, `require its current scope green`, `Every new or materially reshaped proof born green takes mutation as its red`; al-review `implementation change map includes every changed production object`; al-test-design `search the repository for existing proof`, `Current-to-final proof map`, `` keep`, `reshape`, `combine`, `split`, `replace`, or `add ``, `` Acceptance Criteria, after `## Behavior` when both are present ``; `/al-commit` present in al-clone-bcapps, al-clone-bcquality, al-design, al-grill-adr, al-implement, al-lookup, al-pr-shepherd, al-refactor; `/al-azure-devops-attachments` present and `manual attach` absent in al-event-model, al-design, al-implement, al-refactor; no `\bFeature\b` in work-item skills.
- Pinned forks `al-grill-me`, `al-unslop`: untouched. `al-build` scripts: untouched.
- Every commit carries the trailer `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
- Test runs: `pwsh scripts/Invoke-Tests.ps1 -Mode Fast` for the loop; `-Mode Full` once at the end, delegated to a task agent at the mechanical tier (`gpt-5.6-luna`), which runs it once and never reruns Pester to recover output.
- Gates before the PR: `pwsh scripts/Validate-Json.ps1`, `pwsh scripts/Validate-PowerShell.ps1`, `pwsh scripts/Validate-Skills.ps1`, `pwsh scripts/Update-Review.ps1 -Check`, `pwsh scripts/Invoke-Tests.ps1 -Mode Full`.

---

## File map

| Path | Responsibility |
|---|---|
| `skills/al-setup-models/models.default.json` | Create. The single shipped tier→model map. |
| `skills/al-setup-models/SKILL.md` | Create. Shows the built-in map, writes the user file. |
| `scripts/Validate-Skills.ps1` | Modify. Checks (a) `▶` grammar, (b) model-name ban, (c) defaults file shape. |
| `tests/Validate-Skills.Tests.ps1` | Modify. Red fixtures for (a)(b)(c). |
| `hooks.json` | Modify. sessionStart bash + powershell bodies read the user file and inject `# Model tiers`. |
| `tests/ModelTiers.Tests.ps1` | Create. Hook body runs (HOME absent/valid/broken/partial), block order, byte-equal defaults, agent-pin drift. |
| `tests/hooks/Invoke-HookSmoke.ps1` | Modify. Two assertions that `Model tiers` echoes. |
| `tests/routing/scenarios.json` | Modify. Append S42. |
| `tests/README.md` | Modify. Name the new suite and the extra hook assertion. |
| `agents/al-review-lens.agent.md` | Modify. `model: gpt-5.6-sol`. |
| `.github/instructions/skills.instructions.md` | Modify. Rules 8, 28, 29, 33; new section with rule 38. |
| `REVIEW.md` | Regenerate via `scripts/Update-Review.ps1`. |
| `skills/{al-implement,al-refactor,al-review,al-pr-shepherd,al-orchestrate,al-walkthrough,al-design,al-event-model,al-test-design,al-next,al-miner,al-grill-adr}/SKILL.md` | Modify. `▶` lines per spec §6. |
| `.github/copilot-instructions.md`, `README.md`, `tests/ArtifactContracts.Tests.ps1`, `plugin.json`, `.github/plugin/marketplace.json` | Modify. Docs, one assertion, version. |

---

### Task 1: `al-setup-models` skill, the defaults file, and check (c)

Implements spec §1 (defaults), §2 (the skill), §8 check (c).

**Files:**
- Create: `skills/al-setup-models/models.default.json`
- Create: `skills/al-setup-models/SKILL.md`
- Modify: `scripts/Validate-Skills.ps1` (after line 91 `$skillFolders = …`, and the `.DESCRIPTION` block)
- Modify: `tests/Validate-Skills.Tests.ps1` (append a Describe before line 777 `Describe 'Validate-Skills agent checks'`)
- Modify: `tests/routing/scenarios.json` (append S42)

**Interfaces:**
- Produces: `$modelNames` (string array of the three default model names) inside `Invoke-SkillsValidation`, consumed by Task 2 check (b). Violation prefixes: `al-setup-models/models.default.json: …`.

- [ ] **Step 1: Write the failing tests for check (c)**

Insert before `Describe 'Validate-Skills agent checks' -Tag 'Unit' {` in `tests/Validate-Skills.Tests.ps1`:

```powershell
Describe 'Validate-Skills model-tier defaults checks' -Tag 'Unit' {
    BeforeAll {
        $script:GoodDefaults = '{"version":1,"tiers":{"frontier":{"model":"model-f","effort":"high"},"execution":{"model":"model-e","effort":"medium"},"mechanical":{"model":"model-m","effort":"max"}}}'
    }

    It 'passes a well-formed models.default.json beside al-setup-models' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'defaults-good') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = $script:GoodDefaults
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'fails al-setup-models without models.default.json' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'defaults-missing') -Files @{
            'al-setup-models/SKILL.md' = (New-SkillContent -Name 'al-setup-models')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'al-setup-models/models\.default\.json: missing'
    }

    It 'fails models.default.json that does not parse' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'defaults-broken') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = '{not json'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'al-setup-models/models\.default\.json: does not parse'
    }

    It 'fails models.default.json whose tiers are not exactly frontier, execution, mechanical' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'defaults-tiers') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = '{"version":1,"tiers":{"frontier":{"model":"model-f","effort":"high"},"execution":{"model":"model-e","effort":"medium"}}}'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'tiers must be exactly frontier, execution, mechanical'
    }

    It 'fails a tier with an empty model or effort' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'defaults-empty') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = '{"version":1,"tiers":{"frontier":{"model":"model-f","effort":"high"},"execution":{"model":"model-e","effort":""},"mechanical":{"model":"model-m","effort":"max"}}}'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "tier 'execution' needs a non-empty model and effort"
    }
}

```

- [ ] **Step 2: Run the new Describe to verify it fails**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Validate-Skills.Tests.ps1 -FullNameFilter '*model-tier defaults*' -Output Detailed"`
Expected: 4 failed (missing, broken, tiers, empty — the validator reports nothing about the defaults yet), 1 passed.

- [ ] **Step 3: Add check (c) to the validator**

In `scripts/Validate-Skills.ps1`, after the line `$skillFolders = @(Get-ChildItem -LiteralPath $root -Directory | ForEach-Object Name)` insert:

```powershell
# Model tiers: skills/al-setup-models/models.default.json is the single shipped default.
# When that skill folder exists, the file must exist, parse, and hold exactly the three
# tiers with a non-empty model and effort each. Its model names feed the skill-body ban.
$modelNames = @()
$setupFolder = Join-Path $root 'al-setup-models'
$defaultsPath = Join-Path $setupFolder 'models.default.json'
if (Test-Path -LiteralPath $setupFolder -PathType Container) {
    if (-not (Test-Path -LiteralPath $defaultsPath -PathType Leaf)) {
        $violations += 'al-setup-models/models.default.json: missing'
    } else {
        $defaults = $null
        try { $defaults = Get-Content -LiteralPath $defaultsPath -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $defaults = $null }
        if (-not $defaults) {
            $violations += 'al-setup-models/models.default.json: does not parse'
        } else {
            $expectedTiers = @('frontier', 'execution', 'mechanical')
            $tierNames = @()
            if ($defaults.tiers) { $tierNames = @($defaults.tiers.PSObject.Properties.Name) }
            if (($tierNames -join ',') -cne ($expectedTiers -join ',')) {
                $violations += "al-setup-models/models.default.json: tiers must be exactly frontier, execution, mechanical (found: $($tierNames -join ', '))"
            }
            foreach ($tier in $expectedTiers) {
                $entry = if ($defaults.tiers) { $defaults.tiers.$tier } else { $null }
                if (-not $entry -or -not [string]$entry.model -or -not [string]$entry.effort) {
                    $violations += "al-setup-models/models.default.json: tier '$tier' needs a non-empty model and effort"
                } else {
                    $modelNames += [string]$entry.model
                }
            }
        }
    }
}
```

In the `.DESCRIPTION` block, after the sentence ending `an al-prefixed reference with no folder is a violation.` add:

```
    Model tiers: when skills/al-setup-models exists, its models.default.json must parse and
    hold exactly the tiers frontier, execution, and mechanical, each with a non-empty model
    and effort; no model name from that file may appear in any skill markdown; and every
    prose ▶ line matches the delegation grammar
    '▶ <tier> · <vehicle> · <brief> → <return>' with tier in frontier|execution|mechanical
    and vehicle in task|session.
```

- [ ] **Step 4: Run the Describe to verify it passes**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Validate-Skills.Tests.ps1 -FullNameFilter '*model-tier defaults*' -Output Detailed"`
Expected: 5 passed.

- [ ] **Step 5: Create the defaults file**

Create `skills/al-setup-models/models.default.json`:

```json
{
  "version": 1,
  "tiers": {
    "frontier": { "model": "claude-fable-5.1", "effort": "high" },
    "execution": { "model": "gpt-5.6-sol", "effort": "medium" },
    "mechanical": { "model": "gpt-5.6-luna", "effort": "max" }
  }
}
```

- [ ] **Step 6: Create the skill**

Create `skills/al-setup-models/SKILL.md`:

````markdown
---
name: al-setup-models
description: "Use when the model tiers need setting or changing — a new session reports Defaults in use, the user names which model runs a tier, or a model in the map no longer exists in the task tool's model list."
---

# al-setup-models — write the model map

In: the built-in map in [models.default.json](models.default.json) beside this file, any `tier=model` pairs on the invocation line, and the user's existing `~/.copilot/al-agentic-dev/models.json` when present. Out: that file written, and the `# Model tiers` block every later session receives. This skill writes only outside the repository.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Show the map

Read the built-in file. Apply each `tier=model` pair from the invocation line to its row. Show three rows as `tier · model · effort · what it is for`:

- `frontier` — design, judgment, verdicts, uncertain work
- `execution` — writing code and tests from a brief
- `mechanical` — running gates, commits, renders, lookups, review lenses

When the existing file differs from the proposal, show its rows beside the proposal. Ask one question: **A** adopt the map as shown (recommended), **B** change rows.

## Change rows

On B, list the models the `task` tool's `model` parameter description offers in this session — the names and the efforts each supports come from that description, never from recall. Ask one question per row the user wants changed, lettered from that list with the built-in value marked. An effort outside the chosen model's set is corrected in the proposal and named, not asked. Return to the map once every changed row is settled.

## Write the file

Create `~/.copilot/al-agentic-dev/` when absent and write `models.json`:

```json
{"version":1,"tiers":{"frontier":{"model":"<model>","effort":"<effort>"},"execution":{"model":"<model>","effort":"<effort>"},"mechanical":{"model":"<model>","effort":"<effort>"}}}
```

Show the written file. The sessionStart hook reads it at every session start; a missing or unparseable tier falls back to the built-in row and the injected block names it.

## Close

Close with the `# Model tiers` block as the hook will inject it — the three rows, then the dispatch rule — and two facts: this session uses the map from now; every later session gets it at start. Agent pins, the plugin install, and per-repo overrides stay out.
````

- [ ] **Step 7: Append routing scenario S42**

In `tests/routing/scenarios.json`, after the S41 object (the last one), add:

```json
    ,
    {
      "id": "S42",
      "prompt": "Set which models the plugin uses for its frontier, execution, and mechanical tiers.",
      "expect": "al-setup-models"
    }
```

(Place the comma correctly: the S41 object gains a trailing comma and the new object follows it inside the array.)

- [ ] **Step 8: Run the validators**

Run: `pwsh scripts/Validate-Skills.ps1; pwsh scripts/Validate-Json.ps1`
Expected: `OK: al-setup-models` in the list, `All skills validated successfully.`, and Validate-Json exit 0.

- [ ] **Step 9: Commit**

```powershell
git add skills/al-setup-models scripts/Validate-Skills.ps1 tests/Validate-Skills.Tests.ps1 tests/routing/scenarios.json
git commit -m "al-setup-models: ship the model-tier defaults and the skill that writes the user map

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Validator checks (a) `▶` grammar and (b) model-name ban

Implements spec §3 (grammar) and §8 checks (a)(b).

**Files:**
- Modify: `scripts/Validate-Skills.ps1` (new helper after `Get-MarkdownLinkTarget`; new checks after the slash-mention loop that ends at `}` before `if ($violations.Count -eq $skillCount)`)
- Modify: `tests/Validate-Skills.Tests.ps1` (append a Describe after the model-tier defaults Describe)

**Interfaces:**
- Consumes: `$modelNames` from Task 1.
- Produces: `Get-ProseLine -Text <string>` returning lines outside fences with inline code spans removed. Violation texts: `<file>: ▶ line outside the delegation grammar '▶ <tier> · <vehicle> · <brief> → <return>': <line>` and `<file>: names the model '<name>'; name a tier on a ▶ line instead`.

- [ ] **Step 1: Write the failing tests**

Append after the `Describe 'Validate-Skills model-tier defaults checks'` block:

```powershell
Describe 'Validate-Skills delegation checks' -Tag 'Unit' {
    BeforeAll {
        $script:GoodDefaults = '{"version":1,"tiers":{"frontier":{"model":"model-f","effort":"high"},"execution":{"model":"model-e","effort":"medium"},"mechanical":{"model":"model-m","effort":"max"}}}'
    }

    It 'passes ▶ lines in the grammar, a code-span ▶, and a fenced ▶' {
        $body = @'
Before changing a test:

▶ mechanical · task · /al-build gate on the slice → summary.json verdict, exact red cause

1. ▶ execution · session · /al-implement with the work item → branch, commit, receipt

- ▶ frontier · task · judge the two module boundaries → the chosen boundary with its reason

For each step report `▶ <business action>` and the observed result.

```text
▶ anything goes inside a fence
```
'@
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'delegation-good') -Files @{
            'demo/SKILL.md'     = (New-SkillContent -Body $body)
            'al-build/SKILL.md' = (New-SkillContent -Name 'al-build')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }

    It 'fails a ▶ line outside the grammar' -TestCases @(
        @{ Case = 'tier'; Line = '▶ quick · task · run the gate → verdict' }
        @{ Case = 'vehicle'; Line = '▶ mechanical · agent · run the gate → verdict' }
        @{ Case = 'return'; Line = '▶ mechanical · task · run the gate' }
        @{ Case = 'prose'; Line = 'Then ▶ the worker runs the gate.' }
        @{ Case = 'colon'; Line = '▶ mechanical: task: run the gate → verdict' }
    ) {
        param($Case, $Line)

        $root = New-SkillsRoot -Root (Join-Path $TestDrive "delegation-$Case") -Files @{
            'demo/SKILL.md' = (New-SkillContent -Body $Line)
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'outside the delegation grammar'
    }

    It 'fails a ▶ line outside the grammar in a sibling file' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'delegation-sibling') -Files @{
            'demo/SKILL.md'  = (New-SkillContent -Body 'See [Format](FORMAT.md).')
            'demo/FORMAT.md' = '# Format' + [Environment]::NewLine + '▶ run it'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match 'demo/FORMAT\.md: ▶ line outside the delegation grammar'
    }

    It 'fails a default model name in a skill body' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'model-name-body') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = $script:GoodDefaults
            'demo/SKILL.md'                       = (New-SkillContent -Body 'Dispatch the gate on model-e.')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "demo/SKILL\.md: names the model 'model-e'"
    }

    It 'fails a default model name in a sibling file, case-insensitively' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'model-name-sibling') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = $script:GoodDefaults
            'demo/SKILL.md'                       = (New-SkillContent -Body 'See [Format](FORMAT.md).')
            'demo/FORMAT.md'                      = 'Pinned to Model-M.'
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Text | Should -Match "demo/FORMAT\.md: names the model 'model-m'"
    }

    It 'passes a tier name where a model name would fail' {
        $root = New-SkillsRoot -Root (Join-Path $TestDrive 'model-name-tier') -Files @{
            'al-setup-models/SKILL.md'            = (New-SkillContent -Name 'al-setup-models')
            'al-setup-models/models.default.json' = $script:GoodDefaults
            'demo/SKILL.md'                       = (New-SkillContent -Body '▶ mechanical · task · run the gate → verdict')
        }

        $result = Invoke-SkillValidator -Root $root

        $result.ExitCode | Should -Be 0
    }
}

```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Validate-Skills.Tests.ps1 -FullNameFilter '*delegation checks*' -Output Detailed"`
Expected: the five `fails …` cases plus the sibling and two model-name cases fail (8 failed), the two `passes …` cases pass.

- [ ] **Step 3: Add the helper and the checks**

In `scripts/Validate-Skills.ps1`, after the closing `}` of `function Get-MarkdownLinkTarget`, add:

```powershell
function Get-ProseLine {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $fenceChar = ''
    $fenceLength = 0
    foreach ($line in ($Text -split '\r?\n')) {
        $run = [regex]::Match($line, '^\s*(?<fence>`{3,}|~{3,})')
        if ($run.Success) {
            $fence = $run.Groups['fence'].Value
            if ($fenceLength -eq 0) {
                $fenceChar = $fence[0]
                $fenceLength = $fence.Length
                continue
            } elseif ($fence[0] -eq $fenceChar -and $fence.Length -ge $fenceLength) {
                $fenceLength = 0
                continue
            }
        }
        if ($fenceLength -gt 0) { continue }
        $line -replace '`[^`]*`', ''
    }
}
```

Inside the markdown loop, after the slash-mention `foreach ($mention …) { … }` block and before `    }` that closes `foreach ($markdown …)`, add:

```powershell
        $delegationGrammar = '^\s*(?:[-*]|\d+\.)?\s*▶ (frontier|execution|mechanical) · (task|session) · .+ → .+$'
        foreach ($prose in (Get-ProseLine -Text $body)) {
            if ($prose -notmatch '▶') { continue }
            if ($prose -notmatch $delegationGrammar) {
                $violations += "${relative}: ▶ line outside the delegation grammar '▶ <tier> · <vehicle> · <brief> → <return>': $($prose.Trim())"
            }
        }

        foreach ($modelName in $modelNames) {
            if ([string]$text -match [regex]::Escape($modelName)) {
                $violations += "${relative}: names the model '$modelName'; name a tier on a ▶ line instead"
            }
        }
```

`$body` is the post-frontmatter text for SKILL.md and the whole text for siblings — already computed above. `-match` is case-insensitive by default, which the sibling test relies on.

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/Validate-Skills.Tests.ps1 -Output Normal"`
Expected: all tests pass, 0 failed.

- [ ] **Step 5: Run the validator on the real skills**

Run: `pwsh scripts/Validate-Skills.ps1`
Expected: `All skills validated successfully.` If a `FAIL: … ▶ line outside the delegation grammar` names an existing sibling file (for example `al-event-model/BPMN.md`), that line is prose using `▶` as decoration: wrap the `▶` token in backticks in that file and rerun.

- [ ] **Step 6: Commit**

```powershell
git add scripts/Validate-Skills.ps1 tests/Validate-Skills.Tests.ps1
git commit -m "Validate-Skills: gate the ▶ delegation grammar and ban default model names in skills

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: sessionStart hook injects `# Model tiers`

Implements spec §1 (hook), §8 hook tests.

**Files:**
- Modify: `hooks.json` (`hooks.sessionStart[0].bash` and `.powershell`)
- Create: `tests/ModelTiers.Tests.ps1`
- Modify: `tests/hooks/Invoke-HookSmoke.ps1` (two assertions)
- Modify: `tests/README.md`

**Interfaces:**
- Produces: the `# Model tiers` block text (below); the inline default literal in both bodies (`$d = '<compact json>'` in PowerShell, `D='<compact json>'` in bash) equal to `models.default.json` with all whitespace removed.

The block the hook appends after Reply shape (and before Speak BC when the cwd is an AL repo), with default rows:

```
# Model tiers
| Tier | Model | Effort | For |
|---|---|---|---|
| frontier | claude-fable-5.1 | high | design, judgment, verdicts, uncertain work |
| execution | gpt-5.6-sol | medium | writing code and tests from a brief |
| mechanical | gpt-5.6-luna | max | running gates, commits, renders, lookups, review lenses |
Defaults in use — run /al-setup-models to set your models.

A `▶ <tier> · <vehicle> · <brief> → <return>` line dispatches now, with that tier's model and effort passed explicitly. `task`: launch in the background with `model` and `reasoning_effort` set; `read_agent wait:true` where the next step needs the result; answer its question with `write_agent`. `session`: `create_session` with kickoff mode `autopilot`, `model`, `reasoning_effort`, `coordinate_with_creator`, and `notify_on_idle`; answer with `send_session_message`. A packaged agent takes the tier's model as its `model` override. Delegation is down only: no skill detects its own model or spawns upward.
```

The `Defaults in use …` line appears only when the file is absent or unparseable; `Defaults in use for <tiers> — …` when some tiers fell back; neither when every tier came from the file.

- [ ] **Step 1: Write the failing tests**

Create `tests/ModelTiers.Tests.ps1`:

```powershell
#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Hooks = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'hooks.json') -Raw | ConvertFrom-Json
    $script:Start = @($script:Hooks.hooks.sessionStart)[0]
    $script:DefaultsPath = Join-Path $script:RepoRoot 'skills' 'al-setup-models' 'models.default.json'
    $script:DefaultsCompact = (Get-Content -LiteralPath $script:DefaultsPath -Raw) -replace '\s', ''
    $script:Defaults = Get-Content -LiteralPath $script:DefaultsPath -Raw | ConvertFrom-Json

    # bash counts as available only when it sees the HOME this test sets (Git Bash and
    # Linux do; a WSL bash on PATH does not share the Windows environment).
    $script:BashUsable = $false
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        $probe = Join-Path ([System.IO.Path]::GetTempPath()) "home-probe-$([guid]::NewGuid())"
        $saved = $env:HOME
        try {
            $env:HOME = $probe
            $seen = (bash -c 'printf %s "$HOME"' 2>$null) -join ''
            $script:BashUsable = ($seen -replace '\\', '/') -eq ($probe -replace '\\', '/')
        } finally { $env:HOME = $saved }
    }

    function Invoke-SessionStart {
        param(
            [Parameter(Mandatory = $true)][ValidateSet('powershell', 'bash')][string]$Shell,
            [Parameter(Mandatory = $true)][string]$HomeDir,
            [Parameter(Mandatory = $true)][string]$Cwd
        )

        $body = $script:Start.$Shell
        $stdin = @{ cwd = $Cwd } | ConvertTo-Json -Compress
        $savedHome = $env:HOME
        $savedProfile = $env:USERPROFILE
        try {
            $env:HOME = $HomeDir
            $env:USERPROFILE = $HomeDir
            if ($Shell -eq 'powershell') {
                $file = Join-Path $TestDrive "start-$([guid]::NewGuid()).ps1"
                Set-Content -LiteralPath $file -Value $body -Encoding utf8
                $out = $stdin | pwsh -NoProfile -File $file
            } else {
                $file = Join-Path $TestDrive "start-$([guid]::NewGuid()).sh"
                Set-Content -LiteralPath $file -Value $body -Encoding utf8
                $out = $stdin | bash $file
            }
        } finally {
            $env:HOME = $savedHome
            $env:USERPROFILE = $savedProfile
        }
        return (($out -join "`n") | ConvertFrom-Json).additionalContext
    }

    function New-HomeDir {
        param([string]$Name, [string]$ModelsJson)
        $dir = Join-Path $TestDrive "home-$Name"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        if ($null -ne $ModelsJson) {
            $folder = Join-Path $dir '.copilot' 'al-agentic-dev'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $folder 'models.json') -Value $ModelsJson -Encoding utf8
        }
        return $dir
    }

    function Get-DefaultRow {
        param([string]$Tier, [string]$For)
        return "| $Tier | $($script:Defaults.tiers.$Tier.model) | $($script:Defaults.tiers.$Tier.effort) | $For |"
    }
}

Describe 'sessionStart hook model tiers' -Tag 'Process' {
    BeforeAll {
        $script:Cases = @(
            @{ Shell = 'powershell' }
            @{ Shell = 'bash' }
        )
        $script:UserMap = '{"version":1,"tiers":{"frontier":{"model":"user-f","effort":"low"},"execution":{"model":"user-e","effort":"medium"},"mechanical":{"model":"user-m","effort":"high"}}}'
        $script:PartialMap = '{"version":1,"tiers":{"frontier":{"model":"user-f","effort":"low"}}}'
    }

    It 'injects the shipped defaults with the Defaults line when the file is absent (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "absent-$Shell") -Cwd $TestDrive

        $context | Should -Match '# Model tiers'
        $context | Should -Match '\| Tier \| Model \| Effort \| For \|'
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'frontier' -For 'design, judgment, verdicts, uncertain work')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'execution' -For 'writing code and tests from a brief')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'mechanical' -For 'running gates, commits, renders, lookups, review lenses')))
        $context | Should -Match 'Defaults in use — run /al-setup-models to set your models\.'
        $context | Should -Match 'A `▶ <tier> · <vehicle> · <brief> → <return>` line dispatches now'
        $context | Should -Match 'Delegation is down only'
    }

    It 'injects the user map without the Defaults line when the file is valid (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "valid-$Shell" -ModelsJson $script:UserMap) -Cwd $TestDrive

        $context | Should -Match '\| frontier \| user-f \| low \|'
        $context | Should -Match '\| execution \| user-e \| medium \|'
        $context | Should -Match '\| mechanical \| user-m \| high \|'
        $context | Should -Not -Match 'Defaults in use'
    }

    It 'falls back to the shipped defaults with the Defaults line when the file is broken (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "broken-$Shell" -ModelsJson '{not json') -Cwd $TestDrive

        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'frontier' -For 'design, judgment, verdicts, uncertain work')))
        $context | Should -Match 'Defaults in use — run /al-setup-models to set your models\.'
    }

    It 'falls back per tier and names the fallen tiers when some are missing (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "partial-$Shell" -ModelsJson $script:PartialMap) -Cwd $TestDrive

        $context | Should -Match '\| frontier \| user-f \| low \|'
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'execution' -For 'writing code and tests from a brief')))
        $context | Should -Match ([regex]::Escape((Get-DefaultRow -Tier 'mechanical' -For 'running gates, commits, renders, lookups, review lenses')))
        $context | Should -Match 'Defaults in use for execution, mechanical — run /al-setup-models to set your models\.'
    }

    It 'places the block after Reply shape and before Speak BC in an AL repo (<Shell>)' -TestCases $script:Cases {
        param($Shell)
        if ($Shell -eq 'bash' -and -not $script:BashUsable) { Set-ItResult -Skipped -Because 'bash is not on PATH or does not share HOME'; return }
        $alDir = Join-Path $TestDrive "al-$Shell"
        New-Item -ItemType Directory -Path $alDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $alDir 'app.json') -Value '{"id":"00000000-0000-0000-0000-000000000000"}' -Encoding utf8

        $context = Invoke-SessionStart -Shell $Shell -HomeDir (New-HomeDir -Name "order-$Shell") -Cwd $alDir

        $reply = $context.IndexOf('# Reply shape')
        $tiers = $context.IndexOf('# Model tiers')
        $voice = $context.IndexOf('# Speak BC')
        $reply | Should -BeGreaterOrEqual 0
        $tiers | Should -BeGreaterThan $reply
        $voice | Should -BeGreaterThan $tiers
    }
}

Describe 'Model tier defaults are single-sourced' -Tag 'Unit' {
    It 'keeps the PowerShell hook inline defaults equal to models.default.json' {
        $literal = [regex]::Match($script:Start.powershell, "(?m)^\`$d = '(\{.*?\})'\s*$").Groups[1].Value
        $literal | Should -Not -BeNullOrEmpty
        $literal | Should -Be $script:DefaultsCompact
    }

    It 'keeps the bash hook inline defaults equal to models.default.json' {
        $literal = [regex]::Match($script:Start.bash, "(?m)^D='(\{.*?\})'\s*$").Groups[1].Value
        $literal | Should -Not -BeNullOrEmpty
        $literal | Should -Be $script:DefaultsCompact
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/ModelTiers.Tests.ps1 -Output Detailed"`
Expected: every `sessionStart hook model tiers` case fails on `# Model tiers` (powershell) or is skipped (bash where unusable); both single-source tests fail with an empty literal.

- [ ] **Step 3: Write the PowerShell hook body to a scratch file**

Create `.output/hook-powershell.ps1` (gitignored) with this exact content. The `# Reply shape` here-string is the current one from `hooks.json`, unchanged:

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$c = $null
try { $c = ([Console]::In.ReadToEnd() | ConvertFrom-Json).cwd } catch { $c = $null }
$t = @'
# Reply shape
- `➜` leads one sentence before the first tool call, naming what you are about to do.
- While you work, an update lands when an important finding arrives or the direction changes — two lines: `▸` the finding, `➜` the next move. Print the line that has news and drop the other.
- Close with `✅` on a green outcome or `⛔` on a stop, followed by a recap that stands on its own — what you found, what you did, what is next — for a reader who sees only the last message. Outcome first, detail after.
- Glyphs ride these slots only — `▸` finding, `➜` move, `✅` / `⛔` outcome; an emoji in running prose is decoration.
- Compress the framing; keep code, object and field names, commands, and error strings exact.
- Show the actual thing — the command and its output, the screen, the table row, the diff — before explaining it; one sentence of prose per thing shown. The user sees tool output collapsed at most, so what they need to read goes in the reply.
- Use headings, lists, and tables when the content has several parts they make clearer; otherwise plain prose.
- Ask one question per message, with lettered options and the recommendation marked. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.
- Written artifacts match the length the task needs; a section stays only when it carries facts the reader does not already have.
- Machine-read shapes — YAML frontmatter, task-file fields, JSON payloads — keep their exact structure; brevity never truncates them.
'@
$d = '{"version":1,"tiers":{"frontier":{"model":"claude-fable-5.1","effort":"high"},"execution":{"model":"gpt-5.6-sol","effort":"medium"},"mechanical":{"model":"gpt-5.6-luna","effort":"max"}}}'
$def = ($d | ConvertFrom-Json).tiers
$hd = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$mf = Join-Path $hd '.copilot' 'al-agentic-dev' 'models.json'
$u = $null
if (Test-Path -LiteralPath $mf) { try { $u = (Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json -ErrorAction Stop).tiers } catch { $u = $null } }
$for = [ordered]@{ frontier = 'design, judgment, verdicts, uncertain work'; execution = 'writing code and tests from a brief'; mechanical = 'running gates, commits, renders, lookups, review lenses' }
$fb = @()
$rows = foreach ($k in $for.Keys) {
  $m = $null; $e = $null
  if ($u -and $u.$k) { $m = [string]$u.$k.model; $e = [string]$u.$k.effort }
  if (-not $m -or -not $e) { $m = [string]$def.$k.model; $e = [string]$def.$k.effort; $fb += $k }
  "| $k | $m | $e | $($for[$k]) |"
}
$note = if (-not $u) { 'Defaults in use — run /al-setup-models to set your models.' } elseif ($fb.Count -gt 0) { "Defaults in use for $($fb -join ', ') — run /al-setup-models to set your models." } else { '' }
$t += "`n`n# Model tiers`n| Tier | Model | Effort | For |`n|---|---|---|---|`n" + ($rows -join "`n")
if ($note) { $t += "`n$note" }
$t += @'


A `▶ <tier> · <vehicle> · <brief> → <return>` line dispatches now, with that tier's model and effort passed explicitly. `task`: launch in the background with `model` and `reasoning_effort` set; `read_agent wait:true` where the next step needs the result; answer its question with `write_agent`. `session`: `create_session` with kickoff mode `autopilot`, `model`, `reasoning_effort`, `coordinate_with_creator`, and `notify_on_idle`; answer with `send_session_message`. A packaged agent takes the tier's model as its `model` override. Delegation is down only: no skill detects its own model or spawns upward.
'@
$al = $false
if ($c -and (Test-Path -LiteralPath $c)) {
  $al = Test-Path -LiteralPath (Join-Path $c 'app.json')
  if (-not $al) { $al = [bool](Get-ChildItem -LiteralPath $c -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'app.json') } | Select-Object -First 1) }
}
if ($al) {
$t += @'


# Speak BC
BC vocabulary binds every word — conversation, work items, receipts, and code alike: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, codeunit not class, procedure not method. Name real objects, tables, fields, and events by their exact BC names.
'@
}
@{ additionalContext = $t } | ConvertTo-Json -Compress
```

- [ ] **Step 4: Write the bash hook body to a scratch file**

Create `.output/hook-bash.sh` with this exact content. `R` and `V` are the current values from `hooks.json`, unchanged (they hold literal `\n` sequences that the JSON output interprets as newlines; every new piece below uses the same literal `\n`):

```bash
cwd=$(sed -n 's/.*"cwd":"\([^"]*\)".*/\1/p' | head -n 1)
R='# Reply shape\n- `➜` leads one sentence before the first tool call, naming what you are about to do.\n- While you work, an update lands when an important finding arrives or the direction changes — two lines: `▸` the finding, `➜` the next move. Print the line that has news and drop the other.\n- Close with `✅` on a green outcome or `⛔` on a stop, followed by a recap that stands on its own — what you found, what you did, what is next — for a reader who sees only the last message. Outcome first, detail after.\n- Glyphs ride these slots only — `▸` finding, `➜` move, `✅` / `⛔` outcome; an emoji in running prose is decoration.\n- Compress the framing; keep code, object and field names, commands, and error strings exact.\n- Show the actual thing — the command and its output, the screen, the table row, the diff — before explaining it; one sentence of prose per thing shown. The user sees tool output collapsed at most, so what they need to read goes in the reply.\n- Use headings, lists, and tables when the content has several parts they make clearer; otherwise plain prose.\n- Ask one question per message, with lettered options and the recommendation marked. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.\n- Written artifacts match the length the task needs; a section stays only when it carries facts the reader does not already have.\n- Machine-read shapes — YAML frontmatter, task-file fields, JSON payloads — keep their exact structure; brevity never truncates them.'
V='# Speak BC\nBC vocabulary binds every word — conversation, work items, receipts, and code alike: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, codeunit not class, procedure not method. Name real objects, tables, fields, and events by their exact BC names.'
D='{"version":1,"tiers":{"frontier":{"model":"claude-fable-5.1","effort":"high"},"execution":{"model":"gpt-5.6-sol","effort":"medium"},"mechanical":{"model":"gpt-5.6-luna","effort":"max"}}}'
MF="$HOME/.copilot/al-agentic-dev/models.json"
U=''
if [ -f "$MF" ]; then U=$(tr -d ' \n\r\t' < "$MF"); fi
case "$U" in *'"tiers":{'*) ;; *) U='' ;; esac
FB=''
T='# Model tiers\n| Tier | Model | Effort | For |\n|---|---|---|---|'
for k in frontier execution mechanical; do
  case $k in
    frontier) f='design, judgment, verdicts, uncertain work' ;;
    execution) f='writing code and tests from a brief' ;;
    mechanical) f='running gates, commits, renders, lookups, review lenses' ;;
  esac
  seg=$(printf '%s' "$U" | grep -o "\"$k\":{[^}]*}")
  m=$(printf '%s' "$seg" | sed -n 's/.*"model":"\([^"]*\)".*/\1/p')
  e=$(printf '%s' "$seg" | sed -n 's/.*"effort":"\([^"]*\)".*/\1/p')
  if [ -z "$m" ] || [ -z "$e" ]; then
    dseg=$(printf '%s' "$D" | grep -o "\"$k\":{[^}]*}")
    m=$(printf '%s' "$dseg" | sed -n 's/.*"model":"\([^"]*\)".*/\1/p')
    e=$(printf '%s' "$dseg" | sed -n 's/.*"effort":"\([^"]*\)".*/\1/p')
    FB="$FB${FB:+, }$k"
  fi
  T="$T\n| $k | $m | $e | $f |"
done
if [ -z "$U" ]; then T="$T\nDefaults in use — run /al-setup-models to set your models."; elif [ -n "$FB" ]; then T="$T\nDefaults in use for $FB — run /al-setup-models to set your models."; fi
T="$T\n\n"'A `▶ <tier> · <vehicle> · <brief> → <return>` line dispatches now, with that tier'"'"'s model and effort passed explicitly. `task`: launch in the background with `model` and `reasoning_effort` set; `read_agent wait:true` where the next step needs the result; answer its question with `write_agent`. `session`: `create_session` with kickoff mode `autopilot`, `model`, `reasoning_effort`, `coordinate_with_creator`, and `notify_on_idle`; answer with `send_session_message`. A packaged agent takes the tier'"'"'s model as its `model` override. Delegation is down only: no skill detects its own model or spawns upward.'
R="$R\n\n$T"
if [ -n "$cwd" ] && { [ -f "$cwd/app.json" ] || ls "$cwd"/*/app.json >/dev/null 2>&1; }; then R="$R\n\n$V"; fi
printf '{"additionalContext":"%s"}' "$R"
```

- [ ] **Step 5: Load both bodies into hooks.json**

Run this once from the repo root; it rewrites only the two string values:

```powershell
$path = 'hooks.json'
$h = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$h.hooks.sessionStart[0].powershell = (Get-Content -LiteralPath '.output/hook-powershell.ps1' -Raw).TrimEnd("`r", "`n") -replace "`r`n", "`n"
$h.hooks.sessionStart[0].bash = (Get-Content -LiteralPath '.output/hook-bash.sh' -Raw).TrimEnd("`r", "`n") -replace "`r`n", "`n"
$h | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
git --no-pager diff --stat hooks.json
```

Expected: `git diff` shows changes on the two body lines only. If `ConvertTo-Json` also reindented other lines, revert those hunks by hand so the preToolUse entry and file layout stay byte-identical. Confirm with `pwsh scripts/Validate-Json.ps1` (exit 0) and `git --no-pager diff hooks.json | Select-String '^[-+]' | Measure-Object` (4 lines: two removed, two added).

- [ ] **Step 6: Run the suite to verify pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/ModelTiers.Tests.ps1 -Output Detailed"`
Expected: every powershell case passes; every bash case passes where `BashUsable` is true, otherwise skipped; both single-source tests pass.

- [ ] **Step 7: Add the smoke assertions**

In `tests/hooks/Invoke-HookSmoke.ps1`, inside `$assertions = @( … )`, after the `'reply shape heading echoed'` line of each run add:

```powershell
    @{ run = 'al'; text = $alReply; token = 'Model tiers'; expect = $true; what = 'model tiers heading echoed' }
```

after the `al` reply-shape line, and

```powershell
    @{ run = 'plain'; text = $plainReply; token = 'Model tiers'; expect = $true; what = 'model tiers heading echoed' }
```

after the `plain` reply-shape line. In the `.DESCRIPTION`, change `the model echoes both injected headings (# Reply shape, # Speak BC)` to `the model echoes all three injected headings (# Reply shape, # Model tiers, # Speak BC)`.

- [ ] **Step 8: Document in tests/README.md**

In the Static tier code block, change the last line's comment to `Invoke-Pester tests                   # the validator suites, the hook body suite (tests/ModelTiers.Tests.ps1), and the al-build substrate tests`. After the 1024-character paragraph add:

```markdown
`tests/ModelTiers.Tests.ps1` runs both sessionStart hook bodies out of `hooks.json` as processes with `HOME` pointed at a scratch folder in four states — no `models.json`, a valid one, a broken one, one with a single tier — and asserts the injected `# Model tiers` rows and the `Defaults in use` line; the bash cases skip where `bash` is absent or does not share `HOME` (a WSL bash). Two Unit tests hold the inline default literal in each body equal to `skills/al-setup-models/models.default.json` with whitespace removed, and one holds each agent pin equal to its tier's default model.
```

In the Hook tier paragraph, change `where the reply shape, Speak BC voice rule, and ask_user deny must all show` to `where the reply shape, model tiers, Speak BC voice rule, and ask_user deny must all show`.

- [ ] **Step 9: Run the gates that touch these files**

Run: `pwsh scripts/Validate-Json.ps1; pwsh scripts/Validate-PowerShell.ps1; pwsh scripts/Invoke-Tests.ps1 -Mode Fast`
Expected: all exit 0; the Fast summary reports 0 failed.

- [ ] **Step 10: Commit**

```powershell
git add hooks.json tests/ModelTiers.Tests.ps1 tests/hooks/Invoke-HookSmoke.ps1 tests/README.md
git commit -m "hooks: inject the model tiers from the user map with per-tier defaults

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Agent pins follow the tiers

Implements spec §7.

**Files:**
- Modify: `agents/al-review-lens.agent.md` (line 5)
- Modify: `tests/ModelTiers.Tests.ps1` (append a Describe)

- [ ] **Step 1: Write the failing drift test**

Append to `tests/ModelTiers.Tests.ps1`:

```powershell
Describe 'Agent pins follow the model tiers' -Tag 'Unit' {
    It 'pins <Agent> to the <Tier> default model' -TestCases @(
        @{ Agent = 'al-review-lens'; Tier = 'execution' }
        @{ Agent = 'al-knowledge-leaf'; Tier = 'mechanical' }
    ) {
        param($Agent, $Tier)

        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'agents' "$Agent.agent.md") -Raw
        $pin = [regex]::Match($text, '(?m)^model\s*:\s*(.+?)\s*$').Groups[1].Value.Trim("'", '"')

        $pin | Should -Be $script:Defaults.tiers.$Tier.model
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/ModelTiers.Tests.ps1 -FullNameFilter '*Agent pins*' -Output Detailed"`
Expected: `al-review-lens` fails (`gpt-5.6-luna` ≠ `gpt-5.6-sol`); `al-knowledge-leaf` passes.

- [ ] **Step 3: Move the lens pin**

In `agents/al-review-lens.agent.md`, replace line 5 `model: gpt-5.6-luna` with `model: gpt-5.6-sol`.

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/ModelTiers.Tests.ps1 -FullNameFilter '*Agent pins*' -Output Detailed"; pwsh scripts/Validate-Skills.ps1`
Expected: 2 passed; validator `OK: agents/al-review-lens.agent.md`.

- [ ] **Step 5: Commit**

```powershell
git add agents/al-review-lens.agent.md tests/ModelTiers.Tests.ps1
git commit -m "agents: pin al-review-lens to the execution tier and hold both pins to the defaults

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Review rules 8, 28, 29, 33 and new rule 38; regenerate REVIEW.md

Implements spec §8 rules table.

**Files:**
- Modify: `.github/instructions/skills.instructions.md`
- Regenerate: `REVIEW.md`

- [ ] **Step 1: Confirm the drift gate is currently green**

Run: `pwsh scripts/Update-Review.ps1 -Check`
Expected: exit 0.

- [ ] **Step 2: Rewrite rule 8**

Replace:

```
8. Model pins live in `agents/*.agent.md` only. Flag a model name in a skill body or skill frontmatter; a skill that needs a specific model for a delegation names the packaged agent that pins it.
```

with:

```
8. Model names live in `skills/al-setup-models/models.default.json` and in `agents/*.agent.md` pins only. Flag a model name in a skill body or skill frontmatter — the gate fails it; a skill names a tier on a `▶` line (rule 38), never a model.
```

- [ ] **Step 3: Rewrite rules 28 and 29**

Replace:

```
28. Delegation is for large, genuinely independent work. Flag a skill that spawns a subagent for work finishable in a few tool calls, or that spawns one to check its own output. Every delegated review judgment runs in a full-capability subagent; flag a skill that assigns one below that capability.
29. Where fan-out is optional, one sentence covers it: `These parallelize in full-capability subagents; when subagents are unavailable, apply them in one pass.` A lead that launches subagents keeps working on independent steps while they run and waits only where the next step needs their result.
```

with:

```
28. Delegation is for work that returns a compact result — a survey table, one scenario's red→green evidence, a gate verdict — or that owns its own branch. A single lookup stays in-line: flag a `▶` line for work finishable in a few tool calls, and flag one that checks the skill's own output. A delegated review judgment runs at `execution` or above; a leaf following a written contract runs `mechanical`.
29. Fan-out is several `▶ task` lines at one step, launched together in the background; the lead keeps working on independent steps and waits with `read_agent wait:true` only where the next step needs a result. Every Copilot surface has the `task` tool, so no skill carries an unavailable-subagents fallback.
```

- [ ] **Step 4: Extend rule 33**

At the end of rule 33, after `Flag a carrier missing its line, and flag an emoji outside a defined slot — that one is decoration.` append one sentence:

```
 The delegation line `▶ <tier> · <vehicle> · <brief> → <return>` of rule 38 is a defined slot; `al-walkthrough`'s `▶ <business action>` report line stays — it sits in a code span and names no tier.
```

- [ ] **Step 5: Add rule 38**

Append at the end of the file, after rule 37:

```
## Delegation contract

38. A skill delegates a step with one line — `▶ <tier> · <vehicle> · <brief> → <return>` — placed at the step it serves. `tier` is `frontier`, `execution`, or `mechanical`; `vehicle` is `task` for work that writes into the current branch or reads only, `session` for work that owns its own branch. The `brief` names what the child receives — it inherits nothing — and the `return` names what comes back, checkable. Task workers do not delegate; session children run their skill's `▶` lines as written. Callee skills — `/al-build`, `/al-commit`, `/al-arc42`, `/al-azure-devops-attachments`, `/al-pull-request`, `/al-clone-bcapps`, `/al-clone-bcquality` — carry no `▶` line; the caller writes it. Every dispatch prompt carries the brief, the return contract, the unattended line (`You run unattended; the user cannot answer mid-task. Proceed on every reversible step the User Story already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.`), and the plain-text question rule; a child that writes or judges AL also carries the Speak BC paragraph and the grounding rule of rule 31. A child's stop is a decision: the skill's own contract answers it to the same child, or the lead quotes it to the user with options and the recommendation marked and relays the answer unchanged. A return that misses its contract, or a red twice on the same cause, is re-dispatched once, one tier up, with the child's output added to the brief; a second miss goes to the user with the evidence. Flag a `▶` line outside this grammar, a callee skill carrying one, a dispatch prompt missing a fixed part, and a model name where a tier belongs.
```

- [ ] **Step 6: Regenerate REVIEW.md and check**

Run: `pwsh scripts/Update-Review.ps1; pwsh scripts/Update-Review.ps1 -Check; git --no-pager diff --stat`
Expected: `-Check` exits 0; the diff lists `.github/instructions/skills.instructions.md` and `REVIEW.md`.

- [ ] **Step 7: Commit**

```powershell
git add .github/instructions/skills.instructions.md REVIEW.md
git commit -m "skills.instructions: model names live in the defaults and pins; add the delegation contract

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 6: `▶` lines in al-implement and al-refactor

Implements spec §6 mixed skills (implement, refactor) and the callee lines (gate, render, attach, commit). Each file is rewritten whole; the pinned strings from Global Constraints are all present in the text below.

**Files:**
- Modify: `skills/al-implement/SKILL.md` (whole file)
- Modify: `skills/al-refactor/SKILL.md` (whole file)

- [ ] **Step 1: Rewrite al-implement**

Replace the whole of `skills/al-implement/SKILL.md` with:

```markdown
---
name: al-implement
description: Use when an executable User Story has reviewed Gherkin, AAA test specification, and module contracts ready to implement in AL.
---

# al-implement - prove the slice

In: the executable Original User Story, or a child User Story and its Original User Story. Read the executable item's reviewed `Test specification`, including its `Current-to-final proof map`, and the Original User Story's process and Building Block Level 1. If the AAA seam, existing-proof disposition, or expected value is unresolved, return that question to /al-test-design before editing code.

Before editing, trace the narrow path through the workspace. Search for an existing module, event, interface, test, fixture, and pattern first. Confirm every BC object, table, field, procedure, event, enum value, and dialog text through lookup in this session.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Contract

Gherkin defines observable business behavior; AAA defines the reviewed proof seam and expected values; Building Block Level 1 defines caller-visible module ownership; private object layout remains an implementation decision.

## Shape the proof

Before changing an existing test, require its current scope green:

▶ mechanical · task · /al-build gate on the affected test scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

Apply the proof map's proof-preserving reshapes before new expectations or production changes. Account for every existing business assertion in the final cases unless the current requirement explicitly replaces it, rerun the gate green, and add no transitional test that the accepted map does not retain.

## Prove and green, one worker per scenario

For each Gherkin scenario, pick its AAA cases, production site, and seam, then dispatch; the scenarios launch together, and each worker's brief carries the two paragraphs below:

▶ execution · task · one Gherkin scenario: its AAA cases, production site, seam, proof-map rows, the Speak BC paragraph, and the grounding rule → red evidence per case, the green gate line, files touched

Implement each unit or integration AAA case through the named module interface. One Gherkin scenario may need several tests. An unchanged existing test marked `keep` supplies evidence without a duplicate. Every new or materially reshaped automated proof earns a red. If born red, require failure for the intended reason. If born green because the behavior exists, inject one compiling fault into the production site the proof targets, run its scope to red, revert the fault, and confirm green. A compile error or a failure before the assertion is not red; if no fault forces red, strengthen the assertion until it does.

Write the smallest production change that makes the proof green. Keep business writes on validated or posting paths, reuse Base App seams, preserve quality properties, and avoid an AL interface with one implementation. A pre-existing bug or a behavior the User Story does not name is a follow-up line in the receipt, not a change, unless the proof cannot go green without it. Run /al-build's gate until green; a red result remains red until the output names its exact cause.

A walkthrough-only case does not enter the automated red step. Keep it in the receipt for /al-walkthrough. Judge every return against its contract before the next step.

## Map what landed

After green, trace the landed production path from its caller through every changed AL object to the records, events, and module interfaces it uses. Create a connected-object change map from the code, never from the changed-file list. Include every changed production object, only the unchanged neighbours needed to explain its connections, and a separate Proof group for changed test objects. Mark each object `Added`, `Changed`, `Existing`, or `Removed`. Label every edge with the exact procedure, event, interface implementation, or Read/Insert/Modify relation. A changed object with no explained connection remains unresolved.

For one affected Level 1 module, use a Building Block Level 2 white box. For several affected Level 1 modules, use a Level 1 impact overview plus a Level 2 white box for each module whose object relations need explanation. Add a Runtime View only when call order, a transaction boundary, or an error path matters.

▶ mechanical · task · /al-arc42 the chosen views from the connected-object change map → HTML path, SVG and PNG paths, alt text, publishable fragments

Open the HTML in the browser canvas. Keep the change markers in the receipt and executable-item comment. Add or update the Original User Story's Level 2 only when the implementation map reveals stable internal building blocks or interfaces worth preserving; publish that current-state view without change markers. A simple module may need the implementation map but no Original User Story Level 2.

▶ mechanical · task · /al-azure-devops-attachments the PNG and SVG to the executable item → verified attachment URLs

Use the verified URLs in the comment and Original User Story fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Receipt

Write `.output/receipts/<work-item-id>.md` with the work-item ID, implementation-map paths and alt text, tests, objects changed, Level 2 decision, gate result, evidence, and `verified:` / `assumed:` ledger entries. Add the PNG and the same evidence to the executable-item comment when Azure DevOps tools are available.

## Close

At every exit:

▶ mechanical · task · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree

Finish outcome first: what changed, what proves it, where the implementation map is attached, which module interface stayed stable, and whether Original User Story Level 2 changed. Name /al-refactor as the next move. Stop with the exact red reason when any proof is unresolved.
```

- [ ] **Step 2: Rewrite al-refactor**

Replace the whole of `skills/al-refactor/SKILL.md` with:

```markdown
---
name: al-refactor
description: Use after a green AL implementation when it needs a bounded tidy pass, or when the user names a deeper module reshape whose behavior must stay fixed.
---

# al-refactor - improve the shape

In: the green implementation, reviewed AAA specification, receipt, and the Original User Story that is executable itself or parents the executable child User Story. Choose one mode:

- **Tidy:** local duplication, names, extraction, data access, readability, or dead structure in the changed slice.
- **Deepening:** only on an explicit user request that names the module boundary to reshape.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Freeze behavior

Gherkin, reviewed AAA expected values and proof levels, and the Level 1 module interface are fixed. Read the accepted `Current-to-final proof map`, diff, and receipt, then trace consumers before moving a seam. Confirm every BC object, field, event, enum value, or test library used through lookup in this session.

## Decide the list

Inspect the affected proof set as if all current requirements had existed when its tests were first written. Compare the landed tests with the accepted proof map. List the avoidable layers, overlaps, and chronology-shaped tests to correct inside the affected tests and shared helpers; leave unrelated proof alone. A behavior, expected-value, or proof-level change returns to /al-test-design and the user.

Tidy stays inside changed files and immediate seams. Prefer canonical BC patterns and Base App helpers. An interface with one implementation is a finding; collapse it unless a second implementation or stable external contract proves the seam. A defect noticed outside the slice is a follow-up line in the receipt, not a change.

Deepening reduces hidden complexity behind the existing caller-visible interface. Keep ownership singular, test through that interface, and make internals replaceable. A proposed Level 1 interface change returns to /al-design and the user before refactoring.

## Reshape through a worker

Before changing an existing test, require its current scope green:

▶ mechanical · task · /al-build gate on the affected scope, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

Then dispatch the list; the worker's brief carries the paragraph below:

▶ execution · task · the reshape list for the named files with the frozen AAA expected values, the Speak BC paragraph, and the grounding rule → the diff, the green gate line, mutation evidence per reshaped proof

Keep production unchanged while applying proof-preserving reshapes, account for every existing business assertion unless the current requirement explicitly replaces it, then rerun the gate green. Every new or materially reshaped proof born green takes mutation as its red. Inject one compiling fault into the production site the proof targets, require red, revert the fault, and confirm green. If no fault forces red, strengthen the assertion until it does. Run /al-build's gate after each edit and finish on a green gate; restore the last green shape when an edit weakens behavior or the module contract.

Judge the return against the frozen values and the list before the next step.

## Map the landed shape

Regenerate the receipt's connected-object change map from the final diff so it shows the landed shape rather than the pre-refactor shape. If stable internal building blocks changed, update or remove the Original User Story's arc42 Level 2 so it matches the landed code. Routine tidy can change the receipt map without changing Original User Story Level 2.

▶ mechanical · task · /al-arc42 the refreshed views from the final change map → HTML path, SVG and PNG paths, alt text, publishable fragments

▶ mechanical · task · /al-azure-devops-attachments the refreshed PNG and SVG to the executable item → verified attachment URLs

Use the verified URLs in the receipt and Original User Story fragment. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Close

Update the receipt with the final implementation map, `Tidy: none` or the exact reshapes, test evidence, gate result, Original User Story Level 2 delta, and any new `verified:` / `assumed:` entries. At every exit:

▶ mechanical · task · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree

Finish outcome first; stop with the exact red reason when the gate does not pass.
```

- [ ] **Step 3: Validate and test**

Run: `pwsh scripts/Validate-Skills.ps1; pwsh -NoProfile -Command "Invoke-Pester -Path tests/SkillWorkflowContracts.Tests.ps1, tests/ArtifactContracts.Tests.ps1 -Output Normal"`
Expected: `OK: al-implement`, `OK: al-refactor`, `All skills validated successfully.`; Pester 0 failed. Also `(Get-Content skills/al-implement/SKILL.md).Count` ≤ 64 and `(Get-Content skills/al-refactor/SKILL.md).Count` ≤ 64 (60-line body plus 4 frontmatter lines).

- [ ] **Step 4: Commit**

```powershell
git add skills/al-implement/SKILL.md skills/al-refactor/SKILL.md
git commit -m "al-implement, al-refactor: delegate scenarios, gates, renders, attachments, and commits through ▶ lines

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 7: `▶` lines in al-review, al-pr-shepherd, al-orchestrate, al-walkthrough

Implements spec §6 mixed skills (review, pr-shepherd, orchestrate, walkthrough).

**Files:**
- Modify: `skills/al-review/SKILL.md` (lines 31–39)
- Modify: `skills/al-pr-shepherd/SKILL.md` (list items 2 and 4)
- Modify: `skills/al-orchestrate/SKILL.md` (lines 14–24, 32)
- Modify: `skills/al-walkthrough/SKILL.md` (line 18)

- [ ] **Step 1: al-review — gate line and the two agent lines**

Replace line 31:

```
Run /al-build's gate for missing test evidence.
```

with:

```
▶ mechanical · task · /al-build gate on the reviewed scope for missing test evidence, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause
```

Replace lines 33–39 (the `## Parallel lenses` section through `Deduplicate by root cause.`) with:

```
## Parallel lenses

Launch these together in the background while the contract inspection above proceeds; wait only where the verdict needs their findings:

▶ execution · task · al-review-lens with the one dimension `User Story contract` — the checks above as its definition — the diff scope, work items, receipt, and relevant sources → its findings

For standards, read `.bcquality/skills/entry.md` and follow its Entry protocol with goal `review`, inputs `pr-diff`, technologies `[al]`, and all three layers; then one line per selected leaf:

▶ mechanical · task · al-knowledge-leaf with the leaf path, diff scope, READ and DO paths, and the domain-filtered index slice its contract requires → the leaf's DO report

Deduplicate by root cause.
```

- [ ] **Step 2: al-pr-shepherd — the finding worker, the renumber worker, the gate**

Replace list item 2:

```
2. **An actionable Copilot finding** → two classes. A local repair — contained, within what the PR already promises — is fixed, gated through /al-build, committed through /al-commit, pushed, replied to, resolved. A comment that widens what the PR promises is a bullet, not a fix: surface it, propose it for /al-scope or /al-next to place, and wait.
```

with:

```
2. **An actionable Copilot finding** → two classes. A local repair — contained, within what the PR already promises — goes to a worker, then is pushed, replied to, resolved:

   ▶ execution · task · the finding, the PR's promise, the files it names, the Speak BC paragraph, and the grounding rule → the fix diff, the green gate line from /al-build, the /al-commit hashes

   A comment that widens what the PR promises is a bullet, not a fix: surface it, propose it for /al-scope or /al-next to place, and wait.
```

Replace list item 4:

```
4. **Behind main** → merge origin/main INTO the PR branch as a merge commit — a rebase rewrites what reviewers saw. Conflicts resolve by preserving both intents, each side traced to its primary sources: commits, PRs, issues. The mechanical AL collision — the same object or field number claimed by both sides with no overlapping logic — keeps both declarations and renumbers the branch-new number within its idRanges bucket, verified by a workspace scan, never recall. A conflict that reveals a design decision — one concept modeled twice, conflicting logic in one object — stops for the user. /al-build's gate proves the synced tree before the push.
```

with:

```
4. **Behind main** → merge origin/main INTO the PR branch as a merge commit — a rebase rewrites what reviewers saw. Conflicts resolve by preserving both intents, each side traced to its primary sources: commits, PRs, issues. The same object or field number claimed by both sides with no overlapping logic is the one collision a worker resolves:

   ▶ execution · task · the AL number collision: both sides' declarations and the idRanges bucket → both declarations kept, the branch-new number renumbered inside its bucket and verified by a workspace scan

   A conflict that reveals a design decision — one concept modeled twice, conflicting logic in one object — stops for the user. Before the push:

   ▶ mechanical · task · /al-build gate on the synced tree → summary.json verdict, per-runner totals, exact red cause
```

- [ ] **Step 3: al-orchestrate — session lines and the CLI model flag**

Replace lines 12–24 (from `## Run one owner at a time` through the terminal paragraph) with:

```
## Run one owner at a time

1. ▶ execution · session · /al-implement with the work-item ID, repository, Original User Story contract, and exact receipt path → its result, branch, commit, and full receipt content
2. ▶ execution · session · Launch a fresh /al-refactor child stacked on the implementation branch with the receipt content, reviewed AAA, Original User Story, and any named deepening goal → its branch, commit, and updated receipt content
3. ▶ frontier · session · /al-review stacked on the latest writing branch with the executable work item, Original User Story, diff base, and receipt content → the verdict and its findings
4. After each blocking repair, a fresh /al-review line on the repaired branch; repeat until the verdict has no blocking findings.
5. When the `Test specification` names walkthrough proof, after the blocking-free review:

   ▶ execution · session · /al-walkthrough on the latest writing branch with the executable item and Original User Story → evidence for every walkthrough case

In the GitHub Copilot app, each line is `create_session` with kickoff mode `autopilot`, the tier's model and effort, `coordinate_with_creator`, and `notify_on_idle`, stacked on the branch named; read results with `get_session`. `.output/` is ignored, so later app children receive receipt content explicitly rather than by path.

In the terminal Copilot CLI, give each block a UUID and run it sequentially in the current worktree as a fresh headless process: `copilot -p "/al-implement <work-item>" --model <tier model> --session-id <uuid> --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`, then the same shape for /al-refactor, /al-review, and /al-walkthrough when required. The shared worktree, commits, and receipt path carry state; one process runs at a time.
```

Replace line 32:

```
In the CLI, resume that child with `copilot --resume=<uuid> -p "<answer>" --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`.
```

with:

```
In the app, send it with `send_session_message`. In the CLI, resume that child with `copilot --resume=<uuid> -p "<answer>" --model <tier model> --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`.
```

- [ ] **Step 4: al-walkthrough — the republish line**

Replace line 18:

```
The repository workspace MCP owns the branch and container binding. After changing branches or its configuration, restart the MCP or Copilot session before the walk. Run /al-build's clean republish into that container. Record the commit and deployed app version before the first scenario.
```

with:

```
The repository workspace MCP owns the branch and container binding. After changing branches or its configuration, restart the MCP or Copilot session before the walk. Then:

▶ mechanical · task · /al-build clean republish into the bound container → deployed commit and app version

Record both before the first scenario.
```

- [ ] **Step 5: Validate and test**

Run: `pwsh scripts/Validate-Skills.ps1; pwsh -NoProfile -Command "Invoke-Pester -Path tests/SkillWorkflowContracts.Tests.ps1, tests/ArtifactContracts.Tests.ps1 -Output Normal"`
Expected: `All skills validated successfully.`; Pester 0 failed; each of the four files ≤ 64 lines.

- [ ] **Step 6: Commit**

```powershell
git add skills/al-review/SKILL.md skills/al-pr-shepherd/SKILL.md skills/al-orchestrate/SKILL.md skills/al-walkthrough/SKILL.md
git commit -m "al-review, al-pr-shepherd, al-orchestrate, al-walkthrough: name the tier and vehicle at every delegation

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 8: `▶` survey lines in the talking skills

Implements spec §6 talking skills: al-design, al-event-model, al-test-design, al-next, al-miner, al-grill-adr.

**Files:**
- Modify: `skills/al-design/SKILL.md` (lines 14, 32, 36)
- Modify: `skills/al-event-model/SKILL.md` (lines 14, 24–26, 30, 38)
- Modify: `skills/al-test-design/SKILL.md` (lines 24, 28)
- Modify: `skills/al-next/SKILL.md` (line 14)
- Modify: `skills/al-miner/SKILL.md` (line 18)
- Modify: `skills/al-grill-adr/SKILL.md` (lines 8, 31)

- [ ] **Step 1: al-design**

After line 14 (`Start with the canonical shape: … reusable BC shape.`) insert:

```

▶ execution · task · canonical-shape survey: how the Base App models the concept — tables, seams, events — read in .bcapps/release → precedent table with file:line
```

Replace line 32:

```
Ask /al-arc42 to apply the official template and create the local architecture review HTML, editable SVG, and Azure DevOps-safe PNG. The user reviews the HTML before publication. Ask /al-azure-devops-attachments to attach the PNG and SVG, then embed its verified PNG URL, explanatory text, and black boxes under `Building Block View` in the Original User Story Description. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works. Level 1 records intended boundaries. Level 2 waits for implementation evidence.
```

with:

```
▶ mechanical · task · /al-arc42 the Building Block Level 1 view from the settled black boxes → HTML path, SVG and PNG paths, alt text, publishable fragments

Open the HTML in the browser canvas; the user reviews it before publication.

▶ mechanical · task · /al-azure-devops-attachments the PNG and SVG to the Original User Story → verified attachment URLs

Embed the verified PNG URL, explanatory text, and black boxes under `Building Block View` in the Original User Story Description. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works. Level 1 records intended boundaries. Level 2 waits for implementation evidence.
```

Replace line 36:

```
The pass ends when every important behavior has one module owner, each caller-visible interface is named, and the Original User Story contains the accepted Level 1 view. Ask /al-commit to commit any `docs/patterns.md` change and the rest of the worktree at every exit. No `docs/design.md` copy is created.
```

with:

```
The pass ends when every important behavior has one module owner, each caller-visible interface is named, and the Original User Story contains the accepted Level 1 view. At every exit:

▶ mechanical · task · /al-commit the complete worktree — any `docs/patterns.md` change and the rest — work items <ids> → commit hashes and subjects, remaining worktree

No `docs/design.md` copy is created.
```

- [ ] **Step 2: al-event-model**

After line 14 (`Extend the Original User Story Description with … Building Block View`.`) insert:

```

When the Base App has a comparable flow:

▶ execution · task · process precedent: how the Base App's comparable flow posts, validates, and errors, read in .bcapps/release → step table with sources
```

Replace lines 24–26:

```
Follow [BPMN.md](BPMN.md). Create the editable BPMN source, render SVG and PNG from that source, and write the local process review HTML. The user reviews the HTML before publication.

Ask /al-azure-devops-attachments to attach the BPMN source and PNG to the Original User Story, then embed its verified PNG URL with its explanatory text under `Business process`. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.
```

with:

```
Follow [BPMN.md](BPMN.md). Create the editable BPMN source, then:

▶ mechanical · task · render SVG, PNG, and the local process review HTML from the BPMN source, with the BPMN.md render procedure passed in full → SVG, PNG, HTML paths

Open the HTML in the browser canvas; the user reviews it before publication.

▶ mechanical · task · /al-azure-devops-attachments the BPMN source and PNG to the Original User Story → verified attachment URLs

Embed the verified PNG URL with its explanatory text under `Business process`. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.
```

Replace line 30's last sentence `Ask /al-arc42 to apply the official format and create the local architecture review HTML.` with:

```
Then:

▶ mechanical · task · /al-arc42 the Runtime View from the settled sequence → HTML path, SVG and PNG paths, alt text, publishable fragments
```

Replace line 38:

```
The pass ends when Trigger, both guarantees, every BPMN path, and any necessary Runtime View agree with the original request. The user confirms the local HTML before the Original User Story update. No `docs/event-model.md` copy is created.
```

with:

```
The pass ends when Trigger, both guarantees, every BPMN path, and any necessary Runtime View agree with the original request. The user confirms the local HTML before the Original User Story update. No `docs/event-model.md` copy is created. At every exit:

▶ mechanical · task · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree
```

- [ ] **Step 3: al-test-design**

Replace line 24:

```
Before proposing cases, search the repository for existing proof by affected module interface, objects, business terms, fixtures, and assertions. Inventory the affected proof set: every existing test procedure and shared test helper needed by the changed Gherkin paths. Widen the search until every path's current proof is known; leave unrelated behavior out.
```

with:

```
Before proposing cases, search the repository for existing proof by affected module interface, objects, business terms, fixtures, and assertions:

▶ mechanical · task · inventory the existing proof for the affected interface, objects, and business terms → every test procedure and shared helper the changed Gherkin paths need, with paths

Widen the brief until every path's current proof is known; leave unrelated behavior out.
```

Replace line 28:

```
Confirm every Business Central object, table, field, action, procedure, event, enum value, and dialog text through lookup in this session. Reach for standard test libraries and fixtures before inventing helpers.
```

with:

```
Confirm every Business Central object, table, field, action, procedure, event, enum value, and dialog text through lookup in this session. Reach for standard test libraries and fixtures before inventing helpers:

▶ mechanical · task · standard test libraries and fixtures for the named objects → library and fixture names with paths
```

- [ ] **Step 4: al-next**

Replace line 14:

```
Name the executable item and its receipts. Show its connected-object change map before the BC-anatomy delta table. The map explains how changed production objects connect and keeps tests in a separate Proof group. The table covers objects touched, schema, events, permissions, translations, tests, and the caller-visible behavior now present.
```

with:

```
Name the executable item and its receipts. Launch both together:

▶ mechanical · task · receipts and work-item comments for the executable items → one summary per item

▶ mechanical · task · BC-anatomy delta table from the diff base: objects touched, schema, events, permissions, translations, tests, caller-visible behavior now present → the table

Show the connected-object change map before the delta table. The map explains how changed production objects connect and keeps tests in a separate Proof group.
```

- [ ] **Step 5: al-miner**

At the end of line 18 (after `… the local full-text index for error signatures.`) append:

```
 The extraction itself is one worker; the lead judges which candidates become lessons:

▶ mechanical · task · extract repeated failures and steering corrections from the session store for the named range with the session_store_sql tool → candidate table with counts, date spans, session ids, and the query used
```

- [ ] **Step 6: al-grill-adr**

After line 8 (the `In:` paragraph) insert:

```

When the User Story hierarchy is more than a handful of items:

▶ mechanical · task · read the Original User Story, its linked items, and the CONTEXT.md vocabulary → summary table of items, fields, and terms
```

Replace line 31:

```
The pass ends when the Original User Story exists, its Description preserves the confirmed request under `Problem`, and every surfaced domain question is answered, parked in the User Story conversation, or ruled out. Ask /al-commit to commit `CONTEXT.md`, accepted ADRs, and the rest of the worktree at every exit. Continue with /al-event-model.
```

with:

```
The pass ends when the Original User Story exists, its Description preserves the confirmed request under `Problem`, and every surfaced domain question is answered, parked in the User Story conversation, or ruled out. At every exit:

▶ mechanical · task · /al-commit the complete worktree — CONTEXT.md, accepted ADRs, and the rest — work items <ids> → commit hashes and subjects, remaining worktree

Continue with /al-event-model.
```

- [ ] **Step 7: Validate and test**

Run: `pwsh scripts/Validate-Skills.ps1; pwsh -NoProfile -Command "Invoke-Pester -Path tests/SkillWorkflowContracts.Tests.ps1, tests/ArtifactContracts.Tests.ps1 -Output Normal"; Get-ChildItem skills/*/SKILL.md | ForEach-Object { '{0} {1}' -f (Get-Content $_).Count, $_.Directory.Name }`
Expected: `All skills validated successfully.`; Pester 0 failed; every listed count ≤ 64 except `al-build` (≤ 84) and the pinned forks.

- [ ] **Step 8: Commit**

```powershell
git add skills/al-design/SKILL.md skills/al-event-model/SKILL.md skills/al-test-design/SKILL.md skills/al-next/SKILL.md skills/al-miner/SKILL.md skills/al-grill-adr/SKILL.md
git commit -m "talking skills: delegate surveys, renders, attachments, and commits through ▶ lines

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 9: Dev-time docs, one assertion, README, version 4.0.0

Implements spec §8 (copilot-instructions, ArtifactContracts, version).

**Files:**
- Modify: `.github/copilot-instructions.md`
- Modify: `tests/ArtifactContracts.Tests.ps1:99`
- Modify: `README.md` (hooks section and the agents paragraph)
- Modify: `plugin.json`, `.github/plugin/marketplace.json`

- [ ] **Step 1: Change the assertion first**

In `tests/ArtifactContracts.Tests.ps1` replace line 99:

```powershell
        $instructions | Should -Match 'task agent pinned to `gpt-5\.6-luna`'
```

with:

```powershell
        $instructions | Should -Match 'task agent at the mechanical tier'
```

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/ArtifactContracts.Tests.ps1 -Output Normal"`
Expected: 1 failed (`runs Pester once with compact mode-aware output`).

- [ ] **Step 2: Edit `.github/copilot-instructions.md`**

In the shipped-surface tree, change the `hooks.json` line to:

```
hooks.json                      the shipped hooks: preToolUse denies ask_user; sessionStart injects the reply shape, the model tiers, and the Speak BC voice rule in AL repos
```

and after the `skills/<name>/<SIBLING>.md` line add:

```
skills/al-setup-models/models.default.json the shipped model-tier defaults the hook and /al-setup-models share
```

In the skills paragraph: `Twenty-five skills ship today.` → `Twenty-six skills ship today.`; `Twenty are authored for the new set:` → `Twenty-one are authored for the new set:`; before `` the design chain `al-event-model` `` insert `` `al-setup-models` (the three model tiers — frontier, execution, mechanical — written to the user's `~/.copilot/al-agentic-dev/models.json` from the built-in map), ``.

In "What never ships", replace:

```
- A model name in a skill body or skill frontmatter — model pins live in `agents/*.agent.md` only.
```

with:

```
- A model name in a skill body or skill frontmatter — model names live in `skills/al-setup-models/models.default.json` and `agents/*.agent.md` pins only; a skill names a tier on a `▶ <tier> · <vehicle> · <brief> → <return>` line.
```

In the hooks bullet of "What never ships", after `was orphaned when its installer skill retired)` and before `; a new hook needs its own proven defect.` insert: `, and the same sessionStart entry carries the model tiers on its own defect (model names drift, and a pin in a shipped file cannot follow them)`.

In "Working here", replace:

```
Delegate test runs only to a task agent pinned to `gpt-5.6-luna`. The agent runs `scripts/Invoke-Tests.ps1` once and uses its compact result; it never reruns Pester to recover output.
```

with:

```
Delegate test runs only to a task agent at the mechanical tier. The agent runs `scripts/Invoke-Tests.ps1` once and uses its compact result; it never reruns Pester to recover output.
```

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path tests/ArtifactContracts.Tests.ps1 -Output Normal"`
Expected: 0 failed.

- [ ] **Step 3: Edit README.md**

In the paragraph beginning `Two read-only reviewer agents ride under `agents/`` append one sentence: `Their pins follow the model tiers — `al-review-lens` at execution, `al-knowledge-leaf` at mechanical — and a `▶` line's tier override wins at dispatch.`

In "## The hooks", change `hooks.json` ships two hooks:` to `hooks.json` ships two hooks, the second carrying three blocks:` and replace the Session context bullet with:

```markdown
- **Session context** (sessionStart): every new or resumed session receives the reply-shape rules and the model tiers — a `# Model tiers` table read from `~/.copilot/al-agentic-dev/models.json`, falling back per tier to the shipped defaults in `skills/al-setup-models/models.default.json` with a `Defaults in use — run /al-setup-models to set your models.` line, followed by the dispatch rule for `▶ <tier> · <vehicle> · <brief> → <return>` lines. When the working directory is an AL repo (an `app.json` at the root or one directory level deep), the Speak BC vocabulary rule also applies: Insert not create, Post not submit, Ledger Entry not transaction, and so on. In a non-AL directory the vocabulary rule stays out.
```

- [ ] **Step 4: Bump the version**

In `plugin.json`: `"version": "3.1.0"` → `"version": "4.0.0"`. In `.github/plugin/marketplace.json`: both `"version": "3.1.0"` occurrences → `"4.0.0"`.

Run: `pwsh scripts/Validate-Json.ps1`
Expected: exit 0, no version mismatch.

- [ ] **Step 5: Commit**

```powershell
git add .github/copilot-instructions.md tests/ArtifactContracts.Tests.ps1 README.md plugin.json .github/plugin/marketplace.json
git commit -m "docs, version: name the model tiers and al-setup-models; 4.0.0

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 10: Gates, full test run, and the live acceptance runs

Implements spec §9.

**Files:** none new. Records go in the PR body.

- [ ] **Step 1: Run the four static gates**

Run: `pwsh scripts/Validate-Json.ps1; pwsh scripts/Validate-PowerShell.ps1; pwsh scripts/Validate-Skills.ps1; pwsh scripts/Update-Review.ps1 -Check`
Expected: each exits 0. Fix and recommit anything red before continuing.

- [ ] **Step 2: Run the full test suite once, delegated**

Dispatch:

▶ mechanical · task · run `pwsh scripts/Invoke-Tests.ps1 -Mode Full` once from the repo root and report its compact JSON summary verbatim → the summary line with total, passed, failed, skipped, and every failing test's name and message if any

Expected: `failed: 0`. The bash hook cases show as skipped where `bash` is absent or does not share `HOME`; on CI (ubuntu and windows with Git Bash) they run.

- [ ] **Step 3: Acceptance run 1 — hook shows defaults, `/al-setup-models` writes the file**

Move any existing user map aside: `if (Test-Path ~/.copilot/al-agentic-dev/models.json) { Move-Item ~/.copilot/al-agentic-dev/models.json ~/.copilot/al-agentic-dev/models.json.bak }`. Open a new session in this worktree (or `copilot --plugin-dir <this checkout> -s` from a scratch directory) and ask: `Reply with the exact # headings in your additional context and, if present, the line that starts with "Defaults in use".` Expected: `# Reply shape`, `# Model tiers`, and the `Defaults in use — run /al-setup-models to set your models.` line. Then run `/al-setup-models`, answer `A`. Expected: the skill shows the three built-in rows, writes `~/.copilot/al-agentic-dev/models.json`, shows it, and closes with the block. Open another new session and ask the same question. Expected: `# Model tiers` present, no `Defaults in use` line. Restore the `.bak` if one was made.

- [ ] **Step 4: Acceptance run 2 — a mechanical `/al-commit` worker**

Make a scratch change (`Add-Content docs/superpowers/plans/.probe 'probe'` then delete it after the run) and dispatch in the session:

▶ mechanical · task · /al-commit the complete worktree, no work items → commit hashes and subjects, remaining worktree

Expected: `read_agent` shows the worker's model as the mechanical tier's model (`gpt-5.6-luna` with defaults) and the return names the commit hash. Then `git reset --soft HEAD~1; git restore --staged .; Remove-Item docs/superpowers/plans/.probe` to drop the probe commit.

- [ ] **Step 5: Acceptance run 3 — `al-review-lens` takes the execution override**

Dispatch `task` with `agent_type` `al-agentic-dev:al-review-lens`, `model` set to the execution tier's model, and a prompt naming one dimension (`User Story contract`) over `git diff main...HEAD -- skills/al-review/SKILL.md`. Expected: the agent status shows `gpt-5.6-sol` (with defaults), and the agent returns findings or `no blocking issues found`.

- [ ] **Step 6: Hook smoke by hand**

Run: `pwsh tests/hooks/Invoke-HookSmoke.ps1`
Expected: `All 12 hook assertions passed.` (the original 10 plus the two `Model tiers` echoes).

- [ ] **Step 7: Open the PR**

Record runs 1–3 and the smoke result in the PR body, one line each with the observed model and the observed block lines. Use `/al-pull-request`; title `al-agentic-dev: model tiers and ▶ step-level delegation (4.0.0)`.

