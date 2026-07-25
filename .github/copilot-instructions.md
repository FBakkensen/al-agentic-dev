Marketplace of AI-assisted AL/Business Central development plugins for GitHub Copilot CLI.

Two plugins live under `plugins/`:

- `al-agentic-dev/` — 18 skills plus 18 custom agents under `agents/`. The skills cover the plugin tour (agentic-dev-overview), the feature-level agentic flow (steer, grill-adr, event-model, design, scope, refine, implement, page-script, user-verification, refactor, mutate, code-review, quiz), and the build/test gate (build, provision, validate-breaking-changes, sync-main). The agents include `al-researcher`, the isolated BC research gateway, and `al-debug-logging`, the Application Insights runtime-probe worker.
- `al-language-server/` — AL language server for the Copilot CLI LSP tool. Ships `lsp.json` and nothing else.

Top-level layout:

```
.github/plugin/marketplace.json   # Copilot CLI marketplace manifest — every plugin listed here
.github/copilot-instructions.md   # This file — repo-wide dev-time instructions
.github/instructions/             # Path-scoped dev-time instructions (*.instructions.md)
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
tests/                            # Pester tests for plugin scripts (e.g. al-build)
.github/workflows/                # ci.yml
```

Two scoped instruction files exist. The CLI does not auto-load them, so read the matching one before editing files under its path:

- `.github/instructions/al-agentic-dev.instructions.md` — before editing anything under `plugins/al-agentic-dev/`.
- `.github/instructions/al-build.instructions.md` — before editing anything under `plugins/al-agentic-dev/skills/al-build/`.

Every plugin has a root `plugin.json` whose name matches the folder name. Every other component is optional per the Copilot CLI plugin spec:

