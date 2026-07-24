#Requires -Version 7.2
<#
.SYNOPSIS
    Validates the Copilot CLI marketplace and per-plugin manifests.
.DESCRIPTION
    Checks that every plugin listed in .github/plugin/marketplace.json has a folder
    under plugins/ with a root plugin.json manifest whose name matches the marketplace
    entry, that all manifests are valid JSON, that agent files use the .agent.md
    extension, that any hooks config declares "version": 1 (Copilot CLI hook
    format), and that every custom agent's frontmatter carries a name matching its
    filename (unique across the marketplace), a JSON tools array of non-empty
    strings, a model id, and user-invocable: false. The al-agentic-dev plugin
    additionally declares its exact approved custom-agent fleet. This marketplace
    targets GitHub Copilot CLI.
.EXAMPLE
    pwsh scripts/Validate-PluginStructure.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot "..")
)

$errors = @()

# The al-agentic-dev fleet is intentionally model-pinned. Keep this map aligned
# with its agent files when a role's model is changed.
$script:AlAgenticDevFleet = [ordered]@{
    'al-design-option'             = 'claude-fable-5'
    'al-debug-logging'             = 'claude-sonnet-5'
    'al-gate-runner'               = 'gpt-5.6-luna'
    'al-mutant-cycle'              = 'claude-sonnet-5'
    'al-red-green'                 = 'claude-sonnet-5'
    'al-researcher'                = 'claude-opus-4.8'
    'al-review-cr-appsource'       = 'claude-sonnet-5'
    'al-review-cr-bc'              = 'claude-sonnet-5'
    'al-review-cr-bugscan'         = 'claude-fable-5'
    'al-review-cr-comments'        = 'claude-sonnet-5'
    'al-review-cr-compliance'      = 'claude-sonnet-5'
    'al-review-cr-perf'            = 'claude-sonnet-5'
    'al-review-judge'              = 'claude-opus-4.8'
    'al-review-refactor-bc'        = 'claude-fable-5'
    'al-review-refactor-naming'    = 'claude-sonnet-5'
    'al-review-refactor-perf'      = 'claude-sonnet-5'
    'al-review-refactor-simplify'  = 'claude-fable-5'
    'al-review-refactor-structural' = 'claude-fable-5'
}

# Agent names must be unique across the whole marketplace (invoked by name via the
# task tool regardless of which plugin ships them) — tracked across all plugins.
$script:agentNameSources = @{}

function Get-MarketplacePluginNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        $script:errors += "Missing marketplace manifest: $Path"
        Write-Host "FAIL: marketplace manifest missing at $Path" -ForegroundColor Red
        return @()
    }

    try {
        $marketplace = Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        $script:errors += "Invalid JSON in marketplace manifest: $Path"
        Write-Host "FAIL: marketplace manifest JSON invalid at $Path" -ForegroundColor Red
        return @()
    }

    $pluginNames = @()
    foreach ($plugin in @($marketplace.plugins)) {
        if ($null -ne $plugin.name -and $plugin.name.ToString().Trim().Length -gt 0) {
            $pluginNames += $plugin.name.ToString()
        }
    }

    Write-Host "OK: marketplace manifest loaded with $($pluginNames.Count) plugins" -ForegroundColor Green
    return $pluginNames
}

$repoRoot = Resolve-Path -Path $RepoRoot -ErrorAction Stop
$marketplacePath = Join-Path $repoRoot ".github\plugin\marketplace.json"
$pluginsPath = Join-Path $repoRoot "plugins"

function Get-SkillFrontmatterBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillFile
    )

    $content = Get-Content -LiteralPath $SkillFile -Raw
    $lines = $content -split "`r?`n"
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
        throw "Missing opening frontmatter delimiter"
    }

    $closingIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $closingIndex = $i
            break
        }
    }

    if ($closingIndex -lt 0) {
        throw "Missing closing frontmatter delimiter"
    }

    return ($lines[1..($closingIndex - 1)] -join "`n")
}

