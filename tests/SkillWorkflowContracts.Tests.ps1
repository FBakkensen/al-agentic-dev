#Requires -Version 7.2

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:SkillsRoot = Join-Path $script:RepoRoot 'skills'
}

Describe 'Skill workflow contracts' {
    It 'reports evidence when no answer can be verified' {
        $lookup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md') -Raw
        $review = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-review' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $improve = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-improve-codebase-architecture' 'SKILL.md') -Raw

        $lookup | Should -Match 'name the unresolved question and each source searched'
        $lookup | Should -Match 'unresolved: <question> — searched: <source locations>'
        $lookup | Should -Match 'Hand the corresponding `verified:`, `assumed:`, or `unresolved:` ledger line'
        $implement | Should -Match '`verified:` / `assumed:` / `unresolved:` ledger entries'
        $improve | Should -Match '`verified:` / `assumed:` / `unresolved:` entries'
        $review | Should -Match 'receipt''s `verified:` / `assumed:` / `unresolved:` entries'
        $review | Should -Match 'Blocking before Non-Blocking'
        $review | Should -Match 'show the failing case or reproducible path when possible'
    }

    It 'keeps refactor evaluation with al-simplify and its entry skills' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $simplify = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-simplify' 'SKILL.md') -Raw

        $implement | Should -Match 'Name `/simplify` and `/mattpocock-skills:improve-codebase-architecture` as the next move'
        $implement | Should -Not -Match 'Tidy:'
        $simplify | Should -Match '`Tidy: none` or the exact cleanups'
    }

    It 'designs one coherent proof set and preserves existing proof while reshaping it' {
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $improve = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-improve-codebase-architecture' 'SKILL.md') -Raw
        $simplify = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-simplify' 'SKILL.md') -Raw

        $tdd | Should -Match 'search the repository for existing proof'
        $tdd | Should -Match 'Current-to-final proof map'
        $tdd | Should -Match 'keep`, `reshape`, `combine`, `split`, `replace`, or `add'
        $tdd | Should -Match 'Every new or materially reshaped automated proof earns a red'
        $tdd | Should -Match 'inject one compiling fault'
        $tdd | Should -Match 'proof-preserving reshapes before new expectations or production changes'
        $tdd | Should -Match 'rerun the gate green'
        $tdd | Should -Match 'A compile error or a failure before the assertion is not a red'
        $implement | Should -Match 'require its current scope green'
        $implement | Should -Match 'run /mattpocock-skills:tdd with al-tdd'
        $improve | Should -Match 'Read the diff, the receipt, and the `Current-to-final proof map`'
        $simplify | Should -Match 'require its current scope green'
        $simplify | Should -Match 'Every new or materially reshaped proof born green takes mutation as its red'
    }

    It 'gates each compilable step of a deepening and closes on the next entry' {
        $improve = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-improve-codebase-architecture' 'SKILL.md') -Raw

        $improve | Should -Match 'Before the first edit, require an executable work item'
        $improve | Should -Match 'require the affected scope green'
        $improve | Should -Match 'run /al-build''s gate after each compilable step'
        $improve | Should -Match 'Restore the last green shape when a step goes unintentionally red'
        $improve | Should -Match 'At every exit'
        $improve | Should -Match '▶ haiku · /al-commit the complete worktree'
        $improve | Should -Match 'writing the returned fragment into the spec field the Tracker doc names'
        $improve | Should -Match 'This intended red is not a reason to restore'
        $improve | Should -Match 'the developer types `/mattpocock-skills:code-review` next, where al-review reads the receipt'
    }

    It 'runs scenario workers one at a time' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw

        $implement | Should -Match 'The workers run one at a time'
        $implement | Should -Match 'after the previous worker''s return meets its contract'
        $implement | Should -Match 'as a checkpoint'
        $implement | Should -Not -Match 'fault turn'
        $implement | Should -Not -Match 'the workers dispatch as background'
        $tdd | Should -Not -Match 'ends its turn with that proof''s fault site'
    }

    It 'keeps precedent map ownership with al-lookup' {
        $lookup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md') -Raw
        $mapContracts = @(Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse |
            Select-String -SimpleMatch 'docs/precedent-map.md' |
            Select-Object -ExpandProperty Path -Unique)

        $lookup | Should -Match 'Whether /al-lookup runs standalone or inside another skill'
        $lookup | Should -Match 'A map hit writes nothing'
        $lookup | Should -Match 'A search with no sourced answer writes nothing'
        $lookup | Should -Match 'a dirty path stops the run before the map changes'
        $lookup | Should -Match 'ask /al-commit to commit the complete worktree'
        $lookup | Should -Match "remove only this run's row from the index and working tree"
        $lookup | Should -Match 'never ownership of a dirty map change'
        $lookup | Should -Not -Match "developer's next commit"
        @($mapContracts).Count | Should -Be 1
        $mapContracts[0] | Should -Be (Join-Path $script:SkillsRoot 'al-lookup' 'SKILL.md')
    }

    It 'keeps al-wayfinder on the one-lookup rule and writes no files' {
        $wayfinder = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-wayfinder' 'SKILL.md') -Raw

        $wayfinder | Should -Match 'description: .*/mattpocock-skills:wayfinder.*AL repository'
        $wayfinder | Should -Match 'A question one `/al-lookup` call answers \| Never a ticket: run `/al-lookup` inline.'
        $wayfinder | Should -Not -Match '/al-commit'
    }

    It 'sends al-research through its four sources in order, the clone rule, and ledger lines on a pushed research branch' {
        $research = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-research' 'SKILL.md') -Raw

        $research | Should -Match '(?m)^1\. \*\*The precedent map\*\*, through /al-lookup.*\r?\n2\. \*\*Microsoft Learn\*\*.*microsoft_docs_search.*\r?\n3\. \*\*The Base App source\*\*.*`\.bcapps/release` first.*\r?\n4\. \*\*/al-environment-data\*\*.*\r?\n(?!5\.)'
        $research | Should -Match 'while `\.bcapps/` is missing runs /al-clone-bcapps'
        $research | Should -Match '`symbols\.lock\.json` is missing, the blocker is a /al-build provisioning run, the user''s step: write that out in the reply as the blocker'
        $research | Should -Match '(?s)verified: <claim>.*assumed: <claim>.*unresolved: <question>'
        $research | Should -Match 'second git worktree outside the repository folder, so the lead''s checkout never switches branch'
        $research | Should -Match 'asks /al-commit to commit the complete worktree from that folder, pushes the branch, and removes the worktree folder'
        $research | Should -Match 'hand /al-lookup the question with the verified claim and its source pointer'
        $research | Should -Match '/al-lookup owns every map change; this skill edits no map'
    }

    It 'keeps al-next on the Tracker doc, off state and parent changes, and Level 2 through al-arc42' {
        $next = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-next' 'SKILL.md') -Raw
        $arc42 = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'SKILL.md') -Raw

        $next | Should -Match 'every work-item read and write.*Tracker doc'
        $next | Should -Match 'leave its state and parent to the user'
        $next | Should -Match '▶ haiku · /al-arc42 the corrected Level 2 white box.*HTML path, SVG and PNG paths, alt text, publishable fragments'
        $next | Should -Match '▶ haiku · attach the Level 2 PNG and SVG.*as the Tracker doc in docs/agents/issue-tracker\.md says → verified attachment URLs'
        $next | Should -Match 'Build the trace page in-line, with no `▶` line'
        $next | Should -Match 'one row per named BPMN end event, with the columns BPMN end event, executable item, `Behavior` scenario, AAA case and proof level from the `Current-to-final proof map`, test procedure, and changed production object'
        $next | Should -Match 'Write it to `\.output/trace/<original-work-item-id>/trace\.html` as static, self-contained HTML: no CDN, iframe, remote asset, or script'
        $next | Should -Match 'It is disposable and never attached or committed'
        $next | Should -Match 'Show the HTML through `show_widget`, falling back to an Artifact, then the local file\.\r?\n\r?\nReport drift'
        $arc42 | Should -Match '(?m)^In: .*/al-next'
    }

    It 'pins the spec structure under the entry skill''s seven headings' {
        $toSpec = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-to-spec' 'SKILL.md') -Raw

        $headings = 'Problem Statement', 'Solution', 'User Stories', 'Implementation Decisions', 'Testing Decisions', 'Out of Scope', 'Further Notes'
        $toSpec | Should -Match ([regex]::Escape($headings -join ', '))
        $toSpec | Should -Match '`Process contract` \(Trigger, Success guarantee, Minimal guarantee\), then `Business process`, nest under Solution'
        $toSpec | Should -Match '`Building Block View` Level 1 nests here, and a `Runtime View` after it'
        $toSpec | Should -Match 'The spec goes in the spec field the Tracker doc names, under the entry''s headings unchanged'
        $toSpec | Should -Not -Match 'User Story'
        $toSpec | Should -Match 'Write BC vocabulary: Post, Validate, Insert, Ledger Entry, codeunit, procedure'
    }

    It 'keeps Speak BC out of every shipped skill' {
        $offenders = foreach ($file in Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse) {
            $relative = $file.FullName.Substring($script:SkillsRoot.Length + 1).Replace('\', '/')
            if ($relative -match 'node_modules') { continue }
            if ((Get-Content -LiteralPath $file.FullName -Raw) -match 'Speak BC') { "$relative names Speak BC" }
        }

        $offenders | Should -BeNullOrEmpty
    }

    It 'slices the Original work item into child work items and orders Acceptance Criteria for people before agents' {
        $toTickets = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-to-tickets' 'SKILL.md') -Raw
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw

        $toTickets | Should -Match '`Original` names a role in this workflow, not the top of the hierarchy'
        $toTickets | Should -Match 'Every existing item stays where it is, including the Original''s own structural parent'
        $toTickets | Should -Match 'One slice creates no child'
        $toTickets | Should -Match 'Several slices each get one direct child work item under the Original work item'
        $toTickets | Should -Match '`Behavior` precedes `Test specification` when both are present'
        $toTickets | Should -Match 'Either section may be omitted'
        $toTickets | Should -Match 'valid fenced Gherkin'
        $toTickets | Should -Match 'Scenarios use BC business words: Post not submit, Ledger Entry not transaction'
        $toTickets | Should -Not -Match 'User Story'
        $tdd | Should -Match 'acceptance criteria, placed as the Tracker doc''s "write the acceptance criteria" says, after `## Behavior` when both are present'
    }

    It 'keeps al-codebase-design read-only and records the first pattern example where the code lands' {
        $design = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-codebase-design' 'SKILL.md') -Raw
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $toSpec = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-to-spec' 'SKILL.md') -Raw

        $design | Should -Not -Match '/al-commit'
        $design | Should -Match 'writes no repo file'
        $design | Should -Match 'proposed `docs/patterns.md` row'
        $implement | Should -Match 'On a green close, for each shape the slice realized that has a precedent in the Original''s Level 1 and no row in `docs/patterns.md`'
        $implement.IndexOf('On a green close') | Should -BeLessThan $implement.IndexOf('/al-commit the complete worktree')
        $toSpec | Should -Match 'whose concept names a Base App table, document, or posting flow'
        $toSpec | Should -Match 'records its shape and the survey''s Base App precedent'
        $toSpec.IndexOf('first consult `/mattpocock-skills:codebase-design`') | Should -BeLessThan $toSpec.IndexOf('/al-arc42 the Building Block Level 1 view')
    }

    It 'drives pull requests to completion through the Code-host procedure, never Copilot' {
        $shepherd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'SKILL.md') -Raw
        $procedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'AZURE-REPOS.md') -Raw

        $shepherd | Should -Not -Match 'Copilot'
        $procedure | Should -Not -Match 'Copilot'
        $shepherd | Should -Match 'only a green gate pushes; red goes to class 4'
        $shepherd | Should -Match '/al-build gate on the tree about to be pushed'
        $shepherd | Should -Match 'built-in /code-review over that commit range'
        $shepherd | Should -Match '/bcquality:al-code-review over that commit range'
        $shepherd | Should -Match 'no Spec axis'
        $shepherd | Should -Match 'git merge-base --is-ancestor origin/main HEAD'
        $procedure | Should -Match 'az repos pr update --id <n> --status completed --merge-strategy squash'
        $procedure | Should -Match 'az repos pr policy list --id <n>'
    }

    It 'picks the Code-host procedure from the origin remote and stops on an unlisted host' {
        $selection = 'Read `git remote get-url origin`: the procedure is the sibling file whose `Hosts` line lists that host. A `*.` entry matches any subdomain of that domain. A host no procedure lists stops the skill, naming the host.'
        $hosts = '(?m)^Hosts: `dev\.azure\.com`, `ssh\.dev\.azure\.com`, `\*\.visualstudio\.com`\.\r?$'
        foreach ($skill in @('al-pull-request', 'al-pr-shepherd')) {
            $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $procedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'AZURE-REPOS.md') -Raw

            $body | Should -Match ([regex]::Escape($selection)) -Because "$skill words the host selection as its sibling does"
            $body | Should -Not -CMatch '\bgh\b|GitHub|GraphQL|Azure Repos|\baz\b|\bado\b' -Because "$skill names a Code host only through its procedure"
            $procedure | Should -MatchExactly $hosts -Because "$skill's procedure lists its hosts"

            $line = [regex]::Match($body, '(?m)^Procedures: (.+)\.\r?$').Groups[1].Value
            $listed = @([regex]::Matches($line, '\[([^\]]+\.md)\]\(\1\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
            $present = @(Get-ChildItem -LiteralPath (Join-Path $script:SkillsRoot $skill) -Filter '*.md' | Where-Object Name -ne 'SKILL.md' | ForEach-Object Name | Sort-Object)
            $listed | Should -Be $present -Because "$skill's Procedures line lists exactly the procedure files in its folder"
        }
    }

    It 'lists github.com in the GitHub procedure of al-pull-request' {
        $procedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' 'GITHUB.md') -Raw

        $procedure | Should -MatchExactly '(?m)^Hosts: `github\.com`\.\r?$'
    }

    It 'gives al-pull-request the same procedure headings for Azure Repos and GitHub' {
        $headings = foreach ($file in 'AZURE-REPOS.md', 'GITHUB.md') {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' $file) -Raw
            ,@([regex]::Matches($text, '(?m)^## (.+?)\r?$') | ForEach-Object { $_.Groups[1].Value })
        }

        $headings[0].Count | Should -BeGreaterThan 0
        $headings[1] | Should -Be $headings[0]
    }

    It 'has the shepherd pick its procedure from the origin remote across both Code hosts and stop on an unlisted one' {
        $selection = 'Read `git remote get-url origin`: the procedure is the sibling file whose `Hosts` line lists that host. A `*.` entry matches any subdomain of that domain. A host no procedure lists stops the skill, naming the host.'
        $procedures = '(?m)^Procedures: \[AZURE-REPOS\.md\]\(AZURE-REPOS\.md\), \[GITHUB\.md\]\(GITHUB\.md\)\.\r?$'
        $hosts = @{
            'AZURE-REPOS.md' = '(?m)^Hosts: `dev\.azure\.com`, `ssh\.dev\.azure\.com`, `\*\.visualstudio\.com`\.\r?$'
            'GITHUB.md'      = '(?m)^Hosts: `github\.com`\.\r?$'
        }
        $body = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'SKILL.md') -Raw

        $body | Should -Match ([regex]::Escape($selection))
        $body | Should -Match $procedures
        $body | Should -Not -CMatch '\bgh\b|GitHub|GraphQL|Azure Repos|\baz\b|\bado\b|CHANGES_REQUESTED|Waiting for author' -Because 'the body names a Code host only through its procedure'
        foreach ($file in $hosts.Keys) {
            $procedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' $file) -Raw
            $procedure | Should -MatchExactly $hosts[$file] -Because "$file lists its hosts"
        }
    }

    It 'carries the same step headings in the shepherd''s two Code-host procedures' {
        $headings = foreach ($file in 'AZURE-REPOS.md', 'GITHUB.md') {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' $file) -Raw
            ,@([regex]::Matches($text, '(?m)^## (.+?)\r?$') | ForEach-Object { $_.Groups[1].Value })
        }

        $headings[0].Count | Should -BeGreaterThan 0
        $headings[1] | Should -Be $headings[0]
    }

    It 'opens the GitHub pull request ready through gh, with the 65,536-character cap and the Tracker link lines' {
        $procedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' 'GITHUB.md') -Raw

        $procedure | Should -Match ([regex]::Escape('gh pr list --repo <owner>/<name> --head <branch> --state open --json number,url,isDraft,closingIssuesReferences,body'))
        $procedure | Should -Match ([regex]::Escape('gh pr create --repo <owner>/<name> --base <base> --head <branch> --title <title> --body-file <file>'))
        $procedure | Should -Match ([regex]::Escape('gh pr edit <n> --repo <owner>/<name> --title <title> --body-file <file>'))
        $procedure | Should -Match ([regex]::Escape('gh pr ready <n> --repo <owner>/<name>'))
        $procedure | Should -Not -Match '--draft\b' -Because 'a pull request is never created as a draft'
        $procedure | Should -Match 'GitHub caps the body at 65,536 characters'
        $procedure | Should -Not -Match '4000-character'
        $procedure | Should -Match 'closingIssuesReferences'
        $procedure | Should -Match 'name the work item in a pull request'
        $procedure | Should -Not -Match 'AB#|Fixes' -Because 'a Code-host procedure parses no tracker link syntax'
    }

    It 'has the GitHub shepherd procedure read through gh and GraphQL, answer in threads, and squash on the go' {
        $procedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'GITHUB.md') -Raw

        $procedure | Should -Match '2\.99\.0 or later'
        $procedure | Should -Match 'gh auth login'
        $procedure | Should -Match 'every `gh` call passes `--repo <owner>/<name>`'
        $procedure | Should -Match 'gh pr view <n> --repo <owner>/<name> --json state,mergeStateStatus,reviewDecision,statusCheckRollup,reviews,headRefOid,closingIssuesReferences,comments'
        $procedure | Should -Match 'reviewThreads\(first:100,after:<cursor>\)'
        $procedure | Should -Match 'gh api user --jq \.login'
        $procedure | Should -Match 'addPullRequestReviewThreadReply'
        $procedure | Should -Match 'resolveReviewThread'
        $procedure | Should -Match 'gh pr comment <n> --repo <owner>/<name>'
        $procedure | Should -Match 'CHANGES_REQUESTED'
        $procedure | Should -Match 'hasNextPage'
        $procedure | Should -Match 'a `mergeStateStatus` of `DIRTY`'
        $procedure | Should -Match '`CLEAN` or `HAS_HOOKS`'
        $procedure | Should -Match '`UNSTABLE`'
        $procedure | Should -Match 'answers <comment url>'
        $procedure | Should -Not -Match 'AB#'
        $procedure | Should -Match 'gh pr merge <n> --repo <owner>/<name> --squash'
        $procedure | Should -Not -Match '--auto'
    }

    It 'has the shepherd work a CI review''s findings as class 2 on both Code hosts' {
        $shepherd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'SKILL.md') -Raw
        $classes = @([regex]::Matches($shepherd, '(?m)^(\d)\. \*\*(.+?)\*\*') | ForEach-Object { $_.Groups[1].Value + ':' + $_.Groups[2].Value })

        $classes.Count | Should -Be 5
        $classes[1] | Should -Be '2:A CI review''s finding'
        $classes[2] | Should -Match '^3:Anyone else'
        $classes[3] | Should -Match '^4:A red /al-build gate'
        $classes[4] | Should -Match '^5:Behind main'
        $shepherd | Should -Match 'description: .*Use when its threads hold the user''s comments to work, a CI review''s findings to work, or a reviewer''s feedback to surface\.'
        $shepherd | Should -Match 'a thread posted by a review check that runs on the pull request, such as the Claude review or the bcquality review'
        $shepherd | Should -Match 'blocking finding is fixed through the worker class 1 uses, then answered and marked as the procedure says'
        $shepherd | Should -Match 'finding the shepherd judges wrong is answered with the reason and marked the same way; the shepherd reruns its check as the procedure says, and the next read sees the result'
        $shepherd | Should -Match 'finding it cannot settle goes to the user and stops the automation, like class 3'
        $shepherd | Should -Match 'summary comment is always read: its blocking items are acted on only when the check is red'
        $shepherd | Should -Match 'nits are listed in the close and never acted on'
        $shepherd | Should -Match 'a person''s comment, or a blocking review vote — goes to the user and stops the automation'
        $shepherd | Should -Match 'except a review-check bot''s thread, which stays class 2'

        $github = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'GITHUB.md') -Raw
        $github | Should -Match 'first comment is authored by `github-actions` or `github-actions\[bot\]`, while a check whose name contains `review` ran on the head'
        $github | Should -Match 'by another login that is not a review-check bot'
        $github | Should -Match '`dependabot\[bot\]` included, counts as anyone else''s'
        $github | Should -Match 'A CI review''s finding takes the same two calls'
        $github | Should -Match 'gh run rerun <run-id> --failed --repo <owner>/<name>'
        $github | Should -Match 'run id comes from that check''s `detailsUrl` in `statusCheckRollup`'

        $azure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pr-shepherd' 'AZURE-REPOS.md') -Raw
        $azure | Should -Match 'author is the project''s build service identity, `<project> Build Service`, and a build policy on the pull request whose display name contains `review` carries the review'
        $azure | Should -Match 'blocking items are acted on only when that policy''s evaluation is rejected or failed'
        $azure | Should -Match 'any author other than the driving user and a review-check build service identity'
        $azure | Should -Match 'judged wrong gets the reason in the `reply`, then `update_status` to `WontFix`'
        $azure | Should -Match 'az repos pr policy queue --id <n> --evaluation-id <id>'
    }

    It 'walks the Gherkin scenarios in the agent container through a browser driver' {
        $walkthrough = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-walkthrough' 'SKILL.md') -Raw
        $republish = '▶ haiku · /al-build clean republish into the branch''s agent container → deployed commit, app version, Web Client URL, username'
        $confirmAsk = 'asks the user with `AskUserQuestion`'
        $webclientFirst = 'Before the first browser call, the lead invokes /al-webclient'

        $walkthrough | Should -Not -Match 'User Story|Copilot|workspace MCP|bc_'
        $walkthrough | Should -Match ([regex]::Escape($republish))
        [regex]::Matches($walkthrough, '(?m)^\s*▶ ').Count | Should -Be 1
        $walkthrough | Should -Match 'mcp__remote-devices__Claude_Browser__'
        $walkthrough | Should -Match 'one `ToolSearch` call on its prefix'
        $walkthrough | Should -Match ([regex]::Escape('npm install -g @playwright/cli@latest'))
        $walkthrough | Should -Match ([regex]::Escape('playwright-cli -s=<agent-container> open <url> --headed'))
        $walkthrough | Should -Match ([regex]::Escape('--config .output/playwright.json'))
        $walkthrough | Should -Match ([regex]::Escape('navOk: false'))
        $walkthrough | Should -Match ([regex]::Escape($confirmAsk))
        $walkthrough | Should -Match ([regex]::Escape($webclientFirst))
        $walkthrough | Should -Match 'container password, which is not a secret'
        $walkthrough | Should -Match ([regex]::Escape('.output/walkthrough/'))
        $walkthrough | Should -Match ([regex]::Escape('mcp__claude-in-chrome__computer'))
        $walkthrough | Should -Match ([regex]::Escape('screenshot --filename=<path>'))
        $walkthrough | Should -Match 'the comment says every step passed'
        $walkthrough | Should -Match ([regex]::Escape('enable__mcp__remote-devices__Claude_Browser'))
        $walkthrough | Should -Match 'takes its screenshot before the next action'
        $walkthrough | Should -Match 'attaches the screenshots to the executable work item as the Tracker doc says'
        $walkthrough | Should -Match 'posts one comment on the executable work item as the Tracker doc says'

        $walkthrough.IndexOf('mcp__Claude_Browser__') | Should -BeLessThan $walkthrough.IndexOf('mcp__claude-in-chrome__')
        $walkthrough.IndexOf('mcp__claude-in-chrome__') | Should -BeLessThan $walkthrough.IndexOf('Playwright CLI')
        $walkthrough.IndexOf('Playwright CLI') | Should -BeLessThan $walkthrough.IndexOf($republish)
        $walkthrough.IndexOf($confirmAsk) | Should -BeLessThan $walkthrough.IndexOf($republish)
        $walkthrough.IndexOf($republish) | Should -BeLessThan $walkthrough.IndexOf($webclientFirst)
    }

    It 'keeps al-prototype on its own branch, the relaxed gate, three forms, the attach verb, and /al-commit' {
        $prototype = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-prototype' 'SKILL.md') -Raw

        $prototype | Should -Match 'description: .*/mattpocock-skills:prototype.*AL repository'
        $prototype | Should -Match 'own `prototype/<name>` branch'
        $prototype | Should -Match 'own `\.vscode/settings\.json` with no analyzers'
        $prototype | Should -Match 'zero-warnings bar does not apply'
        $prototype | Should -Match '\*\*Logic through AL Runner\.\*\*'
        $prototype | Should -Match '\*\*Logic that needs a surface AL Runner refuses\*\* \(`RunnerOutOfScopeException`\)'
        $prototype | Should -Match '\*\*UI or UX, on top of either\.\*\*'
        $prototype | Should -Match 'the Tracker doc''s "attach a file" says'
        $prototype | Should -Match 'The agent runs /al-commit at every exit'
    }

    It 'states in /al-build that the container login is not a secret and points to it from the skills that use it' {
        $albuild = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-build' 'SKILL.md') -Raw
        $albuild | Should -Match ([regex]::Escape('the throwaway login of a local test container, and they are not secrets'))
        $albuild | Should -Match ([regex]::Escape('`P@ssw0rd`'))

        $pointers = [ordered]@{
            'al-webclient'        = 'that password is not a secret (/al-build)'
            'al-walkthrough'      = 'which is not a secret (/al-build)'
            'al-environment-data' = 'login is not a secret (/al-build)'
            'al-prototype'        = 'the container login is not a secret (/al-build)'
        }
        foreach ($skill in $pointers.Keys) {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $text | Should -Match ([regex]::Escape($pointers[$skill]))
        }
    }

    It 'recovers an agent container with Remove-BcContainer, never docker rm -f' {
        $albuild = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-build' 'SKILL.md') -Raw

        $albuild | Should -Match 'Remove-BcContainer -containerName <container>'
        $albuild | Should -Not -Match 'docker\s+rm\s+-f'
    }

    It 'owns commits and pull requests in dedicated skills' {
        $commit = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-commit' 'SKILL.md') -Raw
        $pullRequest = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' 'SKILL.md') -Raw
        $pullRequestProcedure = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-pull-request' 'AZURE-REPOS.md') -Raw

        $commit | Should -Match 'Treat every file in the worktree as in scope'
        $commit | Should -Match 'Stage all files by default'
        $commit | Should -Match 'maximum number of independently valid commits'
        $commit | Should -Not -Match 'AB#'
        $commit | Should -MatchExactly 'Co-Authored-By: Claude <noreply@anthropic\.com>'

        $pullRequest | Should -Match 'Use `<area>: <imperative change>` for the title'
        $pullRequestProcedure | Should -Match 'mcp__plugin_al-agentic-dev_ado__repo_pull_request_write'
        $pullRequestProcedure | Should -Match 'Azure Repos caps the description at 4000 characters'
        $pullRequestProcedure | Should -Match 'passed explicitly on every .update.'
        $pullRequest | Should -Match 'link every work-item id on the branch as that section says'
        $pullRequest | Should -Not -MatchExactly '\bgh\b'
        $pullRequest | Should -Not -MatchExactly '\baz\b'
        $pullRequest | Should -Not -Match 'ado__|isDraft|4000'
        $pullRequest | Should -Not -Match 'AB#'
        $pullRequest | Should -Match 'this skill runs no tests'
        $pullRequest | Should -Match 'Push unpublished commits'
        $pullRequest | Should -Match 'never creates or keeps a draft'
        $pullRequest | Should -Match 'Name /al-pr-shepherd as the next move'

        foreach ($skill in @('al-clone-bcapps', 'al-grill-with-docs', 'al-implement', 'al-lookup', 'al-pr-shepherd', 'al-improve-codebase-architecture', 'al-simplify', 'al-research')) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $content | Should -Match '/al-commit' -Because "$skill writes repository files"
        }
    }

    It 'scopes the AL style''s word pairs to BC operations and records' {
        $style = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'output-styles' 'AL.md') -Raw

        $style | Should -Match 'binds every word that names a BC operation or record'
        $style | Should -Match 'An ordinary word such as "build" stays\.'
        $style | Should -Match 'The reply uses the BC word without saying which word it replaced\.'
        $style | Should -Match '(?m)^description: Speak BC vocabulary for every BC operation and record'
        $style | Should -Not -Match 'in every word'
    }
}

