# al-agentic-dev plugin overview

**You drive.** Composable AL/Business Central skills carry a feature idea to merge. Each pipeline skill ends by naming its handoff, and you invoke the next `/<skill-name>` yourself; nothing auto-chains. `/al-build` is the exception — a support skill the working skill invokes for you whenever it needs the gate, never a pipeline step awaiting your handoff. BC knowledge beyond direct workspace reading goes through the internal `al-researcher` custom agent. Runtime path uncertainty goes through the internal `al-debug-logging` custom agent. Skills also consult the harness-provided **rubber-duck agent** on non-trivial artifacts ([`rubber-duck-review.md`](rubber-duck-review.md)). Custom agents in `agents/` are spawned programmatically — never slash commands, never invoked by you.

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
| **Cross-cutting** (invoked from any main-pipeline skill or standalone) | the internal `al-researcher` gateway, the internal `al-debug-logging` runtime-probe agent, the rubber-duck consult ([`rubber-duck-review.md`](rubber-duck-review.md)), `/al-steer`, `/al-sync-main` (rebase the branch onto main, mechanically renumber object/field collisions) |
| **Infrastructure** | `/al-build` (compile, publish, run tests) |
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

The plugin ships 18 skills.

| Skill | Role | When to invoke |
|---|---|---|
| `/al-agentic-dev-overview` | Tour of this plugin: pipeline, skills, persistence, cold-start. | "What is al-agentic-dev?", "show me the pipeline", "where do I start from scratch" (no `specs/` folder yet). Mid-feature "where are we?" goes to `/al-steer`. |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary against `CONTEXT.md`, cross-references intent with the codebase, offers domain ADRs only when a hard-to-reverse business rule earns one. | Idea is rough; you want it grilled before settling intent. |
| `/al-event-model` | User-facing journey: `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). | User- or API-facing feature, after `/al-grill-adr`. Backend-only features skip this. |
| `/al-design` | Feature architecture: `architecture.md`, from the idea or `event-model.md`. A review-lens fleet reads the written artifact blind before the `/al-scope` handoff — 5 lenses in `architecture` mode — and a must-fix holds the gate. | After `/al-event-model` for user/API features, or after `/al-grill-adr` for backend-only. |
| `/al-scope` | Decomposes `architecture.md` into a slice-grouped `tasks/` folder, one verification task per slice when `event-model.md` is present, bracketed by the two ops tasks. | After `/al-design`, before `/al-provision` on the bracketed `T-001` task. |
| `/al-provision` | Runs the `kind: provision` task: refresh the build environment (compiler, symbols, analyzers, and — when enabled — the breaking-change baseline) via `/al-build`'s `provision.ps1`, flip the task `done`/`blocked`. | Any `kind: provision` task at `ready`, or a re-run after you clear the named blocker. |
| `/al-validate-breaking-changes` | Runs the `kind: breaking-change` task: validate against the provisioned baseline via `validate-breaking-changes.ps1`, flip the task `done`/`blocked`; a detected break stops for a human. | The feature's last task, or a re-run after you clear the blocker from a failed run. |
| `/al-refine` | One `ready` task → fresh `Test Specification` (technical → `ready-for-implementation`) or `Verification Plan` (verify → `ready-for-verification`). A review-lens fleet reads the artifact blind before the flip — 5 lenses on the specification, 3 on the plan — and a must-fix holds the gate. | Before working a specific task. |
| `/al-implement` | TDD per technical task: Unit cases → Integration cases, red→green. Stops at green and hands off to `/al-refactor` then `/al-mutate`. | After `/al-refine` produces a `Test Specification`. One task per session. |
| `/al-refactor` | Reshape production and test code while tests stay green. No new behaviour. 5 review-lens subagents identify, the session applies with `/al-build` between. | After `/al-implement` takes a task to green (full task diff, once per task), or standalone on legacy code. |
| `/al-mutate` | Validate test rigor by injecting one mutation at a time: run the build gate, classify, revert, report killed/surviving/equivalent mutants. | The rigor step after `/al-refactor` for whatever arrived without a red, or standalone on legacy before `/al-refactor`. |
| `/al-user-verification` | Guides you through the verify task one scenario at a time, in chat, punchline first — runs containers, the recording pre-flight, and Contract checks; you walk the non-recorded Journey Examples in your browser and report what you see (ask-before-reveal). Functional outcomes gate, usability observations → findings/tasks. Gates the next slice. | Verify task is `ready-for-verification` carrying `review: clean` — `/al-code-review` ran clean at slice-done, then `/al-refine` wrote a fresh `Verification Plan`. |
| `/al-code-review` | Gate at slice-done and feature-done. Report-only by default: spawn review lenses, judge, rubber-duck-vet, then report the must-fix queue (→ `/al-implement`), nits, and the gate decision. `--fix` lands the must-fix findings in-loop (red-green subagent) and re-reviews once. | Auto-announced as the next step by `/al-implement` at slice-done (both slice types) and feature-done; or you ask for an in-depth review. |
| `/al-steer` | Coach and navigator. Reads the `tasks/` folder, the goal, the codebase, and recent commits; names what is next, blocked, or drifting; never edits code. Owns `.out-of-scope/` and `.not-yet-specified/`. Canonical replan venue. | "Where are we?", "what's next?", trigger fired in another skill. |
| `/al-sync-main` | Rebase the current branch onto `main` (never merges); mechanically renumbers any object/field number collisions introduced on this branch to the next free slot in their `idRanges` bucket. Full `/al-build` gate before and after. Stops and asks on any real content conflict, naming collision, or unsafe reference rewrite; aborts the rebase cleanly on any stop. | `main` has moved on and the branch needs to catch up before continuing work or opening a PR. |
| `/al-build` | Compile, publish, run tests; writes results to `.output/TestResults/<dirName>/`. | Invoked by whichever skill or agent needs the gate — `/al-implement`, `/al-refactor`, `/al-mutate`, `/al-code-review`, `/al-sync-main`, `al-red-green`, `al-mutant-cycle`. The required gate before commit. |
| `/al-quiz` | Quizzes *you* on recently landed changes, one question at a time in chat — proves your mental model of what shipped, or shows where it is wrong. Read-only, no gate. | After a long agentic run, before merging a feature, returning after time away, or standalone on any diff, slice, or object area you name. |
| `/al-page-script` | Guide the user to record the slice's framework-limited E2E Journey Examples (`Record: yes`) in BC's Page Scripting recorder — one scenario at a time, punchline first; the user records and downloads, the agent replays each on a fresh container and classifies reds. Reserved for behaviour no AL test layer can automate; commits on green. Produces the recordings `/al-user-verification` pre-flights. | After `/al-refine` writes a `Verification Plan` with `Record: yes` examples on a `review: clean` verify task (user-facing slice only). |

## Custom agents

The plugin ships 19 custom agents. The rubber-duck is not one of them — it is the harness-provided agent type reached through the task tool ([`rubber-duck-review.md`](rubber-duck-review.md)).

| Agent | Job | Invoked by |
|---|---|---|
| `al-debug-logging` | Adds temporary `Session.LogMessage` probes, runs the supplied harness, and queries Application Insights through its embedded Telemetry Buddy MCP. Not user-invocable; every `DEBUG-*` probe must be gone before commit. | Any skill or custom agent blocked on an unresolved runtime path |
| `al-red-green` | One AAA case RED→GREEN: write the failing test, confirm RED, pass the blind RED gate, write minimal production code under a frozen test surface, confirm GREEN, return an outcome note. No in-loop escalation. | `/al-implement` (per case), `/al-code-review --fix` (per must-fix finding) |
| `al-review-red` | Rules `TRUE-RED` or `FALSE-RED` on one red beat, fresh every time, before the behaviour under test exists — so the party that wrote the test is never the party that grades it. Not a review lens: no mode, no judge. | `al-red-green` |
| `al-review-compliance` | Lens: project and domain compliance, BC/project naming, scope, grounding, surface reconciliation. Runs in every mode. | `/al-code-review`, `/al-refactor`, the design and refine gates |
| `al-review-coverage` | Lens: behaviour a plan or design claims and never proves. | the design and refine gates |
| `al-review-structural` | Lens: decision-logic boundary, depth over indirection, seam shape. | `/al-refactor`, the design and refine gates |
| `al-review-bc` | Lens: BC-specific anti-patterns and platform reinvention using `al-researcher` evidence. | `/al-code-review`, `/al-refactor`, the design gate |
| `al-review-perf` | Lens: performance via al-performance MCP `scan_al_code`. Read-only — it holds no fixer. | `/al-code-review`, `/al-refactor` |
| `al-review-appsource` | Lens: the AppSource contract — public-surface addition lock-in, base-app modification over interception, shipped-surface lifecycle (per-feature only under `/al-code-review`). | `/al-code-review`, the design gate |
| `al-review-bugscan` | Lens: correctness and obvious logic faults. | `/al-code-review` |
| `al-review-comments` | Lens: code-comment invariants + git history context. | `/al-code-review` |
| `al-review-simplify` | Lens: dedup, dead code, speculative generality. | `/al-refactor` |
| `al-review-objects` | Lens: a task's `New and Modified Objects` entries against the workspace and `architecture.md`. | the refine gate |
| `al-review-assertions` | Lens: AAA cases whose assertions would pass without the behaviour under test. | the refine gate |
| `al-review-judge` | Dedups, substantiates, and ranks one supplied batch of lens findings against its scoped artifact, in the mode the caller declares. | `/al-code-review`, `/al-refactor`, the design and refine gates |
| `al-researcher` | Resolves one framed AL/BC fact through isolated BC patterns, Learn, symbols, or canonical BCApps source and returns a tagged verdict with quoted evidence. | Any skill, main session, or research-capable custom agent needing BC knowledge beyond direct workspace reading |
| `al-design-option` | Develops one self-contained architecture candidate under a supplied divergent constraint — `/al-design` fans out three in parallel and chooses among them itself. | `/al-design` |
| `al-gate-runner` | Runs one supplied build, provision, or breaking-change gate command and relays its authoritative artifacts, no interpretation. | `/al-build`, `/al-provision`, `/al-validate-breaking-changes` |
| `al-mutant-cycle` | Runs one supplied mutate→gate→revert cycle and returns observed evidence; the caller classifies the mutant. | `/al-mutate` |

Eleven of those agents are review lenses — one per concern, each running under a mode the calling skill declares. Which lenses a gate spawns, what each returns, how the judge fences its extra rules, and what a blocking finding does at a gate reviewing a plan all live in [`review-lenses.md`](review-lenses.md). `al-review-red` shares the name family and none of the contract: it gates one red beat rather than judging an artifact, so it carries no mode and reaches no judge.

## What the agents need on your machine

Three agents embed an MCP server and start it on demand — nothing to install up front, but each needs a runtime and network access on first use.

| Agent | Server | Needs |
|---|---|---|
| `al-researcher` | `bc-code-intelligence-mcp` | Node 18+ and network for `npx` |
| `al-debug-logging` | `bc-telemetry-buddy` | Node 18+ and network for `npx` |
| `al-review-perf` | `al-performance` (pinned `@2.1.3`) | Node 18+ and network, plus **`uv`** — or Python 3.9+ with `mcp[cli]>=1.0.0`, since the scanner is a Python server behind an `npx` launcher |

Missing runtime, no network, or a `disabledMcpServers` entry naming the server all land the same way: the agent reports the capability as absent and the run continues without it. The perf lens says so in one line and the other lenses carry the review.

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