function Test-AgentFrontmatterBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentFile
    )

    $result = [PSCustomObject]@{
        Errors = @()
        Name   = $null
        Model  = $null
    }

    $frontmatter = $null
    try {
        $frontmatter = Get-SkillFrontmatterBlock -SkillFile $AgentFile
    } catch {
        $result.Errors += "Invalid or missing frontmatter in agent file $($AgentFile): $($_.Exception.Message)"
        return $result
    }

    $nameMatches = [regex]::Matches($frontmatter, '(?m)^\s*name\s*:')
    if ($nameMatches.Count -gt 1) {
        $result.Errors += "Duplicate name field in agent frontmatter: $AgentFile"
    } else {
        $nameMatch = [regex]::Match($frontmatter, '(?m)^\s*name:\s*(\S+)\s*$')
        if (-not $nameMatch.Success) {
            $result.Errors += "Missing name field in agent frontmatter: $AgentFile"
        } else {
            $result.Name = $nameMatch.Groups[1].Value.Trim()
            $expectedName = [System.IO.Path]::GetFileName($AgentFile) -replace '\.agent\.md$', ''
            if ($result.Name -ne $expectedName) {
                $result.Errors += "Agent name '$($result.Name)' does not match filename stem '$expectedName': $AgentFile"
            }
        }
    }

    $toolsMatches = [regex]::Matches($frontmatter, '(?m)^tools\s*:')
    if ($toolsMatches.Count -gt 1) {
        $result.Errors += "Duplicate tools field in agent frontmatter: $AgentFile"
    } else {
        $toolsMatch = [regex]::Match($frontmatter, '(?m)^tools:\s*(.+?)\s*$')
        if (-not $toolsMatch.Success) {
            $result.Errors += "Missing or malformed tools declaration in agent frontmatter: $AgentFile"
        } else {
            $toolsJson = $null
            try {
                $toolsJson = [System.Text.Json.JsonDocument]::Parse($toolsMatch.Groups[1].Value)
                $toolsRoot = $toolsJson.RootElement
                if ($toolsRoot.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
                    $result.Errors += "Tools declaration must be a JSON array: $AgentFile"
                } elseif ($toolsRoot.GetArrayLength() -eq 0) {
                    $result.Errors += "Empty tools declaration in agent frontmatter: $AgentFile"
                } else {
                    foreach ($tool in $toolsRoot.EnumerateArray()) {
                        if ($tool.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                            $result.Errors += "Tools declaration contains a non-string entry: $AgentFile"
                            break
                        }

                        if ([string]::IsNullOrWhiteSpace($tool.GetString())) {
                            $result.Errors += "Tools declaration contains an empty or whitespace-only entry: $AgentFile"
                            break
                        }
                    }
                }
            } catch {
                $result.Errors += "Invalid JSON in tools declaration: $AgentFile"
            } finally {
                if ($null -ne $toolsJson) {
                    $toolsJson.Dispose()
                }
            }
        }
    }

    $modelMatches = [regex]::Matches($frontmatter, '(?m)^\s*model\s*:')
    if ($modelMatches.Count -gt 1) {
        $result.Errors += "Duplicate model field in agent frontmatter: $AgentFile"
    } else {
        $modelMatch = [regex]::Match($frontmatter, '(?m)^\s*model:\s*(\S+)\s*$')
        if (-not $modelMatch.Success) {
            $result.Errors += "Missing model field in agent frontmatter: $AgentFile"
        } else {
            $result.Model = $modelMatch.Groups[1].Value.Trim()
        }
    }

    $invocableMatches = [regex]::Matches($frontmatter, '(?m)^\s*user-invocable\s*:')
    if ($invocableMatches.Count -gt 1) {
        $result.Errors += "Duplicate user-invocable field in agent frontmatter: $AgentFile"
    } else {
        $invocableMatch = [regex]::Match($frontmatter, '(?m)^\s*user-invocable:\s*(\S+)\s*$')
        if (-not $invocableMatch.Success) {
            $result.Errors += "Missing user-invocable field in agent frontmatter: $AgentFile"
        } elseif ($invocableMatch.Groups[1].Value.Trim() -ne 'false') {
            $result.Errors += "Agent frontmatter user-invocable must be 'false' (found '$($invocableMatch.Groups[1].Value.Trim())'): $AgentFile"
        }
    }

    return $result
}