Describe 'Tracker neutrality' {
    BeforeAll {
        $script:TrackerTokens = [ordered]@{
            'ado MCP tool'  = [regex]::Escape('mcp__plugin_al-agentic-dev_ado__')
            'az boards'     = [regex]::Escape('az boards')
            'az repos'      = [regex]::Escape('az repos')
            'Azure DevOps'  = [regex]::Escape('Azure DevOps')
            'Azure Repos'   = [regex]::Escape('Azure Repos')
            'gh issue'      = '\bgh issue\b'
            'sub-issue'     = '\bsub-issues?\b'
            'gh pr'         = '\bgh pr\b'
            'GraphQL'       = '\bGraphQL\b'
            'AB#'           = 'AB#'
        }
        $script:TypeAndFieldTokens = [ordered]@{
            'PBI'                      = '\bPBIs?\b'
            'Product Backlog Item'     = [regex]::Escape('Product Backlog Item')
            'Epic'                     = '\bEpic\b'
            'Repro Steps'              = [regex]::Escape('Repro Steps')
            'Expected Release Version' = [regex]::Escape('Expected Release Version')
            'Implementation notes'     = [regex]::Escape('Implementation notes')
            'Release notes'            = [regex]::Escape('Release notes')
            'Product field'            = [regex]::Escape('`Product`')
            '--type with a type name'  = '--type\s+[A-Z]'
        }
        $script:SeedTemplates = 'AZURE-DEVOPS.md', 'GITHUB.md'
        $script:Verbs = @(
            'publish to the issue tracker'
            'fetch the relevant ticket'
            'create the Original work item'
            'write the spec'
            'write the acceptance criteria'
            'create a slice'
            'link a blocker'
            'comment'
            'attach a file'
            'name the work item in a pull request'
        )
        $script:Placeholders = @(
            '<new Original work item type>'
            '<defect type>'
            '<slice type>'
            '<spec field for each type>'
            '<acceptance criteria location>'
        )
        $script:TokenHomes = @{
            'AB#' = @('al-setup-matt-pocock-skills/AZURE-DEVOPS.md', 'al-setup-matt-pocock-skills/GITHUB.md')
        }
        $script:TrackerHomes = @(
            'al-setup-matt-pocock-skills/AZURE-DEVOPS.md'
            'al-setup-matt-pocock-skills/GITHUB.md'
            'al-setup-matt-pocock-skills/SKILL.md'
            'al-azure-devops-attachments/'
            'al-pull-request/AZURE-REPOS.md'
            'al-pull-request/GITHUB.md'
            'al-pr-shepherd/AZURE-REPOS.md'
            'al-pr-shepherd/GITHUB.md'
        )
    }

    It 'names no Tracker-specific tool or field outside the seed templates, the attachment skill, and the Code-host procedures' {
        $offenders = foreach ($file in Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse) {
            $relative = $file.FullName.Substring($script:SkillsRoot.Length + 1).Replace('\', '/')
            if ($relative -match 'node_modules') { continue }
            $text = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($name in $script:TrackerTokens.Keys) {
                $homes = if ($script:TokenHomes.ContainsKey($name)) { $script:TokenHomes[$name] } else { $script:TrackerHomes }
                if ($homes | Where-Object { $relative.StartsWith($_) }) { continue }
                if ($text -cmatch $script:TrackerTokens[$name]) { "$relative names $name" }
            }
        }

        $offenders | Should -BeNullOrEmpty
    }

    It 'names no work item type or field anywhere in the shipped skills, the seed templates included' {
        $offenders = foreach ($file in Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse) {
            $relative = $file.FullName.Substring($script:SkillsRoot.Length + 1).Replace('\', '/')
            if ($relative -match 'node_modules') { continue }
            $text = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($name in $script:TypeAndFieldTokens.Keys) {
                if ($text -cmatch $script:TypeAndFieldTokens[$name]) { "$relative names $name" }
            }
        }

        $offenders | Should -BeNullOrEmpty
    }

    It 'keeps both seed templates where the setup reads them, under the heading set-up repositories already carry' {
        $setup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'SKILL.md') -Raw

        foreach ($file in $script:SeedTemplates) {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' $file) -Raw
            $text | Should -MatchExactly '(?m)^## Work item structure\r?$'
            $setup | Should -Match ([regex]::Escape("[$file]($file)"))
        }
    }

    It 'has the Azure DevOps seed template own attachment upload and the native pull-request link' {
        $tracker = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'AZURE-DEVOPS.md') -Raw

        $tracker | Should -Match '/al-azure-devops-attachments'
        $tracker | Should -Match 'verified attachment URLs'
        $tracker | Should -Match 'mcp__plugin_al-agentic-dev_ado__wit_work_item_comment_write'
        $tracker | Should -Match 'Azure Repos pull request links natively'
        $tracker | Should -Match 'link_to_pull_request'
        $tracker | Should -Match 'GitHub pull request carries `AB#<id>`'
    }

    It 'carries the same ## and ### headings in the GitHub and Azure DevOps seed templates, with every verb' {
        $headings = foreach ($file in $script:SeedTemplates) {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' $file) -Raw
            ,@([regex]::Matches($text, '(?m)^(###? .+?)\r?$') | ForEach-Object { $_.Groups[1].Value })
        }

        $headings[0].Count | Should -BeGreaterThan 0
        $headings[1] | Should -Be $headings[0]
        $verbHeadings = $script:Verbs | ForEach-Object { "## When a skill says `"$_`"" }
        @($headings[0] | Where-Object { $_ -in $verbHeadings }) | Should -Be $verbHeadings
    }

    It 'has both seed templates update from the value just read and keep every other section' {
        foreach ($file in $script:SeedTemplates) {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' $file) -Raw
            $text | Should -Match 'replaces only its own section, and writes the whole (field|body) back' -Because "$file keeps the other sections"
        }
    }

    It 'names only Tracker doc sections the seed templates write' {
        $references = foreach ($file in Get-ChildItem -LiteralPath $script:SkillsRoot -Filter '*.md' -Recurse) {
            $relative = $file.FullName.Substring($script:SkillsRoot.Length + 1).Replace('\', '/')
            if ($relative -match 'node_modules' -or $relative.StartsWith('al-setup-matt-pocock-skills/')) { continue }
            $text = Get-Content -LiteralPath $file.FullName -Raw
            foreach ($match in [regex]::Matches($text, 'Tracker doc''s "([^"]+)"')) {
                [pscustomobject]@{ File = $relative; Name = $match.Groups[1].Value }
            }
        }

        @($references).Count | Should -BeGreaterThan 0
        $dangling = $references | Where-Object { $_.Name -notin $script:Verbs } | ForEach-Object { "$($_.File) names `"$($_.Name)`"" }
        $dangling | Should -BeNullOrEmpty
    }

    It 'carries each per-repository placeholder by name in both seed templates' {
        foreach ($file in $script:SeedTemplates) {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' $file) -Raw
            foreach ($placeholder in $script:Placeholders) {
                $text.Contains($placeholder) | Should -BeTrue -Because "$file carries $placeholder"
            }
        }
    }

    It 'has the GitHub seed template work items only through gh and attach images through --attach' {
        $tracker = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'GITHUB.md') -Raw

        $tracker | Should -Match '2\.99\.0 or later'
        $tracker | Should -Match 'gh auth login'
        $tracker | Should -Match '--add-blocked-by'
        $tracker | Should -Match '--attach \./<file>#<alt>'
        $tracker | Should -Match '`updatedAt`'
        $tracker | Should -Match 'BPMN source'
        $tracker | Should -Match '--method PATCH'
        $tracker | Should -Match 'Fixes #<executable item>'
        $tracker | Should -Match 'Pass it to every `gh` call as `--repo <owner>/<repo>`'
    }

    It 'has setup pick the seed template by Tracker and accept any other Tracker' {
        $setup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'SKILL.md') -Raw

        $setup | Should -Match '(?m)^- GitHub:.*\[GITHUB\.md\]\(GITHUB\.md\)'
        $setup | Should -Match '(?m)^- Azure DevOps:.*\[AZURE-DEVOPS\.md\]\(AZURE-DEVOPS\.md\)'
        foreach ($verb in $script:Verbs) {
            $setup.Contains("`"$verb`"") | Should -BeTrue -Because "the setup lists the verb $verb"
        }
        $setup | Should -Match 'Any other Tracker: the user''s description, then a `## Work item structure` section and the verb sections'
        $setup | Should -Not -Match 'serves GitHub and Azure DevOps'
        $setup | Should -Match '`origin`'
    }

    It 'has every attach line defer to the Tracker doc and return verified attachment URLs' {
        $lines = Get-ChildItem -LiteralPath $script:SkillsRoot -Filter 'SKILL.md' -Recurse |
            Where-Object { $_.FullName -notmatch 'node_modules' } |
            Select-String -Pattern '^\s*▶ haiku · attach '

        @($lines).Count | Should -BeGreaterThan 0
        foreach ($line in $lines) {
            $line.Line | Should -Match 'as the Tracker doc in docs/agents/issue-tracker\.md says → verified attachment URLs$'
        }
    }
}

Describe 'Module shape' {
    It 'states the module shape in the Seams section and keeps the one-implementation rule' {
        $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-codebase-design' 'SKILL.md') -Raw
        $design = [regex]::Match($text, '(?s)\r?\n## Seams\r?\n(.*?)(?=\r?\n## |\z)').Groups[1].Value

        $design | Should -Not -BeNullOrEmpty
        $design | Should -Match 'Its root namespace is its interface'
        $design | Should -Match '`<module>\.Internal` holds its internals'
        $design | Should -Match 'folder path equals namespace'
        $design | Should -Match 'carved out of a feature cluster as a child namespace'
        $design | Should -Match 'everything outside a module'
        $design | Should -Match 'An AL interface with one implementation stays out unless a second implementation or a stable external contract proves the seam\. An extensible enum plus an interface that other apps implement is such a contract\.'
    }

    It 'places new behavior in a module and tests a module through its root namespace' {
        $implement = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-implement' 'SKILL.md') -Raw
        $tdd = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-tdd' 'SKILL.md') -Raw

        $implement | Should -Match 'With the module gate on, a new object, callable procedure, or event subscriber goes into a module of the shape /al-codebase-design states; a fix inside an existing open-code procedure stays where it is'
        $tdd | Should -Match 'with the module gate on, that is its root namespace, never its `\.Internal`, from a test at the module''s path in the test tree'
    }

    It 'flags a test that reaches a module''s .Internal and keeps a module''s interface fixed' {
        $review = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-review' 'SKILL.md') -Raw
        $simplify = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-simplify' 'SKILL.md') -Raw

        $review | Should -Match 'tests exercise the caller-visible module interface rather than private internals; a test that reaches a module''s `\.Internal` is the concrete finding'
        $simplify | Should -Match 'the Level 1 module interface \(with the module gate on, each module''s root namespace\) are fixed; a module''s `\.Internal` may be reshaped behind it'
    }

    It 'keeps the word legacy out of the five skills that state the module shape' {
        foreach ($name in 'al-codebase-design', 'al-implement', 'al-tdd', 'al-review', 'al-simplify') {
            Get-Content -LiteralPath (Join-Path $script:SkillsRoot $name 'SKILL.md') -Raw | Should -Not -Match 'legacy' -Because "$name speaks of modules and open code"
        }
    }

    It 'defines Module and Open code in the glossary' {
        $context = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'CONTEXT.md') -Raw

        $context | Should -Match '(?m)^\*\*Module\*\*:\r?\nA child namespace carved out of a feature cluster.*root namespace is its interface.*`\.Internal`.*folder path equals namespace'
        $context | Should -Match '(?m)^\*\*Open code\*\*:\r?\nEvery AL object outside a module.*no special name or mark'
    }
}

