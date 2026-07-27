# Task lifecycle

`event-model.md`, `architecture.md`, and `specs/<NNN>-<slug>/tasks/` are the planning artifacts. Every skill that generates or edits any of the three consults this file first.

## Source of truth: examples

Three populated examples in [`examples/`](./examples/) carry the canonical shape — pattern-match against them before writing a feature's artifacts. The per-task file body has its own grammar in [`task-grammar.md`](./task-grammar.md); this file owns everything around it.

| File | What it is |
|---|---|
| [`examples/event-model.example.md`](./examples/event-model.example.md) | User-facing journey, Role swimlanes, Action / Business Event / View / Status slots. |
| [`examples/architecture.example.md`](./examples/architecture.example.md) | Module map, decision logic and test surfaces, brownfield touchpoints. |
| [`examples/tasks/`](./examples/tasks/) | The `tasks/` folder shape: a `000-feature.md` header plus one frontmatter file per task, technical + verify across two slices. |

Cross-links between sibling artifacts drop the `.example` suffix: generated artifacts link to `event-model.md` / `architecture.md` / the `tasks/` folder inside the same `specs/<NNN>-<slug>/` folder.

## The `tasks/` folder

The filesystem is the ordered manifest — `ls tasks/` is the run order, and there is no index file. `/al-scope` writes `specs/<NNN>-<slug>/tasks/` as a folder, one file per task plus one header:

```
specs/035-foo/tasks/
  000-feature.md                          # Goal + slice-intent. No status, no per-task rows.
  010-T-001-provision.md
  020-T-004-release-order-valid-charge.md
  030-T-007-pending-overrides-cue.md
```

| Token | Meaning |
|---|---|
| `000-feature.md` | the feature header: Goal plus per-slice intent prose — no task rows, no status, no board; it sorts to the top of the folder and is read first |
| `NNN` | execution-order prefix, gapped by 10 (`010`, `020`, `030`), the *sole* owner of order — no second ordering encoding anywhere; insert between two tasks by picking a gap (`025`), and when a gap fills, re-prefix the minimum local run |
| `T-MMM` | monotonic, never reused, never renumbered: the stable locator — the gap lives on the prefix, never on the id, so ids stay dense even as order shifts |
| `<slug>` | kebab-case, for human scanning |

The live status board, the dependency graph, and "next actionable task" are computed on demand by grepping across the folder. `/al-steer` renders the board in chat — the persistent human-facing view, reading frontmatter fresh each invocation. The render matches the frontmatter at render time and can go stale as the files change afterward.

## Frontmatter

YAML frontmatter tops every per-task file, then an H1 title, then the body. The H1 is just the title — no `[ ]`/`[x]` marker; `status:` in frontmatter is the only state. The body's shape is [`task-grammar.md`](./task-grammar.md)'s.

```markdown
---
task: T-007
status: ready
slice: release-sales-order
kind: technical
depends_on: [T-004]
refactors: []
fixes: []
---
# T-007 — Release order, valid item charge

<description, then Test Specification / Verification Plan, …>
```

These fields are the single source of truth for state and graph:

