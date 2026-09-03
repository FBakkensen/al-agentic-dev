# Model tiers and step-level delegation — design

Date: 2026-09-03. Decided in a brainstorm session with two live probes of the delegation vehicles (a background `task` agent on `gpt-5.6-luna` and a `create_session` child on `gpt-5.6-sol`, both told to stop on a decision and resume on the answer). Every decision below carries the evidence that settled it.

## Problem

The lead session now runs on Claude Fable 5.1 — a model built for long-running, judgment-heavy work and for orchestrating other models. The plugin does not use that: every skill runs whole in the lead's context, so the frontier model types tests, runs gates, commits, renders diagrams, and uploads attachments. The only delegation today is `al-orchestrate`'s child sessions and `al-review`'s two packaged agents, both pinned to one model name in shipped files.

Model names are unstable across pickers and time. A pin in a shipped file cannot follow them; a name in a skill body is banned (rule 8) and would be wrong within months anyway. There is no place a user can say "these are my three models" once and have every skill use it.

## Decisions

### 1. Three tiers, one user config file, injected by the sessionStart hook

Three named tiers carry the meaning; a user file carries the names.

| Tier | For | Shipped default | Default effort |
|---|---|---|---|
| `frontier` | design, judgment, verdicts, uncertain work | `claude-fable-5.1` | `high` |
| `execution` | writing code and tests from a brief | `gpt-5.6-sol` | `medium` |
| `mechanical` | running gates, commits, renders, lookups, knowledge leaves | `gpt-5.6-luna` | `max` |

- File: `~/.copilot/al-agentic-dev/models.json`, `{"version":1,"tiers":{"frontier":{"model":…,"effort":…},"execution":{…},"mechanical":{…}}}`. Only names and effort live there; what a tier is for ships in the hook text.
- The existing sessionStart hook (both `bash` and `powershell` bodies) reads the file and injects a `# Model tiers` block after Reply shape and before Speak BC. Absent or unparseable file → the shipped defaults plus one line: `Defaults in use — run /al-setup-models to set your models.` A missing or broken single tier falls back alone and the line names it.
- The block ends with the dispatch rule: a `▶` line dispatches now with that tier's model and effort passed explicitly — `task` (background; `read_agent wait:true` where the next step needs the result; `write_agent` to answer its question) or `session` (`create_session` kickoff `autopilot`, `coordinate_with_creator`, `notify_on_idle`; answers by `send_session_message`); a packaged agent takes the tier's model as `model` override.
- This extends the sessionStart entry that already injects Reply shape; no new matcher, no new event. The defect it rides on: model names drift, and a pin in a shipped file cannot follow them.
- Delegation is down only. The lead is whatever the user picked; no skill detects its own model or spawns upward. (Options rejected: spawning a frontier child from a lower-tier lead; a below-tier warning.)

### 2. `/al-setup-models` writes the file and leads with the built-in map

New skill `skills/al-setup-models/` with a sibling `models.default.json` — the single shipped default. The hook's inline fallback must equal it byte for byte; a Pester test enforces that.

1. Show the built-in map as three rows (`tier · model · effort · what it is for`), with any `tier=model` pairs from the prompt line applied, and the existing file beside it when it differs. One question: **A** adopt as shown (recommended), **B** change rows.
2. On A: write the file (create the folder), show it, close.
3. On B: list the models the `task` tool's `model` parameter description offers in this session — names and supported efforts come from there, not from recall — then one question per row to change, lettered from that list, built-in value marked. An effort outside the model's set is corrected in the proposal, not asked.
4. Close with the `# Model tiers` block as the hook will inject it, and: this session uses the map from now; every later session gets it at start.

Not in scope: agent pins, the plugin install, per-repo overrides. Writes only outside the repo, so no `/al-commit` handoff.

### 3. The `▶` line: one grammar at every delegation point

```
▶ <tier> · <vehicle> · <brief> → <return>
```

