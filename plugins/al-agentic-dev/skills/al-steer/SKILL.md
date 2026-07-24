---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev. Reads the tasks/ folder, the goal, the codebase, and recent commits, names what is next or blocked or drifting, owns .out-of-scope/ and .not-yet-specified/, and is the canonical replan venue.
---

# /al-steer, Coach / navigator

**Read the live planning surface, name the next move — never force it.** The surface: `tasks/`, `architecture.md`, `event-model.md` when present, the goal, codebase, recent commits, `.out-of-scope/`, and `.not-yet-specified/`. Name blocks, drift, and handoff. This is the canonical replan venue and owner of `.out-of-scope/` and `.not-yet-specified/`.

Compute the status board fresh from the `tasks/` folder each invocation — folder shape, frontmatter fields, and the status lifecycle in [`task-lifecycle.md`](../../references/task-lifecycle.md).

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only features).
- Spec folder `specs/<branch>/` holds a `tasks/` folder. Missing but `architecture.md` present → **Stop**, run `/al-scope`. `architecture.md` also missing → **Stop**, run `/al-design` (or `/al-event-model` first for user/API-facing features).

## Write scope

**Read anything in workspace; write task files, `.out-of-scope/`, and `.not-yet-specified/` only.** `status:` flips, replan-flag bodies, and the `review: clean` strips they entail proceed directly.

Structural edits — adding, splitting, deleting, reordering, re-prefixing task files — land only after explicit user ack. Silent restructuring loses the audit trail.

Gap insertion and minimum-local-run re-prefix mechanics are in [`task-lifecycle.md`](../../references/task-lifecycle.md). Complete the whole rename run before the document-integrity check or any downstream handoff. A half-finished run leaves two files sharing a prefix, which the duplicate-prefix check flags.

## Read first, then name

**Surface what the state says — coaching from stale memory is the failure mode that drove the user here.**

Name entries that need a decision: severity, ID, symptom in the codebase's terms (object names, table fields, codeunit calls), one line per entry. Route by kind and state:

**Technical task** (`kind: technical`):

- `ready` → `/al-refine T-NNN`.
- `ready-for-implementation` routes by `phase:`. `refined` or absent → `/al-implement T-NNN`. `implemented` → `/al-refactor T-NNN`. `refactored` → `/al-mutate T-NNN`. `mutated` but not `done` → an open mutation gap; `/al-implement T-NNN` for the killer test.
- `blocked` reads three ways. All `depends_on:` `done`, no replan flag, and the task's own slice already open (a same-`slice:` sibling is not `blocked`) → a stale open; flip it `ready`. All `depends_on:` `done` but every task in its `slice:` still `blocked` → waiting on the cross-slice gate; name it "waiting on slice review", don't flip. An unsatisfied edge or a replan flag → name the missing edge or flag.
- `done` with `phase:` short of `mutated` needs no route — a legitimate early close.

**Ops task** (`kind: provision` / `kind: breaking-change`):

- `ready` → the owning skill (`/al-provision` / `/al-validate-breaking-changes`), never `/al-refine`.
- `blocked` reads two ways. Waiting (a dependency not yet `done`) is normal scope-time state — say "waiting on `T-NNN`", not a problem. Failed (dependencies `done`, the task ran and could not pass) → clear the blocker named in `blocked-on:`, re-run the owning skill.
- A breaking-change task `blocked` with deps `done` but never run waits on the per-feature `/al-code-review`, its flip-owner — say "waiting on feature-done review", don't flip.
- Never open ops tasks to `ready-for-*`.

**Verify task** (`kind: verify`):