| Field | Locates | Used by | Written by |
|---|---|---|---|
| `task: T-NNN` | the task; matches the filename's `T-MMM`; unique across the folder | every skill that touches a task | `/al-scope` |
| `status: ready \| ready-for-implementation \| ready-for-verification \| blocked \| done` | what the task is ready for now — single source of truth | every lifecycle skill | the flipping skill — see [Status lifecycle](#status-lifecycle) |
| `phase: refined \| implemented \| refactored \| mutated` *(technical)*, `planned \| page-scripted` *(verify; optional on both kinds)* | the last pipeline step that **finished** — past-tense, durable. Absence means nothing beyond scope has finished | `/al-steer` (board render) | the skill that finishes the step — see [Status lifecycle](#status-lifecycle). No value duplicates `status:`. There is no `scoped` — that is absence plus `status: ready`. There is no `verified` — that is `status: done` on a verify task |
| `slice: <slug>` | slice membership. Matches one `event-model.md` timeline step (user/API-facing) or `architecture.md` slice (backend-only) | `/al-implement` (detect last technical task in slice → announce `/al-code-review`), `/al-code-review` (per-slice diff scope, gate flip target), `/al-steer` (group by slice when reporting) | `/al-scope` |
| `kind: technical \| verify \| provision \| breaking-change` | task kind. `technical` runs `/al-implement`. `verify` runs `/al-code-review` (slice-done gate), then `/al-page-script` + `/al-user-verification`. `provision` runs `/al-provision`. `breaking-change` runs `/al-validate-breaking-changes` | `/al-implement` (stop on non-technical), `/al-refine` (branch by kind — the two ops kinds bypass it), `/al-page-script` + `/al-user-verification` (preconditions), `/al-provision` + `/al-validate-breaking-changes` (run-and-flip) | `/al-scope` |
| `depends_on: [T-NNN, …]` | hard dependency edges — cannot land without those | `/al-refine`, `/al-implement` (gate readiness), `/al-steer` (graph for replan), cross-slice gate | `/al-scope`; `/al-steer` on replan |
| `refactors: [T-NNN, …]` | reshapes shipped code under invariant | `/al-code-review`, `/al-steer` | `/al-scope`; `/al-steer` |
| `fixes: [T-NNN, …]` | corrects a defect or wrong contract | `/al-code-review`, `/al-steer` | `/al-scope`; `/al-steer` |
| `blocked-on: <one line>` *(scalar string, present iff `status: blocked`)* | why the task is blocked — the one line the developer reads to know what the block waits on (a missing decision, a failed gate, an unsettled dependency) | `/al-steer` (chat render, replan entry point) | whichever skill sets `status: blocked`, **in the same Edit** — including `/al-scope` on tasks emitted `blocked`. The skill flipping away from `blocked` deletes it in the same Edit. One scalar line, overwritten on a re-block, never a list. This field is the headline, not the record: the full replan flag, trigger ID, and evidence stay body prose |
| `deviations:` *(optional YAML list of one-line strings)* | unknowns the working skill absorbed inline without asking — each entry one line: what was assumed and what it touched | `/al-steer` (chat render and pattern read across tasks), `/al-code-review` (reviews the assumptions with the diff) | the skill that absorbs the unknown (`/al-implement` foremost), appended at absorb time. Entries are never edited or removed — a deviation later judged wrong is replan work, not a list cleanup |
| `review: clean` *(optional, `kind: verify` only)* | durable clean per-slice `/al-code-review` evidence — see [`review: clean`](#review-clean) | `/al-refine` (rides untouched through the flip), `/al-page-script` + `/al-user-verification` (precondition), `/al-steer` (state read) | `/al-code-review` only, on a clean per-slice review of a user/API-facing slice |

Empty edge lists may be written as `[]` or omitted. A present list holds bare `T-NNN` ids: the id is the citation, with no file paths and no line numbers. Human-facing *rationale* for an edge stays body prose. The *edge itself* is a frontmatter field. `slice` and `kind` are scope-time decisions: `/al-scope` writes them, downstream skills read them. Changing `slice` (slice membership changed) or `kind` (miscategorised) is replan work, routed through `/al-steer`. The `NNN` prefix and edge lists are also scope-time. `/al-steer` owns later re-prefixing on insert.

`event-model.md` and `architecture.md` carry **no** surgical-edit contract: `/al-design` and `/al-event-model` reshape them whole on re-run.

## Status lifecycle

`status:` answers *what the task is ready for now*; `phase:` answers *what last finished*. A flip to `blocked` erases the former's readiness and never the latter, so the pipeline position survives a block.

| Status | Meaning and transition |
|---|---|
| `ready` | on technical and verify tasks, ready for `/al-refine`; on ops kinds, ready for the owning skill (**Ops kinds**, below). `/al-scope` opens only `T-001` `ready`; every other task opens `blocked` behind its gate |
| `ready-for-implementation` | a technical task has a fresh `Test Specification`. `/al-refine` flips it, stamping `phase: refined` in the same write. The status holds through the whole hardening window while only `phase:` moves: `/al-implement` stamps `implemented` at green, and `/al-refactor` stamps `refactored` when the reshape lands green, each with no status flip. `/al-mutate`'s clean verdict flips `done`, stamping `mutated` in the same Edit — or the developer ends the hardening early and the active skill flips `done` at the current phase. A `done` task whose `phase:` stops short of `mutated` is a legitimate early close, not torn state |
| `ready-for-verification` | a verify task has a fresh `Verification Plan`. `/al-refine` flips it, stamping `phase: planned`. `/al-page-script` stamps `page-scripted` on the green replay batch, with no status flip. `/al-user-verification` flips `done` at sign-off |
| `blocked` | dependency or context is missing. Any skill can set it, writing `status:` and `blocked-on:` in the same Edit and leaving `phase:` untouched. The skill that later resumes the pipeline overwrites `phase:` as its own step finishes. `/al-code-review` opens a user/API-facing slice's verify task `blocked` → `ready` on a clean first review |
| `done` | terminal, the same meaning for every kind: finished, nothing further intended. The ops skills flip their own tasks `done` |

Only the next owning skill overwrites `phase:`. No skill deletes it. One repair exception: a named follow-up on a `done` technical task — an `/al-code-review` must-fix finding routed as `T-NNN`, or an `/al-mutate` survivor's killer test — re-enters `/al-implement` under the originating task. The fix lands red-first and commits under its `T-NNN` prefix. **Both `status:` and `phase:` stay untouched** — the repair is not a pipeline step. The commit and the re-review are its record. Anything beyond those two named routes is replan work, `/al-steer`'s.

Whoever flips a task `done` opens the same-slice **technical** dependents that flip unblocks. Each task whose `depends_on:` is now fully `done` and carries no replan flag flips `blocked` → `ready`. The close names each opened `T-NNN`.

The slice's verify task is never opened this way — it waits behind the per-slice `/al-code-review` gate ([`review: clean`](#review-clean)).

A task `blocked` on an unsatisfied edge or a replan flag stays `blocked`. Clearing it is `/al-steer`'s decision.

**Ops kinds** (`provision`, `breaking-change`) are the exception to the `/al-refine` lifecycle. They carry no `Test Specification` or `Verification Plan` and no `phase:`. They sit on the reserved slugs `slice: provision` / `slice: breaking-change`, never on feature slices. They run `ready` → `done`, or `blocked` on failure — never through `ready-for-implementation` / `ready-for-verification`. For them, `ready` means run the owning skill: `/al-provision` or `/al-validate-breaking-changes`. `/al-refine` declines them with a redirect. `/al-scope` emits `kind: provision` as `T-001`, opening `ready`, and `kind: breaking-change` last, opening `blocked` with `depends_on:` the final terminal task. Each `blocked` → `ready` flip has a named owner, like the cross-slice gate: `/al-provision` opens the first slice's technical tasks on its `done`, and the per-feature `/al-code-review` opens the breaking-change task on a clean pass.

## `review: clean`

Presence is the only durable clean-review evidence for user/API-facing slices; absence means not-reviewed or re-review due. `/al-code-review` stamps it when it opens the verify task to `ready` at slice-done — the status value alone cannot carry the evidence across the `/al-refine`, `/al-page-script`, and `/al-user-verification` steps that follow. Strip rules govern writes; a stale `review: clean` would vouch for an unseen diff:

| Trigger | Required write |
|---|---|
| a flip to `blocked` or `done` | delete the field **in the same Edit** — the slice is re-opening or signing off |
| the `/al-refine` flip `ready` → `ready-for-verification` | **preserve** it: refine moves no production code, so the review still vouches |
| any skill opening a technical task in the slice (`/al-steer`'s push-down fix task after a page-script red, or a replan inserting technical work) | delete it — new slice code invalidates the review, and the push-down path moves no status byte, so the strip cannot ride on a flip; a still-`ready` verify task, opened by the review but not yet refined, flips back to `blocked` in the same edit (the slice re-opened before refinement) |
| `/al-page-script` green | deliberately leave the field alone: the commit adds a recording, no production AL, so the review still vouches for the slice diff |

Backend-only slices carry no field — their clean review flips the next slice `blocked` → `ready`, which is durable by itself. `examples/tasks/` carries no `review: clean` and no `deviations:`: both are transient runtime state written mid-cycle, not scope-time shape `/al-scope` generates. `blocked-on:` *does* appear in the examples on tasks emitted `blocked` — it is written at whatever moment `status: blocked` is set, including scope time.

## The audience split

Task files are agent-facing: every line earns its place by a downstream skill reading it — nothing in a task file is written *for the developer*. The human-facing surface is `/al-steer`'s chat-rendered board plus chat itself. Content with no reader on either side — progress narration, restated plans, completed-checklist ceremony — is written nowhere, not relocated. When a fact matters to both audiences, the frontmatter carries the headline (`status:`, `blocked-on:`, `deviations:`) and the body carries the task-body detail; `/al-steer` renders only the headline.

## Routing by lifetime

The per-task file is branch-scoped — it dies when the feature merges, and so does everything inside it. Route every generated line by whether it survives past `done`:

- **Survives past `done`** → a durable artifact outside the task file, per the destination table below.
- **Dies with the branch** → may live in the task file: the headline fields per [Frontmatter](#frontmatter), and body content the next agent on this branch needs — replan flags, mutation verdicts, verification failures, deferred-decision notes, in-flight scaffolding. Shape inside the body — prose line, table, callout — is the writing skill's call.
- **Neither** — not useful past `done`, not needed by the next agent on this branch → commit-only, when the commit record reads it: it rides the commit message and never enters the task file. Content with no reader in the commit record either is written nowhere, per [The audience split](#the-audience-split). Session-internal reasoning rides neither: it stays in the session, per the destination table.

| Durable content | Destination |
|---|---|
| BC vocabulary, business rule, cross-feature truth | domain ADR or `CONTEXT.md`, via `/al-grill-adr` |
| Architectural decision with cross-task impact | `/al-steer` → `/al-design` |
| Recurring scope rejection with substantive reason | `.out-of-scope/<concept>.md`, via `/al-steer` |
| In-scope question that matters but can't be phrased as a decision yet | `.not-yet-specified/<question>.md` at repo root — graduates to a decision (file deleted) or moves to `.out-of-scope/`, never silently absorbed |
| Process IDs (issue / PR numbers, "the current fix") | commit message or PR description |
| Environment lessons (`-Force` is mandatory here, the container needs republishing) | the project's `scripts/` or `AGENTS.md` |
| Lessons learned, post-mortems | PR description if cross-cutting, otherwise the project's retrospective document |
| Session-internal reasoning (rubber-duck accept/reject, reconciliation chatter) | stays in session — a durable artifact carries the outcome, never the deliberation |

Durable content surfacing in an in-flight task file routes through `/al-steer`, the single replan venue.

## Replan triggers

The trigger number is an address, not a state: a flag in a task file cites `trigger #N` and the next agent knows what pattern was seen. `/al-refine`, `/al-implement`, `/al-refactor`, `/al-code-review`, and `/al-user-verification` cite these triggers in their pre-close replan checks. `/al-steer` clears them. Detection cues are skill-specific. Each skill's replan check names what the cue looks like in its own work.

| # | Name | Pattern |
|---|---|---|
| 1 | Task too big | One task balloons past a session, or its `Test Specification` or `Verification Plan` shows low cohesion — items cluster around two distinct subjects. |
| 2 | Hidden pre-req | A referenced table, codeunit, permission, or behaviour has no task covering it; or implementation needs a production object the task's assertions require but its `New and Modified Objects` never named — route back through `/al-refine` to extend the section, or open a covering task. |
| 3 | Wrong order | The task's `Test Specification` or `Verification Plan` references behaviour a later task introduces. |
| 4 | Sibling now wrong | The current task invalidates another task's context, `Test Specification`, or `Verification Plan`. |
| 5 | New behaviour emerges | A surfaced code path needs its own test — appending the assertion would make an eager test. |
| 6 | Architecture decomposition wrong | Shotgun surgery across the task boundary — one behaviour lands only as edits across several tasks' modules. Or baseline drift — a baselined artifact (`architecture.md`, `CONTEXT.md`, `event-model.md`) no longer describes the workspace, or the user ruled the code right and the baseline wrong. |
| 7 | Goal drift | The Goal in `000-feature.md` no longer describes what the `tasks/` folder delivers. |
| 8 | Verification failed | A `Verification Plan` example does not match observed behaviour. Judgement call between defect (insert a `fixes:` task), wrong `Verification Plan` (rewrite via `/al-refine`), or wrong slice boundary (split via `/al-scope`). |

| The trigger | Response |
|---|---|
| makes the current task plan invalid | flip `status: blocked` and route to `/al-steer` — trigger ID and evidence in the task body, the headline in `blocked-on:` |
| surfaces new information that does not invalidate | note it in the task body and continue. If continuing requires an inline assumption, also add its `deviations:` entry per [Frontmatter](#frontmatter) |
| is #8, Verification failed | always `blocked` + route to `/al-steer` — the gate is binary, no absorb-and-continue variant exists for a failed user verification |

A trigger resting on a tool *diagnosis* — a compile-error class, an AL Runner gap, a heuristic "structural blocker" — is re-confirmed once before the `blocked` flip. A first-pass diagnosis is frequently a cascade artifact: an AL0305 missing-dependency reads as an AL0327 runner gap. A block recorded on a phantom is false state the next session inherits and unwinds. A trigger resting on a recorded fact (`depends_on:`, Goal text, an observed verification mismatch) is acted on as-is.

## Apply a decision vs. make a decision

Only a change that *makes a new decision* reaches `/al-steer`. A change that only *applies a decision already made* stays with the active skill, acted on inline and announced.

Applying: provable from current state and reversible.

- Open a task whose `depends_on:` is now all `done`.
- Flip the active task `done` on a green gate.
- Fix a non-semantic edit inline — a comment, a local rename, formatting that moves no decision logic — whether a review surfaced it or the user asked mid-flow.
- Reuse a seam a sibling task already established.

Making: re-scope, reorder, a new seam, decompose, clear a block whose cause is a missing edge or an unsettled rule.

A public/shipped-surface change is never non-semantic: a public procedure, table field, or page-action rename is an AppSource decision, not hygiene.

## Surgical-edit discipline

Status flips are Edit calls anchored on the `status:` frontmatter line, after a Read of the whole short file — an optimistic-concurrency write, with the byte match as the version check: if you think `ready-for-implementation` but the file says `ready`, Edit fails rather than corrupting state.

Example — `/al-mutate` flips T-007 from `ready-for-implementation` to `done` in `tasks/070-T-007-derive-audit-reason.md`; the clean verdict finishes the mutate stage, so `phase:` moves in the same Edit:

```
old_string:
  status: ready-for-implementation
  phase: refactored
new_string:
  status: done
  phase: mutated
```

One Edit call: `old_string` and `new_string` are each a single two-line string spanning the adjacent `status:` and `phase:` lines (the two-space indentation marks the lines belonging to each string; the task file itself has none). A phase stamp that flips no status (`/al-implement` at green: `phase: refined` → `phase: implemented`) edits the `phase:` line alone. A flip that finishes no stage (a flip to `blocked`) leaves `phase:` untouched and writes `status:` and `blocked-on:` in the same Edit; the flip away from `blocked` deletes `blocked-on:` in the same Edit.

A verify-task flip that also strips `review: clean` applies two Edits in the same write — flip `status:` and delete the `review: clean` line — or regenerates the frontmatter block whole, per the strip rules in [`review: clean`](#review-clean).

**Other writes regenerate, not surgical-edit.** When `/al-refine` fills the `Test Specification` or `Verification Plan`, `/al-mutate` writes a verdict, or `/al-implement` records a NOTE-style block in the task body, the writing skill regenerates that portion of the file whole.

Two task files sharing a `task: T-NNN` is corrupted state: halt and surface the duplicate.