- `tier` ∈ `frontier` `execution` `mechanical`; `vehicle` ∈ `task` `session`.
- `brief`: what the child receives, named concretely — the child inherits nothing; the lead composes its prompt from the brief plus the inputs it names.
- `return`: what comes back, checkable — a verdict line, a file list, commit hashes, red-then-green evidence.
- Every dispatch prompt carries four fixed parts: the brief; the return contract; the unattended line (`You run unattended; the user cannot answer mid-task. Proceed on every reversible step the User Story already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.`); the ask-in-reply line. A child that writes or judges AL also carries the Speak BC paragraph and the grounding rule — a session gets them from the hook, a task only from the brief.
- Two-way: a child's stop is a decision. If the skill's own contract answers it, the lead answers to the *same* child and continues. If only the user can, the lead quotes it with options and recommendation and relays the answer unchanged — `al-orchestrate`'s pass-through becomes the set-wide rule.
- Parallel: several `▶ task` lines at one step launch together in the background; `read_agent wait:true` only where the next step needs that result. Sessions run one owner per branch at a time.
- Escalation: a child that returns without meeting its return contract, or red twice on the same cause, is re-dispatched once, one tier up, with its own output added to the brief. A second miss goes to the user with the evidence.
- Rejected: a `## Delegation` table per skill (separates the dispatch from its step; strains the 60-line budget); inline prose (nothing for the gate to check).

### 4. Vehicle rule: task for the current branch, session for its own branch

Work that writes into the current branch, or reads only, is a `task` — same worktree, result inside the lead's turn. Work that owns its own branch is a `session`.

Evidence (probe, 2026-09-03 09:31–09:33 UTC):

| | `task` (luna) | `create_session` (sol) |
|---|---|---|
| Ran in | this worktree, this branch | own worktree `flemmingbk-solid-waddle`, own branch |
| Question reached lead | idle notification 9 s after start | `cross_session_message` **during the lead's turn**, as a new user message |
| Answer delivered | `write_agent`; received by worker 11 s later | `send_session_message immediate`; received 21 s later |
| Reply reached lead | `read_agent wait:true` returned it **inside the lead's turn** | another `cross_session_message` — a **new user turn**; plus `notify_on_idle` fired after the child's reply |
| Model pin | `model: gpt-5.6-luna` shown in agent status | kickoff `model` accepted |

A task round-trip closes inside one lead turn, so step-level delegation is synchronous from the lead's view. A session reply ends the lead's turn, which fits whole-item ownership where the lead is idle anyway and does not fit mid-step work.

### 5. Depth is one: task workers do not delegate, session children do

- A task worker receives one step's brief and does all of it in its own context — runs the gate, commits if the brief says so. It hands nothing on. Whether a task worker can call `task` was not probed and never needs to be.
- A session child is a full session: it gets the hook, has the `task` tool, and runs its skill's `▶` lines as written.
- Consequence: step-level handoffs (`al-implement`, `al-refactor`, `al-review`, `al-pr-shepherd`, surveys in talking skills) use tasks; whole-skill handoffs (`al-orchestrate`) use sessions.
- Callee skills (`/al-build`, `/al-commit`, `/al-arc42`, `/al-azure-devops-attachments`, `/al-pull-request`, `/al-clone-bcapps`, `/al-clone-bcquality`) carry no `▶` lines; the caller writes the line. Invoked directly by the user, a callee runs in the lead as today. A task worker running a callee therefore never meets a `▶` line.

### 6. Per-skill splits

The unit of delegation is the step, not the skill. Three kinds:

**Talking skills** — interview and judgment stay in the lead; a survey that reads many files or items and returns a table is delegated; a single lookup stays in-line (`/al-lookup`: one call, seconds — a worker costs more turns than it saves).

