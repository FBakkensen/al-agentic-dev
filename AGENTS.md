Marketplace of AI-assisted AL/Business Central development plugins for GitHub Copilot CLI.

Plugins live under `plugins/`:

- `al-agentic-dev/` — 20 skills: the plugin tour (agentic-dev-overview), feature-level agentic flow (steer, grill-adr, event-model, design, scope, refine, research, implement, page-script, user-verification, refactor, mutate, code-review, quiz), the build/test gate (build, provision, validate-breaking-changes, sync-main), and telemetry probes (debug-logging); plus an 18-agent custom-agent fleet under `agents/` (incl. `bc-standard-reference`, the BaseApp / System Application lookup against `microsoft/BCApps`) and the `al-kanban` canvas extension (live task board)
- `al-language-server/` — AL language server for the Copilot CLI LSP tool (ships `lsp.json`)
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
├── extensions/<name>/            # Canvas extensions (extension.mjs, auto-discovered by the desktop app)
└── lsp.json                      # Language-server config ({"lspServers": {...}})
```

Actual shapes: `grill-me` and `release-notes` are skills-only; `al-agentic-dev` adds `agents/`, `hooks/`, plugin-level `references/`, and `extensions/al-kanban/`; `al-language-server` is `lsp.json` only (no skills, no AGENTS.md).

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
- **Not shipped — dev-time only** — every `AGENTS.md` (root and per-plugin), any `README.md`, and maintainer procedure docs with no shipped consumer (e.g. `plugins/al-agentic-dev/extensions/al-kanban/SMOKE-TEST.md`; `references/examples/README.md` is installed with the plugin but no skill reads it — it stays a maintainer index). These carry authoring conventions, editing rules, and coupling contracts for *maintaining* the shipped files — never runtime behaviour. Installed users never rely on them.

The trap runs both ways. Editing a `SKILL.md`, an agent, or a reference is editing the product an end user runs — not a note to yourself. Any rule the assistant needs at runtime in an end-user's session must live in a shipped file (`SKILL.md`, or a `references/*.md` the SKILL explicitly reads), never in an `AGENTS.md`. Conversely, authoring and editing guidance for maintainers belongs in `AGENTS.md`, never leaked into a shipped file.

## Canonical style rubric (rewrite program)

A repo-wide pass restyles every shipped skill, agent, and reference against one rubric distilled from PR #17's five model-control agents (`plugins/al-agentic-dev/agents/al-design-option.agent.md`, `al-gate-runner.agent.md`, `al-mutant-cycle.agent.md`, `al-researcher.agent.md`, `al-review-judge.agent.md`). The rubric itself lives in `plugins/al-agentic-dev/references/voice-contract.md` (shipped, runtime-facing, under "Custom agent return contract" and the top-of-file Style declaration). This section is the maintainer method for applying it without breaking what already works.

- **Runtime/dev classification derivation.** Before adding a new rule anywhere in this program, derive which file it belongs in with one test: would an agent need this rule *while running in an end-user's session* (a chat shape, a Return-payload contract, a naming discipline visible in output)? → it belongs in a shipped file (`SKILL.md`, `agents/*.agent.md`, a `references/*.md` the SKILL explicitly reads). Is it instead about *how a maintainer authors or freezes this repo's shipped files* (a byte-freeze list, a protection tier, a review method)? → it belongs in an `AGENTS.md`. A candidate rule that reads correctly in both places has not been derived far enough — split it.
- **Artifact-specific target shapes.** The rubric does not impose one universal shape. `agents/*.agent.md` targets the Return contract (bounded lede/purpose, explicit ownership, evidence-vs-judgment separation, class-scoped Style, artifact-native labeled fields). `SKILL.md` targets the chat shape skeletons plus the top-of-file Style line. `references/*.md` (excluding templates and examples) targets prose discipline only — no verdict box, no Return contract, because a reference is read, not returned. `references/*.template.md` and `references/examples/**` target schema fidelity, below, not prose shape.
- **A/B/C protection tiers.** Every file in the program's scope carries one tier before it is touched. **Tier A — byte-frozen:** never edited during the program; see the canonical-five byte-freeze below. **Tier B — scenario-gated:** editable only under an enumerated safe scenario (below), because the file carries a coupling a blind restyle would break (a fixed path, a producer/consumer schema, a cross-file lockstep note). **Tier C — free to restyle:** prose-only discipline docs and skill bodies with no named coupling; apply the rubric directly. A file defaults to Tier B until its owning pass confirms Tier C by finding no coupling note pointing at it.
- **Per-file constraint-ledger method.** Before restyling a Tier-B or Tier-C file, list its current runtime contracts in one short ledger: fixed paths it reads or writes, other files that name it in lockstep (grep the corpus for its filename), and any producer/consumer schema it emits or consumes. Restyle against that ledger, then re-grep the same filename after the edit — an unchanged hit count means no coupling silently broke.
- **Tier-B scenario enumeration.** A Tier-B file's ledger yields a short list of scenarios in which prose can change safely (e.g. "reword the paragraph around the fixed path, never the path itself") versus scenarios that would break its contract (e.g. "renaming the JSONL field the consumer keys on"). Enumerate both before editing; proceed only inside a listed safe scenario, and treat an unlisted case as blocked, not as license to improvise.
- **Canonical-owner contradiction scan.** Before restyling any file, grep whether it already contradicts its own canonical description elsewhere (an agent's `model:` frontmatter versus its role in `references/delegation.md` or a plugin `AGENTS.md`'s runtime-surface paragraph, a skill count in `overview.md` versus the actual `skills/` folder). Surface a found contradiction as a reported finding — name both sides and their locations — never silently resolve it inside a style-only pass; a content fix is its own change with its own review.
- **Cross-model adversarial parity review.** Because different clusters in this program are rewritten by different sub-agents, potentially on different models, run a cross-family review before merging each cluster: a reviewer on a different model family than the author re-checks the cluster's diff against the rubric — the same discipline this repo's runtime rubber-duck consult applies mid-session (`plugins/al-agentic-dev/references/rubber-duck-review.md`), applied here at the maintainer level to catch same-family rationalization the author cannot see in its own output.
- **Description exception queue.** A frontmatter `description:` that routing or discovery depends on (a skill's trigger phrase, an agent's task-tool lookup string) is not shortened on sight if doing so risks breaking that match. Log it to an exception queue instead — file, current text, why a bounded rewrite risks the match — and resolve each entry with a deliberate, individually reviewed edit, never a blanket pass.
- **Templates/examples schema freeze.** `references/*.template.md` and `references/examples/**` carry literal schema — frontmatter field names and order, section headings a skill greps for or copies verbatim — not free prose. A restyle pass touches only surrounding prose framing; it never reorders, renames, or removes a field or heading the schema depends on.
- **Canonical five agents byte-freeze (Tier A).** `plugins/al-agentic-dev/agents/al-design-option.agent.md`, `al-gate-runner.agent.md`, `al-mutant-cycle.agent.md`, `al-researcher.agent.md`, and `al-review-judge.agent.md` are the rubric's source exemplars (PR #17) and stay byte-for-byte unchanged for the duration of the program. A rubric conflict a later cluster surfaces against one of these five is resolved by correcting the rubric's derivation in `voice-contract.md`, never by editing an exemplar to match a drifted restyle.
- **Reproducible link pair-set script.** `scripts/Test-MarkdownLinks.ps1` emits sorted, unique `source-file<TAB>literal-target` unresolved pairs, with `-BaselinePath`/`-WriteBaseline`/`-FailOnUnresolved`. Every pass in this program runs it — `-BaselinePath <baseline> -FailOnUnresolved` against a pre-existing baseline when one is kept, else bare and diffed against the pre-edit output — before marking a file or cluster done, so a restyle-broken relative link fails the same pass that introduced it instead of surfacing later.

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

CI (`.github/workflows/ci.yml`) runs all three plus the Pester tests in `tests/` and the extension `node --test` suites (`plugins/**/*.test.mjs`) on push/PR to `main`. `scripts/Test-MarkdownLinks.ps1` is a local audit tool, not a CI gate.

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

