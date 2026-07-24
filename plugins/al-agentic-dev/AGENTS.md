# al-agentic-dev

Composable skills for AL/Business Central agentic development.

*Dev-time only — this file never ships. The shipped surface is the plugin's `SKILL.md`s, `agents/`, `hooks/`, `references/`, and `scripts/`. See the root `AGENTS.md`, "Shipped vs dev-time files".*

## Persistence layers

Two layers. Repo-root artifacts (`CONTEXT.md`, `docs/adr/`, `.out-of-scope/`, `.not-yet-specified/`) outlive features. Branch-scoped `specs/<NNN>-<slug>/` (`event-model.md` for user/API-facing features, `architecture.md`, `tasks/`) lives with one branch, its slug matching the git branch. Owners, the deferred-question ledger, and which writes run the document-integrity check are homed in [`references/overview.md`](references/overview.md) (Persistence layers) and [`references/task-lifecycle.md`](references/task-lifecycle.md) (Routing by lifetime).

The `tasks/` folder is the per-feature task bus. Its entire runtime contract is homed in [`references/task-lifecycle.md`](references/task-lifecycle.md): file naming, frontmatter fields, the `status:`/`phase:` lifecycle, ops kinds, gated `blocked` → `ready` opens (including the same-slice technical dependents a `done` flip opens), `review: clean` strip rules, and the surgical-edit floor. Point at it. A field or lifecycle rule restated here would fork it.

[`references/worktree-feature-branching.md`](references/worktree-feature-branching.md) owns feature branch setup. The `/al-event-model` and `/al-design` SKILL.mds own who runs it when. Both skills read the reference, so an edit to its routes or Stop conditions scans both SKILL.mds in the same change.

## Pipeline

[`references/overview.md`](references/overview.md) is the single source of truth for the pipeline: diagram, 18-skill catalogue, custom-agent table, slice cycle, and cold-start guidance. `/al-agentic-dev-overview` emits it verbatim. Edit it in lockstep with any skill or agent addition, removal, rename, or repurpose.

Per-skill mechanics live in the owning `SKILL.md`. Page-script recording, replay, and red classification live in `/al-page-script`. The verification spawns live in `/al-user-verification`. Report-only and `--fix` semantics live in `/al-code-review`. Replan trigger semantics live in [`references/task-lifecycle.md`](references/task-lifecycle.md). Status-flip and gate-open mechanics live in [`references/task-lifecycle.md`](references/task-lifecycle.md). Skills compose by name, so a change to one skill scans the others for cross-references and updates them in the same change.

## Editing rules

- **Preserve the call boundary.** `/al-build` is the only direct skill-to-skill call. BC research spawns `al-researcher`; the rubber-duck consult, other custom-agent spawns, and inline state writes are homed in [`references/overview.md`](references/overview.md). A skill edit that adds a cross-skill call or auto-chain contradicts that canon. Change the canon first.
- **Custom agent bodies are self-contained.** Skills and agents run in consumer projects where this AGENTS.md does not exist. The review lenses carry their BC vocabulary in their own bodies. The spawning skill's invocation carries only the diff or scope.
- **Naming, BC vocabulary, and grounding are homed in [`references/GROUND-RULES.md`](references/GROUND-RULES.md).** That includes names-as-citation (no inline `file:line` citations in durable artifacts) and the `Researched:` carve-out. Writing skills read it before writing.
- **Four Return shapes deviate from the fixed line-1 label, each coupled to the callers that parse it.** Changing any of these shapes updates every parsing caller in the same change; never restyle one side alone.

  | Agent | Shape | Parsing callers |
  |---|---|---|
  | `al-researcher` | dynamic evidence verdict: `SINGLE-SOURCE` / `VERIFIED` / `CONFLICT` / `UNRESOLVED` on line 1, then quoted evidence and conditional Conflict/Limit fields | every skill or custom agent that needs BC knowledge beyond direct workspace reading |
  | `al-red-green` | `## Outcome note` leads with a dynamic verdict chosen from `GREEN` / `PUSH-UP` / `BLOCKED` | `/al-implement`, `/al-code-review --fix` |
  | the six `al-review-cr-*` lenses | zero or more labeled finding blocks under a fixed per-lens line-1 sentinel (`COMPLIANCE FINDINGS`, `CORRECTNESS FINDINGS`, `BC REVIEW FINDINGS`, `COMMENT AND HISTORY FINDINGS`, `PUBLIC-SURFACE FINDINGS`, `PERFORMANCE SCAN FINDINGS`) — the finding-block shape, not one fixed payload, is the contract | `/al-code-review`, `al-review-judge` |
  | `al-review-refactor-perf` | when the `al-performance` MCP is missing, exactly the one line `perf scan skipped: al-performance MCP not available` — no sentinel, no other line | `/al-refactor`, `al-review-judge` |

