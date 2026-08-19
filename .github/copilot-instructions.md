# Working on this repo

This repo ships the GitHub Copilot plugin `al-agentic-dev`: Agent Skills for AL/Business Central development plus packaged custom agents, bundled MCP servers, and the marketplace manifest. Everything here is Copilot-first — skills name Copilot tools, bundled MCP servers, and packaged agents explicitly.

The branch `flemmingbk-skills-v2` rebuilds the set package by package: the old 26-skill pipeline is stripped, each new version ports proven skills from their donors as real work needs them, and `main` keeps shipping the old set untouched until the final merge. Git history is the donor archive — a retired skill returns from a commit, never from a copy.

## The shipped surface

```
plugin.json                     the plugin manifest: name, version, skills/, agents/, hooks, .mcp.json
.mcp.json                       bundled MCP servers, each with a tools allowlist
hooks.json                      the shipped hook: preToolUse denies the ask_user tool
.github/plugin/marketplace.json the marketplace manifest the plugin installs through
skills/<name>/SKILL.md          frontmatter: name, description, disable-model-invocation
skills/<name>/<SIBLING>.md      optional format files, inside the same folder only
skills/al-build/scripts/*.ps1   the build substrate
skills/al-build/config/         al-build.json
agents/<name>.agent.md          packaged custom agents: name, description, tools, model
```

Ten skills ship today. Four are the AL survivors: `al-build` — the compile-publish-test gate, provisioning, breaking-change validation, Page Scripting replay, and the container lifecycle, and the contract model everything else copies — plus the two lookup-source clones `al-clone-bcapps` and `al-clone-bcquality`, and `al-visualize`, the steering surface (rebuilt on the app-bundled impeccable skill in a later package). Four are verbatim ports with donor-owned bodies: `grilling` and `grill-me` (the stress-test interview and its entry), `wait-what` (the re-pitch), and `unslop` (the AI-tell cut) — see the port rule in `skills.instructions.md`. Two are authored for the new set: `miner` (mines session history into proposed standing lessons, building on /chronicle) and `lookup` (one platform question in, a sourced answer out — Learn MCP, bc-code-intelligence MCP, the BCApps clone, the BCQuality index — accumulating into the consumer repo's precedent map). Three read-only reviewer agents ride under `agents/`; their invokers return in later packages.

The folder name equals the frontmatter `name`; an agent's `name` equals its filename stem, and its `model` pin and `tools` scope are mandatory. A skill reaches outside its folder only by naming another skill — `/al-build` — never by path.

`disable-model-invocation: true` is the default on every skill. Five omit it: `al-build` (changed AL code or another skill's script need invokes it mid-run), `al-visualize` (invoked when a settled artifact or landed change goes to the user drawn), `grilling` (the interview engine `grill-me` starts and grill trigger phrases reach), `unslop` (the donor says it must always apply), and `lookup` (verify-or-declare is a mid-write reflex; the writing and review skills invoke it in-flight). A new exception names who invokes it.

## What never ships

- The word "harness" and harness-conditional phrasing — the gate fails it; name the Copilot tool, MCP server, or packaged agent instead. Verbatim ports are the one exemption: unslop's own rules name the word as jargon to cut.
- A capability paraphrase where a concrete Copilot name exists.
- A model name in a skill body or skill frontmatter — model pins live in `agents/*.agent.md` only.
- Skill frontmatter beyond `name`, `description`, `disable-model-invocation` — no `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable` on a skill.
- Task-state ceremony — a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: New|Active|Blocked|Testing|Resolved|Closed`), or a stage-gate prerequisite. Retired concepts; the gate bans the fields in every folder.
- A link that leaves the skill folder: `](../`, `](/`, any absolute path.
- Slash-command files — out of scope until a proven defect asks for them. One hook ships: `hooks.json` denies the `ask_user` tool with a redirect to plain-text questions (its proven defect: a child session hung silently on an `ask_user` call); a new hook needs its own proven defect.

Say so when a change reintroduces one of these.

The PowerShell substrate is the one exception that ships, and `al-build` is its sole invoker. Outside `skills/al-build/`, a `.ps1` filename or a `scripts/` path in a skill body is a defect — that skill calls `/al-build` instead. The one listed exemption: `al-clone-bcquality` runs the BCQuality knowledge-index generator inside the checkout it clones.

## Dev-time files

These govern work on this repo and never ship. No `SKILL.md` may mention them.

- `.github/copilot-instructions.md` — this file.
- `.github/instructions/skills.instructions.md` — read before editing `skills/**/*.md` or `agents/*.agent.md`.
- `.github/instructions/powershell.instructions.md` — read before editing any `.ps1`.
- `CLAUDE.md`, `AGENTS.md`, `REVIEW.md` — routes into the three files above for each entry point.
- `docs/` — human-facing notes; no agent loads them.
- `scripts/`, `tests/` — the CI gates.

`REVIEW.md` holds a generated verbatim copy of `skills.instructions.md`. Edit the instruction file, then run `scripts/Update-Review.ps1` to regenerate `REVIEW.md`; CI fails on drift (`scripts/Update-Review.ps1 -Check`).

## Reply shape

Dev-time chat in this repo follows the same style the shipped skills ask for:

- Show the actual thing — the command and its output, the diff, the table row — before explaining it; one sentence of prose per thing shown.
- Glyphs ride fixed slots only — findings, verdicts, and moves (⛔ ⚠️ ✅ ▶ 🔧 📍 ⚡) and the run-narration ledes; an emoji in running prose is decoration.
- Run narration is two lines — `▸` the finding, `➜` the next move — with `➜` alone before the first tool call, and `✅` or `⛔` on the closing outcome. Print the line that has news and drop the other.
- Outcome first when finishing, detail after.
- Ask one question per message, with lettered options and the recommendation marked, as plain text in the reply — never through a question or elicitation tool, and never the ask_user tool.

## Working here

`main` is PR-only. This set builds on the long-lived `flemmingbk-skills-v2` branch — packages land as commits there, the plugin version incrementing per package, merged to `main` when the set is ready.

Before pushing, run `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, `scripts/Update-Review.ps1 -Check`, then `Invoke-Pester tests`. CI runs the same five on pushes to `main`, `feature/copilot-first-migration`, and `flemmingbk-skills-v2`, and on every pull request. The gates validate `skills/`, `agents/`, and the plugin manifests; links in `README.md` and `docs/` are deliberately unchecked — not a review finding.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.