Describe 'Open code refactoring path' {
    BeforeAll {
        $script:ArchitectureRoot = Join-Path $script:SkillsRoot 'al-improve-codebase-architecture'
        $script:ArchitectureSkill = Get-Content -LiteralPath (Join-Path $script:ArchitectureRoot 'SKILL.md') -Raw
        $script:OpenCode = Get-Content -LiteralPath (Join-Path $script:ArchitectureRoot 'OPEN-CODE.md') -Raw
    }

    It 'links the path from SKILL.md with its scope and keeps the body within the length rule' {
        $script:ArchitectureSkill | Should -Match 'open code in an app with the module gate on \(`moduleGate\.enabled` true in `al-build\.json`\)'
        $script:ArchitectureSkill | Should -Match '\[OPEN-CODE\.md\]\(OPEN-CODE\.md\)'
        @(Get-Content -LiteralPath (Join-Path $script:ArchitectureRoot 'SKILL.md')).Count | Should -BeLessOrEqual 60
    }

    It 'fixes each module''s root namespace and sends a new module''s interface through the Level 1 interface sentence' {
        $script:ArchitectureSkill | Should -Match 'each module''s root namespace\) are fixed'
        $script:ArchitectureSkill | Should -Match 'a new module''s interface included, goes to the user before any refactor'
        $script:OpenCode | Should -Match 'agreed with the user before the first move \(Freeze\)'
    }

    It 'states the seven steps in order' {
        $phrases = @(
            '1\. \*\*Characterization tests\.\*\*'
            'calling the open-code procedures directly'
            'planned end'
            '2\. \*\*Mutation set\.\*\*'
            'each behavior-bearing site'
            'inject-red-revert'
            'turn a characterization test red'
            'deliberately unpinned'
            '3\. \*\*Extraction\.\*\*'
            'new or existing modules'
            '`\.Internal`'
            'through its root namespace'
            '4\. \*\*Pure proxies\.\*\*'
            'only delegates'
            '5\. \*\*Mutation handover\.\*\*'
            'module''s own tests'
            'retire the characterization tests'
            '6\. \*\*Obsolete\.\*\*'
            'the handover has passed'
            '\[Obsolete\(''<replacement interface>'', ''<tag>''\)\]'
            'AL0432'
            '7\. \*\*Callers switched\.\*\*'
            'mechanically'
            'keeps its mark'
            'zero-warnings green'
        )
        $at = -1
        foreach ($phrase in $phrases) {
            $match = [regex]::Match($script:OpenCode, $phrase)
            $match.Success | Should -BeTrue -Because "OPEN-CODE.md states: $phrase"
            $match.Index | Should -BeGreaterThan $at -Because "$phrase follows the step before it"
            $at = $match.Index
        }
    }

    It 'records a surviving fault as a receipt line and adds no receipt prefix' {
        $script:OpenCode | Should -Match 'the receipt gets a line naming the site'
        $script:OpenCode | Should -Not -Match '(?m)^\s*`?unpinned:'
    }

    It 'keeps event publishers that dependents subscribe to out of the proxies' {
        $script:OpenCode | Should -Match 'never become proxies and never move'
        $script:OpenCode | Should -Match 'Modules raise the same events'
        $script:OpenCode | Should -Match 'one test per event'
    }

    It 'speaks of open code and modules, never legacy' {
        foreach ($name in 'SKILL.md', 'OPEN-CODE.md') {
            Get-Content -LiteralPath (Join-Path $script:ArchitectureRoot $name) -Raw | Should -Not -Match 'legacy' -Because "$name speaks of open code and modules"
        }
    }
}

