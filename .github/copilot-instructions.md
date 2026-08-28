# Working on this repo

This repo ships the GitHub Copilot plugin `al-agentic-dev`: Agent Skills for AL/Business Central development plus packaged custom agents, bundled MCP servers, and the marketplace manifest. Everything here is Copilot-first — skills name Copilot tools, bundled MCP servers, and packaged agents explicitly.

The set was rebuilt package by package on `flemmingbk-skills-v2`, since merged to `main`. Git history is the donor archive — a retired skill returns from a commit, never from a copy.

## The shipped surface

```
plugin.json                     the plugin manifest: name, version, skills/, agents/, hooks, .mcp.json
.mcp.json                       bundled MCP servers, each with a tools allowlist
hooks.json                      the shipped hooks: preToolUse denies ask_user; sessionStart injects the reply shape and the Speak BC voice rule in AL repos
.github/plugin/marketplace.json the marketplace manifest the plugin installs through
skills/<name>/SKILL.md          frontmatter: name, description
skills/<name>/<SIBLING>.md      optional format files, inside the same folder only
skills/al-event-model/bpmn-renderer/ package-local BPMN renderer dependencies
skills/al-build/scripts/*.ps1   the build substrate
skills/al-build/config/         al-build.json
agents/<name>.agent.md          packaged custom agents: name, description, tools, model
```

Twenty-five skills ship today. Three are the AL survivors: `al-build` — the compile-publish-test gate, provisioning, breaking-change validation, and the container lifecycle, and the contract model everything else copies — plus the two lookup-source clones `al-clone-bcapps` and `al-clone-bcquality`. Two are pinned forks whose bodies stay donor text except the al- namespace: `al-grill-me` (the grilling entry) and `al-unslop` (the AI-tell cut) — see the fork rule in `skills.instructions.md`. Twenty are authored for the new set: `al-grilling` (the one-decision-at-a-time stress-test interview), `al-wait-what` (the contextual re-pitch), `al-grill-adr` (one Original Azure DevOps User Story, preserved request, vocabulary, and hard-to-reverse ADRs), `al-miner` (session history into proposed standing lessons, on /chronicle), `al-lookup` (one platform question, a sourced answer, the precedent map), `al-azure-devops-attachments` (Azure CLI upload and verified work-item attachment relations), `al-commit` (full-worktree staging and independently valid commits), `al-pull-request` (ready pull request creation and updates), the design chain `al-event-model` / `al-arc42` / `al-design` / `al-scope` (process contract and BPMN review HTML; official arc42 formatting and architecture review HTML; Level 1 module contracts; one Original User Story with direct outcome slices), `al-test-design` (user-reviewed AAA after Gherkin in Acceptance Criteria), `al-implement` / `al-refactor` / `al-review` (proof through the module interface; behavior-frozen reshape; read-only contract verdict), `al-next` (reconciliation of User Story design, slices, receipts, and landed code), `al-pr-shepherd` (one open PR to merge — CI watched, Copilot findings fixed, main merged in with intent-preserving conflicts; the merge itself is the user's go), `al-orchestrate` (one reviewed executable item through al-implement → al-refactor → al-review), and `al-walkthrough` (the Gherkin walk in the running Web Client through the consumer repository's workspace MCP). Two read-only reviewer agents ride under `agents/`, serving `al-review`'s fan-out: `al-review-lens` and `al-knowledge-leaf`.

The folder name equals the frontmatter `name`; an agent's `name` equals its filename stem, and its `model` pin and `tools` scope are mandatory. A skill reaches outside its folder only by naming another skill — `/al-build` — never by path.

Every skill is model-invocable. Skill frontmatter omits `disable-model-invocation`, and every description carries the trigger branches that let the model reach it.

## What never ships

- The word "harness" and harness-conditional phrasing — the gate fails it; name the Copilot tool, MCP server, or packaged agent instead. The pinned `al-unslop` fork is the one exemption: its own rules name the word as jargon to cut.
- A capability paraphrase where a concrete Copilot name exists.
- A model name in a skill body or skill frontmatter — model pins live in `agents/*.agent.md` only.
- Skill frontmatter beyond `name` and `description` — no `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`, or `disable-model-invocation` on a skill.
- Task-state ceremony — a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: New|Active|Blocked|Testing|Resolved|Closed`), or an abstract stage gate. A concrete artifact may require user agreement before its consumer runs; that is contract readiness, not lifecycle state. The gate bans the fields in every folder.
- A link that leaves the skill folder: `](../`, `](/`, any absolute path.
- Slash-command files — out of scope until a proven defect asks for them. Two hooks ship in `hooks.json`, each on its own proven defect: the preToolUse ask_user deny (a child session hung silently on an `ask_user` call) and the sessionStart context injection (generic CS names leaked into work items and review conclusions, and the v1 reply-shape block in the user's `~/.copilot/copilot-instructions.md` was orphaned when its installer skill retired); a new hook needs its own proven defect.

Say so when a change reintroduces one of these.

The PowerShell substrate ships only under `skills/al-build/`, and `/al-build` invokes its procedures. Outside `skills/al-build/`, a `.ps1` filename or a `scripts/` path in a skill body is a defect — that skill calls `/al-build` instead. The one listed exemption: `al-clone-bcquality` runs the BCQuality knowledge-index generator inside the checkout it clones.

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

`main` is PR-only. A change lands on a fresh feature branch and merges through a PR, the plugin version incrementing per package.

Before pushing, run `scripts/Validate-Json.ps1`, `scripts/Validate-PowerShell.ps1`, `scripts/Validate-Skills.ps1`, `scripts/Update-Review.ps1 -Check`, then `scripts/Invoke-Tests.ps1 -Mode Full`. CI runs the same five on pushes to `main`, `feature/copilot-first-migration`, and `flemmingbk-skills-v2`, and on every pull request. The gates validate `skills/`, `agents/`, and the plugin manifests; links in `README.md` and `docs/` are deliberately unchecked — not a review finding.

Use `scripts/Invoke-Tests.ps1 -Mode Fast` for the local loop; it excludes process-bound and live-fixture tests without changing the full gate.

Delegate test runs only to a task agent pinned to `gpt-5.6-luna`. The agent runs `scripts/Invoke-Tests.ps1` once and uses its compact result; it never reruns Pester to recover output.

`.output/` and `**/secret.json` are gitignored. Never commit build artifacts or secrets.