- **Spec artifacts are pure markdown, text-only.** The no-mermaid rule is homed in the `/al-design` and `/al-scope` skill bodies. Visual polish is a separate dev-server concern, never the spec's.
- **`architecture.md` is reshape-only. Per-task files carry the surgical-edit contract.** Both are homed in [`references/task-lifecycle.md`](references/task-lifecycle.md).
- **New skills need a stated gap.** Propose one only when no existing skill, task-file note, `al-researcher` result, or cross-cutting reference can absorb the need. Say so in one line.
- **Express intent and rationale, not enumerated skip conditions.** SKILLs and references state why a discipline exists and what problem it solves. The agent maps rationale to situation. Slot prescriptions, `_When earned:_` / `_Skip when:_` enumerations, and fill-in templates are rejected by name.
- **`al-debug-logging` owns runtime probes and its telemetry MCP.** It emits temporary `Session.LogMessage` events and queries Application Insights through its embedded `bc-telemetry-buddy` server. `/al-build` owns no telemetry capture or telemetry artifacts.
- **`al-researcher` owns canonical source lookup.** `microsoft/BCApps` paths, branch selection, search rules, `gh` commands, and fallback stay in `agents/al-researcher.agent.md`. Web access is only the raw-file fallback. No separately discoverable source agent may bypass the gateway.

## Reference layout

References sit in two tiers:

- Plugin-level shared, `references/` — read by two or more skills. Path from any SKILL.md: `../../references/<file>`. The five testing references live in the `references/testing/` subfolder; path from any SKILL.md: `../../references/testing/<file>`.
- Skill-local, `skills/<skill>/references/` — read by one skill only. Path from that SKILL.md: `references/<file>`.

A resource read by two or more skills lives at plugin level. A shared resource inside one skill's folder makes ownership unclear. Cross-skill paths (`../<skill>/references/<file>`) are a smell to be migrated.

| File | Tier | Purpose / readers / lockstep |
|---|---|---|
| `overview.md` | plugin-level | user-facing tour, emitted verbatim by `/al-agentic-dev-overview`; edit in lockstep with any skill or agent change |
| `GROUND-RULES.md` | plugin-level | the one always-on contract: output shape via the `i-have-adhd` skill, one-decision-per-question, grounding mechanics, BC vocabulary, house shapes, production-AL thrift; injected by the `sessionStart` hook, re-read by skills on invocation |
| `doc-integrity.md` | plugin-level | inline document-integrity check; run by the writing skills (`/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-steer`) before the gate report |
| `rubber-duck-review.md` | plugin-level | rubber-duck consult discipline; read by every skill that consults the duck |
| `testing/testability.md` | plugin-level | seams and test-double taxonomy; read by `/al-design`, `/al-implement`, `/al-refactor` |
| `testing/test-specification.md` | plugin-level | Test Specification / Verification Plan grammar; read by `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `testing/tdd.md` | plugin-level | TDD cycle axis incl. mutation operators; read by `/al-implement`, `/al-mutate` |
| `testing/test-strategy.md` | plugin-level | test-execution pyramid on the BC stack (the execution axis); read by `/al-build`, `/al-implement`, `/al-mutate`, `/al-refine`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `testing/test-layout.md` | plugin-level | two-peer-test-app layout and AL Runner capability map (the placement axis); read by `/al-scope`, `/al-refine`, `/al-implement`, `/al-refactor` |
| `task-lifecycle.md` | plugin-level | `tasks/` folder shape, surgical-edit floor, content routing by lifetime, and the eight replan triggers; read by `/al-design`, `/al-event-model`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-code-review`, `/al-user-verification`, `/al-mutate`, `/al-steer` |
| `examples/` (folder) | plugin-level | populated example artifacts; pattern-match source for writing skills |
| `cross-branch-numbering.md` | plugin-level | `NNN`/`NNNN` picking across parallel branches; read by `/al-design`, `/al-event-model`, `/al-grill-adr` |
| `worktree-feature-branching.md` | plugin-level | feature branch setup; read by `/al-event-model`, `/al-design` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue; read by `/al-design` |
| `LANGUAGE.md` | plugin-level | architectural vocabulary; read by `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-refactor`, `/al-code-review` |
| `CONTEXT.template.md` | plugin-level | materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `out-of-scope.template.md` | `/al-steer`-local | materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow.

