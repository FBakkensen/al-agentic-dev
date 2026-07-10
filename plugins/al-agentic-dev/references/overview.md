# al-agentic-dev plugin overview

Composable skills for AL/Business Central agentic development. One feature flows idea → merge through a pipeline of named skills, each owning a specific cut of the work. **You drive the pipeline:** every skill ends by naming the next natural step, and you invoke it by typing `/<skill-name>` — nothing auto-chains. A skill calls another skill only in two cases: `/al-research` (BC fact escalation) and `/al-build` (compile/publish/test); non-trivial artifacts additionally get an autonomous consult of the **rubber-duck agent** (an independent read a worker model leans on mid-step — [`rubber-duck-review.md`](rubber-duck-review.md)). Everything else is a handoff you take. Skills also invoke lightweight **custom agents** (review lenses, the red-green worker) under `agents/` — real `.agent.md` definitions, not slash commands, never invoked by you directly.

## Pipeline

```
/al-grill-adr  →  /al-event-model  →  /al-design     →  /al-scope                →  /al-refine    →  /al-implement   →  /al-refactor → /al-mutate →  /al-code-review  →  /al-user-verification
(CONTEXT,         (event-model.md,    (architecture    (tasks/ folder, slices +    (per-task        (TDD per task,     (reshape green,         (gate at slice-      (guides the user through
 ADRs)             user/API-facing     .md, AL-shape    technical + verify per     task specs)       red→green)         then validate rigor)    done + feature-done) the verify task; flip
                   only, backend-only  only)            user/API-facing slice)                                                                                         done or blocked → /al-steer)
                   skips this step)
```

Each `→` is a handoff the finishing skill names and **you** take; no step launches the next. Per technical task the inner cycle is `/al-implement` (red→green, stops at green) → `/al-refactor` (reshape while green) → `/al-mutate` (validate test rigor) → the slice gate. `/al-refactor` is strongly directed for non-trivial work, `/al-mutate` for whatever arrived without a red — but you decide whether and when to run them.

