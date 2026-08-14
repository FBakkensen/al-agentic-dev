---
name: al-routing
description: "Use when a skill finishes work on a task and the outcome needs recording, or when a skill creating or reading task files needs the schema, the ladder, and the derivations."
---

# al-routing — the state engine

Task state has one home: this skill. Every other skill reports what happened in plain words and invokes `/al-routing`; the stamps, the derivations, and the next open moves are decided here. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## The frontmatter

Every task file in `specs/<NNN>-<slug>/tasks/` — `000-feature.md`, the prose Goal, stands apart — is named `NNN-T-MMM-<slug>.md` — `NNN` is execution order, so a slice's last task is its highest `NNN` — and opens with:

```yaml
task: T-007          # stable id, unique across the folder, never reused or renumbered
kind: technical | verify | provision | breaking-change
slice: <slug>        # an event-model.md timeline step or architecture.md slice; ops tasks sit on the reserved slugs provision / breaking-change
depends_on: [T-004]  # hard edges onto the tasks this one must follow
status: open | done  # the only two written states
phase: refined | implemented | refactored | planned | page-scripted | provisioned | bcapps-cloned   # first three technical, then verify, then provision
review: clean        # the review gate's stamp
tier: mechanical | standard | frontier   # the weakest model class the task's remaining work needs
green-gate:
  commit: <40-character SHA>  # the durable HEAD a full gate proved
  profile: full
```

Creation writes the structural fields plus `status: open`, no `phase:`, and no green-gate receipt — `/al-scope` at scoping, or the skill that finds new work mid-pipeline, naming the edges its find must wait on. `/al-scope` also stamps `tier:` at creation; a finder's task omits it — recording is any model's work, sizing is not. A finder task takes a free `NNN` below the slice's verify task where one exists, so the verify task stays the slice's tail; a backend-only slice appends at the tail. The breaking-change task never carries `phase:`. Every later write is a stamp this skill makes when a run's outcome arrives.

## Derived, never written

Ready, blocked, and waiting are computed fresh at every read — no field mirrors them, so none can go stale. A task is **runnable** when `status: open`, every `depends_on` entry is satisfied, and no gate below holds it; it **waits** otherwise, and presenting it names the open edge or holding gate. An edge inside a slice is satisfied by `done`; a cross-slice edge also needs the target slice reviewed — its last task carrying `review: clean`.

## Clean-gate receipt

A completed full gate reports the `HEAD` committed immediately from its unchanged green tree. Record or replace its receipt on the outcome task with `commit:` and `profile: full`, in the same routing commit as the outcome, then say `✅ Green gate recorded — T-123 @ abc123 (full).` A receiver accepts the newest receipt in its scope only on a clean tree, when the recorded commit is an ancestor of `HEAD` and `git diff --name-only <commit>..HEAD` names only that receipt-owning task file. A non-full profile, missing or unreachable commit, or any other path requires a new full gate. No skill finishes red, so no invalid receipt is written.

## The ladder

`phase:` names the last finished step; absent means nothing past scope has run.

- `technical`, open — no phase → `/al-refine` · `refined` → `/al-implement` · `implemented` → `/al-refactor`.
- `verify`, open — no phase → `/al-refine` · `planned` with its `review: clean` stamp → `/al-user-verification` · `page-scripted` → `/al-user-verification` resumes the walk from the task body's `Partial-run record:`, or starts it when none exists.
- `provision`, open — no phase → `/al-provision` · `provisioned` → `/al-clone-bcapps` · `bcapps-cloned` → `/al-clone-bcquality`. `breaking-change` → `/al-validate-breaking-changes`. Neither ops kind passes through `/al-refine`.
- `done` is settled at any phase; on a technical task short of `refactored` it is a deliberate early close, not a gap.

## Gates
- **Scoping / re-scope** — no breaking-change task in `tasks/`, or an `architecture.md` reshaped since the folder settled, → `/al-scope` before anything routes. While provision is not `done`, its ladder step is the only move.
- **Slice / feature done** — every technical task in a slice `done` and its last task lacking `review: clean` → `/al-code-review`; every task but breaking-change done and its task lacking `review: clean` → feature `/al-code-review`.
- **All done** — everything `done`, breaking-change included → `/al-sync-main`, then the user opens the PR. Branch synced and PR open → closed.