```
plugins/<plugin-name>/
├── plugin.json                   # Copilot CLI manifest (name, version, description, component paths) — required
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

Actual shapes: `al-agentic-dev` carries `skills/` (one folder per skill), `agents/`, `hooks/`, and plugin-level `references/`. `al-language-server` is `lsp.json` only, with no skills.

## Copilot CLI runtime facts (verified against this harness)

- `${PLUGIN_ROOT}` and `$env:COPILOT_PLUGIN_ROOT` expand in plugin hook commands. A hook's cwd is the installed plugin root. When a `sessionStart` hook prints `{"additionalContext": "..."}` to stdout, that context is injected into the session. No hook fires on compaction — `sessionStart` fires on new and resumed sessions only.
- There is no `${CLAUDE_SKILL_DIR}` equivalent. SKILL.md bodies are injected verbatim, unexpanded. A skill references its own files relative to "this skill's base directory", announced at skill activation.
- Instruction files load as follows: `.github/copilot-instructions.md` and a root `AGENTS.md` load at session start; `.github/instructions/*.instructions.md` loads at session start only when `applyTo` is `**` or absent. A path-scoped `applyTo` is ignored by the CLI entirely, even after touching a matching file — it reaches only the PR code review agent, so the CLI needs an explicit pointer to read those files. A nested `AGENTS.md` lazy-loads when files in its directory are touched.
- Skill frontmatter honors `name`, `description`, `license`, and `allowed-tools`. Agent files must end in `.agent.md`. An agent's `tools:` list uses the Copilot aliases (`read`, `edit`, `search`, `execute`, `web`, `agent`, `skill`, `todo`) or `server/tool` for MCP tools.
- A subagent granted `skill` invokes skills exactly as the main session does, and is told the skill's base directory. A subagent granted `agent` spawns further agents, built-in and custom plugin agents alike, verified two levels deep. The built-in `explore` agent declares neither.
- A subagent is path-blind: no `COPILOT_PLUGIN_ROOT`, no skill or plugin path variables, and it is never told its own definition-file path. Its cwd is the consumer repo root. An agent that needs a plugin-relative path receives it from its caller or reaches it through a skill.
- Direct plugin installs (`copilot plugin install ./path`) are deprecated. Test through a local marketplace instead: `copilot plugin marketplace add <repo-root>`, then `copilot plugin install <name>@<marketplace>`.

## Shipped vs dev-time files

This repo builds a shipped product. Two kinds of files live here.

Shipped files install into end-user sessions via the marketplace: `.github/plugin/marketplace.json`, every plugin's `plugin.json`, and all plugin components — `SKILL.md`, `agents/*.agent.md`, `hooks/`, `references/*.md`, `scripts/`, `extensions/`, `lsp.json`. Their audience is an AL/BC developer working in their own repo. That developer never sees this marketplace. Write shipped files project-agnostic, in the user-facing voice, assuming none of the dev-time context in this file.

Dev-time files never ship: `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`, and maintainer docs with no shipped consumer. They carry authoring conventions, editing rules, and coupling contracts for maintaining the shipped files. Installed users never rely on them.

Route every rule by who needs it. A rule the assistant needs at runtime in an end-user session belongs in a shipped file: a `SKILL.md`, or a `references/*.md` the SKILL explicitly reads. Guidance for authoring and editing this repo's files belongs in an instruction file. Editing a `SKILL.md`, an agent, or a reference is editing the product an end user runs, not a note to yourself.

## Authoring doctrine

The `writing-great-skills` and `grill-me` skills (https://github.com/mattpocock/skills) and the `i-have-adhd` skill (https://github.com/ayghri/i-have-adhd) are prerequisites. When one is missing, stop and ask the user before installing anything; install only via the skills.sh installer (`npx skills@latest add <owner>/<repo>`), never by hand-copying files. Their vocabulary — no-op test, leading words, duplication, sediment, sprawl, progressive disclosure, positive phrasing — is this repo's working language. Apply their rules. Never restate them.

This repo adds:

- **The canon is pretraining.** Models have read Clean Code, Ousterhout, Brooks, Evans, Fowler, the Pragmatic Programmer, TDD. A file states only this repo's specific decision, threshold, or BC/AL binding. A sentence restating the canon is a no-op.
- **Pretrained words outrank invented ones.** Official BC/AL terms take priority where they exist. Keeping an invented term requires the user's approval. An invented term's citation spread is sediment, never evidence of value; replacement cost is landing work, never a keep argument; a term glossed by its pretrained rival proves the rival suffices.
- **One home per concept.** Where a concept is defined in both an instruction file and a shipped file, the shipped file is the home. Everywhere else points at it. A restated rule is a fork, and forks drift.
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
4. Wait for the Copilot review to complete, then address and resolve every thread.
5. Merge via the PR once CI is green (squash preferred).
6. Delete the branch.

### The Copilot review is an unenforced gate

Copilot's review is a `COMMENT` with no check run and no commit status, so green CI marks a PR mergeable while the review is still running. Nothing blocks that merge. Two conditions hold it, both checked from the timeline:

- **Review pending** — wait. Every push re-requests Copilot automatically, so pushing a fix returns the PR to pending.
- **Unresolved threads** — address them, then reply and resolve.

Pending means Copilot owes a review: count its `review_requested` timeline events against its `reviewed` events, and any excess request is outstanding. Do not compare timestamps — a push's re-request and the previous review land in the same second, sometimes in reverse order. Match the reviewer login case-insensitively on `copilot*`: the timeline calls it `Copilot`, REST calls it `copilot-pull-request-reviewer[bot]`. The GraphQL `reviews` connection lags by minutes and will show a landed review as absent — it is reliable for `reviewThreads`, not for whether a review exists.

```powershell
$env:GH_HOST = "9altitudes.ghe.com"; $repo = "gtm-general/gtm-bc-copilot-cli-playbook"

# pending?
$tl = gh api "repos/$repo/issues/<N>/timeline" --paginate --jq '[.[] | select(.event=="review_requested" or .event=="reviewed") | {e:.event, who:((.requested_reviewer.login // .user.login)|ascii_downcase)}]' | ConvertFrom-Json
$c = $tl | Where-Object { $_.who -like 'copilot*' }
$pending = ($c | Where-Object e -eq 'review_requested').Count -gt ($c | Where-Object e -eq 'reviewed').Count

# unresolved threads
gh api graphql -f query='query { repository(owner:"gtm-general", name:"gtm-bc-copilot-cli-playbook") {
  pullRequest(number:<N>) { reviewThreads(first:50) { nodes { id isResolved
    comments(first:10) { nodes { databaseId path line body } } } } } } }'

gh api "repos/$repo/pulls/<N>/comments/<comment_id>/replies" -f body="..."
gh api graphql -f query='mutation { resolveReviewThread(input:{threadId:"<PRRT_...>"}) { thread { isResolved } } }'
```

Cross-check `gh api "repos/$repo/pulls/<N>/comments"` against the threads. A comment id present in REST but absent from the threads is a finding GraphQL has not caught up on yet.

Every thread gets a reply before it is resolved, naming the change made, the reasoning that argues the finding down, or where it lands as follow-up.

A `pre-commit` hook in `.githooks/` blocks local commits on `main`; new clones activate it once with `git config core.hooksPath .githooks`. The `main-pr-only` ruleset requires `validate`, `test`, and every review thread resolved. The `Copilot review for default branch` ruleset auto-requests Copilot and re-reviews on push.

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

## Reviewing a pull request

Everything above applies to review as much as to authoring. Five checks earn a comment here more than anywhere else:

1. A shipped file written in the dev-time voice, or carrying marketplace-specific context an end user never has. See "Shipped vs dev-time files".
2. A claim about the Copilot CLI harness that contradicts "Copilot CLI runtime facts". Those are measured, not assumed.
3. A `.ps1` missing `#Requires -Version 7.2`, depending on Windows PowerShell 5.1 syntax, or assuming a cwd other than the repo root.
4. A build artifact, a `secret.json`, or a credential in the diff.
5. A rule duplicated across files rather than pointed at its one home.

## Installing (end users)

```
copilot plugin marketplace add https://9altitudes.ghe.com/gtm-general/gtm-bc-copilot-cli-playbook.git
copilot plugin install <plugin-name>@gtm-bc-copilot-cli-playbook
```

Requires access to the 9altitudes GHE tenant.