| Skill | `▶` lines |
|---|---|
| `al-design` | `execution · task` canonical-shape survey: how the Base App models the concept — tables, seams, events — in `.bcapps/release` → precedent table with file:line; render, attach, commit callee lines |
| `al-event-model` | `execution · task` process precedent: how the Base App's comparable flow posts, validates, errors → step table with sources; `mechanical · task` BPMN render; attach, commit |
| `al-test-design` | `mechanical · task` inventory of existing proof for the affected interface, objects, terms → test procedures and helpers with paths; `mechanical · task` standard test libraries and fixtures for the named objects → names with paths |
| `al-next` | `mechanical · task` BC-anatomy delta table from the diff base; `mechanical · task` receipts and comments summarized per executable item |
| `al-miner` | `mechanical · task` extract repeated failures and steering corrections from the session-history range → candidate table with session ids; the lead judges which become lessons |
| `al-grill-adr` | `mechanical · task` read the Original User Story, linked items, `CONTEXT.md` vocabulary → summary table — only when the hierarchy is more than a handful of items |
| `al-scope`, `al-grilling`, `al-wait-what`, `al-lookup`, `al-setup-models` | none beyond callee lines already present (`al-lookup` → commit); `/research` route in `al-lookup` unchanged |
| `al-grill-me`, `al-unslop` | pinned forks, untouched |

**Callee skills** — one line each, written by the caller:

| Callee | `▶` line |
|---|---|
| gate | `▶ mechanical · task · /al-build gate on <scope>, WARN_AS_ERROR as the caller states → summary.json verdict, per-runner totals, exact red cause` |
| commit | `▶ mechanical · task · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree` |
| render | `▶ mechanical · task · /al-arc42 <views> from <settled content> → HTML path, SVG and PNG paths, alt text, publishable fragments` — the lead opens the HTML in the browser canvas; a task child has no canvas |
| attach | `▶ mechanical · task · /al-azure-devops-attachments <files> to <work item> → verified attachment URLs` |
| PR | `▶ mechanical · task · /al-pull-request for <branch> → PR number and URL` |
| clones | `▶ mechanical · task · /al-clone-bcapps` or `/al-clone-bcquality` `→ clone ready or the red named` |

**Mixed skills** — the lead decides, a worker types or runs, the lead judges the return:

| Skill | Lead keeps | `▶` lines |
|---|---|---|
| `al-implement` | trace the path; per Gherkin scenario pick AAA cases and production site; build the change map from code; write the receipt | `execution · task` one per scenario: cases, site, seam, proof-map rows → red evidence per case, green gate line, files touched; gate, render, attach, commit |
| `al-refactor` | mode choice; the tidy or reshape list; freeze check; Level 2 decision | `execution · task` the list for named files with frozen AAA values → diff, gate green, mutation evidence; gate, render, attach, commit |
| `al-review` | ledger; contract inspection; dedupe; verdict | `execution · task · al-review-lens` with the `User Story contract` dimension → findings; `mechanical · task · al-knowledge-leaf` one per selected leaf → DO report; gate for missing evidence |
| `al-pr-shepherd` | the read-act-wait loop; human-feedback stop; design-conflict stop; merge on the user's go | `execution · task` per actionable Copilot finding: finding, PR promise → fix diff; `execution · task` the mechanical AL collision renumber → both declarations kept, verified numbers; gate, commit |
| `al-orchestrate` | the loop; pass-through; evidence reactions | `execution · session` /al-implement; `execution · session` /al-refactor; `frontier · session` /al-review; `execution · session` /al-walkthrough. CLI shape adds `--model <tier model>` to each `copilot -p` line. |
| `al-walkthrough` | the walk — the workspace MCP is bound to this session | `mechanical · task · /al-build clean republish into <container> → deployed commit and app version` |

Tier calls: `al-review`'s lens dimension runs execution because it judges behaviour; the knowledge leaves run mechanical because they follow a written contract. `al-orchestrate`'s implement and refactor sessions run execution because seam and cases were decided in `al-test-design`; review runs frontier because the verdict is the judgment.

