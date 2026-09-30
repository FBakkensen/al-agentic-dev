# Working on this repo

This repo ships the Claude Code plugin `al-agentic-dev`: Agent Skills for AL/Business Central development plus a `SessionStart` hook, bundled MCP servers, and the marketplace that installs it with its Base plugins. The plugin is Claude Code–exclusive (ADR 0001) — skills name Claude Code tools, bundled MCP servers, and Base plugin skills explicitly.

Git history is the donor archive — a retired skill returns from a commit, never from a copy.

## The shipped surface

```
.claude-plugin/plugin.json      the plugin manifest: name, description, version (set only here), the bundled MCP servers — microsoft-learn, and ado on the org naveksaas, none with a tools allowlist — the Base plugin dependencies
.claude-plugin/marketplace.json the marketplace: this plugin at ./ plus the re-listed Base plugins bcquality and al-language-server-go-windows
hooks/hooks.json                the SessionStart hook: runs hooks/Write-SessionStart.ps1
hooks/session-start.md          the delegation rules and the entry → addition table the hook injects in every session
output-styles/AL.md             the opt-in al-agentic-dev:AL style: Speak BC and the interview-diagram rule; frontmatter name AL, keep-coding-instructions true, no force-for-plugin
skills/<name>/SKILL.md          frontmatter: name, description
skills/<name>/<SIBLING>.md      optional format files, inside the same folder only
skills/al-event-model/bpmn-renderer/ package-local BPMN renderer dependencies
skills/al-build/scripts/*.ps1   the build substrate
skills/al-build/config/         al-build.json
```

Twenty skills ship today.

- `al-build` — the compile-publish-test gate, provisioning, breaking-change validation, and the container lifecycle; the contract model everything else copies.
- `al-clone-bcapps` — the BCApps lookup-source clone.
- `al-clone-bcquality` — the BCQuality lookup-source clone.
- `al-grill-adr` — one Original work item, the preserved request, vocabulary, and hard-to-reverse ADRs.
- `al-lookup` — one platform question, a sourced answer, the precedent map.
- `al-azure-devops-attachments` — Azure CLI upload and verified work-item attachment relations.
- `al-commit` — full-worktree staging and independently valid commits.
- `al-pull-request` — ready pull request creation and updates.
- `al-event-model` — the process contract and BPMN review HTML.
- `al-arc42` — official arc42 formatting and architecture review HTML.
- `al-design` — Level 1 module contracts.
- `al-scope` — one Original work item with direct outcome slices.
- `al-test-design` — user-reviewed AAA after Gherkin in Acceptance Criteria.
- `al-implement` — proof through the module interface.
- `al-refactor` — behavior-frozen reshape.
- `al-review` — read-only contract verdict.
- `al-next` — reconciliation of design, slices, receipts, and landed code.
- `al-pr-shepherd` — one open PR to merge: CI watched, review findings fixed, main merged in with intent-preserving conflicts; the merge itself is the user's go.
- `al-walkthrough` — the Gherkin walk in the running Web Client through the Consumer repository's workspace MCP.
- `al-setup-matt-pocock-skills` — the Azure DevOps issue-tracker option and tracker text for `/mattpocock-skills:setup-matt-pocock-skills`.

The folder name equals the frontmatter `name`. A skill reaches outside its folder only by naming another skill — `/al-build` — never by path.

Every skill is model-invocable. Skill frontmatter omits `disable-model-invocation`, and every description carries the trigger branches that let the model reach it.

## What never ships