| Lane | Skills |
|---|---|
| **Side-band** (invoked from any main-pipeline skill or standalone) | `/al-research` (BC fact escalation) — one of the two skills another skill may call directly (with `/al-build`); the rubber-duck consult ([`rubber-duck-review.md`](rubber-duck-review.md)); plus `/al-steer`, `/al-sync-main` (rebase the branch onto main, mechanically renumber object/field collisions) |
| **Infrastructure** | `/al-build` (compile, publish, run tests — the other skill another skill may call), `/al-debug-logging` (transient `FeatureTelemetry.LogUsage` probes) |
| **Ops** (bracket the feature; run an `/al-build` script + flip task status) | `/al-provision` (`T-001`, refresh the build environment), `/al-validate-breaking-changes` (last, validate against the released baseline) |
| **Shaping** (after `/al-implement` on a task, or standalone on legacy) | `/al-refactor`, `/al-mutate` |
| **Verification** (user-facing slices, after `/al-code-review` per-slice) | `/al-page-script` (guide the user to record framework-limited E2E), `/al-user-verification` (walk the rest + gate the slice) |
| **Meta** | `/al-agentic-dev-overview` (this skill), `/al-quiz` (quiz the developer on landed changes — keeps the human's mental model in contact with the codebase) |

Slice mechanics: `/al-refine` opens one `ready` task at a time. Technical tasks become `ready-for-implementation`, then `/al-implement` drives them to `done` (green + reconciled). `/al-refactor` reshapes the task diff while green; `/al-mutate` validates the tests catch the decision logic. When a slice's technical tasks are done (slice-done), `/al-implement` announces `/al-code-review` per-slice — it reviews the code, not the user walk, so it runs before the verify task is opened. For a user/API-facing slice a clean review opens the verify track: code-review stamps `review: clean` and flips the verify task to `ready`; `/al-refine` writes its `Verification Plan` → `ready-for-verification`; then page-script/user-verification. `/al-page-script` guides you to record the slice's framework-limited E2E Journey Examples (those marked `Record: yes` — behaviour no AL test can automate) in BC's Page Scripting recorder, one scenario at a time, and replays each on a fresh container; then `/al-user-verification` pre-flights the recording batch, runs Contract Examples, and walks you through the non-recorded Journey Examples (`Record: no`) and Exploration Charters in your own browser before the next slice opens to `ready` for refinement. Backend-only slices skip page-script and user-verification, chaining through `/al-code-review` into the next slice. `/al-scope` brackets the feature with two ops tasks: a `kind: provision` task first (`/al-provision` refreshes the build environment — compiler, symbols, breaking-change baseline) and a `kind: breaking-change` task last (`/al-validate-breaking-changes` checks the feature against the released baseline before merge); both run a script and flip status, bypassing `/al-refine`. At feature-done (every task in feature `done`), `/al-code-review` fires per-feature before merge.

State handoff is the filesystem, never in-memory: every skill can be invoked cold from a session and reconstruct where it is from the `specs/` artifacts and task frontmatter. Status-frontmatter writes (a `done` flip, opening an unblocked dependent) are state writes the owning skill does inline — that is not a cross-skill call.

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

Skills invoke workers as real GitHub Copilot CLI custom agents — `.agent.md` files under `agents/`, each with fixed frontmatter (`tools:`, `model:`, `user-invocable: false`) and a fixed body; not slash commands, and never directly invoked by you. Model role is fixed at the Terra worker role except `al-review-cr-bugscan`, which is pinned smart for correctness judgment; [`delegation.md`](delegation.md) owns the map.

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
| `bc-standard-reference` | Canonical BaseApp / System Application / APIV2 lookup, quoting Microsoft's shipped AL from `microsoft/BCApps` version-matched to your app. | `/al-research` names it as its BaseApp source |


The former `al-doc-verify` worker is now an **inline check**: the writing skills (`/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-steer`) verify each canonical artifact against `references/doc-integrity.md` themselves before the gate report — no subagent.

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`, `.not-yet-specified/` (the deferred-question ledger, one file per question: in-scope questions that matter but can't be decided yet — `/al-grill-adr` and `/al-design` write them, `/al-refine` scans before speccing, `/al-steer` grooms until each question graduates to a decision or moves to `.out-of-scope/`). Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-steer` (out-of-scope and the deferred-question ledger). The writing skills run the inline document-integrity check on `CONTEXT.md` and domain ADR writes before handoff; `.out-of-scope/` and `.not-yet-specified/` are outside the document gate.
- **Branch-scoped, per in-flight feature**: `specs/<NNN>-<slug>/event-model.md` (present for user/API-facing features) + `architecture.md` + a `tasks/` folder. Slug matches the current git branch.

The `tasks/` folder holds one file per task plus a `000-feature.md` header (Goal + slice intent, no status). Each per-task file is `NNN-T-MMM-<slug>.md`: the `NNN` filename prefix is the run order (`ls tasks/` lists tasks as they execute, gapped by 10), `T-MMM` is a stable locator id. State and graph live in YAML frontmatter at the top of each file: `task:`, `status:`, `slice:`, `kind:`, `depends_on:`, `refactors:`, `fixes:`, plus `blocked-on:` (one-line block reason, present while `blocked`) and `deviations:` (one-line entries for assumptions the agent absorbed without asking). Status values: `ready`, `ready-for-implementation`, `ready-for-verification`, `blocked`, `done`. `ready` means ready for `/al-refine`; executable tasks use `ready-for-implementation` or `ready-for-verification`. `T-MMM` ids monotonic, never reused. `kind: verify` marks the per-slice user-verification task; `kind: technical` marks technical tasks; `kind: provision` / `kind: breaking-change` mark the bracketing ops tasks (run a script, flip status, no `/al-refine`). Verify tasks gain a transient `review: clean` frontmatter field when `/al-code-review` per-slice runs clean at slice-done (stamped as it opens the verify task to `ready`); it rides through the `/al-refine` flip to `ready-for-verification`, and strips on any flip to `blocked`/`done` or when new technical work opens in the slice. There is no index file — the filesystem is the manifest, the board is grepped on demand and rendered by `/al-steer`. Your standing view is `/al-steer` in chat: what's moving, what's blocked and why, which assumptions the agent absorbed, and what waits on you. Task files themselves are agent-facing; you should never need to open one.

## Cold-start: where do I begin from `main`?

You have an AL repo, no `specs/<NNN>-<slug>/` yet, on the default branch. The chain starts at:

- **User- or API-facing feature** → `/al-grill-adr` (grill the idea) → `/al-event-model` (settle the user-facing journey; creates the branch and spec folder) → `/al-design` → `/al-scope` → `/al-refine` on first task → `/al-implement`.
- **Backend-only feature** (no user/API surface) → `/al-grill-adr` → `/al-design` (skips event-model; creates the branch and spec folder) → `/al-scope` → `/al-refine` on first task → `/al-implement`.

The inline document-integrity check runs inside the document-writing skills after each canonical markdown write, not as a standalone cold-start step.

If the idea is already crystallised, skip `/al-grill-adr`. Most features benefit from it.

## State-aware navigation

This overview is static; it does not read your branch, the `tasks/` folder, or recent commits. For "where am I now?" / "what should I do next?" / "T-007 is blocked, walk me through it", invoke `/al-steer`. It reads state, names the next step, routes to the right skill.
