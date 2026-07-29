# al-agentic-dev — neutral rebuild plan

Greenfield rewrite of the `al-agentic-dev` plugin into 17 harness-neutral Agent Skills. Written to be executed by a workflow: Phase 1 is 17 independent units, Phases 2–5 are serial.

## Outcome

A repo whose entire shipped surface is `skills/<name>/SKILL.md` — frontmatter `name` + `description` only — installable on Claude Code, Copilot CLI, VS Code Copilot, and Codex with one command:

```
npx skills add <owner>/<repo> --skill '*'
```

No custom agents. No hooks. No plugin manifests. No file crossing a skill-folder boundary. Prose target ~1,000 lines, down from ~4,300 today (skills 1,800 + references 1,600 + agents 900).

## Decisions locked

| # | Decision |
|---|---|
| 1 | Rebuild in this repo; rename it; archive `bc-agentic-dev-tools-marketplace` (the stale Claude-lineage fork, PR #17 vs #52) |
| 2 | Shipped surface is `skills/<name>/SKILL.md` at repo root. Delete `plugin.json`, `.github/plugin/marketplace.json`, version ceremony |
| 3 | Three reference mechanisms, no exceptions: shared behaviour → its own skill invoked **by name**; shared format → sibling file **inside** the owning skill; human docs → `docs/`, never loaded by an agent |
| 4 | Delete all 19 custom agents. Content collapses into the owning skill as prose |
| 5 | 17 skills. `al-page-script` merges into `al-user-verification`; `al-steer` is deleted; `al-next` is new |
| 6 | `al-steer`'s jobs: routing moves into skill *descriptions* written in task-state terms, plus `al-next`. `.out-of-scope/`, `.not-yet-specified/`, and the 8 replan-flag triggers are deleted outright |
| 6b | `al-next` never executes a skill. It is invoked at each skill's close and presents the option(s) |
| 7 | PowerShell scripts stay in `al-build/scripts/`, and **`al-build` is their sole invoker**. `al-provision`, `al-validate-breaking-changes`, and `al-user-verification` reach every script by calling `/al-build` **by name** — a skill reference, never a file path. They remain separate skills with their own descriptions and task-flipping logic |
| 8 | Keep `tests/al-build/*`, `Validate-Json.ps1`, `Validate-PowerShell.ps1`. Add ~60-line `Validate-Skills.ps1`. Delete 3,537 lines of prose-pinning and plugin-structure tests |
| 9 | Greenfield prose; substrate (`scripts/`, `config/`, `tests/al-build/`) moves byte-identical |
| 10 | `GROUND-RULES.md` splits by owner (see *Voice and rules* below) |

## Target layout

```
<repo-root>/
├── skills/
│   ├── al-agentic-dev-overview/   SKILL.md + AGENTS-SNIPPET.md
│   ├── al-next/                   SKILL.md
│   ├── al-grill-adr/              SKILL.md
│   ├── al-event-model/            SKILL.md + EVENT-MODEL-FORMAT.md
│   ├── al-design/                 SKILL.md + ARCHITECTURE-FORMAT.md + ADR-FORMAT.md + CONTEXT-FORMAT.md
│   ├── al-scope/                  SKILL.md + TASK-FORMAT.md
│   ├── al-refine/                 SKILL.md
│   ├── al-implement/              SKILL.md
│   ├── al-refactor/               SKILL.md
│   ├── al-mutate/                 SKILL.md
│   ├── al-code-review/            SKILL.md
│   ├── al-user-verification/      SKILL.md + RECORDING-FORMAT.md
│   ├── al-build/                  SKILL.md + config/ + scripts/*.ps1   ← moves verbatim
│   ├── al-provision/              SKILL.md
│   ├── al-validate-breaking-changes/ SKILL.md
│   ├── al-quiz/                   SKILL.md
│   └── al-sync-main/              SKILL.md
├── docs/                          human-facing: pipeline, per-skill notes, this plan
├── scripts/                       Validate-Skills.ps1, Validate-Json.ps1, Validate-PowerShell.ps1
├── tests/al-build/                unchanged
├── .github/
│   ├── copilot-instructions.md    rewritten — single source of the dev-time rules
│   ├── instructions/
│   │   ├── skills.instructions.md      applyTo: skills/**/*.md
│   │   └── powershell.instructions.md  applyTo: **/*.ps1
│   └── workflows/ci.yml           updated
├── CLAUDE.md                      @-imports all three .github instruction files
├── AGENTS.md                      3 pointer lines, no duplicated content
├── REVIEW.md                      generated copy of the directives, verbatim
└── README.md
```

Deleted: `plugins/`, `agents/`, `hooks/`, `references/`, `.github/plugin/`, the two old `*.instructions.md` files, the 6 prose test suites, `Validate-PluginStructure.ps1`, `Test-MarkdownLinks.ps1`.

## Writing contract — binds every SKILL.md

Every rewrite unit must satisfy all of these. `Validate-Skills.ps1` enforces 1–3 mechanically.

1. **Frontmatter is exactly `name` and `description`.** No `allowed-tools`, `model`, `mcp-servers`, `user-invocable`, `disable-model-invocation`.
2. **No link leaves the skill folder.** No `../`, no absolute repo paths. Sibling files inside the folder only.
3. **`SKILL.md` exists and the folder name matches `name`.**
4. **The description carries the routing.** State the precondition in task-state terms — *"Use when a task is at `phase: implemented`"* — so the harness's own dispatcher can reach the skill. This replaces the deleted routing tables.
5. **Name other skills, never link to them.** `/al-build`, `/al-grilling`. A skill name is the whole reference. This is also how a skill reaches another skill's scripts — `/al-build` runs them, nobody else names a path into `al-build/scripts/`.
5b. **The task-file frontmatter field list is duplicated, deliberately.** `status:`, `phase:`, `kind:`, `slice:`, `depends_on:` and their allowed values are the bus between skills; every skill that reads or writes them carries the six-line list. `TASK-FORMAT.md` in `al-scope` owns the *body* shape only. Drift in a duplicated list fails loudly; drift from one owner nobody reads fails silently in `al-next`'s routing.
   **Superseded 2026-07-28:** the duplicated list produced exactly the silent-drift class it feared, six review rounds deep. Task state now has one home — `skills/al-routing/SKILL.md` — every other skill reports outcomes in plain words, and `Validate-Skills.ps1` fails a lifecycle field stated anywhere else. Rubric rule 29 inverted accordingly.
6. **No custom-agent names.** `al-researcher`, `al-red-green`, `al-gate-runner`, `al-review-*`, `al-mutant-cycle`, `al-design-option`, `al-debug-logging` do not exist. Where fan-out genuinely helps, one sentence: *"If your harness supports subagents, these parallelize; otherwise apply them in one pass."*
7. **No harness assumptions.** No `COPILOT_*` env vars, no `agent_type:`, no model names, no MCP server names. Tools are described by what they do ("search the workspace", "read Microsoft Learn"), not by tool id.
8. **Close by naming the outcome, then `/al-next`.** One line each. Not a table of conditional exits.
9. **No verification scaffolding.** Per the Opus 5 guide, drop "verify your work", "double-check", "re-read before responding" — the model does this already and the instruction causes over-verification.
10. **Body ≤ 60 lines** (≤ 80 for `al-implement`, `al-code-review`, `al-user-verification`, `al-build`). Cut to the decision the model can't make on its own; delete anything it would do by default.

## Voice and rules — where `GROUND-RULES.md` lands

| Section | New home |
|---|---|
| Output shape, chat thrift, house shapes | `al-agentic-dev-overview/AGENTS-SNIPPET.md`, installed at user level (below) |
| **Grounding** — every BC object/field/procedure name comes from a session-fresh lookup, never recall | ~5 lines inlined in `al-implement`, `al-refactor`, `al-code-review`, `al-design` |
| **BC vocabulary** — Insert not create, Post not submit, Ledger Entry not transaction | same four skills, same block |
| **Production-AL thrift** — platform first, no abstraction for one caller, name the ceiling | same four skills, same block |
| Gates | `al-build` |
| Task lifecycle, replan flags, `.out-of-scope/`, `.not-yet-specified/` | deleted |

**Snippet install** — `al-agentic-dev-overview` offers, on request, to write `AGENTS-SNIPPET.md` to `~/.agents/AGENTS.md` (canonical, forward-compatible with the emerging standard) and mirror it into a marked block in each file a harness actually reads today:

```
<!-- al-agentic-dev:start -->
…snippet…
<!-- al-agentic-dev:end -->
```

Targets: `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.copilot/copilot-instructions.md`. Re-running rewrites only the marked block. User level, never per-repo. When a harness adopts `~/.agents/AGENTS.md`, delete that mirror.

---

## Phase 0 — preflight (serial)

1. Branch `rebuild/neutral-skills` off `main`.
2. `git mv` the substrate to its new home: `plugins/al-agentic-dev/skills/al-build/{scripts,config}` → `skills/al-build/{scripts,config}`. No content edits.
3. Confirm `tests/al-build/*` still passes against the moved paths; fix path references only.

Done when: `Invoke-Pester tests/al-build` is green and no `.ps1` content changed.

## Phase 1 — 17 skill rewrites (parallel, one unit per skill)

Each unit is independent by construction — no skill references another skill's files. Each gets: the writing contract above, its source files, and its spec row.

| Skill | Source material | Carry | Drop |
|---|---|---|---|
| `al-agentic-dev-overview` | `references/overview.md`, old SKILL.md | pipeline picture, 17-skill catalogue, cold start, the snippet-install offer | agent table, persistence-layer prose, `/al-steer` routing |
| `al-next` | `al-steer` SKILL.md (routing section only) | read `tasks/`, name the viable move(s), present them | replan flags, ledgers, restructuring, status-board ceremony |
| `al-grill-adr` | old SKILL.md | domain interview, when an ADR is earned; `ADR-FORMAT.md` and `CONTEXT-FORMAT.md` live in `al-design` — name them, don't link | `user-involvement.md` contract, `.not-yet-specified/`, doc-integrity gate |
| `al-event-model` | old SKILL.md, `examples/event-model.example.md` | the journey interview, BC vocabulary of Role/Action/Business Event/View/Status; format + one example inline in `EVENT-MODEL-FORMAT.md` | doc-integrity gate, `/al-steer` exits |
| `al-design` | old SKILL.md, `examples/architecture.example.md`, `bc-patterns.md`, `adr.template.md`, `CONTEXT.template.md` | the design interview, candidate comparison; formats as three sibling files | `al-design-option` fan-out, rubber-duck consult, doc-integrity gate |
| `al-scope` | old SKILL.md, `task-grammar.md`, `task-lifecycle.md`, `examples/tasks/*` | decomposition into slices; `TASK-FORMAT.md` holds the task **body** shape — section order, table columns, two worked examples. The frontmatter field list is inlined per rule 5b | the 8 replan triggers, gated-open rules, `review: clean` strip mechanics |
| `al-refine` | old SKILL.md | one task → Test Specification or Verification Plan; read the shape from existing task files | `task-grammar.md` links, `al-second-opinion` |
| `al-implement` | old SKILL.md, `testing/tdd.md`, `testing/testability.md`, `testing/test-layout.md` | red→green per AAA case, Unit before Integration, the grounding block | `al-red-green` / `al-review-red` spawns, blind-RED gate, hash-frozen surface, 9 `/al-steer` exits |
| `al-refactor` | old SKILL.md, `references/legacy-refactor-plan.md` | reshape while green, `/al-build` between changes, the grounding block | four lens subagents, serial-apply choreography |
| `al-mutate` | old SKILL.md | mutate one site, gate, classify, revert; killed/surviving/equivalent | `al-mutant-cycle` spawn |
| `al-code-review` | old SKILL.md, `review-lenses.md`, 13 `al-review-*.agent.md` | **one list of review dimensions** (correctness, assertions, coverage, BC patterns, AppSource, perf, structure, naming, comments, simplification), the rework/change-request split, the grounding block | 13 agent spawns, `al-review-judge`, rubber-duck veto, mode matrix |
| `al-user-verification` | old SKILL.md + all of `al-page-script`, `references/bc-replay-yaml-format.md`, `recorder-gestures.md` | the guided walk, one scenario at a time, ask-before-reveal, recording as a step; container spawns and replay go through `/al-build`; `RECORDING-FORMAT.md` holds the yml essentials | `/al-steer` handoffs, trigger #4/#8 flags, direct script paths |
| `al-build` | old SKILL.md | **the index of every script entry point** — `test.ps1`, `provision.ps1`, `validate-breaking-changes.ps1`, `pagescript-replay.ps1`, `new-bc-container.ps1`, `new-agent-container.ps1` — plus the green/red bar and **read `.output/TestResults/summary.json`, not raw output** (this replaces `al-gate-runner`'s context isolation) | agent spawn, `al-debug-logging` route |
| `al-provision` | old SKILL.md | check the task, run the provision gate **via `/al-build`**, flip the task `done` or `blocked` | `/al-steer` exits, direct script paths |
| `al-validate-breaking-changes` | old SKILL.md | check the task, run the breaking-change gate **via `/al-build`**, stop for a human on a break | `/al-steer` exits, direct script paths |
| `al-quiz` | old SKILL.md | one question at a time on the recent diff | GROUND-RULES opener |
| `al-sync-main` | old SKILL.md, `cross-branch-numbering.md` | rebase onto main, renumber object/field collisions, stop on anything needing a decision | GROUND-RULES opener |

Done when: every folder has a `SKILL.md` passing the writing contract, and its `description` states its precondition in task-state terms.

## Phase 2 — integration (serial, after Phase 1)

1. **Handoff line.** Every skill closes by naming its outcome and then `/al-next`. Verify all 17.
2. **Script invocation.** `al-build` documents every script entry point. `al-provision`, `al-validate-breaking-changes`, and `al-user-verification` call `/al-build` by name and declare it a prerequisite skill in one line. No `../` and no `scripts/` path appears outside `al-build`.
3. **Cross-skill names resolve.** Every `/al-*` named in any body is a skill in the set. **Superseded 2026-07-28:** the one external skill, `/grilling`, was vendored 1:1 as `/al-grilling` — no external skill names remain.
4. **`docs/`.** One page per skill mirroring mattpocock's `docs/<category>/<skill>.md`, plus the pipeline overview. Human-facing only.
5. **README.md.** Install command, the 17-skill list, the snippet-install note.

## Phase 3 — validation harness (serial)

1. Write `scripts/Validate-Skills.ps1` (~60 lines): frontmatter is exactly `name` + `description`; folder name matches `name`; `SKILL.md` present; **every relative link resolves inside the skill folder** (no `../`, no absolute paths).
2. Delete `tests/GroundRules.Tests.ps1`, `ReviewLenses.Tests.ps1`, `TaskGrammar.Tests.ps1`, `ResearchGateway.Tests.ps1`, `RedGreenGate.Tests.ps1`, `DebugTelemetryAgent.Tests.ps1`, `Validate-PluginStructure.Tests.ps1`, `Test-MarkdownLinks.Tests.ps1`, `scripts/Validate-PluginStructure.ps1`, `scripts/Test-MarkdownLinks.ps1`.
3. Update `ci.yml`: `Validate-Json` → `Validate-PowerShell` → `Validate-Skills` → `Invoke-Pester tests`.

## Phase 3b — PR review instructions (serial)

Every PR and every push to a PR is auto-reviewed by GitHub Copilot (ruleset-configured, "Review new pushes" on). Copilot code review reads `.github/copilot-instructions.md` and `.github/instructions/NAME.instructions.md` — **from the head branch**, so a PR that changes these files is reviewed under its own new rules.

Constraints GitHub states for these files, which shape how they're written: ~1,000-line cap; short imperative directives beat narrative; concrete correct-vs-incorrect examples work; and Copilot **ignores** external links, formatting demands, PR-summary changes, merge-blocking, and vague asks. That is why every principle below is inlined rather than cited.

1. Delete `.github/instructions/al-agentic-dev.instructions.md` and `al-build.instructions.md` — they describe the plugin layout being removed.
2. Rewrite `.github/copilot-instructions.md` to ~40 lines: what the repo is (a set of harness-neutral Agent Skills installed with `npx skills`), the shipped surface (`skills/<name>/SKILL.md`, frontmatter `name` + `description` only), what never ships (custom agents, hooks, plugin manifests, cross-folder links, harness-specific frontmatter), and the substrate that does (`skills/al-build/scripts/*.ps1`). No links out.
3. Write `.github/instructions/powershell.instructions.md`, `applyTo: "**/*.ps1"`: PowerShell 7.2+; every script exits non-zero on failure; no interactive prompts; paths quoted; a new script needs a Pester test under `tests/al-build/`.
4. Write `.github/instructions/skills.instructions.md` exactly as below.

````markdown
---
applyTo: "skills/**/*.md"
---

# Reviewing a skill

Every folder under `skills/` is an Agent Skill: a `SKILL.md` plus optional sibling files, read by Claude Code, GitHub Copilot, and Codex alike. Flag anything below.

## Portability — one skill, every harness

1. Frontmatter has exactly two keys, `name` and `description`. Flag `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`, `disable-model-invocation`.
2. The folder name equals `name`.
3. No relative link leaves the skill folder. Flag `](../`, `](/`, and any absolute path.
   - Correct: `See [TASK-FORMAT.md](TASK-FORMAT.md).`
   - Incorrect: `See [task-grammar.md](../../references/task-grammar.md).`
4. Another skill is named, never linked.
   - Correct: `Run the gate with /al-build.`
   - Incorrect: `Run [al-build](../al-build/SKILL.md).`
5. Scripts are run only by the skill that owns them. Outside `skills/al-build/`, flag any `.ps1` filename or `scripts/` path; the skill calls `/al-build` instead.
6. No harness-specific names. Flag environment variables such as `COPILOT_PLUGIN_ROOT`, custom agent names, model names such as `claude-opus-5` or `gpt-5`, MCP server ids, and `agent_type:`.
7. Tools are described by what they do.
   - Correct: `search the workspace for the object declaration`
   - Incorrect: `use the Grep tool`

## The description is the router

8. The description says what the skill does and the state that should trigger it, in terms the model can match against the work in front of it: `Use when a task is at phase: implemented`.
9. One trigger per distinct branch. Flag synonyms that rename a single branch.
10. Flag identity restated from the body. The description spends its budget on triggers.

## Length and density

11. A `SKILL.md` body is at most 60 lines — 80 for `al-implement`, `al-code-review`, `al-user-verification`, `al-build`. Flag anything longer and name what to cut.
12. Flag any sentence the model already obeys without it. "Be thorough", "think carefully", "read the file before editing" change nothing and cost tokens.
13. Flag one meaning stated in two places inside a skill. Each rule has one authoritative home.
14. Flag verification scaffolding: "verify your work", "double-check", "re-read before responding", "use a subagent to confirm". Models self-verify; the instruction produces over-verification and wasted tokens.
15. Flag a phase restated three ways where one familiar word carries it. Prefer a compact word the model already holds over a spelled-out triad.
16. Flag stale layers — a rule about a file, agent, or step that no longer exists.

## Say what to do, not what to avoid

17. Prefer the target behaviour to the prohibition; a ban names the thing it bans and makes it more available.
    - Correct: `Ask one question per message.`
    - Incorrect: `Don't ask several questions at once.`
    Keep a prohibition only where no positive phrasing exists, and pair it with what to do instead.

## Finishing

18. Each step ends on a condition that can be checked, and where it matters, an exhaustive one.
    - Correct: `every modified object appears in the change list`
    - Incorrect: `produce a change list`
19. A skill closes by naming its outcome, then `/al-next` — one line each. Flag a table of conditional exits.

## Reply shape a skill asks for

20. A skill that shapes the reply asks for: one sentence before the first tool call; a brief update only on an important finding or a change of direction; the outcome first when finishing, detail after.
21. Flag a skill that asks the model to announce each step before taking it.
22. Written artifacts match the length the task needs. Flag instructions to add summary sections, recaps, or boilerplate headings.

## Delegation

23. Delegation is for large, genuinely independent work. Flag a skill that spawns a subagent for work finishable in a few tool calls, or that spawns one to check its own output.
24. Where fan-out is optional, one sentence covers it: `If your harness supports subagents, these parallelize; otherwise apply them in one pass.`

## Task-file frontmatter is duplicated on purpose

25. `status:`, `phase:`, `kind:`, `slice:`, `depends_on:` and their allowed values appear in full in every skill that reads or writes a task file. Do not flag this as duplication. Flag a skill that writes a task file without the list, and flag any value outside it.

## AL correctness

26. A skill that writes AL carries the grounding rule: every BC object, table, field, procedure, event, or enum value name is confirmed by a lookup in the current session, never recalled. Flag its absence in `al-implement`, `al-refactor`, `al-code-review`, `al-design`.
27. Those same four carry BC vocabulary — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction — and production-AL thrift: reach for the platform before writing code, no interface with a single implementation, and name the ceiling on a deliberate shortcut.
````

5. Write a repo-root `CLAUDE.md` that **imports all three files**, so Claude Code — and every reviewer subagent, which receives the whole CLAUDE.md hierarchy — gets the directives themselves rather than a pointer to them. A sentence saying "read this file first" expands to nothing; `@` imports are expanded into context at launch.

   ```markdown
   @.github/copilot-instructions.md
   @.github/instructions/skills.instructions.md
   @.github/instructions/powershell.instructions.md
   ```

   All three paths sit inside the working directory, so they load with no approval dialog and survive compaction. Combined ~155 lines, inside the ~200-line guidance. `.github/copilot-instructions.md` remains the single source; `CLAUDE.md` holds no rules of its own.

6. Write a repo-root `AGENTS.md` for Codex and VS Code Copilot working on this repo. `AGENTS.md` has no import syntax, so it carries three pointer lines and no duplicated content: read `.github/copilot-instructions.md` before working here, read `.github/instructions/skills.instructions.md` before editing `skills/**/*.md`, read `.github/instructions/powershell.instructions.md` before editing any `.ps1`.

7. Write a repo-root `REVIEW.md` — read by Anthropic's managed Code Review and injected into every reviewer agent as the highest-priority block, above its default guidance. It cannot reference anything: `@` imports are not expanded and linked files are not read, so the directive list from `skills.instructions.md` is **pasted verbatim**. Add two lines that only `REVIEW.md` can set: escalate a violation of these directives from the default nit to **Important**, and skip findings under `skills/al-build/scripts/` that CI already covers. Note `/code-review` run locally does *not* read `REVIEW.md` — that path is covered by the `CLAUDE.md` imports in step 5.

8. Add a step to the `validate` job in `ci.yml` asserting that `skills.instructions.md` below its frontmatter appears as a contiguous verbatim block **inside** `REVIEW.md` — containment, not equality, since `REVIEW.md` adds its own severity and skip lines around it:

   ```powershell
   $src = (Get-Content .github/instructions/skills.instructions.md -Raw) -replace '(?s)^---.*?---\r?\n'
   if ((Get-Content REVIEW.md -Raw) -notlike "*$src*") {
     throw "REVIEW.md is out of sync with skills.instructions.md"
   }
   ```

   `REVIEW.md` is a generated copy by necessity. Without this, an edit to the source silently leaves Claude's reviewers enforcing the old rules while Copilot's enforce the new ones.

Note the layering: these files are **dev-time only**. They govern work *on* this repo and never ship. No `SKILL.md` may reference them.

Reviewer coverage this produces:

| Reviewer | Reaches the directives via |
|---|---|
| GitHub Copilot code review (every PR and push) | `.github/copilot-instructions.md` + `skills.instructions.md` |
| Claude `/code-review` (local) | `CLAUDE.md` imports |
| Claude managed Code Review (GitHub App) | `REVIEW.md`, at Important severity |
| ultrareview (`/code-review ultra`) | undocumented; the bundle carries `CLAUDE.md` and `REVIEW.md`, so no extra work — verify empirically on the first PR |

Done when: a PR touching `skills/` draws Copilot review comments citing these rules; no instruction file contains an `http` link; `CLAUDE.md` appears under **Memory files** in `/context`; and the `REVIEW.md` drift check passes.

## Phase 4 — demolition (one commit)

Delete `plugins/`, `.github/instructions/`, `.github/plugin/`. Confirm nothing outside `skills/`, `docs/`, `scripts/`, `tests/` ships.

## Phase 5 — release (serial)

1. Rename the repo and update remotes.
2. Tag a release so consumers can pin — `npx skills add <owner>/<repo>@<tag>` is supported; plain `<owner>/<repo>` tracks default-branch HEAD.
3. Install end-to-end into one real AL project and run one full slice.
4. Archive `bc-agentic-dev-tools-marketplace`.

## Acceptance

- `npx skills add <owner>/<repo> --skill '*'` installs every skill in the set; each is invocable in Claude Code, Copilot CLI, VS Code Copilot, and Codex.
- Installing a **single** skill works — no skill references a *file* it doesn't own. `al-provision`, `al-validate-breaking-changes`, and `al-user-verification` declare `/al-build` as a prerequisite *skill*; that is a name, not a path.
- `Validate-Skills.ps1` passes; `Invoke-Pester tests` passes.
- `grep -rE '\]\(\.\./' skills/` returns nothing.
- `grep -rn 'scripts/' skills/ --include=SKILL.md` hits `al-build` only.
- No `SKILL.md` mentions `.github/`, `CLAUDE.md`, or `AGENTS.md` — the dev-time layer never leaks into the shipped layer.
- A PR touching `skills/` draws Copilot review comments citing `skills.instructions.md`; the instruction files contain no `http` links.
- `grep -rE 'COPILOT_|al-review-|al-researcher|al-red-green|al-gate-runner|allowed-tools|mcp-servers' skills/` returns nothing.
- One full slice — grill → event model → design → scope → provision → refine → implement → refactor → mutate → review → verify — runs on a real AL repo without a missing reference.

## Deferred — decide at execution time

1. ~~**New repo name.**~~ **Done 2026-07-28: `gtm-general/al-agentic-dev`**, renamed from `gtm-bc-copilot-cli-playbook`, with the description updated off "plugins for GitHub Copilot CLI". GHES keeps a redirect from the old name, and nothing had been installed yet, so the change is clean. Still to do: rename the **local working folder**, which is separately named `bc-agentic-dev-tools-marketplace-for-copilot` — that moves the Claude Code auto-memory path with it.
2. ~~**Repo host.**~~ **Decided 2026-07-28: stays on `9altitudes.ghe.com`** (`gtm-general/al-agentic-dev`). Install uses the **full URL**, which is host-independent — verified: it resolved a `github.com` URL correctly while the local `gh` default host was GHE. `GH_HOST` appears only in the pinning instructions, because `@tag` is parsed on the shorthand alone, and it is scoped to the one command there: a consumer's `gh` default is their own, and a left-over `GH_HOST` would misroute their next install. `npx skills update` needs no host handling — the lockfile stores each skill's fully resolved source URL.
3. **Release mechanism.** Plain git tags, or changesets + a release workflow as mattpocock uses.
4. **`agents/openai.yaml` sidecar per skill.** Three lines of Codex UI metadata inside each folder — violates nothing, and every third-party skill you have installed ships one. Skipping it is a defensible read of "bare minimum"; no consequence either way.

## External dependencies, declared

~~`/grilling` (from `mattpocock/skills`) is the one skill expected from outside this repo.~~ **Superseded 2026-07-28: vendored 1:1 as `skills/al-grilling/`** (its `agents/openai.yaml` sidecar dropped as harness-specific), making the set self-contained and the dependency CI-checkable. `/al-grill-adr`, `/al-event-model`, `/al-design`, and `/al-refine` escalate to `/al-grilling` when an answer itself needs pressure, per the Q3 rule that shared behaviour becomes a named skill rather than duplicated prose.

## Known losses, accepted

- Per-agent model pinning (`claude-opus-5` / `fable` / `sonnet`) — not expressible neutrally.
- Guaranteed parallel fan-out of the 13 review lenses — becomes one pass unless the harness offers subagents and the model chooses to use them.
- The deferred-question and out-of-scope ledgers, and the 8 replan triggers.
- Hook-injected ground rules on session start — replaced by the user-level snippet.
