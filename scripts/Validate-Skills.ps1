#Requires -Version 7.2
<#
.SYNOPSIS
    Validates every skills/ folder as a Claude Code plugin skill, and the AL output style.
.DESCRIPTION
    Each folder holds a SKILL.md whose frontmatter carries exactly the keys name and
    description, constrained per the Agent Skills specification (agentskills.io): name is
    1-64 characters of lowercase a-z0-9 and single hyphens and equals the folder name
    exactly; description is a non-empty single-line value of at most 1024 characters,
    quoted whenever it contains a colon. Every skill is model-invocable, so
    disable-model-invocation is not accepted.
    Every relative Markdown link in the folder's .md files resolves to a file inside that
    same folder, and only skills/al-build may name a .ps1 file or a scripts/ path.
    Harness-conditional phrasing is banned: no skill markdown contains the token
    'harness' — tools and delegation targets are named by their Claude Code names.
    Task-state ceremony is retired: no skill body states a legacy lifecycle field
    (status:, phase:, blocked-on:, review:, tier:, green-gate:) or an Azure DevOps
    work-item transition (State: New|Active|Blocked|Testing|Resolved|Closed).
    A /name skill reference that matches a folder under the skills root resolves
    regardless of prefix; an al-prefixed reference with no folder is a violation.
    Namespaced references use the drift check's <ns>:<skill> tokenizer (SkillReference.ps1)
    over each whole file, description included. A namespace is declared when a dependency in
    the plugin manifest (-PluginManifest) names it before its '@'. al-agentic-dev:<x>, with
    or without '/', is a violation that asks for the bare /<x>; /<ns>:<skill> with an
    undeclared namespace is a violation; a bare x:y whose x is undeclared is not a
    reference, so file:line and $env:NAME pass.
    Every prose ▶ line matches the delegation grammar '▶ <model> · <brief> → <return>'
    with model opus, sonnet, or haiku, and a brief that does not open on a leftover
    task or session vehicle. fable gets its own violation: it bills usage credits.
    The output-styles folder holds the style developers select as al-agentic-dev:AL:
    at least one style's name is exactly AL, and every style's frontmatter carries
    name exactly AL, keep-coding-instructions: true, and no force-for-plugin, in YAML
    that parses (read with the powershell-yaml module, which the gate requires). A case
    mismatch or missing setting silently hands developers the Default style; the flag
    overrides the developer's own choice. Every violation is reported; any violation exits 1.
.EXAMPLE
    pwsh scripts/Validate-Skills.ps1
#>
[CmdletBinding()]
param(
    [string]$SkillsRoot = (Join-Path $PSScriptRoot '..' 'skills'),
    [string]$OutputStylesRoot = (Join-Path $PSScriptRoot '..' 'output-styles'),
    [string]$PluginManifest = (Join-Path $PSScriptRoot '..' '.claude-plugin' 'plugin.json')
)

. (Join-Path $PSScriptRoot 'SkillReference.ps1')

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

