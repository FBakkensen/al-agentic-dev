#Requires -Version 7.2
<#
.SYNOPSIS
    Validates that every folder under skills/ is a portable, self-contained Agent Skill.
.DESCRIPTION
    Each skill folder holds a SKILL.md whose frontmatter carries the keys name and
    description, constrained per the Agent Skills specification (agentskills.io): name is
    1-64 characters of lowercase a-z0-9 and single hyphens and equals the folder name
    exactly; description is a non-empty single-line value of at most 1024 characters,
    quoted whenever it contains a colon. Model invocation is the exception: every skill
    carries disable-model-invocation: true, except the model-invocable eight (al-build,
    al-grilling, al-knowledge-pass, al-next, al-routing, al-agentic-dev-overview,
    al-visualize, al-spec-review), which omit
    the key entirely.
    Every relative Markdown link in the folder's .md files resolves to a file inside that
    same folder, and only skills/al-build may name a .ps1 file or a scripts/ path — save
    for the per-skill exemptions in $scriptExemptions, each an upstream tool a named skill
    runs inside a checkout it clones. Task
    state has one home: outside skills/al-routing, no skill body states a lifecycle field
    (status:, phase:, blocked-on:, review:, tier:, green-gate:). Every skill carries the shared plain-text
    question rule. Every /al-<name> skill reference resolves to a folder under the skills
    root. Every violation is reported; any violation exits 1.
.EXAMPLE
    pwsh scripts/Validate-Skills.ps1
#>
[CmdletBinding()]
param(
    [string]$SkillsRoot = (Join-Path $PSScriptRoot '..' 'skills')
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
$modelInvocable = @('al-build', 'al-grilling', 'al-knowledge-pass', 'al-next', 'al-routing', 'al-agentic-dev-overview', 'al-visualize', 'al-spec-review')
$questionRule = 'Ask every question in the reply itself, as plain text — never through a question or elicitation tool.'
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
                $violations += "$($skill.Name)/SKILL.md: disable-model-invocation: true is required (model invocation is the exception; only al-build, al-grilling, al-knowledge-pass, al-next, al-routing, al-agentic-dev-overview, al-visualize, al-spec-review omit it)"
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
            } elseif (-not (Test-Path -LiteralPath (Join-Path $markdown.Directory.FullName $path))) {
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
            if (-not $body.Contains($questionRule)) {
                $violations += "${relative}: missing the required plain-text question rule"
            }
        }

        if ($skill.Name -ne 'al-routing') {
            foreach ($field in [regex]::Matches($body, '(?<![\w-])(status|phase|blocked-on|review|tier|green-gate)\s*:')) {
                $violations += "${relative}: states the lifecycle field '$($field.Groups[1].Value):' outside al-routing; task state has one home"
            }
        }

        foreach ($mention in [regex]::Matches($body, '/al-[a-z0-9-]+')) {
            $end = $mention.Index + $mention.Length
            $next = if ($end -lt $body.Length) { $body.Substring($end, [Math]::Min(2, $body.Length - $end)) } else { '' }
            if ($next -match '^\.[A-Za-z0-9]' -or $next -match '^[/\\]') { continue }
            $prev = if ($mention.Index -gt 0) { [string]$body[$mention.Index - 1] } else { ' ' }
            if ($prev -match '[\w.>/\\-]') { continue }
            $name = $mention.Value.TrimStart('/')
            if ($skillFolders -cnotcontains $name) {
                $violations += "${relative}: names a skill that has no folder: $($mention.Value)"
            }
        }
    }

    if ($violations.Count -eq $skillCount) {
        Write-Host "OK: $($skill.Name)" -ForegroundColor Green
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    Write-Error "$($violations.Count) skill violation(s) found."
    exit 1
}

Write-Host "`nAll skills validated successfully." -ForegroundColor Cyan
