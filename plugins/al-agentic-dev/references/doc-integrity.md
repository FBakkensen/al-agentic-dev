# Document integrity check

**Verify the artifact you just wrote yourself, inline, before the gate report.** The skills that write canonical planning markdown — `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-steer` — run these checks after writing or restructuring an artifact, before the gate report or downstream handoff. No subagent runs them. Every check lands on a verdict. The [Verdict table](#verdict-inline) owns what each verdict requires.

Integrity means: the artifact exists and matches its profile, headings and task-file frontmatter are structurally sound, sibling spec files agree on shared IDs / slice slug / handoff wiring, and linked `CONTEXT.md` / `docs/adr/` references exist. Domain truth, BC fact truth, design quality, and test sufficiency are never judged here — the writing step and downstream skills own those.

**The check reads documents, never code.** In scope: the artifact just written, its directly linked sibling artifacts in the same spec folder, the plugin grammar references under this plugin's `references/` directory, and `CONTEXT.md` / `docs/adr/` when linked — always for `/al-grill-adr`. The check consults no symbols and runs no research.

## Profiles

| Artifact | Verifies |
|---|---|
| `CONTEXT.md` and ADR | durable intent, decision shape, and link integrity |
| `event-model.md` | Role / Action / Business Event / View / Status structure |
| `architecture.md` | module map, boundaries, cross-file consistency. Every object the slice introduces or extends carries a `new` / `extends <existing>` marker at first mention. A `(new)` suffix or inline `new <type>` / `extends <base>` both count. A missing marker is a **warn** — `/al-refine` seeds each task's `New and Modified Objects` ledes from those markers |
| `tasks/` folder | per-task-file frontmatter, folder integrity, and the `Test Specification` / `Verification Plan` sections |

## `tasks/` structural checks

`000-feature.md` carries Goal + slice intent and no task frontmatter — never flag it for missing fields.

| Check | Verdict | Fires when |
|---|---|---|
| Frontmatter integrity | **fail** | a `NNN-T-MMM-<slug>.md` file lacks parseable YAML frontmatter with `task:`, `status:`, `slice:`, `kind:`; the filename's `T-MMM` differs from the frontmatter `task:`; or `kind:` is outside `technical \| verify \| provision \| breaking-change` |
| Duplicate id | **fail** | two task files share a `task:` id |
| Duplicate prefix | **fail** | two task files share an `NNN` prefix — a re-prefix run left a collision, and run order is now ambiguous |
| Dangling edge | **fail** | any id in a `depends_on:` / `refactors:` / `fixes:` list has no matching task file |
| Order vs edges | **warn** | a task's `NNN` prefix is lower than a task it `depends_on:` — it would sort to run before its dependency. The edge is the hard truth; the prefix is the soft run order. Re-prefix via `/al-steer` |
| Verify under-coverage | **warn** | a `kind: verify` task whose `depends_on:` omits a `kind: technical` file sharing its `slice:` — the verify task's `depends_on:` should enumerate its slice's technical set. Flag `verify gate under-covers slice; dependency graph incomplete`. Slice-done itself is read from `slice:` membership (every `slice:`-matched technical task `done`), so the missing edge is a graph-integrity gap, not an early-gate risk |
| Ops-slug pairing | **fail** | `kind: provision` without `slice: provision`, `kind: breaking-change` without `slice: breaking-change`, or a `kind: technical` / `verify` task on a reserved slug |
| `New and Modified Objects` coverage | **fail** | the task under work carries a populated `Test Specification` but no `New and Modified Objects` — blocks the `ready-for-implementation` flip. The bare labeled line `New and Modified Objects: none` is the valid test-only form; a section heading without entries fails. Scope to the named task's file only. `done` tasks may predate the grammar. Task files without a `Test Specification` are not yet refined — do not flag them. Ops kinds (`provision`, `breaking-change`) carry no `Test Specification` or `Verification Plan` and never reach `ready-for-implementation` / `ready-for-verification` — do not flag them |
| E2E `Record:` flag | **fail** | a `kind: verify` task with a populated `Verification Plan` whose `Scope: E2E` Journey Example omits the mandatory `Record: yes` / `Record: no` line — the flag routes the example to `/al-page-script` (record) vs `/al-user-verification` (walk). Scope to a task file with a populated plan only. `Contract` / `Exploration` examples carry no `Record:` — do not flag them |

## `tasks/` lifecycle checks

A lifecycle field out of step with its task's — or its slice's — state is a missed Edit in the owning transition. Every check here is a **warn**. The owning skill writes or strips these fields in the same Edit as the transition it marks. A survivor is false state the next session inherits.

| Check | Fires when | Flag |
|---|---|---|
| `blocked-on:` missing | a `status: blocked` task carries no `blocked-on:` line — the write belongs in the same Edit as the flip | `block without headline; developer can't see why` |
| `blocked-on:` stale | a `blocked-on:` line on a non-`blocked` task. `done` tasks may predate the grammar — do not flag | `stale block headline; remove-on-unblock missed` |
| `phase:` on ops | `phase:` on an ops kind (`provision`, `breaking-change`) | `phase on ops task; ops kinds carry no pipeline phase` |
| `phase:` kind mismatch | a technical task with `planned` / `page-scripted`, or a verify task with `refined` / `implemented` / `refactored` / `mutated` | `phase value belongs to the other kind` |
| `phase:` stamp missed | technical `status: ready-for-implementation` without any `phase:`, or verify `status: ready-for-verification` without `phase: planned` or `page-scripted`. Technical `done` without a phase is not flagged — `done` tasks may predate the grammar, the same carve-out as `blocked-on:` | `phase stamp missed; owning skill's Edit incomplete` |
| `phase:` ahead of status | technical `phase:` present while `status: ready`, or verify `phase: planned` / `page-scripted` while `status: ready`. Never fires on: technical `ready-for-implementation`, which legitimately carries any phase through the hardening window; `done` at any phase — a legitimate early close; or `blocked` — `phase:` legitimately survives a block | `phase ahead of status; state torn` |
| `review: clean` stale | the field on a verify task whose `status:` is neither `ready` nor `ready-for-verification`. `/al-code-review` stamps it at slice-done when it opens the verify task to `ready`, and it rides through to `ready-for-verification` | `stale review marker; strip-on-flip missed` |
| `review: clean` premature | the field on a verify task while any technical task sharing its `slice:` is not `done` | `review marker predates open slice work; re-review due` |

## Verdict (inline)

| Verdict | Meaning |
|---|---|
| **fail** | a structural or boundary blocker exists — fix it before the gate report; never hand off a structurally broken artifact |
| **warn** | any non-blocking structural or handoff inconsistency — structure holds. Note it in the gate report and proceed |
| **pass** | no blockers and no warnings remain |
