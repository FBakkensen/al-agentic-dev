---
name: al-code-review
description: AL/Business Central code review at gate points. Fixes rework autonomously, grills change requests with the user, and re-reviews once. Use when a slice's last technical task lands (slice-done) — both backend-only and user/API-facing slices, before the verify task is refined — when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

# /al-code-review — review gate

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Review finished AL/Business Central work at **slice-done** or **feature-done**. Every surviving finding is dispositioned by the baseline test under **A finding on code** in [`review-lenses.md`](../../references/review-lenses.md): `rework` lands in this run, `change request` is grilled with the user at the close, then one re-review. `/al-build` is the only skill this skill invokes; lenses, `al-review-judge`, the rubber-duck, and `al-red-green` are spawned agents.

## Entry and stops

- **Slice-done:** every technical task in one slice is `done`. Review the technical code before verification: implement → code-review → refine verify task → page-script/user-verification → next user/API slice. A backend-only slice skips verification and opens its next slice. `/al-refactor` and `/al-mutate` run after implementation and before this gate; `/al-mutate` normally supplies the clean verdict that marks a task `done`.
- **Feature-done:** review the full feature diff after the final task is `done`, before merge.
- Delegate the full gate through `/al-build` and require green (CodeCop, AppSourceCop, UICop, AppSource Validation), plus branch `^\d{3}-`, `specs/<branch>/tasks/`, and a clean tree — unrelated uncommitted work pollutes scope, and this run's rework commits land on top of it. Any failure → **Stop** and report the gap; never review an uncertain baseline.
- Read [`task-grammar.md`](../../references/task-grammar.md) and [`test-strategy.md`](../../references/testing/test-strategy.md) before synthesis.
- A user/API slice is review-ready only when its verify task is `blocked` without a replan flag, or `ready-for-verification` without `review: clean`. `blocked` with a replan flag, a non-`done` technical task, or a `done` verify task → **Stop**; code lenses do not clear failed user evidence.

## Scope

Per-slice scope is the completed technical tasks sharing one `slice:` with an owed review. Per-feature scope is the full pre-merge feature diff. WIP, mixed state, or ambiguous commits → ask one lettered question: slice `<slug>` diff / branch versus `main` / uncommitted tree / named SHA range.

A per-slice diff spans every `T-NNN` commit from its first commit through `done`, plus this run's fix commits. `T-NNN <verb>: <message>` prefixes identify ownership; a fix preserves the originating prefix. A squash that defeats the prefix → ask, never guess. Task files under `tasks/` are evidence: read their `status:`, `depends_on:`, `Closeout`, and `Contract notes` fields rather than inferring them.

## Review pass

1. **Find.** Fan out the read-only lenses in parallel — five per-slice, six per-feature, per the Scope column — declaring `Mode: code-review`, the scope, and the scoped diff and context, per [`review-lenses.md`](../../references/review-lenses.md). Pass the compliance lens the grounding rules' **Constructs** bullet from [`GROUND-RULES.md`](../../references/GROUND-RULES.md) verbatim. A failed lens, an empty lens, or one returning the invocation-error line is a reported summary gap, never a silent retry and never a clean lens.

   | Lens | Owns | Scope |
   |---|---|---|
   | `al-review-compliance` | Project/domain/task compliance from `CONTEXT.md`, `docs/adr/`, `architecture.md`, and `Test Specification`; BC/project naming, construct grounding, `Integration` push-up seams, traceability to `Expected Behaviors` / `Decision Matrix` / AAA cases, mutation recommendations, and reconciled `New and Modified Objects` | both |
   | `al-review-bugscan` | Fresh-read correctness and obvious logic faults; design escalation for ad-hoc conditionals | both |
   | `al-review-bc` | BC topic-store anti-patterns, platform reinvention, speculative generality, and the direct-`xRec` validation trap | both |
   | `al-review-comments` | Modified-file comment invariants and evidenced recent-history regressions | both |
   | `al-review-appsource` | Intentionality of diff-added public shipped procedures, fields, and actions, read with `app.json` | per-feature only |
   | `al-review-perf` | `al-performance` `scan_al_code` findings in touched procedures of changed `.al` files; identify-only, no apply plan | both |

   Each lens returns its sentinel, the `Mode:` echo, then labeled `Finding:` / `Where:` / `Why:` / `Source:` blocks; the perf lens adds `Severity:`. When `al-performance` is absent, the perf lens returns exactly `perf scan skipped: al-performance MCP not available` in place of its sentinel — degraded coverage, never clean. Name the remedy in the screen: the scanner needs `uv` or Python 3.9+ with `mcp[cli]` on PATH, and a `disabledMcpServers` entry naming `al-performance` suppresses it on purpose. Use [`LANGUAGE.md`](../../references/LANGUAGE.md) exactly.