- The word "harness" and harness-conditional phrasing — the gate fails it; name the Claude Code tool, MCP server, or agent instead.
- A capability paraphrase where a concrete Claude Code name exists.
- Skill frontmatter beyond `name` and `description` — no `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`, or `disable-model-invocation` on a skill.
- Task-state ceremony — a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: New|Active|Blocked|Testing|Resolved|Closed`), or an abstract stage gate. A concrete artifact may require user agreement before its consumer runs; that is contract readiness, not lifecycle state. The gate bans the fields in every folder.
- A link that leaves the skill folder: `](../`, `](/`, any absolute path.
- An MCP server with a `tools` allowlist — Claude Code silently drops the server; the JSON gate fails it.
- A `.mcp.json` at the repo root — Claude Code also loads it as this repo's project MCP servers, so every dev session here would start the plugin's servers; they live in `plugin.json`'s `mcpServers`, and the JSON gate fails a root `.mcp.json`.
- Slash-command files — out of scope until a proven defect asks for them. One hook ships: `SessionStart` injects the delegation rules and the entry → addition table in every session (ADR 0003). A new hook needs its own proven defect.

Say so when a change reintroduces one of these.

The PowerShell substrate ships only under `skills/al-build/`, and `/al-build` invokes its procedures; `hooks/` is the second `.ps1` home, for the hook's printer. Outside `skills/al-build/`, a `.ps1` filename or a `scripts/` path in a skill body is a defect — that skill calls `/al-build` instead. The one listed exemption: `al-clone-bcquality` runs the BCQuality knowledge-index generator inside the checkout it clones.

## Dev-time files

These govern work on this repo and never ship. No `SKILL.md` may mention them.

- `CLAUDE.md` — this file.
- `.claude/rules/skills.md` — the skill rules; loads when a file under `skills/` is read.
- `.claude/rules/powershell.md` — the PowerShell rules; loads when a `.ps1` is read.
- `docs/` — human-facing notes; no agent loads them, except `docs/agents/`, the tracker, triage-label, and domain-doc configuration the development skills read through the `## Agent skills` block below.
- `scripts/`, `tests/` — the CI gates, plus `scripts/Update-EvalBasePlugins.ps1`, which fetches the Base plugin copies the evals load.
- `evals/` — the trigger eval suite, run by hand, never by CI.
- `.base-plugins/`, `evals/results/` — gitignored Base plugin copies and eval results; the JSON and PowerShell gates skip both.

## Reply shape

- Ask through the active skill's form — `AskUserQuestion` or a grilling round — with the recommendation marked.
- When a question turns on structure — a hierarchy, relations, a sequence or flow, or the reach of options — or the user says they don't follow, show one diagram drawn from real data (actual work-item ids, file names, skill names), then ask a simpler question under it: `show_widget`, then an Artifact, then an indented tree or a table in the reply. Pure preference and yes/no questions get none.

## Working here

`main` is PR-only. A change lands on a fresh feature branch and merges through a PR. The version lives only in `.claude-plugin/plugin.json`; it stays `0.9.0` through the migration in #52, and no migration PR writes it.

The session that opens a PR merges it; it never enables auto-merge. Every PR targets `main`, so its merge closes the issues the PR body names with `Fixes #<n>`. Right after `gh pr create`:

1. Arm this watcher with the `Monitor` tool, `timeout_ms` 1800000. It prints `PR #<pr> changed` whenever anything on the PR changes, and exits once the PR is merged or closed:

```bash
set -o pipefail; pr=<pr>; repo=FBakkensen/al-agentic-dev; last=""
while :; do
  now=$(gh pr view $pr --repo $repo --json state,mergeStateStatus,headRefOid,statusCheckRollup,reviews,comments,reviewDecision,updatedAt 2>/dev/null | md5sum) || { sleep 30; continue; }
  [ "$now" != "$last" ] && echo "PR #$pr changed" && last=$now
  gh pr view $pr --repo $repo --json state --jq .state 2>/dev/null | grep -qE 'MERGED|CLOSED' && exit 0
  sleep 30
done
```

2. On each line, look at the PR and do whatever it needs: merge it once it can merge, fix what fails, answer and resolve review threads, and merge `origin/main` on a conflict.
3. When the monitor expires with the PR still open, arm it again.

Before pushing, run `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, `scripts/Test-BasePluginDrift.ps1`, then `scripts/Invoke-Tests.ps1 -Mode Full`. CI runs the same five on pushes to `main` and on every pull request. The gates validate `skills/`, `hooks/`, `output-styles/`, and the plugin manifests; links in `README.md` and `docs/` are deliberately unchecked — not a review finding.

Use `scripts/Invoke-Tests.ps1 -Mode Fast` for the local loop; it excludes process-bound and live-fixture tests without changing the full gate.

Delegate test runs only to one `haiku` `Agent`. The agent runs `scripts/Invoke-Tests.ps1` once and uses its compact result; it never reruns Pester to recover output.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.

## Trigger evals

Evals check triggers only: does the skill fire, and does an addition fire with its entry skill. No eval grades a skill's behavior or output.

A new skill, or a change to a skill's description or trigger, ships with its eval case, run with `claude plugin eval --case <case>` before the PR, 3 runs, passing at 2 of 3. For an AL addition, the case types its entry skill (for example `/mattpocock-skills:to-spec`), and a `tool_used: Skill` grader asserts that the addition fires.

The full suite runs only when many descriptions change in one PR.

Every run is billed. No CI step runs the suite.

1. Fetch the Base plugin copies into `.base-plugins/`: `pwsh scripts/Update-EvalBasePlugins.ps1`. Rerun it to refresh them. A case lists this plugin and every copy in `plugins:`, the AL language server included: without it, al-agentic-dev's `dependencies` go unsatisfied and the plugin silently doesn't load.
2. Run one case: `claude plugin eval . --case <case> --ablation none --threshold 0.66`. Drop `--case` for the full suite. `--threshold 0.66` makes the exit code match the 2-of-3 bar; the default of `1.0` fails any case below 3 of 3. Use `--runs 1` while iterating, and the default 3 runs for the check before the PR.
3. A case is `evals/<case>/prompt.md` (the four-entry `plugins:` list, `allowed_tools: [Read, Glob, Grep, Skill]`, no `model`) plus `graders/skill-fired.md`, a `tool_used` grader on `Skill` whose `input_match` names the skill. A negative case's `graders/no-al-skill.md` asserts `min: 0` and `max: 0` on any `al-agentic-dev:` skill. `tests/EvalSuite.Tests.ps1` fails when a skill has no case.

## Agent skills

### Issue tracker

GitHub Issues for `fbakkensen/al-agentic-dev` on `github.com`, via `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default roles, each label string equal to its role name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