## Runtime surface

The plugin is distributed via `.github/plugin/marketplace.json` and targets GitHub Copilot CLI. It ships 18 custom agents under `agents/`, invoked via the task tool by name. Each agent's `.agent.md` frontmatter pins its model — the single home; the repo-root `scripts/Validate-PluginStructure.ps1` checks every pin against its fleet map. [`references/overview.md`](references/overview.md) carries the user-facing agent table. `al-researcher` alone owns the research MCPs and canonical BCApps lookup. The 15 other research-capable agents carry `agent` tool access and route facts through the gateway. `al-debug-logging` alone owns `bc-telemetry-buddy`.

SKILL.md bodies are injected verbatim and unexpanded, with no template variables. A skill locates its own files relative to the base directory announced at activation.

When authoring new plugin capability, default to a skill. Add a custom agent only when fan-out or context isolation earns it.

MCP-absence behavior is per-consumer, not uniform. The owning skill or agent states its fallback. Two exceptions:

- `al-red-green` blocks on a missing object-ID allocator.
- `al-review-refactor-perf` returns its skip line.

A blanket claim here would fork them.

Skills stay project-agnostic across consumer repos. A skill runs in any AL/BC project without hardcoding this marketplace's paths or a specific repo's layout. Soft guidance, not a CI gate.

### The one hook

`hooks/hooks.json` (Copilot native format, `"version": 1`) registers a single `sessionStart` hook. It reads `references/GROUND-RULES.md` via `$env:COPILOT_PLUGIN_ROOT` (PowerShell) or `$COPILOT_PLUGIN_ROOT` (bash, jq-or-node encoded) and emits it as `{"additionalContext": ...}`. Four couplings, all empirically verified:

- The PowerShell command keeps its `[Console]::OutputEncoding = UTF8` prefix. Without it, `pwsh -c` on Windows writes stdout in the legacy codepage. That mangles `→`/`—` and silently breaks the CLI's JSON parse, and the hook injects nothing.
- The compaction gap is accepted. `sessionStart` fires on new and resumed sessions only, never on compaction, and `preCompact` cannot inject. The recovery path is skills re-reading the file on invocation.
- The hook only injects, never verifies. Enforcement stays prompt-resident, matching the plugin's all-advisory model. It fails open: a missing file or missing jq/node emits nothing and the session proceeds.
- The hook never restates the rules. It reads the one file, so there is no second copy to drift.

Adding a second hook is a deliberate decision, not a default.

## Layout

```
agents/                          # Shipped custom agents (18; each pins its model in frontmatter)
├── al-red-green.agent.md            # One AAA case RED→GREEN
├── al-gate-runner.agent.md          # One authoritative gate run
├── al-mutant-cycle.agent.md         # One mutate→gate→revert cycle
├── al-design-option.agent.md        # One architecture candidate under a divergent constraint
├── al-researcher.agent.md           # One BC fact through isolated research tools
├── al-debug-logging.agent.md        # Temporary probes queried through Application Insights
├── al-review-cr-*.agent.md          # 6 /al-code-review lenses (compliance, bugscan, bc, comments, appsource, perf)
├── al-review-judge.agent.md         # Dedups/ranks one lens finding batch
└── al-review-refactor-*.agent.md    # 5 /al-refactor lenses (simplify, bc, structural, naming, perf)
hooks/
└── hooks.json                   # Sole hook: sessionStart injects references/GROUND-RULES.md; fail-open
references/                      # Plugin-level shared — see the Reference layout table
skills/
├── al-agentic-dev-overview/SKILL.md  # Emits ../../references/overview.md verbatim
├── al-build/                    # Build/test gate; own AGENTS.md, config/, scripts/
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
