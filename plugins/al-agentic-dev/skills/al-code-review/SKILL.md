---
name: al-code-review
description: AL/Business Central code review at gate points. Report-only by default; pass --fix to land must-fix findings and re-review once. Use when a slice's last technical task lands (slice-done) — both backend-only and user/API-facing slices, before the verify task is refined — when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-code-review — review gate

Review finished AL/Business Central work at **slice-done** or **feature-done**. Default is report-only; `--fix` lands eligible must-fixes through red→green and re-reviews once. Invoke only `/al-build`; lenses, `al-review-judge`, rubber-duck, and (under `--fix`) `al-red-green` are spawned agents.

## Entry and stops

- **Slice-done:** every technical task in one slice is `done`. Review technical code before verification: implement → code-review → refine verify task → page-script/user-verification → next user/API slice; backend-only skips verification and opens its next slice. `/al-refactor` and `/al-mutate` run after implementation and before this gate; `/al-mutate` normally supplies the clean verdict that marks a task `done`.
- **Feature-done:** review the full feature diff after the final task is `done`, before merge.
- Require branch `^\d{3}-`, `specs/<branch>/tasks/`, a green `/al-build` baseline (CodeCop, AppSourceCop, UICop, AppSource Validation), and a tree matching reviewer intent. Unrelated uncommitted reshape pollutes scope; `--fix` requires a clean tree. Any failure → **Stop**; report the gap, never review an uncertain baseline.
- Read [`test-specification.md`](../../references/test-specification.md), [`test-strategy.md`](../../references/test-strategy.md), and [`voice-contract.md`](../../references/voice-contract.md) before synthesis. A user/API slice is review-ready only when its verify task is `blocked` without a replan flag, or `ready-for-verification` without `review: clean`. `blocked` with a replan flag, a non-`done` technical task, or a `done` verify task → **Stop**; failed user evidence is not cleared by code lenses.

## Scope

Infer **per-slice** from completed technical tasks sharing `slice:` and an owed review; infer **per-feature** from the full pre-merge feature diff. If WIP, mixed state, or commits make that uncertain, ask one lettered question: slice `<slug>` diff / branch versus `main` / uncommitted tree / named SHA range.

Per-slice scope is every `T-NNN` commit from its first commit through `done`, plus this run's `--fix` commits. `T-NNN <verb>: <message>` prefixes identify ownership; `--fix` preserves the originating prefix. A squash that defeats the prefix → ask, never guess. Read task files under `tasks/`; their `status:`, `depends_on:`, `Closeout`, and `Contract notes` fields are evidence, not inference.

## Review pass

1. **Find:** fan out these read-only lenses in parallel, passing only scoped diff/context; compliance also receives the evidence bar's **Constructs** bullet verbatim. A failed or empty lens is a summary gap, never a silent retry.

   | Lens | Owns | Mode |
   |---|---|---|
   | `al-review-cr-compliance` | Project/domain/task compliance from `CONTEXT.md`, `docs/adr/`, `architecture.md`, and `Test Specification`; BC/project naming, construct evidence, `Integration` push-up seams, traceability to `Expected Behaviors` / `Decision Matrix` / AAA cases, rigor advisory, and reconciled `New and Modified Objects` | both |
   | `al-review-cr-bugscan` | Fresh-read correctness and obvious logic faults; design escalation for ad-hoc conditionals | both |
   | `al-review-cr-bc` | BC topic-store anti-patterns (`find_bc_knowledge` → noise-drop `parker-pragmatic/*` / `*/recommend-*` → `get_bc_topic` → `anti_pattern_indicators`), platform reinvention, over-build, and direct `xRec` validation trap | both |
   | `al-review-cr-comments` | Modified-file comment invariants and evidenced recent-history regressions | both |
   | `al-review-cr-appsource` | Intentionality of diff-added public shipped procedures, fields, and actions, read with `app.json` | per-feature only |
   | `al-review-cr-perf` | `al-performance` `scan_al_code` findings in touched procedures of changed `.al` files; never `fix_al_file` | both |

   Lenses return raw `Finding:` / `Where:` / `Why:` / `Source (lens name + topic id):` blocks; perf also returns `Severity:` and any auto-fixable marker. They name file, object, and observed fact; no verdict word survives without its check. `al-performance` absence is the exact one-line skip `perf scan skipped: al-performance MCP not available`. Use [`LANGUAGE.md`](../../references/LANGUAGE.md) exactly.

2. **Judge:** invoke `al-review-judge` once with the scoped diff and all raw blocks. It deduplicates, substantiates, ranks, and returns `MUST-FIX`, `SHOULD-FIX`, or `NO-ACTION`. Map those to must-fix, nit, and dropped. The judge alone classifies; this skill alone marks must-fixes fixable-in-loop or needs-a-decision. `al-review-judge` unavailable → `BLOCKED`, name it, and **Stop**; no inline substitute.

3. **Veto:** give the rubber-duck every must-fix survivor. A duck refutation vetoes autonomous action → escalate, never fix. A candidate it raises gets one bounded judge follow-up containing only that candidate, prior classification, and scope; reconcile that final result without another duck or judge loop. Missing follow-up judge → `BLOCKED` and **Stop**. Follow [`rubber-duck-review.md`](../../references/rubber-duck-review.md), including its cross-family fallback.

