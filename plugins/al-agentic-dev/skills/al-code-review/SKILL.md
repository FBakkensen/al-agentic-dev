---
name: al-code-review
description: AL/Business Central code review at gate points. Report-only by default; pass --fix to land must-fix findings and re-review once. Use when a slice's last technical task lands (slice-done) — both backend-only and user/API-facing slices, before the verify task is refined — when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

# /al-code-review — review gate

Review finished AL/Business Central work at **slice-done** or **feature-done**. Default is report-only. `--fix` lands eligible must-fixes red→green and re-reviews once. `/al-build` is the only skill this skill invokes; lenses, `al-review-judge`, the rubber-duck, and (under `--fix`) `al-red-green` are spawned agents.

## Entry and stops

- **Slice-done:** every technical task in one slice is `done`. Review the technical code before verification: implement → code-review → refine verify task → page-script/user-verification → next user/API slice. A backend-only slice skips verification and opens its next slice. `/al-refactor` and `/al-mutate` run after implementation and before this gate; `/al-mutate` normally supplies the clean verdict that marks a task `done`.
- **Feature-done:** review the full feature diff after the final task is `done`, before merge.
- Require branch `^\d{3}-`, `specs/<branch>/tasks/`, a green `/al-build` baseline (CodeCop, AppSourceCop, UICop, AppSource Validation), and a tree matching reviewer intent — unrelated uncommitted reshape pollutes scope. `--fix` requires a clean tree. Any failure → **Stop** and report the gap; never review an uncertain baseline.
- Read [`test-specification.md`](../../references/testing/test-specification.md), [`test-strategy.md`](../../references/testing/test-strategy.md), and [`GROUND-RULES.md`](../../references/GROUND-RULES.md) before synthesis.
- A user/API slice is review-ready only when its verify task is `blocked` without a replan flag, or `ready-for-verification` without `review: clean`. `blocked` with a replan flag, a non-`done` technical task, or a `done` verify task → **Stop**; code lenses do not clear failed user evidence.

## Scope

Per-slice scope is the completed technical tasks sharing one `slice:` with an owed review. Per-feature scope is the full pre-merge feature diff. WIP, mixed state, or ambiguous commits → ask one lettered question: slice `<slug>` diff / branch versus `main` / uncommitted tree / named SHA range.

A per-slice diff spans every `T-NNN` commit from its first commit through `done`, plus this run's `--fix` commits. `T-NNN <verb>: <message>` prefixes identify ownership; `--fix` preserves the originating prefix. A squash that defeats the prefix → ask, never guess. Task files under `tasks/` are evidence: read their `status:`, `depends_on:`, `Closeout`, and `Contract notes` fields rather than inferring them.

## Review pass

1. **Find.** Fan out the mode's read-only lenses in parallel — five per-slice, six per-feature, per the Mode column — passing only the scoped diff and context. Pass the compliance lens the grounding rules' **Constructs** bullet from [`GROUND-RULES.md`](../../references/GROUND-RULES.md) verbatim. A failed or empty lens is a reported summary gap, never a silent retry.

   | Lens | Owns | Mode |
   |---|---|---|
   | `al-review-cr-compliance` | Project/domain/task compliance from `CONTEXT.md`, `docs/adr/`, `architecture.md`, and `Test Specification`; BC/project naming, construct grounding, `Integration` push-up seams, traceability to `Expected Behaviors` / `Decision Matrix` / AAA cases, mutation recommendations, and reconciled `New and Modified Objects` | both |
   | `al-review-cr-bugscan` | Fresh-read correctness and obvious logic faults; design escalation for ad-hoc conditionals | both |
   | `al-review-cr-bc` | BC topic-store anti-patterns, platform reinvention, speculative generality, and the direct-`xRec` validation trap | both |
   | `al-review-cr-comments` | Modified-file comment invariants and evidenced recent-history regressions | both |
   | `al-review-cr-appsource` | Intentionality of diff-added public shipped procedures, fields, and actions, read with `app.json` | per-feature only |
   | `al-review-cr-perf` | `al-performance` `scan_al_code` findings in touched procedures of changed `.al` files; never `fix_al_file` | both |

   Each lens returns its one-line sentinel, then labeled `Finding:` / `Where:` / `Why:` / `Source:` blocks; the perf lens adds `Severity:` and any auto-fixable marker. When `al-performance` is absent, the perf lens returns exactly `perf scan skipped: al-performance MCP not available` in place of its sentinel. Use [`LANGUAGE.md`](../../references/LANGUAGE.md) exactly.

2. **Judge.** Invoke `al-review-judge` once with the scoped diff and all raw lens blocks. Its return begins `REVIEW JUDGMENT`; every supplied finding comes back with `Rank:`, `Classification:`, `Finding:`, `Where:`, `Evidence:`, `Lenses:`, and `Reason:`. Map `MUST-FIX` / `SHOULD-FIX` / `NO-ACTION` to must-fix, nit, and dropped. The judge alone classifies; this skill alone marks each must-fix as fixable in this run or as requiring a decision. Judge unavailable → `BLOCKED`, name it, **Stop**; no inline substitute.

3. **Veto.** Send the rubber-duck every must-fix survivor per [`rubber-duck-review.md`](../../references/rubber-duck-review.md). A duck refutation vetoes autonomous action → escalate, never fix. A candidate the duck raises gets one bounded judge follow-up containing only that candidate, its prior classification, and the scope; reconcile that result without another duck or judge loop. Missing follow-up judge → `BLOCKED`, **Stop**. Rubber-duck unavailable under `--fix` → degrade to report-only: report the must-fix queue and land nothing, since the veto is what licenses autonomous fixing.

