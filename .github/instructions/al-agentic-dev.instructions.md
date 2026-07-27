---
applyTo: "plugins/al-agentic-dev/**"
---

# al-agentic-dev

Composable skills for AL/Business Central agentic development.

*Dev-time only — this file never ships. The shipped surface is the plugin's `SKILL.md`s, `agents/`, `hooks/`, `references/`, and `scripts/`. See `.github/copilot-instructions.md`, "Shipped vs dev-time files".*

## Persistence layers

Two layers. Repo-root artifacts (`CONTEXT.md`, `docs/adr/`, `.out-of-scope/`, `.not-yet-specified/`) outlive features. Branch-scoped `specs/<NNN>-<slug>/` (`event-model.md` for user/API-facing features, `architecture.md`, `tasks/`) lives with one branch, its slug matching the git branch. Owners, the deferred-question ledger, and which writes run the document-integrity check are homed in [`references/overview.md`](references/overview.md) (Persistence layers) and [`references/task-lifecycle.md`](references/task-lifecycle.md) (Routing by lifetime).

The `tasks/` folder is the per-feature task bus. Its entire runtime contract is homed in [`references/task-lifecycle.md`](references/task-lifecycle.md): file naming, frontmatter fields, the `status:`/`phase:` lifecycle, ops kinds, gated `blocked` → `ready` opens (including the same-slice technical dependents a `done` flip opens), `review: clean` strip rules, and the surgical-edit floor. Point at it. A field or lifecycle rule restated here would fork it.

[`references/worktree-feature-branching.md`](references/worktree-feature-branching.md) owns feature branch setup. The `/al-event-model` and `/al-design` SKILL.mds own who runs it when. Both skills read the reference, so an edit to its routes or Stop conditions scans both SKILL.mds in the same change.

## Pipeline

[`references/overview.md`](references/overview.md) is the single source of truth for the pipeline: diagram, 18-skill catalogue, custom-agent table, slice cycle, and cold-start guidance. `/al-agentic-dev-overview` emits it verbatim. Edit it in lockstep with any skill or agent addition, removal, rename, or repurpose.

Per-skill mechanics live in the owning `SKILL.md`. Page-script recording, replay, and red classification live in `/al-page-script`. The verification spawns live in `/al-user-verification`. Report-only and `--fix` semantics live in `/al-code-review`. Replan trigger semantics live in [`references/task-lifecycle.md`](references/task-lifecycle.md). Status-flip and gate-open mechanics live in [`references/task-lifecycle.md`](references/task-lifecycle.md). Skills compose by name, so a change to one skill scans the others for cross-references and updates them in the same change.

## Editing rules