2. **Judge.** Invoke `al-review-judge` once with `Mode: code-review`, the scoped diff, and all raw lens blocks — never the lenses' `Out-of-scope:` notes. Its return begins `REVIEW JUDGMENT`; every supplied finding comes back with `Rank:`, `Classification:`, `Finding:`, `Where:`, `Evidence:`, `Lenses:`, and `Reason:`. The judge alone classifies severity, and severity routes nothing: this skill dispositions every `MUST-FIX` and `SHOULD-FIX` survivor as `rework` or `change request` by the baseline test under **A finding on code** in [`review-lenses.md`](../../references/review-lenses.md); `NO-ACTION` drops. Judge unavailable → `BLOCKED`, name it, **Stop**; no inline substitute.

3. **Veto.** Send the rubber-duck every `MUST-FIX` survivor per [`rubber-duck-review.md`](../../references/rubber-duck-review.md). A duck refutation vetoes autonomous action: the finding leaves the rework queue and is reported at the close, never fixed. A candidate the duck raises gets one bounded judge follow-up containing only that candidate, its prior classification, and the scope; reconcile that result without another duck or judge loop. Missing follow-up judge → `BLOCKED`, **Stop**. Rubber-duck unavailable → `BLOCKED`, name it, **Stop** — the veto licenses autonomous fixing of `MUST-FIX` rework, and no `MUST-FIX` lands without it. `SHOULD-FIX` rework lands un-vetted; the single re-review is its check.

A mutation recommendation is advisory, never rework. A non-empty rework queue or change-request residue holds the gate.

## Fix and grill

Apply the whole rework queue autonomously, then grill the change-request residue, then re-review once. Builds and containers stay serial.

- **Substantive:** changed behaviour, decision, design judgment, or public/shipped surface. The fix runs under the originating task per the repair exception in [`task-lifecycle.md`](../../references/task-lifecycle.md); `status:` and `phase:` stay untouched. Invoke `al-red-green` with the missing or adjusted AAA case (Arrange/Act/Assert), the originating task's `New and Modified Objects` block, and the task file path. Its red is graded blind by `al-review-red` and its test surface is hash-frozen through green ([`tdd.md`](../../references/testing/tdd.md)) — a `BLOCKED` from either escalates to `/al-steer`, since the AAA case was minted by this review and correcting it is a decision. Reconcile `New and Modified Objects` and `Researched:` bullets, commit under the `T-NNN` prefix, and require green. Mutation is recommended follow-up, not run here. An AS0007 public/shipped rename is substantive or a change request, never hygiene.
- **Hygiene:** provably non-semantic. Apply, delegate the gate through `/al-build`, then commit standalone. A red build → revert and re-judge as substantive.
- A performance finding is classified by semantic risk like any other, never by its scanner provenance. A rewrite provably equivalent on the read path is hygiene. One that changes what is loaded, locked, persisted, or triggered is substantive — and when no red can prove it, it joins the grilling queue rather than inventing one.
- User-verified behaviour is a baseline, so in a per-feature diff a substantive finding in a user/API slice already walked by `/al-user-verification` is a change request by the criterion itself — an autonomous fix would invalidate the walk. Hygiene still lands. Backend-only substantive rework uses red→green normally.
- A substantive fix that cannot go green joins the grilling queue; never leave the tree red or invent a decision.

Grill the change-request residue in the live session per **A finding on code**: one conversation at a time in the judge's `Rank:` order, clustered by contested baseline decision, each converging on one of the three terminal outcomes. A do-it-now ruling joins this run's fixes on the substantive/hygiene terms above. A written task lands in `specs/<branch>/tasks/` and holds the gate until it is `done`. A keep-the-code ruling clears here and routes the baseline update as `Next: /al-steer` citing trigger #6.

