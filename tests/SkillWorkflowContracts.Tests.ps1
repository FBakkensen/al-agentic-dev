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

    It 'keeps al-next on the Tracker doc, off state and parent changes, and Level 2 through al-arc42' {
        $next = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-next' 'SKILL.md') -Raw
        $arc42 = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-arc42' 'SKILL.md') -Raw

        $next | Should -Match 'every work-item read and write.*Tracker doc'
        $next | Should -Match 'leave its state and parent to the user'
        $next | Should -Match '▶ haiku · /al-arc42 the corrected Level 2 white box.*HTML path, SVG and PNG paths, alt text, publishable fragments'
        $next | Should -Match '▶ haiku · attach the Level 2 PNG and SVG.*as the Tracker doc in docs/agents/issue-tracker\.md says → verified attachment URLs'
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
        $toTickets | Should -Not -Match 'User Story'
        $tdd | Should -Match 'Acceptance Criteria, after `## Behavior` when both are present'
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
        $procedure | Should -Match 'How a pull request names a work item'
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

    It 'states in /al-build that the container login is not a secret and points to it from the skills that use it' {
        $albuild = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-build' 'SKILL.md') -Raw
        $albuild | Should -Match ([regex]::Escape('the throwaway login of a local test container, and they are not secrets'))
        $albuild | Should -Match ([regex]::Escape('`P@ssw0rd`'))

        $pointers = [ordered]@{
            'al-webclient'        = 'that password is not a secret (/al-build)'
            'al-walkthrough'      = 'which is not a secret (/al-build)'
            'al-environment-data' = 'login is not a secret (/al-build)'
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

        foreach ($skill in @('al-clone-bcapps', 'al-grill-with-docs', 'al-implement', 'al-lookup', 'al-pr-shepherd', 'al-improve-codebase-architecture', 'al-simplify')) {
            $content = Get-Content -LiteralPath (Join-Path $script:SkillsRoot $skill 'SKILL.md') -Raw
            $content | Should -Match '/al-commit' -Because "$skill writes repository files"
        }
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
            'Repro Steps'   = [regex]::Escape('Repro Steps')
            'PBI'           = '\bPBIs?\b'
            'gh issue'      = '\bgh issue\b'
            'sub-issue'     = '\bsub-issues?\b'
            'gh pr'         = '\bgh pr\b'
            'GraphQL'       = '\bGraphQL\b'
            'AB#'           = 'AB#'
        }
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

    It 'keeps the Azure DevOps seed template where the setup reads it, under the heading set-up repositories already carry' {
        $tracker = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'AZURE-DEVOPS.md') -Raw
        $setup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'SKILL.md') -Raw

        $tracker | Should -MatchExactly '(?m)^## Work item structure$'
        $tracker | Should -Match '(?m)^### Attach files$'
        $tracker | Should -Match '(?m)^### How a pull request names a work item$'
        $setup | Should -Match ([regex]::Escape('[AZURE-DEVOPS.md](AZURE-DEVOPS.md)'))
    }

    It 'has the Azure DevOps seed template own attachment upload and the native pull-request link' {
        $tracker = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'AZURE-DEVOPS.md') -Raw

        $tracker | Should -Match '/al-azure-devops-attachments'
        $tracker | Should -Match 'verified attachment URLs'
        $tracker | Should -Match 'Description on a Feature or PBI, and in Repro Steps on a Bug'
        $tracker | Should -Match 'mcp__plugin_al-agentic-dev_ado__wit_work_item_comment_write'
        $tracker | Should -Match 'Azure Repos pull request links natively'
        $tracker | Should -Match 'link_to_pull_request'
        $tracker | Should -Match 'GitHub pull request carries `AB#<id>`'
    }

    It 'carries the same operation headings in the GitHub and Azure DevOps seed templates' {
        $headings = foreach ($file in 'AZURE-DEVOPS.md', 'GITHUB.md') {
            $text = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' $file) -Raw
            $text | Should -MatchExactly '(?m)^## Work item structure\r?$'
            ,@([regex]::Matches($text, '(?m)^### (.+?)\r?$') | ForEach-Object { $_.Groups[1].Value })
        }

        $headings[0].Count | Should -BeGreaterThan 0
        $headings[1] | Should -Be $headings[0]
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
        $tracker | Should -Match 'this structure governs where the conventions above differ: no skill closes or reopens one, and every `gh` call passes `--repo`'
    }

    It 'has setup pick the seed template by Tracker and give any other Tracker none' {
        $setup = Get-Content -LiteralPath (Join-Path $script:SkillsRoot 'al-setup-matt-pocock-skills' 'SKILL.md') -Raw

        $setup | Should -Match '(?m)^- GitHub:.*\[GITHUB\.md\]\(GITHUB\.md\)'
        $setup | Should -Match '(?m)^- Azure DevOps:.*\[AZURE-DEVOPS\.md\]\(AZURE-DEVOPS\.md\)'
        $setup | Should -Match 'When a skill says "publish to the issue tracker"'
        $setup | Should -Match 'When a skill says "fetch the relevant ticket"'
        $setup | Should -Match 'any other Tracker'
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