- **Preserve the call boundary.** `/al-build` is the only direct skill-to-skill call. BC research spawns `al-researcher`; the rubber-duck consult, other custom-agent spawns, and inline state writes are homed in [`references/overview.md`](references/overview.md). A skill edit that adds a cross-skill call or auto-chain contradicts that canon. Change the canon first.
- **Custom agent bodies are self-contained.** Skills and agents run in consumer projects where this instruction file does not exist. A lens carries its own detection rules and BC vocabulary in its body, and reads the shared protocol from `references/review-lenses.md`. The spawning skill's invocation carries the declared mode, the scope, and the payload — nothing else.
- **Naming, BC vocabulary, and grounding are homed in [`references/GROUND-RULES.md`](references/GROUND-RULES.md).** That includes names-as-citation (no inline `file:line` citations in durable artifacts) and the `Researched:` carve-out. Writing skills read it before writing.
- **User involvement is homed in [`references/user-involvement.md`](references/user-involvement.md).** A planning SKILL.md names the strategic categories of its own altitude and its own question repertoire, then points at the reference for the shared contract. Restating the fact/strategic/tactical split, the fidelity ladder, or the alternatives beat inside a SKILL.md forks it.
- **`/grill-me` and `i-have-adhd` are external dependencies.** Neither is ever forked into the plugin; `GROUND-RULES.md` carries the install pointer for both.
- **Canvas support ships as guidance, never as a shipped extension.** No canvas component, shell, or starter kit lives in `plugins/`. The scope and teardown rules are prose in `references/user-involvement.md` — nothing in this repo can police what an agent scaffolds inside a consumer's AL project, so a validation script would be theatre.
- **Four Return shapes deviate from the fixed line-1 label, each coupled to the callers that parse it.** Changing any of these shapes updates every parsing caller in the same change; never restyle one side alone.

  | Agent | Shape | Parsing callers |
  |---|---|---|
  | `al-researcher` | dynamic evidence verdict: `SINGLE-SOURCE` / `VERIFIED` / `CONFLICT` / `UNRESOLVED` on line 1, then quoted evidence and conditional Conflict/Limit fields | every skill or custom agent that needs BC knowledge beyond direct workspace reading |
  | `al-red-green` | `## Outcome note` leads with a dynamic verdict chosen from `GREEN` / `PUSH-UP` / `BLOCKED` | `/al-implement`, `/al-code-review --fix` |
  | `al-review-red` | dynamic red verdict `TRUE-RED` / `FALSE-RED` on line 1, or the fail-closed line `RED REVIEW INVOCATION ERROR: incomplete evidence` alone; no mode, no sentinel, no judge | `al-red-green` |
  | the eleven review lenses | zero or more labeled finding blocks under a fixed per-lens line-1 sentinel plus a line-2 `Mode:` echo — the sentinel registry, the invocation-error line, the per-mode evidence bar, and the finding-block shape are homed in [`references/review-lenses.md`](references/review-lenses.md) | `/al-code-review`, `/al-refactor`, `/al-design`, `/al-refine`, `al-review-judge` |
  | `al-review-perf` | when the `al-performance` MCP is missing, exactly the one line `perf scan skipped: al-performance MCP not available` — no sentinel, no other line | `/al-code-review`, `/al-refactor`, `al-review-judge` |

- **Spec artifacts are pure markdown, text-only.** The no-mermaid rule is homed in the `/al-design` and `/al-scope` skill bodies. Visual polish is a separate dev-server concern, never the spec's.
- **`architecture.md` is reshape-only. Per-task files carry the surgical-edit contract.** Both are homed in [`references/task-lifecycle.md`](references/task-lifecycle.md).
- **New skills need a stated gap.** Propose one only when no existing skill, task-file note, `al-researcher` result, or cross-cutting reference can absorb the need. Say so in one line.
- **Express intent and rationale, not enumerated skip conditions.** SKILLs and references state why a discipline exists and what problem it solves. The agent maps rationale to situation. Slot prescriptions, `_When earned:_` / `_Skip when:_` enumerations, and fill-in templates are rejected by name.
- **`al-debug-logging` owns runtime probes and its telemetry MCP.** It emits temporary `Session.LogMessage` events and queries Application Insights through its embedded `bc-telemetry-buddy` server. `/al-build` owns no telemetry capture or telemetry artifacts.
- **An agent naming `<server>/<tool>` in `tools:` must declare that server in `mcp-servers:`.** A `tools:` entry is a reference, not a declaration; without the block the agent silently holds nothing. `scripts/Validate-PluginStructure.ps1` gates this.
- **No lens holds a fixer — capability custody is not change authority.** `al-performance` exposes `fix_al_file`, and it stays off `al-review-perf`'s allowlist. The tool takes only a file path and a dry-run flag: no occurrence selector, and its dry-run `Fixes applied:` list names pattern ids rather than locations, so no approval gate can confine a rewrite to the diff. A provably equivalent one-line perf fix lands as a targeted `edit` under `/al-code-review`'s hygiene rule; anything structural queues as a manual reshape in `/al-refactor`.
- **`al-review-red` shares the lens name family and none of the lens contract.** It takes no `Mode:`, carries no sentinel, never reaches `al-review-judge`, and stays out of `references/review-lenses.md`. `tests/ReviewLenses.Tests.ps1` keeps a named non-lens allowlist rather than an inline exclusion; a future `al-review-*` agent that is not a lens joins that list in the same change.
- **`al-researcher` owns canonical source lookup.** `microsoft/BCApps` paths, branch selection, search rules, `gh` commands, and fallback stay in `agents/al-researcher.agent.md`. Web access is only the raw-file fallback. No separately discoverable source agent may bypass the gateway.

