Marketplace of AI-assisted AL/Business Central development plugins for GitHub Copilot CLI.

Two plugins live under `plugins/`:

- `al-agentic-dev/` — 20 skills plus 18 custom agents under `agents/`. The skills cover the plugin tour (agentic-dev-overview), the feature-level agentic flow (steer, grill-adr, event-model, design, scope, refine, research, implement, page-script, user-verification, refactor, mutate, code-review, quiz), the build/test gate (build, provision, validate-breaking-changes, sync-main), and telemetry probes (debug-logging). The agents include `bc-standard-reference`, the BaseApp / System Application lookup against `microsoft/BCApps`.
- `al-language-server/` — AL language server for the Copilot CLI LSP tool. Ships `lsp.json` and nothing else.

Top-level layout:

```
.github/plugin/marketplace.json   # Copilot CLI marketplace manifest — every plugin listed here
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
tests/                            # Pester tests for plugin scripts (e.g. al-build)
.github/workflows/                # ci.yml
```

Every plugin has a root `plugin.json` whose name matches the folder name. Every other component is optional per the Copilot CLI plugin spec:

```
plugins/<plugin-name>/
├── plugin.json                   # Copilot CLI manifest (name, version, description, component paths) — required
├── AGENTS.md                     # Dev-time plugin context
├── skills/                       # Skills
│   └── <skill-name>/
│       ├── SKILL.md              # Skill body (frontmatter: name, description, allowed-tools)
│       ├── scripts/              # PowerShell 7.2+ (optional)
│       └── references/           # Supporting docs (optional)
├── agents/                       # Custom agents (<name>.agent.md — the extension is mandatory)
├── hooks/hooks.json              # Hook config, Copilot native format ("version": 1, camelCase events)
├── references/                   # Plugin-level docs shared across skills/agents
├── extensions/<name>/            # Canvas extensions (extension.mjs, auto-discovered by the desktop app)
└── lsp.json                      # Language-server config ({"lspServers": {...}})
```

Actual shapes: `al-agentic-dev` carries `skills/` (one folder per skill), `agents/`, `hooks/`, and plugin-level `references/`. `al-language-server` is `lsp.json` only, with no skills and no AGENTS.md.

## Copilot CLI runtime facts (verified against this harness)

- `${PLUGIN_ROOT}` and `$env:COPILOT_PLUGIN_ROOT` expand in plugin hook commands. A hook's cwd is the installed plugin root. When a `sessionStart` hook prints `{"additionalContext": "..."}` to stdout, that context is injected into the session. No hook fires on compaction — `sessionStart` fires on new and resumed sessions only.
- There is no `${CLAUDE_SKILL_DIR}` equivalent. SKILL.md bodies are injected verbatim, unexpanded. A skill references its own files relative to "this skill's base directory", announced at skill activation.
- Nested `AGENTS.md` files lazy-load when files in their directory are touched. The root one loads at session start.
- Skill frontmatter honors `name`, `description`, `license`, and `allowed-tools`. Agent files must end in `.agent.md`. An agent's `tools:` list uses the Copilot aliases (`read`, `edit`, `search`, `execute`, `web`, `agent`, `todo`) or `server/tool` for MCP tools.
- Direct plugin installs (`copilot plugin install ./path`) are deprecated. Test through a local marketplace instead: `copilot plugin marketplace add <repo-root>`, then `copilot plugin install <name>@<marketplace>`.

## Shipped vs dev-time files

This repo builds a shipped product. Two kinds of files live here.

Shipped files install into end-user sessions via the marketplace: `.github/plugin/marketplace.json`, every plugin's `plugin.json`, and all plugin components — `SKILL.md`, `agents/*.agent.md`, `hooks/`, `references/*.md`, `scripts/`, `extensions/`, `lsp.json`. Their audience is an AL/BC developer working in their own repo. That developer never sees this marketplace. Write shipped files project-agnostic, in the user-facing voice, assuming none of the dev-time context in this file.

Dev-time files never ship: every `AGENTS.md` (root and per-plugin) and maintainer docs with no shipped consumer. They carry authoring conventions, editing rules, and coupling contracts for maintaining the shipped files. Installed users never rely on them.

Route every rule by who needs it. A rule the assistant needs at runtime in an end-user session belongs in a shipped file: a `SKILL.md`, or a `references/*.md` the SKILL explicitly reads. Guidance for authoring and editing this repo's files belongs in an `AGENTS.md`. Editing a `SKILL.md`, an agent, or a reference is editing the product an end user runs, not a note to yourself.