## Outcome → stamp

One edit per stamped outcome, committed as it lands under the owning task's `T-NNN` prefix — the red-path `Last run:` lines included; nothing else moves:

| The reported outcome | Stamp |
|---|---|
| `/al-refine` wrote the proof | `phase: refined` (technical) / `phase: planned` (verify); `tier:` re-stamped to the class its report names for the remaining work |
| `/al-implement` reached green outside a repair episode | `phase: implemented`; record its full-gate receipt |
| `/al-refactor` closed its pass — reshape landed, or every dimension came back clean | `phase: refactored` and `status: done`; replace the receipt after a reshaped green, otherwise retain the incoming one |
| `/al-user-verification` sealed the slice's last recording | `phase: page-scripted` |
| `/al-user-verification` finished the walk clean | `status: done` |
| `/al-code-review` cleared the slice / the feature | `review: clean` on the slice's last task / on the breaking-change task; record its latest durable full gate when it changed the tree |
| `/al-provision` ran | green → `phase: provisioned`; red → one `Last run:` line in the task body naming what failed, frontmatter untouched |
| `/al-clone-bcapps`, `/al-clone-bcquality`, or `/al-validate-breaking-changes` ran | green → `phase: bcapps-cloned` for the first, `status: done` for the other two; red → one `Last run:` line in the task body naming what failed, frontmatter untouched |
| the user closes a task early — a verify task waived (every delta pinned by green Integration cases, its wire human-verified in a prior walk) or absorbed into a sibling's merged plan included | `status: done`; a waived or absorbed verify close also writes the one `Closeout:` line naming the cover — the pinning cases and prior walk, or the carrying task. A waiver closes the walk, never the slice's review gate |

Four outcomes stamp nothing: `/al-scope` landed the tasks folder → present the opening move.

- A run whose outcome is a task it created — a change request at the review gate, a quiz follow-up → the new task is the move, and any gate it re-holds re-fires once it settles.
- A repair episode — the fix green, its repair-scope review, a verification run paused on a fail — stays inside its episode: no phase stamp; a durable full green records or replaces its receipt, and the run resumes at the failed scenario.
- A run that stopped on an open question or declined its task → the stop line in chat is the whole record; the user re-runs once it settles.

Any other unmatched outcome goes back to the reporter as one question rather than being guessed into a stamp.

## Leave the tree clean

After recording — stamp or no stamp — a dirty tree is put to the user: summarize what the leftover changes do, intent rather than a file list — the user reads the chat, not the diff — deduce the task they belong to and suggest its `T-NNN`, listing each candidate with its reason when several fit, and ask whether to commit them too. Yes → one separate commit prefixed with the chosen `T-NNN`, or a plain descriptive message when no task owns them, never folded into another commit. No → they stay uncommitted, named as the record.

## Present the moves

After recording a report — or when `/al-next` asks — first sweep every task frontmatter in the folder and derive each gate above, naming the result in one line — `Gates: <slice> review firing` or `Gates: none` — a firing gate outranks every ladder move and is presented first; a move whose gate condition the sweep does not confirm is never named. Then one line per runnable task: its `task:` id, the skill the ladder names, the model class the move wants, and what opened it, in the feature's own object and field vocabulary. A move's class is the task's `tier:`, raised to frontier for `/al-refine` and `/al-user-verification`, raised to standard for `/al-refactor` and `/al-code-review`; untiered, any other move at standard. Several open → id order, naming which unblocks the most; runnable verify tasks sharing a surface and fixtures are one walk opportunity — merged at refine or walked back-to-back in one warm session, never serial refine→walk cycles. None → the one edge or gate that must settle, and who settles it. A repair-episode report skips the move list — its own path continues.

Close on the state recorded and the moves named; the session continues in the caller's flow.
