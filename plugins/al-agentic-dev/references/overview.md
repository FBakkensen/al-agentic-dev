# al-agentic-dev plugin overview

Composable AL/Business Central skills, idea → merge. **You drive:** each skill names its handoff; you invoke `/<skill-name>`; nothing auto-chains. Only `/al-research` (BC fact escalation) and `/al-build` (compile/publish/test) are direct skill calls. Non-trivial artifacts also consult the autonomous **rubber-duck agent** ([`rubber-duck-review.md`](rubber-duck-review.md)); custom agents in `agents/` are `.agent.md` workers, never slash commands or directly invoked by you.

## Pipeline

```
/al-grill-adr  →  /al-event-model  →  /al-design     →  /al-scope                →  /al-refine    →  /al-implement   →  /al-refactor → /al-mutate →  /al-code-review  →  /al-user-verification
(CONTEXT,         (event-model.md,    (architecture    (tasks/ folder, slices +    (per-task        (TDD per task,     (reshape green,         (gate at slice-      (guides the user through
 ADRs)             user/API-facing     .md, AL-shape    technical + verify per     task specs)       red→green)         then validate rigor)    done + feature-done) the verify task; flip
                   only, backend-only  only)            user/API-facing slice)                                                                                         done or blocked → /al-steer)
                   skips this step)
```

Each `→` is your handoff. Technical-task cycle: `/al-implement` (red→green, stop) → `/al-refactor` (reshape while green) → `/al-mutate` (test rigor) → slice gate. `/al-refactor` is strongly directed for non-trivial work; `/al-mutate` for work without a red; you decide when to run both.