Partition survivors: fixable `MUST-FIX` → fix queue; `SHOULD-FIX` → nits; `NO-ACTION` → dropped; duck-refuted or needs-a-decision → escalate (`/al-steer`). A rigor note is advisory, not a must-fix. A non-empty must-fix queue holds the gate.

## Report-only

Report and stop; do not move code. List each must-fix as `Finding / Where / Why / Recommended next`, normally `Next: /al-implement T-NNN` traced from its prefix (natural owner only when fuzzy). Label provably non-semantic comment scrub, local/private rename, and formatting as hygiene; nits are left once.

A `done` task with logic no red proved (`deviations:`, refactor-added branches, or untested-path edits) and no Closeout mutation verdict gets `Next: /al-mutate T-NNN`, never `/al-implement`; mutation is user-directed, stamps only `phase: mutated` on an already-`done` task, and does not hold the clean stamp. Escalations write nothing and route to `/al-steer`.

## `--fix`

Land the fix queue, then re-review once; builds and containers remain serial.

- **Substantive:** changed behaviour, decision, design judgment, or public/shipped surface. Reopen the originating task, invoke `al-red-green` with the missing/adjusted AAA case (Arrange/Act/Assert), the originating task's `New and Modified Objects` block, and task file path; reconcile `New and Modified Objects` and `Researched:` bullets, commit under its `T-NNN` prefix, and require green. Mutation is recommended follow-up, not run here. An AS0007 public/shipped rename is substantive or escalated, never hygiene.
- **Hygiene:** provably non-semantic. Apply, run `/al-build`, and commit standalone. A red build → revert and re-judge as substantive or escalate.
- A substantive fix that cannot go green, or any needs-a-decision finding → escalate; never leave the tree red or invent a decision.
- In a per-feature diff, a substantive finding in a user/API slice already walked by `/al-user-verification` escalates to `/al-steer`; an automatic fix would invalidate the walk. Hygiene still lands. Backend-only substantive findings use red→green normally.

Re-review the updated diff exactly once. Clean → stamp; a remaining or recurring must-fix → report `Next: /al-implement T-NNN` (or `/al-steer` for recurrence) and do not re-fix.

## Clean gate

No must-fix (after the single re-review under `--fix`) writes `review: clean`; this skill is its only writer. Lifecycle and strip rules live in [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md).

| Mode | Clean write and handoff |
|---|---|
| User/API slice, first review | In one Edit, stamp `review: clean`, flip verify `blocked` → `ready`, then `Next: /al-refine T-NNN`. |
| User/API slice, re-review | Re-stamp only; preserve its `ready-for-verification` Verification Plan. Missing `Record: yes` recording at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` → `/al-page-script T-NNN`; otherwise → `/al-user-verification T-NNN`. |
| Backend-only slice | Find the first technical task whose `depends_on:` names this slice's last technical task; flip every technical task in that next slice `blocked` → `ready`, then `Next: /al-refine` its first task. The final slice hands to `Next: /al-code-review` per-feature and then breaking-change validation. |
| Per-feature | Flip `kind: breaking-change` `blocked` → `ready`, `Next: /al-validate-breaking-changes` → merge. |

## Screen and handoff

Keep lens churn and judge transcript out of chat. Open with one line and a three-row `**Scope**` / `**Baseline**` / `**Mode**` chip; name each failed lens. Close with `**Fix queue**`, `**Nits**`, `**Escalated**`, and `**Gate**`; under `--fix`, also list `**Fixed**` commits. On abort, give the partial summary and no resume.

Use `Finding:` / `Where:` / `Action:` for relayed findings and verify each cause → effect in named objects before sending. The judge's return begins `REVIEW JUDGMENT`; each supplied finding remains represented with `Rank:`, `Classification:`, `Finding:`, `Where:`, `Evidence:`, `Lenses:`, and `Reason:`. This skill writes no durable planning artifacts except clean-gate state and, under `--fix`, reconciled originating tasks. Under `--fix`, it may make only the scoped code/test edits required by eligible fix-queue findings and their required fix commits; never `architecture.md`, `event-model.md`, ADRs, `CONTEXT.md`, or `.out-of-scope/`.

| Condition | Next |
|---|---|
| Must-fix queue | `Next: /al-implement T-NNN` for highest-priority owner; rerun review after. |
| Rigor note | `/al-mutate T-NNN` alongside a clean stamp. |
| Clean user/API slice | First review → `Next: /al-refine`; re-review → `Next: /al-page-script T-NNN` or `Next: /al-user-verification T-NNN`. |
| Clean backend-only slice | `/al-refine` next slice, or `/al-validate-breaking-changes` when final. |
| Clean feature | Merge; recommend `/al-quiz` on the feature diff. |
| Escalation or unreadable state | `Next: /al-steer`; report-only fallback is `Next: /al-implement` on named findings. |

## Composition

| | |
|---|---|
| **Runs after** | Slice-done (including user/API re-review after `/al-steer` strips `review: clean`) or feature-done |
| **Hands off to** | `/al-implement`, `/al-refine`, `/al-page-script`, `/al-user-verification`, `/al-validate-breaking-changes`, or `/al-steer` as above |
| **Calls directly** | `/al-build`; one rubber-duck veto pass per review pass |
| **Spawns** | Six `al-review-cr-*` lenses, `al-review-judge`, bounded judge follow-up, and under `--fix` `al-red-green` |
| **Replan venue** | `/al-steer` only for escalation classes |