function Test-AlAgenticDevFleet {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AgentResults
    )

    $fleetErrors = @()

    foreach ($expectedAgent in $script:AlAgenticDevFleet.Keys) {
        if (-not $AgentResults.ContainsKey($expectedAgent)) {
            $fleetErrors += "Missing expected al-agentic-dev agent '$expectedAgent'"
            continue
        }

        $actualModel = $AgentResults[$expectedAgent].Model
        $expectedModel = $script:AlAgenticDevFleet[$expectedAgent]
        if ($actualModel -ne $expectedModel) {
            $fleetErrors += "al-agentic-dev agent '$expectedAgent' must use model '$expectedModel' (found '$actualModel')"
        }
    }

    foreach ($actualAgent in $AgentResults.Keys) {
        if (-not $script:AlAgenticDevFleet.Contains($actualAgent)) {
            $fleetErrors += "Unexpected al-agentic-dev agent '$actualAgent'"
        }
    }

    return $fleetErrors
}

function Test-IsQuotedScalar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmed = $Value.Trim()
    if ($trimmed.Length -lt 2) { return $false }
    return (($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) -or
        ($trimmed.StartsWith("'") -and $trimmed.EndsWith("'")))
}

$pluginNames = @(Get-MarketplacePluginNames -Path $marketplacePath)

if ($pluginNames.Count -eq 0) {
    Write-Host "WARN: No plugins found in marketplace manifest." -ForegroundColor Yellow
}