| Lane | Skills |
|---|---|
| **Side-band** (invoked from any main-pipeline skill or standalone) | `/al-research` (BC fact escalation) — one of the two skills another skill may call directly (with `/al-build`); the rubber-duck consult ([`rubber-duck-review.md`](rubber-duck-review.md)); plus `/al-steer`, `/al-sync-main` (rebase the branch onto main, mechanically renumber object/field collisions) |
| **Infrastructure** | `/al-build` (compile, publish, run tests — the other skill another skill may call), `/al-debug-logging` (transient `FeatureTelemetry.LogUsage` probes) |
| **Ops** (bracket the feature; run an `/al-build` script + flip task status) | `/al-provision` (`T-001`, refresh the build environment), `/al-validate-breaking-changes` (last, validate against the released baseline) |
| **Shaping** (after `/al-implement` on a task, or standalone on legacy) | `/al-refactor`, `/al-mutate` |
| **Verification** (user-facing slices, after `/al-code-review` per-slice) | `/al-page-script` (guide the user to record framework-limited E2E), `/al-user-verification` (walk the rest + gate the slice) |
| **Meta** | `/al-agentic-dev-overview` (this skill), `/al-quiz` (quiz the developer on landed changes — keeps the human's mental model in contact with the codebase) |

`/al-refine` opens one `ready` task. Technical work stays `ready-for-implementation` while `phase:` advances: `/al-implement` → `implemented`, `/al-refactor` → `refactored`, `/al-mutate` → `done` on a clean rigor verdict; early done waives remaining hardening. Slice-done → `/al-code-review` before any user walk. A clean user/API review writes `review: clean`, opens verify `ready`, then `/al-refine` writes `Verification Plan` → `ready-for-verification`. `/al-page-script` records and fresh-container replays `Record: yes` framework-limited E2E examples; `/al-user-verification` pre-flights them, runs Contract Examples, then walks `Record: no` Journey Examples and Exploration Charters. Backend-only slices skip both. `/al-scope` brackets the feature with `kind: provision` (`/al-provision`) and `kind: breaking-change` (`/al-validate-breaking-changes`) script-run ops tasks; both bypass `/al-refine`. Feature-done → per-feature `/al-code-review` before merge.

State lives in `specs/` and task frontmatter, never memory; every skill can start cold. The owner writes its `done` flips and unblocked dependents inline — state writes, not cross-skill calls.

## Skills

| Skill | Role | When to invoke |
|---|---|---|
| `/al-agentic-dev-overview` | Tour of this plugin: pipeline, skills, persistence, cold-start. | "What is al-agentic-dev?", "show me the pipeline", "where do I start". |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only when a hard-to-reverse business rule earns one. | Idea is rough; you want it grilled before settling intent. |
| `/al-event-model` | User-facing journey: `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). | User- or API-facing feature, after `/al-grill-adr`. Backend-only features skip this. |
| `/al-design` | Feature architecture: `architecture.md`. Module map, BC patterns, R → P → W boundary, brownfield touchpoints, test strategy. | After `/al-event-model` for user/API features, or after `/al-grill-adr` for backend-only. |
| `/al-scope` | Decomposes `architecture.md` into a slice-grouped `tasks/` folder, one file per task, bracketed by a `provision` first task and a `breaking-change` last task. | After `/al-design`. |
| `/al-research` | Verify BC specifics from authoritative sources, quote them, return — the evidence-bar escalation seat. Callable from a session and by another skill. | Two sources disagree, a fact lands in a durable design artifact, or a fuzzy BC question needs framing + independent verification. Single-fact lookups go direct. |
| `/al-provision` | Runs the `kind: provision` task: refresh the build environment via `/al-build`'s `provision.ps1`, flip the task `done`/`blocked`. | The feature's first task, or any `kind: provision` task at `ready`. |
| `/al-validate-breaking-changes` | Runs the `kind: breaking-change` task: validate the feature against the released baseline via `validate-breaking-changes.ps1`; a detected break stops for a human. | The feature's last task, once all other work is `done`. |
| `/al-refine` | One task → `Test Specification` or `Verification Plan`. | Before working a specific task. |
| `/al-implement` | TDD per technical task: Unit cases → Integration cases, red→green. Stops at green and hands off to `/al-refactor` then `/al-mutate`. | After `/al-refine` produces a `Test Specification`. |
| `/al-refactor` | Improve shape while green. No new behaviour. 5 review-lens subagents identify, the session applies. | After `/al-implement` takes a task to green, or standalone on legacy code. |
| `/al-mutate` | Validate test rigor by injecting mutations one at a time. | The rigor step after `/al-refactor` for whatever arrived without a red, or standalone on legacy before `/al-refactor`. |
| `/al-user-verification` | Guides you through the verify task one scenario at a time, in chat, punchline first — runs containers, the recording pre-flight, and Contract checks; you walk the non-recorded Journey Examples in your browser and report what you see (ask-before-reveal). Functional outcomes gate, usability observations → findings/tasks. Gates the next slice. | Verify task is `ready-for-verification` carrying `review: clean` — `/al-code-review` ran clean at slice-done, then `/al-refine` wrote a fresh `Verification Plan`. |
| `/al-code-review` | Gate at slice-done and feature-done. Report-only by default: spawn review lenses, judge, rubber-duck-vet, then report the must-fix queue (→ `/al-implement`), nits, and the gate decision. `--fix` lands the must-fix findings in-loop (red-green subagent) and re-reviews once. | Auto-announced as the next step by `/al-implement` at slice-done (both slice types) and feature-done. |
| `/al-steer` | Coach and navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/` and `.not-yet-specified/`. Canonical replan venue. | "Where are we?", "what's next?", trigger fired in another skill. |
| `/al-sync-main` | Rebase the current branch onto `main` (never merges); mechanically renumbers any object/field number collisions introduced on this branch to the next free slot in their `idRanges` bucket. Full `/al-build` gate before and after. Stops and asks on any real content conflict, naming collision, or unsafe reference rewrite; aborts the rebase cleanly on any stop. | `main` has moved on and the branch needs to catch up before continuing work or opening a PR. |
| `/al-build` | Compile, publish, run tests; writes results to `.output/TestResults/<dirName>/`. | After modifying AL code or tests. Required gate before commit. |
| `/al-debug-logging` | Temporary `DEBUG-*` `FeatureTelemetry.LogUsage` probes; read `telemetry.jsonl`; remove probes. Final state: zero `DEBUG-*` in tree. | Runtime behaviour diverges from source and tests can't reveal which path ran. |
| `/al-quiz` | Quizzes *you* on recently landed changes, one question at a time in chat — proves your mental model of what shipped, or shows where it is wrong. Read-only, no gate. | After a long agentic run, before merging a feature, or returning after time away. |
| `/al-page-script` | Guide the user to record the slice's framework-limited E2E Journey Examples (`Record: yes`) in BC's Page Scripting recorder — one scenario at a time, punchline first; the user records and downloads, the agent replays each on a fresh container and classifies reds. Reserved for behaviour no AL test can automate; commits on green. Produces the recordings `/al-user-verification` pre-flights. | After `/al-refine` writes a `Verification Plan` with `Record: yes` examples on a `review: clean` verify task (user-facing slice only). |

## Custom agents

Skills invoke fixed `.agent.md` workers under `agents/`; they are not slash commands and you never call them directly. Each agent fixes `tools:`, `model:`, and `user-invocable: false` in frontmatter — no invocation override or substitution. The fleet is **18**: **10** workers (`claude-sonnet-5` default), **5** smart agents (`claude-fable-5`: `al-design-option`, `al-review-cr-bugscan`, `al-review-refactor-bc`, `al-review-refactor-simplify`, `al-review-refactor-structural`), **2** arbiters (`claude-opus-4.8`: `al-researcher`, `al-review-judge`), and **1** bounded executor (`gpt-5.6-luna`: `al-gate-runner`). [`delegation.md`](delegation.md) owns the map.

| Agent | Role | Invoked by |
|---|---|---|
| `al-red-green` | One AAA case RED→GREEN: write the failing test, confirm RED, write minimal production code, confirm GREEN, return an outcome note. Fixed worker role — no in-loop escalation. | `/al-implement` (per case), `/al-code-review --fix` (per must-fix finding) |
| `al-review-cr-compliance` | `/al-code-review` lens 1: project compliance, naming, scope, evidence bar, surface reconciliation. | `/al-code-review` |
| `al-review-cr-bugscan` | `/al-code-review` lens 2: shallow scan for large correctness bugs. | `/al-code-review` |
| `al-review-cr-bc` | `/al-code-review` lens 3: BC-specific anti-patterns via bc-code-intelligence MCP. | `/al-code-review` |
| `al-review-cr-comments` | `/al-code-review` lens 4: code-comment invariants + git history context. | `/al-code-review` |
| `al-review-cr-appsource` | `/al-code-review` lens 5: AppSource public-surface addition lock-in (per-feature only). | `/al-code-review` |
| `al-review-cr-perf` | `/al-code-review` lens 6: performance via al-performance MCP `scan_al_code`. | `/al-code-review` |
| `al-review-refactor-simplify` | `/al-refactor` lens 1: dedup, dead code, over-build. | `/al-refactor` |
| `al-review-refactor-bc` | `/al-refactor` lens 2: BC best-practice + platform-reinvention via bc-code-intelligence MCP. | `/al-refactor` |
| `al-review-refactor-structural` | `/al-refactor` lens 3: R→P→W boundary, depth over indirection, seam introduction. | `/al-refactor` |
| `al-review-refactor-naming` | `/al-refactor` lens 4: BC vocabulary + project terminology naming. | `/al-refactor` |
| `al-review-refactor-perf` | `/al-refactor` lens 5: performance via al-performance MCP, structural reshapes only. | `/al-refactor` |
| `al-review-judge` | Dedups, substantiates, and ranks one supplied batch of `/al-code-review` or `/al-refactor` lens findings against its scoped diff. Arbiter role. | `/al-code-review`, `/al-refactor` |
| `bc-standard-reference` | Canonical BaseApp / System Application / APIV2 lookup, quoting Microsoft's shipped AL from `microsoft/BCApps` version-matched to your app. | `/al-research` names it as its BaseApp source |
| `al-researcher` | Arbitrates one framed consequential BC fact across source families, quoting evidence and reconciling disagreement. Arbiter role. | `/al-research` |
| `al-design-option` | Develops one self-contained architecture candidate under a supplied divergent constraint. Smart role — `/al-design` fans out three in parallel and chooses among them itself. | `/al-design` |
| `al-gate-runner` | Runs one supplied build, provision, or breaking-change gate command and relays its authoritative artifacts, no interpretation. Bounded-executor role. | `/al-build`, `/al-provision`, `/al-validate-breaking-changes`, `/al-mutate` final closeout |
| `al-mutant-cycle` | Runs one supplied mutate→gate→revert cycle and returns observed evidence; the caller classifies the mutant. Worker role. | `/al-mutate` |

`al-doc-verify` is now an inline check: `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, and `/al-steer` verify canonical artifacts against `references/doc-integrity.md` before gate reporting.

## Persistence layers

| Layer | Contents and owner |
|---|---|
| Repo-root, durable | `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`, `.not-yet-specified/`. `/al-grill-adr` owns CONTEXT and domain ADRs; `/al-steer` owns out-of-scope and the deferred-question ledger. Writing skills run document-integrity on CONTEXT and ADR writes; the two dot-folders are outside that gate. |
| Branch-scoped | `specs/<NNN>-<slug>/event-model.md` for user/API features, `architecture.md`, and `tasks/`; slug matches the branch. |

`tasks/` contains `000-feature.md` (Goal and slice intent, no status) plus `NNN-T-MMM-<slug>.md` task files. `NNN` is gapped run order; `T-MMM` is monotonic and never reused. YAML frontmatter holds `task:`, `status:`, `slice:`, `kind:`, `depends_on:`, `refactors:`, `fixes:`, `blocked-on:` while blocked, and `deviations:` for absorbed assumptions. Status is `ready`, `ready-for-implementation`, `ready-for-verification`, `blocked`, or `done`; `ready` awaits `/al-refine`, executable work uses the two ready-for states. `kind:` is `technical`, per-slice `verify`, or bracketing `provision` / `breaking-change` (script + status flip; no `/al-refine`). A clean per-slice review writes transient `review: clean` as it opens verify `ready`; it survives refine to `ready-for-verification` and strips on `blocked`, `done`, or new same-slice technical work. The filesystem is the manifest; `/al-steer` renders the board. Task files are agent-facing.

## Cold-start: where do I begin from `main`?

From the default branch with no `specs/<NNN>-<slug>/`:

- **User- or API-facing feature** → `/al-grill-adr` (grill the idea) → `/al-event-model` (settle the user-facing journey; creates the branch and spec folder) → `/al-design` → `/al-scope` → `/al-refine` on first task → `/al-implement`.
- **Backend-only feature** (no user/API surface) → `/al-grill-adr` → `/al-design` (skips event-model; creates the branch and spec folder) → `/al-scope` → `/al-refine` on first task → `/al-implement`.

Document-writing skills run inline document-integrity after each canonical write; it is not a cold-start step. A crystallised idea may skip `/al-grill-adr`; most benefit from it.

## State-aware navigation

This static overview does not read your branch, `tasks/`, or commits. For "where am I?", "what's next?", or a blocked task → `/al-steer`; it reads state and routes the next skill.
