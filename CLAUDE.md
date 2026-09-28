# Working on this repo

This repo ships the Claude Code plugin `al-agentic-dev`: Agent Skills for AL/Business Central development plus a `SessionStart` hook, bundled MCP servers, and the marketplace that installs it with its Base plugins. The plugin is Claude Code–exclusive (ADR 0001) — skills name Claude Code tools, bundled MCP servers, and Base plugin skills explicitly.

Git history is the donor archive — a retired skill returns from a commit, never from a copy.

## The shipped surface

```
.claude-plugin/plugin.json      the plugin manifest: name, description, version (set only here), the ado_org userConfig, the Base plugin dependencies
.claude-plugin/marketplace.json the marketplace: this plugin at ./ plus the re-listed Base plugins bcquality and al-language-server-go-windows
.mcp.json                       bundled MCP servers — microsoft-learn and ado — none with a tools allowlist
hooks/hooks.json                the SessionStart hook: runs hooks/Write-SessionStart.ps1
hooks/session-start.md          the delegation rules the hook injects in every session
skills/<name>/SKILL.md          frontmatter: name, description
skills/<name>/<SIBLING>.md      optional format files, inside the same folder only
skills/al-event-model/bpmn-renderer/ package-local BPMN renderer dependencies
skills/al-build/scripts/*.ps1   the build substrate
skills/al-build/config/         al-build.json
```
Twenty-six skills ship today. Three are the AL survivors: `al-build` — the compile-publish-test gate, provisioning, breaking-change validation, and the container lifecycle, and the contract model everything else copies — plus the two lookup-source clones `al-clone-bcapps` and `al-clone-bcquality`. Two are pinned forks whose bodies stay donor text except the al- namespace: `al-grill-me` and `al-unslop` — see the fork rule in `.claude/rules/skills.md`. The rest are authored for this set: `al-grilling`, `al-wait-what`, `al-grill-adr`, `al-miner`, `al-lookup`, `al-azure-devops-attachments`, `al-commit`, `al-pull-request`, `al-setup-models`, the design chain `al-event-model` / `al-arc42` / `al-design` / `al-scope`, `al-test-design`, `al-implement` / `al-refactor` / `al-review`, `al-next`, `al-pr-shepherd`, `al-orchestrate`, and `al-walkthrough`. Issue #52 retires `al-grill-me`, `al-unslop`, `al-grilling`, `al-wait-what`, `al-setup-models`, `al-orchestrate`, and `al-miner` in their own PRs.

The folder name equals the frontmatter `name`. A skill reaches outside its folder only by naming another skill — `/al-build` — never by path.

Every skill is model-invocable. Skill frontmatter omits `disable-model-invocation`, and every description carries the trigger branches that let the model reach it.

## What never ships

- The word "harness" and harness-conditional phrasing — the gate fails it; name the Claude Code tool, MCP server, or agent instead. The pinned `al-unslop` fork is the one exemption: its own rules name the word as jargon to cut.
- A capability paraphrase where a concrete Claude Code name exists.
- Skill frontmatter beyond `name` and `description` — no `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`, or `disable-model-invocation` on a skill.
- Task-state ceremony — a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: New|Active|Blocked|Testing|Resolved|Closed`), or an abstract stage gate. A concrete artifact may require user agreement before its consumer runs; that is contract readiness, not lifecycle state. The gate bans the fields in every folder.
- A link that leaves the skill folder: `](../`, `](/`, any absolute path.
- An MCP server with a `tools` allowlist — Claude Code silently drops the server; the JSON gate fails it.
- Slash-command files — out of scope until a proven defect asks for them. One hook ships: `SessionStart` injects the delegation rules in every session (ADR 0003). A new hook needs its own proven defect.

Say so when a change reintroduces one of these.

The PowerShell substrate ships only under `skills/al-build/`, and `/al-build` invokes its procedures; `hooks/` is the second `.ps1` home, for the hook's printer. Outside `skills/al-build/`, a `.ps1` filename or a `scripts/` path in a skill body is a defect — that skill calls `/al-build` instead. The one listed exemption: `al-clone-bcquality` runs the BCQuality knowledge-index generator inside the checkout it clones.

## Dev-time files

These govern work on this repo and never ship. No `SKILL.md` may mention them.

- `CLAUDE.md` — this file.
- `.claude/rules/skills.md` — the skill rules; loads when a file under `skills/` is read.
- `.claude/rules/powershell.md` — the PowerShell rules; loads when a `.ps1` is read.
- `docs/` — human-facing notes; no agent loads them, except `docs/agents/`, the tracker, triage-label, and domain-doc configuration the development skills read through the `## Agent skills` block below.
- `scripts/`, `tests/` — the CI gates.

## Reply shape

- Ask through the active skill's form — `AskUserQuestion` or a grilling round — with the recommendation marked.
- When a question turns on structure — a hierarchy, relations, a sequence or flow, or the reach of options — or the user says they don't follow, show one diagram drawn from real data (actual work-item ids, file names, skill names), then ask a simpler question under it: `show_widget`, then an Artifact, then an indented tree or a table in the reply. Pure preference and yes/no questions get none.

## Working here

`main` is PR-only. A change lands on a fresh feature branch and merges through a PR. The version lives only in `.claude-plugin/plugin.json`; it stays `0.9.0` through the migration in #52, and no migration PR writes it.

Before pushing, run `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, then `scripts/Invoke-Tests.ps1 -Mode Full`. CI runs the same four on pushes to `main` and on every pull request. The gates validate `skills/`, `hooks/`, and the plugin manifests; links in `README.md` and `docs/` are deliberately unchecked — not a review finding.

Use `scripts/Invoke-Tests.ps1 -Mode Fast` for the local loop; it excludes process-bound and live-fixture tests without changing the full gate.

Delegate test runs only to one `haiku` `Agent`. The agent runs `scripts/Invoke-Tests.ps1` once and uses its compact result; it never reruns Pester to recover output.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.

## Agent skills

### Issue tracker

GitHub Issues for `fbakkensen/al-agentic-dev` on `github.com`, via `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default roles, each label string equal to its role name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