Re-review the updated diff exactly once — a complete fresh fleet, judged from scratch. Clean → clean gate. A remaining or recurring finding → report `Next: /al-implement T-NNN` (or `/al-steer` for recurrence) and do not re-fix.

A `done` task with logic no red proved (`deviations:`, refactor-added branches, or untested-path edits) and no `Closeout` mutation verdict gets `Next: /al-mutate T-NNN`, never `/al-implement`. Mutation is user-directed, stamps only `phase: mutated` on an already-`done` task, and never holds the clean stamp.

## Clean gate

No rework and no open change request after the single re-review clears the gate. A clean user/API per-slice review writes `review: clean`; this skill is its only writer. Backend-only slices carry no field — their gate flips are the durable record. Lifecycle and strip rules live in [`task-lifecycle.md`](../../references/task-lifecycle.md).

| Mode | Clean write and handoff |
|---|---|
| User/API slice, first review | In one Edit, stamp `review: clean` and flip verify `blocked` → `ready`, then `Next: /al-refine T-NNN`. |
| User/API slice, re-review | Re-stamp only; preserve its `ready-for-verification` Verification Plan. Missing `Record: yes` recording at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` → `/al-page-script T-NNN`; otherwise → `/al-user-verification T-NNN`. |
| Backend-only slice | Find the first technical task whose `depends_on:` names this slice's last technical task; flip every technical task in that next slice `blocked` → `ready`, then `Next: /al-refine` its first task. The final slice hands to `Next: /al-code-review` per-feature and then breaking-change validation. |
| Per-feature | Flip `kind: breaking-change` `blocked` → `ready`, `Next: /al-validate-breaking-changes` → merge. |

## Screen and handoff

Keep lens churn, the judge transcript, and the grilling's step-by-step out of chat. Open with one line and a three-row `**Scope**` / `**Baseline**` / `**Mode**` chip; name each failed lens. Close with `**Rework**` (applied, with commits), `**Change requests**` (each with its terminal outcome), and `**Gate**`. On abort, give the partial summary and no resume.

Relay findings as `Finding:` / `Where:` / `Action:`, verifying each cause → effect in named objects before sending. This skill writes no durable planning artifacts except clean-gate state, reconciled originating tasks, and the tasks the grilling writes. It makes only the scoped code/test edits the rework queue and do-it-now rulings require, plus their fix commits; never `architecture.md`, `event-model.md`, ADRs, `CONTEXT.md`, or `.out-of-scope/`.

| Condition | Next |
|---|---|
| Change request written as a task | `Next: /al-implement T-NNN`; rerun review after. |
| Finding remaining after the re-review | `Next: /al-implement T-NNN`, or `/al-steer` on recurrence. |
| Keep-the-code ruling | `Next: /al-steer` citing trigger #6 — the baseline update. |
| Mutation recommendation | `/al-mutate T-NNN` alongside a clean stamp. |
| Clean user/API slice | First review → `Next: /al-refine`; re-review → `Next: /al-page-script T-NNN` or `Next: /al-user-verification T-NNN`. |
| Clean backend-only slice | `/al-refine` next slice, or `Next: /al-code-review` per-feature when final. |
| Clean feature | `Next: /al-validate-breaking-changes`, then merge; recommend `/al-quiz` on the feature diff. |
| Unreadable state | `Next: /al-steer`. |

## Composition

| | |
|---|---|
| **Runs after** | Slice-done (including user/API re-review after `/al-steer` strips `review: clean`) or feature-done |
| **Hands off to** | `/al-implement`, `/al-refine`, `/al-page-script`, `/al-user-verification`, `/al-validate-breaking-changes`, or `/al-steer` as above |
| **Calls directly** | `/al-build`; one rubber-duck veto pass per review pass |
| **Spawns** | The mode's lenses (five per-slice, six per-feature, per [`review-lenses.md`](../../references/review-lenses.md)), `al-review-judge`, bounded judge follow-up, and `al-red-green` (which nests `al-review-red`) per substantive rework |
| **Replan venue** | `/al-steer` for keep-the-code baseline updates and red→green blocks |