### 7. Agents keep a pin; the tier override wins at dispatch

Both `agents/*.agent.md` stay: their fixed body, tools allowlist (a review worker that cannot edit), and model default are worth keeping. The `▶` line passes the tier's model as the `task` `model` override; the pin only matters when the map is absent.

- `al-review-lens` → `model: gpt-5.6-sol` (execution). `al-knowledge-leaf` stays `model: gpt-5.6-luna` (mechanical).
- A Pester test holds the agent → tier table and asserts each pin equals that tier's model in `models.default.json`.
- Rejected: deleting the agents and inlining their bodies as briefs (no pins, but `al-review` overruns its budget and review workers gain edit tools).

### 8. Rules, gate, dev-time files, version

`skills.instructions.md`:

| Rule | Change |
|---|---|
| 8 | Model names live in `skills/al-setup-models/models.default.json` and `agents/*.agent.md` pins only. A skill names a tier on a `▶` line, never a model. |
| 28 | Delegation is for work that returns a compact result — a survey table, one scenario's red→green evidence, a gate verdict — or that owns its own branch. A single lookup stays in-line. A delegated review judgment runs at execution or above; a leaf following a written contract runs mechanical. "Full-capability" wording dropped. |
| 29 | Fan-out is several `▶ task` lines at one step, launched together; wait only where the next step needs the result. The "when subagents are unavailable" sentence is dropped — every Copilot surface has `task`. |
| 33 | `▶ <tier> · <vehicle> · <brief> → <return>` is a defined slot. `al-walkthrough`'s `▶ <business action>` report line stays: it sits in a code span and names no tier. |
| 38 (new) | The delegation contract: grammar; tier and vehicle sets; task workers do not delegate, session children do; callee lines live in the caller; the four fixed dispatch parts plus Speak BC and grounding for AL-writing or AL-judging children; answers to the same child; escalation once, one tier up. |

`Validate-Skills.ps1` gains three checks, each with a red fixture in `tests/Validate-Skills.Tests.ps1`: (a) every `▶` outside a code span matches `^▶ (frontier|execution|mechanical) · (task|session) · .+ → .+$`; (b) no model name from `models.default.json` appears in any `skills/**/*.md`; (c) `models.default.json` has exactly the three tiers, each with non-empty `model` and `effort`.

Hook tests: run the PowerShell sessionStart body with a temp `HOME` in three states — absent, valid, broken — and assert the injected block; the bash body likewise where `bash` is on PATH. Plus the byte-equal test between the hook's inline defaults and `models.default.json`.

`copilot-instructions.md`: twenty-six skills with `al-setup-models` named; the hooks line gains "and the model tiers"; the test-run line reads "a task agent at the mechanical tier" and `tests/ArtifactContracts.Tests.ps1` follows. `REVIEW.md` regenerated.

Version: `plugin.json` and `.github/plugin/marketplace.json` → `4.0.0`. One package, no phases.

### 9. Acceptance

Mechanical: all five gates green.

Live, in this worktree before the PR merges, each recorded in the PR body:

1. New session → `# Model tiers` block present with `Defaults in use`; `/al-setup-models`, A → file written; new session → block without that line.
2. One `▶ mechanical · task · /al-commit` on a scratch change → worker returns hashes; `read_agent` shows `model: gpt-5.6-luna`.
3. `al-review-lens` dispatched with the execution override → agent status shows `gpt-5.6-sol`.

First real use, after merge, not a gate: `al-implement` on one real User Story in an AL consumer repo — scenario workers return red→green evidence and the lead never runs the gate itself. Findings go to the next package.

## Out of scope

- Upward delegation or model self-detection in the lead.
- Per-repo tier overrides.
- Rewriting installed plugin files from a skill.
- Nested delegation from task workers.
- Changes to the pinned forks `al-grill-me` and `al-unslop`.
- `al-build`'s scripts and the `.ps1` substrate.