## Authoring doctrine

The `writing-great-skills` and `grill-me` skills (https://github.com/mattpocock/skills) and the `i-have-adhd` skill (https://github.com/ayghri/i-have-adhd) are prerequisites. When one is missing, stop and ask the user before installing anything; install only via the skills.sh installer (`npx skills@latest add <owner>/<repo>`), never by hand-copying files. Their vocabulary — no-op test, leading words, duplication, sediment, sprawl, progressive disclosure, positive phrasing — is this repo's working language. Apply their rules. Never restate them.

This repo adds:

- **The canon is pretraining.** Models have read Clean Code, Ousterhout, Brooks, Evans, Fowler, the Pragmatic Programmer, TDD. A file states only this repo's specific decision, threshold, or BC/AL binding. A sentence restating the canon is a no-op.
- **Pretrained words outrank invented ones.** Official BC/AL terms take priority where they exist. Keeping an invented term requires the user's approval. An invented term's citation spread is sediment, never evidence of value; replacement cost is landing work, never a keep argument; a term glossed by its pretrained rival proves the rival suffices.
- **One home per concept.** Where a concept is defined in both an `AGENTS.md` and a shipped file, the shipped file is the home. Everywhere else points at it. A restated rule is a fork, and forks drift.
- **Principles stay at their decision site.** An artifact slot is named for what the reader needs there, never for the doctrine that produces it. A principle promoted into a schema slot forces every producer and consumer of the artifact to invoke it — that spread is the slot's doing, not the principle's worth.
- **No manufactured leads.** Sections are heading plus content. A bold lead line appears only when a genuinely strong leading phrase exists.
- **Calibrate to current models.** State each rule once. Repetition and MUST/NEVER walls degrade compliance. Give outcome, stopping condition, and constraints, not scripted step-by-step process. Cut anything the model does unprompted. An explicit scope or quality bar still earns its place.
- **Rewrite whole files, not sections.** A restyle starts from a blank page: extract what the file must carry, write the file fresh, then diff against the original to confirm no meaning was lost. Section-by-section edits preserve the retired voice.
- **Short declarative sentences, one job each.** A sentence packing several rules behind semicolons and em-dashes splits into several sentences. State the rule itself. Commentary on its own importance ("on purpose", "load-bearing") adds nothing the rule doesn't already say.

## Git workflow on this repo

Remote: `9altitudes.ghe.com/gtm-general/gtm-bc-copilot-cli-playbook` (private, org-internal). Use `gh` with `GH_HOST=9altitudes.ghe.com` (or `--hostname`) for repo operations.

`main` is PR-only. Never commit on `main`. For every change:

1. Fetch and branch off a fresh `origin/main`: `git fetch origin`, then `git checkout -b <topic> origin/main`.
2. Commit on the branch.
3. Push the branch and open a PR with `gh pr create`.
4. Merge via the PR once CI is green (squash preferred).
5. Delete the branch.

Two mechanisms enforce this. A `pre-commit` hook in `.githooks/` blocks local commits on `main`. New clones activate it once with `git config core.hooksPath .githooks`. A GitHub ruleset on the remote requires a PR with passing CI.

Run before pushing:

```powershell
pwsh scripts/Validate-Json.ps1            # All JSON files parse
pwsh scripts/Validate-PowerShell.ps1      # All .ps1 files have valid syntax
pwsh scripts/Validate-PluginStructure.ps1 # Marketplace and per-plugin manifests exist and match
```

CI (`.github/workflows/ci.yml`) runs all three plus the Pester tests in `tests/` on push and PR to `main`. `scripts/Test-MarkdownLinks.ps1` is a local audit tool, not a CI gate.

Adding or renaming a plugin:

1. Create `plugins/<name>/` with the shape above.
2. Add the entry to `.github/plugin/marketplace.json`.
3. Run all three validation scripts locally.

Scripts are PowerShell 7.2+ (`#Requires -Version 7.2`), self-contained, and run from the repo root.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.

## Installing (end users)

```
copilot plugin marketplace add https://9altitudes.ghe.com/gtm-general/gtm-bc-copilot-cli-playbook.git
copilot plugin install <plugin-name>@gtm-bc-copilot-cli-playbook
```

Requires access to the 9altitudes GHE tenant.