function Invoke-SkillsValidation {
    [CmdletBinding()]
    param(
        [string]$SkillsRoot = (Join-Path $PSScriptRoot '..' 'skills'),
        [string]$OutputStylesRoot = (Join-Path $PSScriptRoot '..' 'output-styles'),
        [string]$PluginManifest = (Join-Path $PSScriptRoot '..' '.claude-plugin' 'plugin.json')
    )

$violations = @()
$root = (Resolve-Path -LiteralPath $SkillsRoot -ErrorAction Stop).Path
# A dependency's namespace is its plugin name, the part before '@', as the drift check reads it.
$namespaces = @()
if (Test-Path -LiteralPath $PluginManifest -PathType Leaf) {
    $manifest = Get-Content -LiteralPath $PluginManifest -Raw | ConvertFrom-Json
    $namespaces = @(foreach ($dependency in @($manifest.PSObject.Properties['dependencies']?.Value)) {
        if (-not $dependency) { continue }
        (($dependency -is [string]) ? $dependency : [string]$dependency.name).Split('@')[0]
    })
} else {
    $violations += "plugin manifest not found: $PluginManifest"
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
            $allowedKeys = @('name', 'description')
            $unknownKeys = @($keys | Where-Object { $allowedKeys -cnotcontains $_ })
            $duplicateKeys = @($keys | Group-Object | Where-Object Count -gt 1)
            if ($unknownKeys.Count -gt 0 -or $duplicateKeys.Count -gt 0 -or
                $keys -cnotcontains 'name' -or $keys -cnotcontains 'description') {
                $violations += "$($skill.Name)/SKILL.md: frontmatter keys must be name and description (found: $($keys -join ', '))"
            }

            $flagMatch = [regex]::Match($frontmatter, '(?m)^disable-model-invocation\s*:\s*(.+?)\s*$')
            if ($flagMatch.Success) {
                $violations += "$($skill.Name)/SKILL.md: all skills are model-invocable; remove disable-model-invocation"
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
            foreach ($script in [regex]::Matches([string]$text, '[\w.\-/]*[\w\-]\.ps1|(?<![\w-])scripts/', 'IgnoreCase')) {
                $tokenStart = $script.Index
                while ($tokenStart -gt 0 -and [string]$text[$tokenStart - 1] -notmatch '\s') { $tokenStart-- }
                $token = $text.Substring($tokenStart, $script.Index + $script.Length - $tokenStart)
                if ($token -match 'https?://') { continue }
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
        }

        foreach ($hit in [regex]::Matches([string]$text, 'harness', 'IgnoreCase')) {
            $violations += "${relative}: uses harness-conditional phrasing ('$($hit.Value)'); name the Claude Code tool or agent instead"
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
            # /<ns>:<skill> is the namespace check's alone.
            if ($next -match '^:[A-Za-z0-9]') { continue }
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

        foreach ($reference in @(Get-NamespacedSkillReference -Text ([string]$text))) {
            $token = "$($reference.Namespace):$($reference.Skill)"
            if ($reference.Namespace -ieq 'al-agentic-dev') {
                $violations += "${relative}: $token names our own skill; write it bare: /$($reference.Skill)"
            } elseif ($reference.Slash -and $namespaces -cnotcontains $reference.Namespace) {
                $violations += "${relative}: /$token names '$($reference.Namespace)', which no plugin manifest dependency declares"
            }
        }

        $delegationLead = '^\s*(?:[-*]|\d+\.)?\s*▶ '
        $delegationGrammar = "$delegationLead(opus|sonnet|haiku) · (?!(?:task|session) · ).+ → .+$"
        foreach ($prose in (Get-ProseLine -Text $body)) {
            if ($prose -notmatch '▶') { continue }
            if ($prose -match "${delegationLead}fable · ") {
                $violations += "${relative}: ▶ line runs on fable, which bills usage credits; delegate on opus, sonnet, or haiku: $($prose.Trim())"
            } elseif ($prose -cnotmatch $delegationGrammar) {
                $violations += "${relative}: ▶ line outside the delegation grammar '▶ <model> · <brief> → <return>' with model opus, sonnet, or haiku: $($prose.Trim())"
            }
        }
    }

    if ($violations.Count -eq $skillCount) {
        Write-Host "OK: $($skill.Name)" -ForegroundColor Green
    }
}

Import-Module powershell-yaml -ErrorAction Stop
$styles = @(if (Test-Path -LiteralPath $OutputStylesRoot -PathType Container) {
    Get-ChildItem -LiteralPath $OutputStylesRoot -Filter '*.md' -File
})
$styleNames = @()
foreach ($style in $styles) {
    $styleCount = $violations.Count
    $relative = "output-styles/$($style.Name)"
    $lines = @((Get-Content -LiteralPath $style.FullName -Raw) -split '\r?\n')
    $close = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $close = $i; break }
    }
    if ($lines[0].Trim() -ne '---' -or $close -lt 1) {
        $violations += "${relative}: frontmatter block does not parse"
        continue
    }

    $frontmatter = if ($close -gt 1) { $lines[1..($close - 1)] -join "`n" } else { '' }
    # Claude Code loads a style whose YAML does not parse with every field unset, so
    # keep-coding-instructions silently drops to false; parse it as YAML, not by pattern.
    try {
        $fields = ConvertFrom-Yaml -Yaml $frontmatter -ErrorAction Stop
    } catch {
        $violations += "${relative}: frontmatter YAML does not parse: $(($_.Exception.Message -split '\r?\n')[0])"
        continue
    }
    if ($fields -isnot [System.Collections.IDictionary]) {
        $violations += "${relative}: frontmatter YAML is not a mapping of settings"
        continue
    }
    # Claude Code reads lowercase field names only, and the parsed hashtable ignores case.
    $fieldNames = @($fields.Keys | ForEach-Object { [string]$_ })

    # A cast would turn the sequence [AL] into the string AL; only a string scalar counts.
    $name = if ($fieldNames -ccontains 'name' -and $fields['name'] -is [string]) { $fields['name'] } else { '' }
    $styleNames += $name
    if ($name -cne 'AL') {
        $violations += "${relative}: name '$name' must be exactly 'AL'; any other name hands developers the Default style"
    }
    $keep = if ($fieldNames -ccontains 'keep-coding-instructions') { $fields['keep-coding-instructions'] } else { $null }
    if (-not ($keep -is [bool] -and $keep)) {
        $violations += "${relative}: keep-coding-instructions must be true"
    }
    if ($fieldNames -ccontains 'force-for-plugin') {
        $violations += "${relative}: force-for-plugin overrides the developer's own output style; remove it"
    }

    if ($violations.Count -eq $styleCount) {
        Write-Host "OK: $relative" -ForegroundColor Green
    }
}
if ($styleNames -cnotcontains 'AL') {
    $violations += "output-styles holds no style named AL: $OutputStylesRoot"
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    Write-Error "$($violations.Count) skill violation(s) found."
    return 1
}

Write-Host "`nAll skills validated successfully." -ForegroundColor Cyan
return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-SkillsValidation -SkillsRoot $SkillsRoot -OutputStylesRoot $OutputStylesRoot -PluginManifest $PluginManifest)
}
