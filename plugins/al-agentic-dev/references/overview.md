# al-agentic-dev plugin overview

**You drive.** Composable AL/Business Central skills carry a feature idea to merge. Each skill ends by naming its handoff, and you invoke the next `/<skill-name>` yourself. Nothing auto-chains. Only two skills may be called directly by another skill: `/al-research` (verify a BC fact from authoritative sources) and `/al-build` (compile/publish/test). Skills also consult the harness-provided **rubber-duck agent** on non-trivial artifacts ([`rubber-duck-review.md`](rubber-duck-review.md)). Custom agents in `agents/` are `.agent.md` files spawned by skills — never slash commands, never invoked by you.

## Pipeline

```
/al-grill-adr  →  /al-event-model  →  /al-design     →  /al-scope                →  /al-refine    →  /al-implement   →  /al-refactor → /al-mutate →  /al-code-review  →  /al-user-verification
(CONTEXT,         (event-model.md,    (architecture    (tasks/ folder, slices +    (per-task        (TDD per task,     (reshape green,         (gate at slice-      (guides the user through
 ADRs)             user/API-facing     .md, AL-shape    technical + verify per     task specs)       red→green)         then validate rigor)    done + feature-done) the verify task; flip
                   only, backend-only  only)            user/API-facing slice)                                                                                         done or blocked → /al-steer)
                   skips this step)
```

Technical-task hardening: `/al-implement` (red→green, stop) → `/al-refactor` (reshape while green) → `/al-mutate` (test rigor) → slice gate. `/al-refactor` is strongly directed for non-trivial work. `/al-mutate` is for production lines no red ever forced — refactor reshapes, hard-to-test legacy — even inside a TDD'd task. Mutating red→green code only re-proves TDD. You decide when to run both.