foreach ($pluginName in $pluginNames) {
    $pluginPath = Join-Path $pluginsPath $pluginName
    if (-not (Test-Path $pluginPath)) {
        $errors += "Missing plugin folder for marketplace entry: $pluginName"
        Write-Host "FAIL: plugin folder missing for $pluginName" -ForegroundColor Red
        continue
    }

    $pluginJsonPath = Join-Path $pluginPath "plugin.json"
    if (-not (Test-Path $pluginJsonPath)) {
        $errors += "Missing plugin.json in $pluginName"
        Write-Host "FAIL: $pluginName/plugin.json missing" -ForegroundColor Red
        continue
    }

    $manifest = $null
    try {
        $manifest = Get-Content -Path $pluginJsonPath -Raw | ConvertFrom-Json
        Write-Host "OK: $pluginName/plugin.json exists and is valid JSON" -ForegroundColor Green
    } catch {
        $errors += "Invalid JSON in $pluginName/plugin.json"
        Write-Host "FAIL: $pluginName/plugin.json is invalid JSON" -ForegroundColor Red
        continue
    }

    if ($manifest.name -ne $pluginName) {
        $errors += "plugin.json name '$($manifest.name)' does not match marketplace entry '$pluginName'"
        Write-Host "FAIL: $pluginName/plugin.json name mismatch ('$($manifest.name)')" -ForegroundColor Red
    }

    $legacyDir = Join-Path $pluginPath ".claude-plugin"
    if (Test-Path $legacyDir) {
        $errors += "Legacy .claude-plugin/ directory present in $pluginName"
        Write-Host "FAIL: $pluginName contains a legacy .claude-plugin/ directory" -ForegroundColor Red
    }

    $agentsDir = Join-Path $pluginPath "agents"
    $agentResults = @{}
    if (Test-Path $agentsDir) {
        $strayAgents = @(Get-ChildItem -Path $agentsDir -Filter *.md -File |
            Where-Object { $_.Name -notlike '*.agent.md' })
        foreach ($stray in $strayAgents) {
            $errors += "Agent file without .agent.md extension: $pluginName/agents/$($stray.Name)"
            Write-Host "FAIL: $pluginName/agents/$($stray.Name) must use the .agent.md extension" -ForegroundColor Red
        }
        if ($strayAgents.Count -eq 0) {
            Write-Host "OK: $pluginName agents use the .agent.md extension" -ForegroundColor Green
        }

        $agentFiles = @(Get-ChildItem -Path $agentsDir -Filter *.agent.md -File)
        foreach ($agentFile in $agentFiles) {
            $agentResult = Test-AgentFrontmatterBlock -AgentFile $agentFile.FullName
            $agentFileStem = $agentFile.Name -replace '\.agent\.md$', ''
            $agentResults[$agentFileStem] = $agentResult
            foreach ($agentErrorMessage in $agentResult.Errors) {
                $errors += $agentErrorMessage
                Write-Host "FAIL: $agentErrorMessage" -ForegroundColor Red
            }
            if ($agentResult.Errors.Count -eq 0) {
                Write-Host "OK: $pluginName/agents/$($agentFile.Name) frontmatter valid" -ForegroundColor Green
            }

            if ($null -ne $agentResult.Name) {
                if ($script:agentNameSources.ContainsKey($agentResult.Name)) {
                    $errors += "Duplicate agent name '$($agentResult.Name)' in $($agentFile.FullName) (already used by $($script:agentNameSources[$agentResult.Name]))"
                    Write-Host "FAIL: duplicate agent name '$($agentResult.Name)'" -ForegroundColor Red
                } else {
                    $script:agentNameSources[$agentResult.Name] = $agentFile.FullName
                }
            }
        }

    }

    if ($pluginName -eq 'al-agentic-dev') {
        $fleetErrors = @(Test-AlAgenticDevFleet -AgentResults $agentResults)
        foreach ($fleetError in $fleetErrors) {
            $errors += $fleetError
            Write-Host "FAIL: $fleetError" -ForegroundColor Red
        }
        if ($fleetErrors.Count -eq 0) {
            Write-Host "OK: al-agentic-dev agent fleet matches approved name-to-model map" -ForegroundColor Green
        }
    }

    $hooksCandidates = @(
        (Join-Path $pluginPath "hooks.json"),
        (Join-Path $pluginPath "hooks\hooks.json")
    )
    if ($null -ne $manifest.hooks -and $manifest.hooks -is [string]) {
        $hooksCandidates += (Join-Path $pluginPath $manifest.hooks)
    }
    foreach ($hooksPath in ($hooksCandidates | Select-Object -Unique)) {
        if (-not (Test-Path $hooksPath)) { continue }
        try {
            $hooksConfig = Get-Content -Path $hooksPath -Raw | ConvertFrom-Json
        } catch {
            $errors += "Invalid JSON in hooks config: $hooksPath"
            Write-Host "FAIL: hooks config invalid JSON at $hooksPath" -ForegroundColor Red
            continue
        }
        if ($hooksConfig.version -ne 1) {
            $errors += "Hooks config missing 'version': 1 (Copilot CLI format): $hooksPath"
            Write-Host "FAIL: hooks config at $hooksPath must declare `"version`": 1" -ForegroundColor Red
        } else {
            Write-Host "OK: $pluginName hooks config declares version 1" -ForegroundColor Green
        }
    }

    $skillsPath = Join-Path $pluginPath "skills"
    if (Test-Path $skillsPath) {
        $skillFiles = @(Get-ChildItem -Path $skillsPath -Recurse -Filter SKILL.md -File)
        foreach ($skillFile in $skillFiles) {
            $frontmatter = $null
            try {
                $frontmatter = Get-SkillFrontmatterBlock -SkillFile $skillFile.FullName
            } catch {
                $errors += "Invalid or missing frontmatter in $($skillFile.FullName): $($_.Exception.Message)"
                Write-Host "FAIL: invalid frontmatter block in $($skillFile.FullName)" -ForegroundColor Red
                continue
            }

            $descriptionMatch = [regex]::Match($frontmatter, '(?m)^\s*description:\s*(.+?)\s*$')
            if (-not $descriptionMatch.Success) {
                $errors += "Missing description field in skill frontmatter: $($skillFile.FullName)"
                Write-Host "FAIL: missing description in $($skillFile.FullName)" -ForegroundColor Red
                continue
            }

            $descriptionValue = $descriptionMatch.Groups[1].Value.Trim()
            if (($descriptionValue -match ':\s' -or $descriptionValue -match ':$') -and -not (Test-IsQuotedScalar -Value $descriptionValue)) {
                $errors += "Unquoted description with colon-space in skill frontmatter: $($skillFile.FullName)"
                Write-Host "FAIL: description must be quoted when it contains ': ' in $($skillFile.FullName)" -ForegroundColor Red
                continue
            }

            Write-Host "OK: $($skillFile.FullName) skill frontmatter parsed" -ForegroundColor Green
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll plugins have valid Copilot CLI marketplace structure." -ForegroundColor Cyan