## Reference layout

References sit in two tiers:

- Plugin-level shared, `references/` — read by two or more skills. Path from any SKILL.md: `../../references/<file>`. The four testing references live in the `references/testing/` subfolder; path from any SKILL.md: `../../references/testing/<file>`.
- Skill-local, `skills/<skill>/references/` — read by one skill only. Path from that SKILL.md: `references/<file>`.

A resource read by two or more skills lives at plugin level. A shared resource inside one skill's folder makes ownership unclear. Cross-skill paths (`../<skill>/references/<file>`) are a smell to be migrated.

| File | Tier | Purpose / readers / lockstep |
|---|---|---|
| `overview.md` | plugin-level | user-facing tour, emitted verbatim by `/al-agentic-dev-overview`; edit in lockstep with any skill or agent change |
| `GROUND-RULES.md` | plugin-level | the one always-on contract: output shape via the `i-have-adhd` skill, one-decision-per-question, grounding mechanics, BC vocabulary, house shapes, production-AL thrift; injected by the `sessionStart` hook, re-read by skills on invocation |
| `user-involvement.md` | plugin-level | the one home for the shared interview contract: the fact / strategic / tactical split, the fidelity ladder, the alternatives-after-grilling beat, the artifact-as-memory rule, the `/grill-me` escalation, and canvas guidance; read by `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, and `/al-steer` |
| `doc-integrity.md` | plugin-level | inline document-integrity check; run by the writing skills (`/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-steer`) before the gate report |
| `rubber-duck-review.md` | plugin-level | rubber-duck consult discipline; read by every skill that consults the duck |
| `review-lenses.md` | plugin-level | the one home for the five review modes, the lens×mode membership matrix, the `Mode:`/`Scope:` invocation contract, the per-mode evidence bar, terminal states, the sentinel registry, the judge's mode fence, and the plan-gate stop shape (dispositions, the split between agent-decided and user-settled findings, plugin-gap record, one bounded re-review); read by `/al-code-review`, `/al-refactor`, `/al-design`, `/al-refine`, every review lens, and `al-review-judge` |
| `testing/testability.md` | plugin-level | seams and test-double taxonomy; read by `/al-design`, `/al-implement`, `/al-refactor` |
| `testing/tdd.md` | plugin-level | TDD cycle axis incl. mutation operators; read by `/al-implement`, `/al-mutate` |
| `testing/test-strategy.md` | plugin-level | test-execution pyramid on the BC stack (the execution axis); read by `/al-build`, `/al-implement`, `/al-mutate`, `/al-refine`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `testing/test-layout.md` | plugin-level | two-peer-test-app layout and AL Runner capability map (the placement axis); read by `/al-scope`, `/al-refine`, `/al-implement`, `/al-refactor` |
| `task-lifecycle.md` | plugin-level | `tasks/` folder shape, filenames, frontmatter, the `000-feature.md` header, surgical-edit floor, content routing by lifetime, and the eight replan triggers; read by `/al-design`, `/al-event-model`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-code-review`, `/al-user-verification`, `/al-mutate`, `/al-steer` |
| `task-grammar.md` | plugin-level | the per-task file body from the container line down — shape rules, sections, and the `Test Specification` / `Verification Plan` grammar for both kinds; read by `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `examples/` (folder) | plugin-level | populated example artifacts; pattern-match source for writing skills |
| `cross-branch-numbering.md` | plugin-level | `NNN`/`NNNN` picking across parallel branches; read by `/al-design`, `/al-event-model`, `/al-grill-adr` |
| `worktree-feature-branching.md` | plugin-level | feature branch setup; read by `/al-event-model`, `/al-design` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue; read by `/al-design`, `al-review-bc` |
| `LANGUAGE.md` | plugin-level | architectural vocabulary; read by `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-refactor`, `/al-code-review` |
| `CONTEXT.template.md` | plugin-level | materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `out-of-scope.template.md` | `/al-steer`-local | materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow.

## Runtime surface

The plugin is distributed via `.github/plugin/marketplace.json` and targets GitHub Copilot CLI. It ships 19 custom agents under `agents/`, invoked via the task tool by name. Each agent's `.agent.md` frontmatter pins its model — the single home; the repo-root `scripts/Validate-PluginStructure.ps1` checks every pin against its fleet map. [`references/overview.md`](references/overview.md) carries the user-facing agent table. `al-researcher` alone owns the research MCPs and canonical BCApps lookup. The 17 other research-capable agents carry `agent` tool access and route facts through the gateway. `al-debug-logging` alone owns `bc-telemetry-buddy`; `al-review-perf` alone owns `al-performance`.

Agent-scoped MCP behaviour, measured on CLI 1.0.71-2 with an isolated `COPILOT_HOME`:

- An agent-declared server registers default-disabled and enables when that agent runs, so its startup cost is paid only then. The routine `Skipping disabled MCP server` log line is idle behaviour, not suppression.
- An explicit user `disabledMcpServers` entry **wins** — the agent sees no tool. The plugin cannot defeat a user opt-out.
- An agent's own declaration wins over a same-name entry in the user's `mcp-config.json`, so the pinned version is what the agent gets.

Session-scoped mechanisms exist (`plugin.json` `"mcpServers"`, a plugin-root `.mcp.json`) and are deliberately unused: they would put every server in every session, including runs that never touch the capability.

SKILL.md bodies are injected verbatim and unexpanded, with no template variables. A skill locates its own files relative to the base directory announced at activation.

When authoring new plugin capability, default to a skill. Add a custom agent only when fan-out or context isolation earns it.

MCP-absence behavior is per-consumer, not uniform. The owning skill or agent states its fallback. Two exceptions:

- `al-red-green` blocks on a missing object-ID allocator.
- `al-review-perf` returns its skip line.

A blanket claim here would fork them.

Skills stay project-agnostic across consumer repos. A skill runs in any AL/BC project without hardcoding this marketplace's paths or a specific repo's layout. Soft guidance, not a CI gate.

### The two hooks

`hooks/hooks.json` (Copilot native format, `"version": 1`) registers `sessionStart` and `agentStop`. Both are `powershell`-only: with both a `bash` and a `powershell` key the CLI picks `powershell` on Windows and `bash` elsewhere, but with only `powershell` it runs that on every platform, resolving `pwsh.exe`/`powershell.exe` on Windows and `pwsh` elsewhere. `pwsh` is already required by `skills/al-build/scripts/`, so a bash twin buys nothing and doubles every hook.

`sessionStart` reads `references/GROUND-RULES.md` via `$env:COPILOT_PLUGIN_ROOT` and emits it as `{"additionalContext": ...}`. Couplings, all empirically verified:

- The PowerShell command keeps its `[Console]::OutputEncoding = UTF8` prefix. Without it, `pwsh -c` on Windows writes stdout in the legacy codepage. That mangles `→`/`—` and silently breaks the CLI's JSON parse, and the hook injects nothing.
- The compaction gap is accepted. `sessionStart` fires on new and resumed sessions only, never on compaction, and `preCompact` cannot inject. The recovery path is skills re-reading the file on invocation.
- The hook never restates the rules. It reads the one file, so there is no second copy to drift.

`agentStop` runs `hooks/Invoke-TaskGrammarHook.ps1`, which checks the task files written this session against `references/task-grammar.md` through `hooks/Test-TaskFileGrammar.ps1` — the same parser `tests/TaskGrammar.Tests.ps1` runs, so hook and CI cannot diverge. Couplings, all empirically verified against CLI 1.0.75:

- `agentStop` returns `decision` and `reason`, never `additionalContext` — its mapper is `l => ({decision: l?.decision, reason: l?.reason})`. On `decision: "block"` the CLI calls `enqueueUserMessage({prompt: reason})`, so the reason becomes the agent's next instruction and the turn continues. That enforces rather than informs.
- The event is `agentStop`, not `postToolUse` or `userPromptSubmitted`. A hook matcher tests the tool *name* only, so `postToolUse` would spawn on every edit anywhere in the repo — measured at ~590 ms per `pwsh -NoProfile -NoLogo` spawn, which the CLI already passes. `userPromptSubmitted` fires before the turn's writes, so a one-prompt session such as `/al-implement` would never see its own output. `agentStop` fires once per turn, after the writes, including that single turn.
- Session start comes from the payload's `transcriptPath` creation time, so the first run of a session already sees that session's writes. Without it a marker written by the first run would set a baseline nothing predates.
- The hook blocks at most twice per session, counted in a temp state file keyed by session id. A file the agent cannot fix stops the hook, never the session.
- It fails open. A missing `specs/`, a missing parser, an unparseable payload, or any thrown error emits nothing and the session proceeds.

Adding a third hook is a deliberate decision, not a default.

## Layout

```
agents/                          # Shipped custom agents (19; each pins its model in frontmatter)
├── al-red-green.agent.md            # One AAA case RED→GREEN
├── al-review-red.agent.md           # Blind TRUE-RED/FALSE-RED verdict on one red beat (not a lens)
├── al-gate-runner.agent.md          # One authoritative gate run
├── al-mutant-cycle.agent.md         # One mutate→gate→revert cycle
├── al-design-option.agent.md        # One architecture candidate under a divergent constraint
├── al-researcher.agent.md           # One BC fact through isolated research tools
├── al-debug-logging.agent.md        # Temporary probes queried through Application Insights
├── al-review-*.agent.md             # 11 review lenses, one per concern (compliance, coverage, structural,
│                                    #   bc, perf, appsource, bugscan, comments, simplify, objects, assertions)
└── al-review-judge.agent.md         # Dedups/ranks one lens finding batch
hooks/
└── hooks.json                   # Sole hook: sessionStart injects references/GROUND-RULES.md; fail-open
references/                      # Plugin-level shared — see the Reference layout table
skills/
├── al-agentic-dev-overview/SKILL.md  # Emits ../../references/overview.md verbatim
├── al-build/                    # Build/test gate; config/, scripts/, own scoped instruction file
├── al-code-review/SKILL.md
├── al-design/SKILL.md
├── al-event-model/SKILL.md
├── al-grill-adr/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-page-script/              # SKILL.md + references/ (recorder-gestures, bc-replay YAML format)
├── al-provision/SKILL.md
├── al-quiz/SKILL.md
├── al-refactor/                 # SKILL.md + references/legacy-refactor-plan.md
├── al-refine/SKILL.md
├── al-scope/SKILL.md
├── al-steer/                    # SKILL.md + references/out-of-scope.template.md
├── al-sync-main/SKILL.md
├── al-user-verification/SKILL.md
└── al-validate-breaking-changes/SKILL.md
```

Tests live at repo root, never inside a plugin: flat `tests/*.Tests.ps1` for repo-wide contracts, nested `tests/<target>/*.Tests.ps1` for per-target Pester suites (e.g. `tests/al-build/`), fixtures under `tests/fixtures/`. `plugins/` carries only deliverables.

There are no build scripts. Skill bodies, reference templates, and the PowerShell helpers under `skills/al-build/scripts/` are the entire product.