| Lane | Skills |
|---|---|
| **Cross-cutting** (invoked from any main-pipeline skill or standalone) | `/al-research` (verify a BC fact from authoritative sources), the rubber-duck consult ([`rubber-duck-review.md`](rubber-duck-review.md)), `/al-steer`, `/al-sync-main` (rebase the branch onto main, mechanically renumber object/field collisions) |
| **Infrastructure** | `/al-build` (compile, publish, run tests), `/al-debug-logging` (transient `FeatureTelemetry.LogUsage` probes) |
| **Ops** (bracket the feature; run an `/al-build` script + flip task status) | `/al-provision` (`T-001`, refresh the build environment), `/al-validate-breaking-changes` (last, validate against the provisioned baseline) |
| **Shaping** (after `/al-implement` on a task, or standalone on legacy) | `/al-refactor`, `/al-mutate` |
| **Verification** (user-facing slices, after `/al-code-review` per-slice) | `/al-page-script` (guide the user to record framework-limited E2E), `/al-user-verification` (walk the rest + gate the slice) |
| **Meta** | `/al-agentic-dev-overview` (this skill), `/al-quiz` (quiz the developer on landed changes — keeps the human's mental model in contact with the codebase) |

`/al-scope` brackets the feature with `kind: provision` (`/al-provision`, the feature's first task) and `kind: breaking-change` (`/al-validate-breaking-changes`, the last) script-run ops tasks; both bypass `/al-refine`. Between them, run the slice cycle in this order:

1. `/al-refine` opens one `ready` task. Technical work stays `ready-for-implementation` while `phase:` advances: `/al-implement` stamps `implemented`, `/al-refactor` stamps `refactored`, and `/al-mutate`'s clean rigor verdict flips `status: done` stamping `mutated`; an early `done` waives remaining hardening.
2. Slice-done → `/al-code-review` before any user walk. A clean user/API review writes `review: clean` and opens the verify task `ready`; `/al-refine` then writes its `Verification Plan` → `ready-for-verification`.
3. `/al-page-script` records and fresh-container replays the `Record: yes` framework-limited E2E examples; `/al-user-verification` pre-flights them, runs Contract Examples, then walks the `Record: no` Journey Examples and Exploration Charters. Backend-only slices skip both.
4. Feature-done → per-feature `/al-code-review` before merge.

State lives in `specs/` and task frontmatter, never memory; every skill can start cold. The owner writes its `done` flips and unblocked dependents inline — state writes, not cross-skill calls.

## Skills

The plugin ships 20 skills.

| Skill | Role | When to invoke |
|---|---|---|
| `/al-agentic-dev-overview` | Tour of this plugin: pipeline, skills, persistence, cold-start. | "What is al-agentic-dev?", "show me the pipeline", "where do I start from scratch" (no `specs/` folder yet). Mid-feature "where are we?" goes to `/al-steer`. |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary against `CONTEXT.md`, cross-references intent with the codebase, offers domain ADRs only when a hard-to-reverse business rule earns one. | Idea is rough; you want it grilled before settling intent. |
| `/al-event-model` | User-facing journey: `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). | User- or API-facing feature, after `/al-grill-adr`. Backend-only features skip this. |
| `/al-design` | Feature architecture: `architecture.md`, from the idea or `event-model.md`. | After `/al-event-model` for user/API features, or after `/al-grill-adr` for backend-only. |
| `/al-scope` | Decomposes `architecture.md` into a slice-grouped `tasks/` folder, one verification task per slice when `event-model.md` is present, bracketed by the two ops tasks. | After `/al-design`, before `/al-provision` on the bracketed `T-001` task. |
| `/al-research` | Verify BC specifics from authoritative sources, quote them, return. Callable from a session and by another skill. | Two sources disagree, a fact lands in a durable design artifact, or a fuzzy BC question needs framing + cross-family verification. Single-fact lookups go direct. |
| `/al-provision` | Runs the `kind: provision` task: refresh the build environment (compiler, symbols, analyzers, and — when enabled — the breaking-change baseline) via `/al-build`'s `provision.ps1`, flip the task `done`/`blocked`. | Any `kind: provision` task at `ready`, or a re-run after you clear the named blocker. |
| `/al-validate-breaking-changes` | Runs the `kind: breaking-change` task: validate against the provisioned baseline via `validate-breaking-changes.ps1`, flip the task `done`/`blocked`; a detected break stops for a human. | The feature's last task, or a re-run after you clear the blocker from a failed run. |
| `/al-refine` | One `ready` task → fresh `Test Specification` (technical → `ready-for-implementation`) or `Verification Plan` (verify → `ready-for-verification`). | Before working a specific task. |
| `/al-implement` | TDD per technical task: Unit cases → Integration cases, red→green. Stops at green and hands off to `/al-refactor` then `/al-mutate`. | After `/al-refine` produces a `Test Specification`. One task per session. |
| `/al-refactor` | Reshape production and test code while tests stay green. No new behaviour. 5 review-lens subagents identify, the session applies with `/al-build` between. | After `/al-implement` takes a task to green (full task diff, once per task), or standalone on legacy code. |
| `/al-mutate` | Validate test rigor by injecting one mutation at a time: run the build gate, classify, revert, report killed/surviving/equivalent mutants. | The rigor step after `/al-refactor` for whatever arrived without a red, or standalone on legacy before `/al-refactor`. |
| `/al-user-verification` | Guides you through the verify task one scenario at a time, in chat, punchline first — runs containers, the recording pre-flight, and Contract checks; you walk the non-recorded Journey Examples in your browser and report what you see (ask-before-reveal). Functional outcomes gate, usability observations → findings/tasks. Gates the next slice. | Verify task is `ready-for-verification` carrying `review: clean` — `/al-code-review` ran clean at slice-done, then `/al-refine` wrote a fresh `Verification Plan`. |
| `/al-code-review` | Gate at slice-done and feature-done. Report-only by default: spawn review lenses, judge, rubber-duck-vet, then report the must-fix queue (→ `/al-implement`), nits, and the gate decision. `--fix` lands the must-fix findings in-loop (red-green subagent) and re-reviews once. | Auto-announced as the next step by `/al-implement` at slice-done (both slice types) and feature-done; or you ask for an in-depth review. |
| `/al-steer` | Coach and navigator. Reads the `tasks/` folder, the goal, the codebase, and recent commits; names what is next, blocked, or drifting; never edits code. Owns `.out-of-scope/` and `.not-yet-specified/`. Canonical replan venue. | "Where are we?", "what's next?", trigger fired in another skill. |
| `/al-sync-main` | Rebase the current branch onto `main` (never merges); mechanically renumbers any object/field number collisions introduced on this branch to the next free slot in their `idRanges` bucket. Full `/al-build` gate before and after. Stops and asks on any real content conflict, naming collision, or unsafe reference rewrite; aborts the rebase cleanly on any stop. | `main` has moved on and the branch needs to catch up before continuing work or opening a PR. |
| `/al-build` | Compile, publish, run tests; writes results to `.output/TestResults/<dirName>/`. | After modifying AL code or tests. Required gate before commit. |
| `/al-debug-logging` | Temporary `DEBUG-*` `FeatureTelemetry.LogUsage` probes; read `telemetry.jsonl`; remove probes. Final state: zero `DEBUG-*` in tree. | Runtime behaviour diverges from source and tests can't reveal which path ran. |
| `/al-quiz` | Quizzes *you* on recently landed changes, one question at a time in chat — proves your mental model of what shipped, or shows where it is wrong. Read-only, no gate. | After a long agentic run, before merging a feature, returning after time away, or standalone on any diff, slice, or object area you name. |
| `/al-page-script` | Guide the user to record the slice's framework-limited E2E Journey Examples (`Record: yes`) in BC's Page Scripting recorder — one scenario at a time, punchline first; the user records and downloads, the agent replays each on a fresh container and classifies reds. Reserved for behaviour no AL test layer can automate; commits on green. Produces the recordings `/al-user-verification` pre-flights. | After `/al-refine` writes a `Verification Plan` with `Record: yes` examples on a `review: clean` verify task (user-facing slice only). |

## Custom agents

The plugin ships 18 custom agents. The rubber-duck is not one of them — it is the harness-provided agent type reached through the task tool ([`rubber-duck-review.md`](rubber-duck-review.md)).

| Agent | Job | Invoked by |
|---|---|---|
| `al-red-green` | One AAA case RED→GREEN: write the failing test, confirm RED, write minimal production code, confirm GREEN, return an outcome note. No in-loop escalation. | `/al-implement` (per case), `/al-code-review --fix` (per must-fix finding) |
| `al-review-cr-compliance` | `/al-code-review` lens 1: project compliance, naming, scope, grounding, surface reconciliation. | `/al-code-review` |
| `al-review-cr-bugscan` | `/al-code-review` lens 2: correctness and obvious logic faults. | `/al-code-review` |
| `al-review-cr-bc` | `/al-code-review` lens 3: BC-specific anti-patterns via bc-code-intelligence MCP. | `/al-code-review` |
| `al-review-cr-comments` | `/al-code-review` lens 4: code-comment invariants + git history context. | `/al-code-review` |
| `al-review-cr-appsource` | `/al-code-review` lens 5: AppSource public-surface addition lock-in (per-feature only). | `/al-code-review` |
| `al-review-cr-perf` | `/al-code-review` lens 6: performance via al-performance MCP `scan_al_code`. | `/al-code-review` |
| `al-review-refactor-simplify` | `/al-refactor` lens 1: dedup, dead code, speculative generality. | `/al-refactor` |
| `al-review-refactor-bc` | `/al-refactor` lens 2: BC best-practice + platform-reinvention via bc-code-intelligence MCP. | `/al-refactor` |
| `al-review-refactor-structural` | `/al-refactor` lens 3: decision-logic boundary, depth over indirection, seam introduction. | `/al-refactor` |
| `al-review-refactor-naming` | `/al-refactor` lens 4: BC vocabulary + project terminology naming. | `/al-refactor` |
| `al-review-refactor-perf` | `/al-refactor` lens 5: performance via al-performance MCP, structural reshapes only. | `/al-refactor` |
| `al-review-judge` | Dedups, substantiates, and ranks one supplied batch of `/al-code-review` or `/al-refactor` lens findings against its scoped diff. | `/al-code-review`, `/al-refactor` |
| `bc-standard-reference` | Canonical BaseApp / System Application / Business Foundation / APIV2 lookup, quoting Microsoft's shipped AL from `microsoft/BCApps` version-matched to your app. | `/al-research` (its BaseApp source), `/al-debug-logging` (BaseApp events for probes); also consulted from `/al-event-model`, `/al-design`, `/al-scope`, `/al-refactor` |
| `al-researcher` | Arbitrates one framed consequential BC fact across source families, quoting evidence and reconciling disagreement. | `/al-research` |
| `al-design-option` | Develops one self-contained architecture candidate under a supplied divergent constraint — `/al-design` fans out three in parallel and chooses among them itself. | `/al-design` |
| `al-gate-runner` | Runs one supplied build, provision, or breaking-change gate command and relays its authoritative artifacts, no interpretation. | `/al-build`, `/al-provision`, `/al-validate-breaking-changes`, `/al-mutate` final closeout |
| `al-mutant-cycle` | Runs one supplied mutate→gate→revert cycle and returns observed evidence; the caller classifies the mutant. | `/al-mutate` |

## Persistence layers

**Repo-root artifacts outlive features; `specs/` artifacts live with one branch.**

| Layer | Contents and owner |
|---|---|
| Repo-root, durable | `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`, `.not-yet-specified/`. `/al-grill-adr` owns CONTEXT and domain ADRs; `/al-steer` owns `.out-of-scope/` and `.not-yet-specified/`. Writing skills run document-integrity on CONTEXT and ADR writes; the two dot-folders are outside that gate. |
| Branch-scoped | `specs/<NNN>-<slug>/event-model.md` for user/API features, `architecture.md`, and `tasks/`; slug matches the branch. |

The `tasks/` folder is the feature's work queue: the filesystem is the ordered manifest — one file per task plus a `000-feature.md` header — and `/al-steer` renders the board. File naming, frontmatter, and the status/phase lifecycle: [`task-lifecycle.md`](task-lifecycle.md).

## Cold-start: where do I begin from `main`?

**From the default branch with no `specs/<NNN>-<slug>/`, the feature's surface picks its route:**

- **User- or API-facing feature** → `/al-grill-adr` (grill the idea) → `/al-event-model` (settle the user-facing journey; creates the branch and spec folder) → `/al-design` → `/al-scope` → `/al-provision` on the bracketed `T-001` → `/al-refine` on the first technical task → `/al-implement`.
- **Backend-only feature** (no user/API surface) → `/al-grill-adr` → `/al-design` (skips event-model; creates the branch and spec folder) → `/al-scope` → `/al-provision` on the bracketed `T-001` → `/al-refine` on the first technical task → `/al-implement`.

Document-writing skills run inline document-integrity after each canonical write; it is not a cold-start step. A crystallised idea may skip `/al-grill-adr`; most benefit from it.

## State-aware navigation

**This static overview does not read your branch, `tasks/`, or commits.** For "where am I?", "what's next?", or a blocked task → `/al-steer`; it reads state and routes the next skill.
