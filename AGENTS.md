Marketplace of AI-assisted AL/Business Central development plugins for GitHub Copilot CLI.

Plugins live under `plugins/`:

- `al-agentic-dev/` — feature-level agentic flow (steer, grill-adr, event-model, design, scope, refine, research, implement, page-script, user-verification, refactor, mutate, code-review, quiz) plus the build/test gate (build, provision, validate-breaking-changes) and telemetry probes (debug-logging)
- `al-language-server/` — AL language server for the Copilot CLI LSP tool (ships `lsp.json`)
- `bc-standard-reference/` — BaseApp / System Application lookup via a dedicated custom agent
- `grill-me/` — interview and stress-test plans
- `release-notes/` — PR-driven release note generation

Top-level layout:

```
.github/plugin/marketplace.json   # Copilot CLI marketplace manifest — every plugin listed here
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
tests/                            # Pester tests for plugin scripts (e.g. al-build)
.github/workflows/                # ci.yml
```

Every plugin has a root `plugin.json` (Copilot CLI manifest — name matches the folder name) and usually a dev-time `AGENTS.md`. All other components are optional per the Copilot CLI plugin spec:

```
plugins/<plugin-name>/
├── plugin.json                   # Copilot CLI manifest (name, version, description, component paths) — required
├── AGENTS.md                     # Dev-time plugin context — voice and conventions live here
├── skills/                       # Skills
│   └── <skill-name>/
│       ├── SKILL.md              # User-facing skill body (frontmatter: name, description, allowed-tools)
│       ├── scripts/              # PowerShell 7.2+ (optional)
│       └── references/           # Supporting docs (optional)
├── agents/                       # Custom agents (<name>.agent.md — the extension is mandatory)
├── hooks/hooks.json              # Hook config, Copilot native format ("version": 1, camelCase events)
├── references/                   # Plugin-level docs shared across skills/agents
└── lsp.json                      # Language-server config ({"lspServers": {...}})
```

Actual shapes: `grill-me` and `release-notes` are skills-only; `al-agentic-dev` adds `hooks/` and plugin-level `references/`; `bc-standard-reference` is `agents/` + `references/` with no skills; `al-language-server` is `lsp.json` only (no skills, no AGENTS.md).

Single-skill plugins put their skill at `skills/<plugin-name>/`; multi-skill plugins (like `al-agentic-dev`) put each skill at its own `skills/<skill-name>/`.

## Copilot CLI runtime facts (verified against this harness)

- `${PLUGIN_ROOT}` and `$env:COPILOT_PLUGIN_ROOT` expand in plugin hook commands; a hook's cwd is the installed plugin root; `sessionStart` hook stdout of shape `{"additionalContext": "..."}` is injected into the session. There is no compaction trigger for hooks — `sessionStart` fires on new/resumed sessions only.
- There is no `${CLAUDE_SKILL_DIR}` equivalent; SKILL.md bodies are injected verbatim, unexpanded. Skills reference their own files relative to "this skill's base directory" (announced at skill activation).
- Nested `AGENTS.md` files lazy-load when files in their directory are touched, same as the root one loading at session start.
- Skill frontmatter honors `name`, `description`, `license`, `allowed-tools`. Agent files must end in `.agent.md`; their `tools:` list uses Copilot aliases (`read`, `edit`, `search`, `execute`, `web`, `agent`, `todo`) or `server/tool` for MCP tools.
- Direct plugin installs (`copilot plugin install ./path`) are deprecated — test via a local marketplace: `copilot plugin marketplace add <repo-root>` then `copilot plugin install <name>@<marketplace>`.

## Shipped artefacts vs dev-time files

This repo builds a **shipped product**. Two kinds of files live here, and the line between them is load-bearing:

- **Shipped** — installed into end-user sessions via the marketplace: `.github/plugin/marketplace.json`, every plugin's `plugin.json`, and all plugin components — `SKILL.md`, `agents/*.agent.md`, `hooks/`, `references/*.md`, `scripts/`, `lsp.json`. This *is* the product. Its audience is an AL/BC developer working in *their own* repo, who never sees this marketplace. Write it project-agnostic, in the user-facing voice, assuming none of the dev-time context below.
- **Not shipped — dev-time only** — every `AGENTS.md` (root and per-plugin) and any `README.md`. These load only when you're working *in this marketplace repo* (this session). Installed users never see them. They carry authoring conventions, editing rules, and coupling contracts for *maintaining* the shipped files — never runtime behaviour.

The trap runs both ways. Editing a `SKILL.md`, an agent, or a reference is editing the product an end user runs — not a note to yourself. Any rule the assistant needs at runtime in an end-user's session must live in a shipped file (`SKILL.md`, or a `references/*.md` the SKILL explicitly reads), never in an `AGENTS.md`. Conversely, authoring and editing guidance for maintainers belongs in `AGENTS.md`, never leaked into a shipped file.

## Git workflow on this repo

Remote: `9altitudes.ghe.com/gtm-general/gtm-bc-copilot-cli-playbook` (private, org-internal). Use `gh` with `GH_HOST=9altitudes.ghe.com` (or `--hostname`) for repo operations.

**`main` is PR-only.** Never commit on `main`. For every change: fetch and branch off a fresh `origin/main` (`git checkout -b <topic>`), commit there, push the branch, open a PR with `gh pr create`, merge via the PR once CI is green (squash preferred), then delete the branch.

Enforcement: a `pre-commit` hook in `.githooks/` blocks local commits on `main`, and a GitHub ruleset on the remote requires a PR with passing CI. New clones must run `git config core.hooksPath .githooks` once to activate the hook.

Run before pushing:

```powershell
pwsh scripts/Validate-Json.ps1            # All JSON files parse
pwsh scripts/Validate-PowerShell.ps1      # All .ps1 files have valid syntax
pwsh scripts/Validate-PluginStructure.ps1 # Marketplace and per-plugin manifests exist and match
```

CI (`.github/workflows/ci.yml`) runs all three plus the Pester tests in `tests/` on push/PR to `main`.

Adding or renaming a plugin:

1. Create `plugins/<name>/` with the shape above.
2. Add the entry to `.github/plugin/marketplace.json`.
3. Run all three validation scripts locally.

Scripts are PowerShell 7.2+ (`#Requires -Version 7.2`), self-contained, runnable from repo root.

`.output/` and `**/secret.json` are gitignored — never commit build artifacts or secrets.

## Installing (end users)

```
copilot plugin marketplace add https://9altitudes.ghe.com/gtm-general/gtm-bc-copilot-cli-playbook.git
copilot plugin install <plugin-name>@gtm-bc-copilot-cli-playbook
```

Requires access to the 9altitudes GHE tenant.