Describe 'Group by feature into namespaces' {
    BeforeAll {
        $script:GroupSkillPath = Join-Path $script:SkillsRoot 'al-group-by-feature-into-namespaces' 'SKILL.md'
        $script:GroupSkill = Get-Content -LiteralPath $script:GroupSkillPath -Raw
    }

    It 'keeps the file within the length rule and names each of the three trigger branches in the description' {
        @(Get-Content -LiteralPath $script:GroupSkillPath).Count | Should -BeLessOrEqual 60
        $description = [regex]::Match($script:GroupSkill, '(?m)^description: (.+)$').Groups[1].Value
        $description | Should -Match 'an AL app has no namespaces'
        $description | Should -Match 'organize an app''s objects by feature into namespaces'
        $description | Should -Match 'module gate is to be switched on in an existing repository'
    }

    It 'delegates the survey on opus and returns the map table with dependent-referenced objects marked final' {
        $line = @($script:GroupSkill -split '\r?\n' | Where-Object { $_ -match '^▶ opus · ' })
        $line.Count | Should -Be 1
        $line[0] | Should -Match 'usage clusters'
        $line[0] | Should -Match 'as granular as the code allows'
        $line[0] | Should -Match 'namespace level covering everything it touches'
        $line[0] | Should -Match 'event publishers and procedures an add-on can call marked final'
        $line[0] | Should -Match ' → table of object type, ID, name, proposed namespace, folder \(the namespace path below the source root\), and evidence \(what it references, what references it, which fields it shares\), one row per object$'
    }

    It 'surveys the app and its test apps once and mirrors the grouping into the test namespaces' {
        $line = @($script:GroupSkill -split '\r?\n' | Where-Object { $_ -match '^▶ opus · ' })[0]
        $line | Should -Match 'survey the app in <app folder> and the test apps <test app folders> into one namespace map'
        $line | Should -Match 'a test object lands in <root>\.Test plus the namespace path of the objects it exercises, at the covering level when it spans clusters'
        $script:GroupSkill | Should -Match 'One survey covers the app and every test app'
        $script:GroupSkill | Should -Match '`containerTestApps` included'
    }

    It 'gets the developer''s agreement before anything is written' {
        $agree = [regex]::Match($script:GroupSkill, '(?s)\r?\n## Agree\r?\n(.*?)(?=\r?\n## |\z)').Groups[1].Value
        $agree | Should -Match '`show_widget`, falling back to an Artifact, then a table in the reply'
        $agree | Should -Match '`AskUserQuestion`'
        $agree | Should -Match 'Nothing is written before the developer agrees'
        $script:GroupSkill.IndexOf('## Agree') | Should -BeGreaterThan $script:GroupSkill.IndexOf('▶ opus ·')
        $script:GroupSkill.IndexOf('## Apply') | Should -BeGreaterThan $script:GroupSkill.IndexOf('## Agree')
    }

    It 'applies the agreed map through /al-build and runs the gate before the module gate is written' {
        $apply = [regex]::Match($script:GroupSkill, '(?s)\r?\n## Apply\r?\n(.*?)(?=\r?\n## |\z)').Groups[1].Value
        $apply | Should -Match '(?m)^▶ haiku · /al-build provision the symbols, apply `\.output/namespace-map\.json` with root namespace <root>, then the gate with ALBT_MODULE_GATE_ENABLED false.* → '
        $apply | Should -Match '"type", "id", "name", "namespace"'
        $apply | Should -Not -Match '\.ps1|scripts/'
    }

    It 'splits the agreed map per app and applies each test app under <root>.Test without a new provision' {
        $apply = [regex]::Match($script:GroupSkill, '(?s)\r?\n## Apply\r?\n(.*?)(?=\r?\n## |\z)').Groups[1].Value
        $apply | Should -Match 'Split the agreed map into one file per app, `\.output/namespace-map\.json` for the app and `\.output/namespace-map-<app folder>\.json` for each test app'
        $apply | Should -Match 'a new provision would clear them'
        $apply | Should -Match '(?m)^▶ haiku · /al-build apply each test app''s map `\.output/namespace-map-<app folder>\.json` with root namespace <root>\.Test and that app folder, without provisioning, then the gate with ALBT_MODULE_GATE_ENABLED false.* → '
        $apply.IndexOf('/al-build provision the symbols') | Should -BeLessThan $apply.IndexOf('/al-build apply each test app')
    }

    It 'writes the moduleGate block on with the root namespace only after a green gate, then runs the gate again' {
        $switch = [regex]::Match($script:GroupSkill, '(?s)\r?\n## Switch the gate on\r?\n(.*?)(?=\r?\n## |\z)').Groups[1].Value
        $switch | Should -Match 'Once both gates are green'
        $switch | Should -Match '"moduleGate": \{ "enabled": true, "rootNamespace": "<root>" \}'
        $switch | Should -Match '(?m)^▶ haiku · /al-build gate with the module gate on'
        $switch | Should -Match 'moduleGate` block'
        $script:GroupSkill.IndexOf('## Switch the gate on') | Should -BeGreaterThan $script:GroupSkill.IndexOf('## Apply')
    }

    It 'creates no module, changes no object''s access, and commits through /al-commit at every exit' {
        $script:GroupSkill | Should -Match 'creates no module and changes no object''s access'
        $close = [regex]::Match($script:GroupSkill, '(?s)\r?\n## Close\r?\n(.*?)\z').Groups[1].Value
        $close | Should -Match 'At every exit — clean close, a red gate that pauses the run, or a question left with the developer'
        $close | Should -Match '(?m)^▶ haiku · /al-commit the complete worktree → '
        $script:GroupSkill | Should -Not -Match 'legacy'
    }

    It 'carries the AL grounding rule' {
        $script:GroupSkill | Should -Match 'confirmed by a lookup in the current session, never recalled'
    }

    It 'lists the skill in the grounding rule''s list in the skill rules' {
        $rules = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.claude' 'rules' 'skills.md') -Raw
        $rules | Should -Match '`al-prototype`, `al-research`, and `al-group-by-feature-into-namespaces` carry the grounding rule'
    }
}
