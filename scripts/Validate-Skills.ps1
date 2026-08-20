#Requires -Version 7.2
<#
.SYNOPSIS
    Validates every skills/ folder as a Copilot-first Agent Skill and every
    agents/*.agent.md as a packaged custom agent.
.DESCRIPTION
    Skills: each folder holds a SKILL.md whose frontmatter carries the keys name and
    description, constrained per the Agent Skills specification (agentskills.io): name is
    1-64 characters of lowercase a-z0-9 and single hyphens and equals the folder name
    exactly; description is a non-empty single-line value of at most 1024 characters,
    quoted whenever it contains a colon. Model invocation is the exception: every skill
    carries disable-model-invocation: true, except the model-invocable five (al-build,
    al-visualize, al-grilling, al-unslop, al-lookup), which omit the key entirely.
    Verbatim ports (al-grilling, al-grill-me, al-wait-what, al-unslop) ship donor bodies
    unchanged beyond the al- namespace, so two checks skip them: the plain-text question
    rule (hooks.json enforces the ask_user ban at runtime) and the harness token scan
    (al-unslop lists the word as jargon to cut). Every other check applies to them unchanged.
    Every relative Markdown link in the folder's .md files resolves to a file inside that
    same folder, and only skills/al-build may name a .ps1 file or a scripts/ path — save
    for the per-skill exemptions in $scriptExemptions, each an upstream tool a named skill
    runs inside a checkout it clones.
    Harness-conditional phrasing is banned: no skill or agent markdown contains the token
    'harness' — tools, MCP servers, and delegation targets are named by their Copilot names.
    Task-state ceremony is retired: no skill body states a legacy lifecycle field
    (status:, phase:, blocked-on:, review:, tier:, green-gate:) or an Azure DevOps
    work-item transition (State: New|Active|Blocked|Testing|Resolved|Closed).
    Every skill carries the shared plain-text question rule, which bans the ask_user tool
    by name. A /name skill reference that
    matches a folder under the skills root resolves regardless of prefix; an al-prefixed
    reference with no folder is a violation.
    Agents: each agents/*.agent.md carries exactly the frontmatter keys name, description,
    tools, and model; name equals the filename stem and meets the skill name spec;
    description follows the skill description rules; model is a non-empty pin; tools is a
    non-empty inline value or block list. Every violation is reported; any violation exits 1.
.EXAMPLE
    pwsh scripts/Validate-Skills.ps1
#>
[CmdletBinding()]
param(
    [string]$SkillsRoot = (Join-Path $PSScriptRoot '..' 'skills'),
    [string]$AgentsRoot = (Join-Path $PSScriptRoot '..' 'agents')
)

function Get-MarkdownLinkTarget {
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
        foreach ($link in [regex]::Matches($line, '\[[^\]]*\]\(\s*(?:<(?<target>[^>]+)>|(?<target>[^\s)]+))')) {
            $link.Groups['target'].Value
        }
    }
}

$violations = @()
$root = (Resolve-Path -LiteralPath $SkillsRoot -ErrorAction Stop).Path
$modelInvocable = @('al-build', 'al-visualize', 'al-grilling', 'al-unslop', 'al-lookup')
# Verbatim ports ship donor bodies unchanged beyond the al- namespace: the question rule
# and the harness scan skip them (hooks.json enforces the ask_user ban at runtime); all
# other checks apply.
$verbatimPorts = @('al-grilling', 'al-grill-me', 'al-wait-what', 'al-unslop')
$questionRule = 'Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.'
# Per-skill script exemptions, approved one at a time. The key is the skill folder; the
# value is the exact script paths that skill may name. al-build is exempt wholesale
# because it owns the substrate; every other entry is an upstream tool the skill runs
# inside a checkout it clones, matched on the full path so a same-named script in
# another folder stays a violation.
$scriptExemptions = @{
    'al-clone-bcquality' = @('.bcquality/tools/Build-KnowledgeIndex.ps1')
}
$skillFolders = @(Get-ChildItem -LiteralPath $root -Directory | ForEach-Object Name)

foreach ($skill in Get-ChildItem -LiteralPath $root -Directory) {
    $skillCount = $violations.Count
    $skillMd = Join-Path $skill.FullName 'SKILL.md'

    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
        $violations += "$($skill.Name): SKILL.md is missing"
    } else {
        $lines = @((Get-Content -LiteralPath $skillMd -Raw) -split '\r?\n')
        $close = -1
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '---') { $close = $i; break }
        }

        if ($lines[0].Trim() -ne '---' -or $close -lt 1) {
            $violations += "$($skill.Name)/SKILL.md: frontmatter block does not parse"
        } else {
            $frontmatter = $lines[1..($close - 1)] -join "`n"
            $keys = @([regex]::Matches($frontmatter, '(?m)^([A-Za-z][\w-]*)\s*:') |
                ForEach-Object { $_.Groups[1].Value })
            $allowedKeys = @('name', 'description', 'disable-model-invocation')
            $unknownKeys = @($keys | Where-Object { $allowedKeys -cnotcontains $_ })
            $duplicateKeys = @($keys | Group-Object | Where-Object Count -gt 1)
            if ($unknownKeys.Count -gt 0 -or $duplicateKeys.Count -gt 0 -or
                $keys -cnotcontains 'name' -or $keys -cnotcontains 'description') {
                $violations += "$($skill.Name)/SKILL.md: frontmatter keys must be name, description, and optionally disable-model-invocation (found: $($keys -join ', '))"
            }

            $flagMatch = [regex]::Match($frontmatter, '(?m)^disable-model-invocation\s*:\s*(.+?)\s*$')
            if ($modelInvocable -ccontains $skill.Name) {
                if ($flagMatch.Success) {
                    $violations += "$($skill.Name)/SKILL.md: $($skill.Name) is model-invocable; remove disable-model-invocation"
                }
            } elseif ($flagMatch.Groups[1].Value.Trim() -cne 'true') {
                $violations += "$($skill.Name)/SKILL.md: disable-model-invocation: true is required (model invocation is the exception; only al-build, al-visualize, al-grilling, al-unslop, al-lookup omit it)"
            }

            $name = [regex]::Match($frontmatter, '(?m)^name\s*:\s*(.+?)\s*$').Groups[1].Value.Trim("'", '"')
            if ($name.Length -gt 64 -or $name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
                $violations += "$($skill.Name)/SKILL.md: name '$name' must be 1-64 characters of lowercase letters, digits, and single hyphens"
            }
            if ($name -cne $skill.Name) {
                $violations += "$($skill.Name)/SKILL.md: name '$name' does not match the folder name"
            }

            $descriptionMatch = [regex]::Match($frontmatter, '(?m)^description\s*:\s*(\S.*?)\s*$')
            $description = $descriptionMatch.Groups[1].Value
            $isQuoted = $description.Length -ge 2 -and
                (($description[0] -eq '"' -and $description[-1] -eq '"') -or
                 ($description[0] -eq "'" -and $description[-1] -eq "'"))
            $descriptionBody = if ($isQuoted) { $description.Substring(1, $description.Length - 2).Trim() } else { $description }
            if (-not $descriptionMatch.Success -or $description -match '^[>|][+-]?$' -or -not $descriptionBody) {
                $violations += "$($skill.Name)/SKILL.md: description must be a non-empty single-line value"
            } elseif ($descriptionBody.Length -gt 1024) {
                $violations += "$($skill.Name)/SKILL.md: description exceeds 1024 characters"
            }
            if (($description -match ':\s' -or $description -match ':$') -and -not $isQuoted) {
                $violations += "$($skill.Name)/SKILL.md: description contains a colon and must be quoted"
            }
        }
    }

    foreach ($markdown in Get-ChildItem -LiteralPath $skill.FullName -Recurse -Filter '*.md' -File) {
        $relative = [System.IO.Path]::GetRelativePath($root, $markdown.FullName) -replace '\\', '/'
        $text = Get-Content -LiteralPath $markdown.FullName -Raw

        foreach ($target in (Get-MarkdownLinkTarget -Text ([string]$text))) {
            if ($target -match '^(https?|mailto):' -or $target -match '^(#|//)') { continue }
            $path = ($target -split '[#?]')[0]
            if (-not $path) { continue }
            if ($path -match '\\') {
                $violations += "${relative}: link uses backslashes; use forward slashes: $target"
            } elseif ($path -match '(^|/)\.\.(/|$)' -or [System.IO.Path]::IsPathRooted($path)) {
                $violations += "${relative}: link leaves the skill folder: $target"
            } elseif (-not (Test-Path -LiteralPath (Join-Path $markdown.Directory.FullName $path) -PathType Leaf)) {
                $violations += "${relative}: link target does not exist: $target"
            }
        }

        if ($skill.Name -ne 'al-build') {
            $allowedScripts = @($scriptExemptions[$skill.Name])
            foreach ($script in [regex]::Matches([string]$text, '[\w.\-/]*[\w\-]\.ps1|(?<![\w-])scripts/', 'IgnoreCase')) {
                $tokenStart = $script.Index
                while ($tokenStart -gt 0 -and [string]$text[$tokenStart - 1] -notmatch '\s') { $tokenStart-- }
                $token = $text.Substring($tokenStart, $script.Index + $script.Length - $tokenStart)
                if ($token -match 'https?://') { continue }
                if ($allowedScripts -and ($allowedScripts -ccontains $script.Value)) { continue }
                $violations += "${relative}: names a script outside al-build: $($script.Value)"
            }
        }

        $body = [string]$text
        if ($markdown.Name -ceq 'SKILL.md') {
            $bodyLines = @($body -split '\r?\n')
            if ($bodyLines.Count -gt 2 -and $bodyLines[0].Trim() -eq '---') {
                for ($i = 1; $i -lt $bodyLines.Count; $i++) {
                    if ($bodyLines[$i].Trim() -eq '---') {
                        $body = if ($i + 1 -lt $bodyLines.Count) { $bodyLines[($i + 1)..($bodyLines.Count - 1)] -join "`n" } else { '' }
                        break
                    }
                }
            }
            if (-not $body.Contains($questionRule) -and $verbatimPorts -cnotcontains $skill.Name) {
                $violations += "${relative}: missing the required plain-text question rule"
            }
        }

        if ($verbatimPorts -cnotcontains $skill.Name) {
            foreach ($hit in [regex]::Matches([string]$text, 'harness', 'IgnoreCase')) {
                $violations += "${relative}: uses harness-conditional phrasing ('$($hit.Value)'); name the Copilot tool or agent instead"
            }
        }

        foreach ($field in [regex]::Matches($body, '(?<![\w-])(status|phase|blocked-on|review|tier|green-gate)\s*:')) {
            $violations += "${relative}: states the lifecycle field '$($field.Groups[1].Value):'; task-state ceremony is retired"
        }
        foreach ($transition in [regex]::Matches($body, '(?<![\w-])[Ss]tate\s*:\s*(New|Active|Blocked|Testing|Resolved|Closed)\b')) {
            $violations += "${relative}: states the work-item transition '$($transition.Value)'; task-state ceremony is retired"
        }

        foreach ($mention in [regex]::Matches($body, '/[a-z0-9]+(?:-[a-z0-9]+)*')) {
            $end = $mention.Index + $mention.Length
            $next = if ($end -lt $body.Length) { $body.Substring($end, [Math]::Min(2, $body.Length - $end)) } else { '' }
            if ($next -match '^\.[A-Za-z0-9]' -or $next -match '^[/\\]') { continue }
            $prev = if ($mention.Index -gt 0) { [string]$body[$mention.Index - 1] } else { ' ' }
            if ($prev -match '[\w.>/\\-]') { continue }
            $name = $mention.Value.TrimStart('/')
            if ($skillFolders -ccontains $name) { continue }
            # A slash token matching no folder is a violation only in the al- family;
            # a generic non-folder token is indistinguishable from a platform command or path.
            if ($name -clike 'al-*') {
                $violations += "${relative}: names a skill that has no folder: $($mention.Value)"
            }
        }
    }

    if ($violations.Count -eq $skillCount) {
        Write-Host "OK: $($skill.Name)" -ForegroundColor Green
    }
}

$agentFiles = @()
if (Test-Path -LiteralPath $AgentsRoot -PathType Container) {
    $agentFiles = @(Get-ChildItem -LiteralPath $AgentsRoot -Filter '*.agent.md' -File | Sort-Object Name)
}

foreach ($agent in $agentFiles) {
    $agentCount = $violations.Count
    $agentRelative = "agents/$($agent.Name)"
    $stem = $agent.Name -replace '\.agent\.md$', ''
    $text = Get-Content -LiteralPath $agent.FullName -Raw
    $lines = @($text -split '\r?\n')
    $close = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $close = $i; break }
    }

    if ($lines[0].Trim() -ne '---' -or $close -lt 1) {
        $violations += "${agentRelative}: frontmatter block does not parse"
    } else {
        $frontmatterLines = @($lines[1..($close - 1)])
        $frontmatter = $frontmatterLines -join "`n"
        $keys = @([regex]::Matches($frontmatter, '(?m)^([A-Za-z][\w-]*)\s*:') |
            ForEach-Object { $_.Groups[1].Value })
        $requiredKeys = @('name', 'description', 'tools', 'model')
        $unknownKeys = @($keys | Where-Object { $requiredKeys -cnotcontains $_ })
        $duplicateKeys = @($keys | Group-Object | Where-Object Count -gt 1)
        $missingKeys = @($requiredKeys | Where-Object { $keys -cnotcontains $_ })
        if ($unknownKeys.Count -gt 0 -or $duplicateKeys.Count -gt 0 -or $missingKeys.Count -gt 0) {
            $violations += "${agentRelative}: frontmatter keys must be exactly name, description, tools, and model (found: $($keys -join ', '))"
        }

        $name = [regex]::Match($frontmatter, '(?m)^name\s*:\s*(.+?)\s*$').Groups[1].Value.Trim("'", '"')
        if ($name.Length -gt 64 -or $name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
            $violations += "${agentRelative}: name '$name' must be 1-64 characters of lowercase letters, digits, and single hyphens"
        }
        if ($name -cne $stem) {
            $violations += "${agentRelative}: name '$name' does not match the file name stem '$stem'"
        }

        $descriptionMatch = [regex]::Match($frontmatter, '(?m)^description\s*:\s*(\S.*?)\s*$')
        $description = $descriptionMatch.Groups[1].Value
        $isQuoted = $description.Length -ge 2 -and
            (($description[0] -eq '"' -and $description[-1] -eq '"') -or
             ($description[0] -eq "'" -and $description[-1] -eq "'"))
        $descriptionBody = if ($isQuoted) { $description.Substring(1, $description.Length - 2).Trim() } else { $description }
        if (-not $descriptionMatch.Success -or $description -match '^[>|][+-]?$' -or -not $descriptionBody) {
            $violations += "${agentRelative}: description must be a non-empty single-line value"
        } elseif ($descriptionBody.Length -gt 1024) {
            $violations += "${agentRelative}: description exceeds 1024 characters"
        }
        if (($description -match ':\s' -or $description -match ':$') -and -not $isQuoted) {
            $violations += "${agentRelative}: description contains a colon and must be quoted"
        }

        $model = [regex]::Match($frontmatter, '(?m)^model\s*:\s*(.+?)\s*$').Groups[1].Value.Trim("'", '"')
        if (-not $model -or $model -match '^[>|][+-]?$') {
            $violations += "${agentRelative}: model must be a non-empty pin"
        }

        $toolsInline = [regex]::Match($frontmatter, '(?m)^tools\s*:\s*(.*?)\s*$').Groups[1].Value
        $hasBlockItems = $false
        for ($i = 0; $i -lt $frontmatterLines.Count; $i++) {
            if ($frontmatterLines[$i] -match '^tools\s*:') {
                for ($j = $i + 1; $j -lt $frontmatterLines.Count -and $frontmatterLines[$j] -notmatch '^[A-Za-z]'; $j++) {
                    if ($frontmatterLines[$j] -match '^\s*-\s*\S') { $hasBlockItems = $true; break }
                }
                break
            }
        }
        $inlineEmpty = (-not $toolsInline) -or $toolsInline -match '^(\[\s*\]|""|'''')$'
        if ($inlineEmpty -and -not $hasBlockItems) {
            $violations += "${agentRelative}: tools must be a non-empty list"
        }
    }

    foreach ($hit in [regex]::Matches([string]$text, 'harness', 'IgnoreCase')) {
        $violations += "${agentRelative}: uses harness-conditional phrasing ('$($hit.Value)'); name the Copilot tool or agent instead"
    }

    if ($violations.Count -eq $agentCount) {
        Write-Host "OK: $agentRelative" -ForegroundColor Green
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    Write-Error "$($violations.Count) skill violation(s) found."
    exit 1
}

Write-Host "`nAll skills validated successfully." -ForegroundColor Cyan