- `ready` → `/al-refine T-NNN`. A `ready` verify task always carries `review: clean` — it was opened by a clean review.
- `blocked`, checked in order: a replan or failure flag in the body (e.g. a failed walk, trigger #8) → name the failure inline and route per its trigger — a failed *walk* is not cleared by re-running *code* review. Else in-slice technical deps still pending → waiting, say so. Else every in-slice technical task `done` with no `review: clean` → slice-done owing its **first** per-slice review; `/al-code-review T-NNN`.
- `ready-for-verification` with no `review: clean` → a re-review is owed (the marker was stripped when new technical work opened; the `Verification Plan` stands). An in-slice fix task still open → waiting on `T-NNN` — routing to `/al-code-review` early would Stop-bounce on its slice-not-review-ready precondition. Every in-slice technical task `done` again → `/al-code-review T-NNN`.
- `ready-for-verification` with `review: clean` and `Record: yes` Journey Examples whose recordings are missing → `/al-page-script T-NNN`.
- `ready-for-verification` with `review: clean` and all recordings present (or no `Record: yes` example) → `/al-user-verification T-NNN`.

**Slice-done** (every in-slice technical task `done` and the slice's verify task lacks `review: clean`; or a backend-only last task `done` with the next slice still `blocked`) → `/al-code-review` per-slice gate. The verify track sits behind this gate — a clean review opens the verify task; never open it to `ready` ahead of the review.

**Feature-done** (every task `done` except the breaking-change task — still `blocked`, never run — no merge yet) → `/al-code-review` per-feature gate, whose clean pass opens the breaking-change task.

Name the gate by name so the user picks the right skill. Each entry states cause → effect in named objects, not a category; a decision fork goes to the user per **One decision per question** ([GROUND-RULES.md](../../references/GROUND-RULES.md)).

## Route to next skill, do not perform it

User uncertain which way to jump → run `/grill-me` on the branch.

## Replan flags

Other skills stamp `**Replan flag**: trigger #N` in task bodies; `/al-steer` reads the flags, decides the response, and clears them. The eight trigger patterns, the trigger-response table, and the tool-diagnosis re-confirm rule are in [`task-lifecycle.md`](../../references/task-lifecycle.md).

Reds routed here by `/al-page-script` arrive by chat handoff — status unchanged, no flag; its *Failure classification* frames the decision owed. Flags stamped by `/al-user-verification` (trigger #4 / #8) frame theirs in the flag body and the trigger table. Decide from the handoff or flag's framing rather than re-classifying the red.

`/al-steer`'s own writes on a resolution:

- Opening or inserting a technical task in a slice strips `review: clean` from that slice's verify task in the same edit pass — the strip rules in [`task-lifecycle.md`](../../references/task-lifecycle.md), including the flip of a still-`ready` verify task back to `blocked`. After a page-script production-bug red, opening the integration fix task and stripping the marker is `/al-steer`'s one write pass; the strip is the signal routing the slice back through `/al-code-review` after the fix lands.
- A false alarm — grilling vetoes the trigger — restores the prior `status:` and rewrites the flag body to record the resolution.

## Restructuring

**Name candidate edits matching what the trigger surfaced; apply only after explicit ack.** Splitting, inserting, reordering, deleting, rewriting a description, stripping a stale `Test Specification` or `Verification Plan` are all in scope. Run `/grill-me` on non-trivial choices.

## Document verification

After a structural write, before naming the downstream handoff, verify the `tasks/` folder against the `tasks/` profile in [`doc-integrity.md`](../../references/doc-integrity.md); the duplicate-prefix and dangling-edge checks are load-bearing after a re-prefix. Simple `status:` flips, closeout notes, and inline replan flags skip the gate.

## Owns `.out-of-scope/`

**A substantive rejection lands at `.out-of-scope/<concept>.md` so the next session can't re-litigate it.** Grilling vetoes a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR; a deferral belongs in `.not-yet-specified/`) → record it there. Scan `.out-of-scope/*.md` during replan and grilling; on match, surface the prior rejection in the user's words. Template `references/out-of-scope.template.md` in this skill's base directory materialises on first need; a match appends a *Prior requests* entry rather than spawning a second file.

## Owns `.not-yet-specified/`

**The deferred-question ledger holds what is in scope but *not yet ruled*; `.out-of-scope/` holds what was *ruled out*.** Every question file must graduate — a silently absorbed question becomes an implementation guess.

The ledger lives at repo root, one file per question, never an answer. A question earns a file when `/al-grill-adr` or `/al-design` named it, the user said it matters, and nobody can phrase it as a decision yet.

Scan the folder during replan and grilling. A landed decision makes a question answerable → route it: `/al-grill-adr` for a domain rule, `/al-research` for a BC fact, or decide it here. The answer lands in the artifact that owns it; delete the question file in the same pass. The user rules a question out of scope → move its file to `.out-of-scope/<concept>.md`, rewritten from question to substantive rejection.

## Next step

**Naming the next step *is* this skill's deliverable — the steering note ends with the concrete move read off current board state.** `Next: /<skill> T-NNN` for the resolved block, or the deliberate `blocked` hold with what must settle first. `/al-steer` never auto-invokes the skill it names; the user takes the step.

## Composition

| | |
|---|---|
| **Invoked from**     | any SKILL on replan trigger, or by user for "where are we" |
| **Routes to**        | the skill named by the kind-routing map above; `.out-of-scope/` and `.not-yet-specified/` per their owning sections |
