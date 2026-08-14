# Working on this repo

This repo ships the GitHub Copilot plugin `al-agentic-dev`: Agent Skills for AL/Business Central development plus packaged custom agents, bundled MCP servers, and the marketplace manifest. Everything here is Copilot-first — skills name Copilot tools, bundled MCP servers, and packaged agents explicitly.

## The shipped surface

```
plugin.json                     the plugin manifest: name, version, skills/, agents/, .mcp.json
.mcp.json                       bundled MCP servers, each with a tools allowlist
.github/plugin/marketplace.json the marketplace manifest the plugin installs through
skills/<name>/SKILL.md          frontmatter: name, description, disable-model-invocation
skills/<name>/<SIBLING>.md      optional format files, inside the same folder only
skills/al-build/scripts/*.ps1   the build substrate
skills/al-build/config/         al-build.json
agents/<name>.agent.md          packaged custom agents: name, description, tools, model
```

The folder name equals the frontmatter `name`; an agent's `name` equals its filename stem, and its `model` pin and `tools` scope are mandatory. A skill reaches outside its folder only by naming another skill — `/al-build` — never by path. Skill names are prefix-free: `al-` marks the AL pipeline family, and a generic name like `babysit-pr` is as valid as `al-build`.

`disable-model-invocation: true` is the default on every skill: the pipeline is user-driven, so a skill loads only when the user types its slash command. Exactly nine skills omit the flag, each because something must load it without a slash command: `al-build` (invoked mid-run by other skills), `al-grilling` (invoked mid-interview by `al-grill-adr`, `al-event-model`, `al-design`, `al-refine`), `al-knowledge-pass` (the BCQuality pass over a diff — invoked mid-run by `al-code-review` and `al-refactor`), `al-implement` (feedback implementation invoked mid-run by `al-code-review` and `al-refactor`), `al-routing` (the task-state engine — invoked at close by every skill that moves task state, and loaded by `al-next` and `al-scope` for its schema), `al-visualize` (the decision surface — invoked mid-run by `al-design`, `al-event-model`, `al-refine`, `al-scope`, `al-code-review`, `al-quiz`, and at close by every pipeline skill that presents its settled artifact or landed change drawn), `al-spec-review` (the blind spec gate — invoked at close by `al-design`, `al-event-model`, `al-scope`, and `al-refine` to read a just-written spec artifact against its sources), `al-next` (the plain-language navigator), `al-agentic-dev-overview` (discovery by someone who doesn't know the commands). A new exception names who invokes it.

## What never ships

- The word "harness" and harness-conditional phrasing — the gate fails it; name the Copilot tool, MCP server, or packaged agent instead.
- A capability paraphrase where a concrete Copilot name exists.
- A model name in a skill body or skill frontmatter — model pins live in `agents/*.agent.md` only.
- Skill frontmatter beyond `name`, `description`, `disable-model-invocation` — no `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable` on a skill.
- A task-state transition outside `al-routing` — a legacy lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`) or an Azure DevOps work-item transition (`State: New|Active|Blocked|Testing|Resolved|Closed`).
- A link that leaves the skill folder: `](../`, `](/`, any absolute path.
- Hooks and slash-command files — out of scope until a proven defect asks for them.

Say so when a change reintroduces one of these.

The PowerShell substrate is the one exception that ships, and `al-build` is its sole invoker. Outside `skills/al-build/`, a `.ps1` filename or a `scripts/` path in a skill body is a defect — that skill calls `/al-build` instead.

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

`main` is PR-only. Branch off a fresh `origin/main` and open a PR with `gh`.

Before pushing, run `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, `scripts/Update-Review.ps1 -Check`, then `Invoke-Pester tests`. CI runs the same five on pushes and pull requests to `main` and `feature/copilot-first-migration`. The gates validate `skills/`, `agents/`, and the plugin manifests; links in `README.md` and `docs/` are deliberately unchecked — not a review finding.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.