Partition survivors: fixable `MUST-FIX` → fix queue; `SHOULD-FIX` → nits; `NO-ACTION` → dropped; duck-refuted or requiring a decision → escalate to `/al-steer`. A mutation recommendation is advisory, never a must-fix. A non-empty must-fix queue holds the gate.

## Report-only

Report and stop; move no code. List each must-fix as `Finding / Where / Why / Recommended next`, normally `Next: /al-implement T-NNN` traced from its commit prefix (natural owner only when the prefix is fuzzy). Label provably non-semantic comment scrub, local/private rename, and formatting as hygiene. State each nit once.

A `done` task with logic no red proved (`deviations:`, refactor-added branches, or untested-path edits) and no `Closeout` mutation verdict gets `Next: /al-mutate T-NNN`, never `/al-implement`. Mutation is user-directed, stamps only `phase: mutated` on an already-`done` task, and never holds the clean stamp. Escalations write nothing and route to `/al-steer`.

## `--fix`

Land the fix queue, then re-review once. Builds and containers stay serial.

- **Substantive:** changed behaviour, decision, design judgment, or public/shipped surface. The fix runs under the originating task per the repair exception in [`task-lifecycle.md`](../../references/task-lifecycle.md); `status:` and `phase:` stay untouched. Invoke `al-red-green` with the missing or adjusted AAA case (Arrange/Act/Assert), the originating task's `New and Modified Objects` block, and the task file path. Reconcile `New and Modified Objects` and `Researched:` bullets, commit under the `T-NNN` prefix, and require green. Mutation is recommended follow-up, not run here. An AS0007 public/shipped rename is substantive or escalated, never hygiene.
- **Hygiene:** provably non-semantic. Apply, run `/al-build`, and commit standalone. A red build → revert and re-judge as substantive or escalate.
- A substantive fix that cannot go green, or any finding that requires a decision → escalate; never leave the tree red or invent a decision.
- In a per-feature diff, a substantive finding in a user/API slice already walked by `/al-user-verification` escalates to `/al-steer` — an automatic fix would invalidate the walk. Hygiene still lands. Backend-only substantive findings use red→green normally.

Re-review the updated diff exactly once. Clean → clean gate. A remaining or recurring must-fix → report `Next: /al-implement T-NNN` (or `/al-steer` for recurrence) and do not re-fix.

## Clean gate

No must-fix (after the single re-review under `--fix`) clears the gate. A clean user/API per-slice review writes `review: clean`; this skill is its only writer. Backend-only slices carry no field — their gate flips are the durable record. Lifecycle and strip rules live in [`task-lifecycle.md`](../../references/task-lifecycle.md).

| Mode | Clean write and handoff |
|---|---|
| User/API slice, first review | In one Edit, stamp `review: clean` and flip verify `blocked` → `ready`, then `Next: /al-refine T-NNN`. |
| User/API slice, re-review | Re-stamp only; preserve its `ready-for-verification` Verification Plan. Missing `Record: yes` recording at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` → `/al-page-script T-NNN`; otherwise → `/al-user-verification T-NNN`. |
| Backend-only slice | Find the first technical task whose `depends_on:` names this slice's last technical task; flip every technical task in that next slice `blocked` → `ready`, then `Next: /al-refine` its first task. The final slice hands to `Next: /al-code-review` per-feature and then breaking-change validation. |
| Per-feature | Flip `kind: breaking-change` `blocked` → `ready`, `Next: /al-validate-breaking-changes` → merge. |

## Screen and handoff

Keep lens churn and the judge transcript out of chat. Open with one line and a three-row `**Scope**` / `**Baseline**` / `**Mode**` chip; name each failed lens. Close with `**Fix queue**`, `**Nits**`, `**Escalated**`, and `**Gate**`; under `--fix`, also list `**Fixed**` commits. On abort, give the partial summary and no resume.

Relay findings as `Finding:` / `Where:` / `Action:`, verifying each cause → effect in named objects before sending. This skill writes no durable planning artifacts except clean-gate state and, under `--fix`, reconciled originating tasks. Under `--fix`, it makes only the scoped code/test edits the eligible fix-queue findings require, plus their fix commits; never `architecture.md`, `event-model.md`, ADRs, `CONTEXT.md`, or `.out-of-scope/`.

| Condition | Next |
|---|---|
| Must-fix queue | `Next: /al-implement T-NNN` for highest-priority owner; rerun review after. |
| Mutation recommendation | `/al-mutate T-NNN` alongside a clean stamp. |
| Clean user/API slice | First review → `Next: /al-refine`; re-review → `Next: /al-page-script T-NNN` or `Next: /al-user-verification T-NNN`. |
| Clean backend-only slice | `/al-refine` next slice, or `Next: /al-code-review` per-feature when final. |
| Clean feature | `Next: /al-validate-breaking-changes`, then merge; recommend `/al-quiz` on the feature diff. |
| Escalation or unreadable state | `Next: /al-steer`; report-only fallback is `Next: /al-implement` on named findings. |

## Composition

| | |
|---|---|
| **Runs after** | Slice-done (including user/API re-review after `/al-steer` strips `review: clean`) or feature-done |
| **Hands off to** | `/al-implement`, `/al-refine`, `/al-page-script`, `/al-user-verification`, `/al-validate-breaking-changes`, or `/al-steer` as above |
| **Calls directly** | `/al-build`; one rubber-duck veto pass per review pass |
| **Spawns** | The mode's `al-review-cr-*` lenses (five per-slice, six per-feature), `al-review-judge`, bounded judge follow-up, and under `--fix` `al-red-green` |
| **Replan venue** | `/al-steer` only for escalation classes |
