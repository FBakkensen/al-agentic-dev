# Working on this repo

This repo is a set of harness-neutral Agent Skills for AL/Business Central development. Users install them with `npx skills add <owner>/<repo> --skill '*'` and run them in Claude Code, GitHub Copilot CLI, VS Code Copilot, or Codex. Nothing shipped here may assume one of those harnesses.

## The shipped surface

Everything that ships lives under `skills/`:

```
skills/<name>/SKILL.md          frontmatter: name, description, disable-model-invocation
skills/<name>/<SIBLING>.md      optional format files, inside the same folder only
skills/al-build/scripts/*.ps1   the build substrate
skills/al-build/config/         al-build.json
```

The folder name equals the frontmatter `name`. The set installs and ships as one unit; self-containment is about portability across harnesses, not standalone installs. A skill reaches outside its folder only by naming another skill — `/al-build` — never by path.

`disable-model-invocation: true` is the default on every skill: the pipeline is user-driven, so a skill loads only when the user types its slash command. Exactly six skills omit the flag, each because something must load it without a slash command: `al-build` (invoked mid-run by other skills), `al-grilling` (invoked mid-interview by `al-grill-adr`, `al-event-model`, `al-design`, `al-refine`), `al-routing` (the task-state engine — invoked at close by every skill that moves task state, and loaded by `al-next` and `al-scope` for its schema), `al-visualize` (the decision surface — invoked mid-run by `al-design`, `al-event-model`, `al-refine`, `al-scope`, `al-code-review`, `al-quiz`), `al-next` (the plain-language navigator), `al-agentic-dev-overview` (discovery by someone who doesn't know the commands). A new exception names who invokes it.

## What never ships

- Custom agents, hooks, plugin manifests, marketplace files.
- Harness-specific frontmatter: `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`.
- A link that leaves the skill folder: `](../`, `](/`, any absolute path.
- Harness-specific names: model names, MCP server ids, `COPILOT_*` variables, custom agent names, `agent_type:`.

Say so when a change reintroduces one of these.

The PowerShell substrate is the one exception that ships, and `al-build` is its sole invoker. Outside `skills/al-build/`, a `.ps1` filename or a `scripts/` path in a skill body is a defect — that skill calls `/al-build` instead.

## Dev-time files

These govern work on this repo and never ship. No `SKILL.md` may mention them.

- `.github/copilot-instructions.md` — this file.
- `.github/instructions/skills.instructions.md` — read before editing `skills/**/*.md`.
- `.github/instructions/powershell.instructions.md` — read before editing any `.ps1`.
- `CLAUDE.md`, `AGENTS.md`, `REVIEW.md` — routes into the three files above for each harness.
- `docs/` — human-facing notes; no agent loads them.
- `scripts/`, `tests/` — the CI gates.

`REVIEW.md` holds a generated verbatim copy of `skills.instructions.md`. Edit the instruction file, then run `scripts/Update-Review.ps1` to regenerate `REVIEW.md`; CI fails on drift (`scripts/Update-Review.ps1 -Check`).

## Working here

`main` is PR-only. Branch off a fresh `origin/main` and open a PR with `gh`.

Before pushing, run `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, `scripts/Update-Review.ps1 -Check`, then `Invoke-Pester tests`. CI runs the same five. The gates validate `skills/` only; links in `README.md` and `docs/` are deliberately unchecked — not a review finding.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.
