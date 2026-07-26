---
name: al-mutate
description: "Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run the script-backed build gate, classify, revert, report killed/surviving/equivalent mutants. The rigor step the user runs after `/al-refactor` on whatever arrived without a red, or standalone on legacy code before `/al-refactor`."
allowed-tools: ["execute", "read", "edit"]
---

# /al-mutate — test-rigor gate

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Mutate production code one site at a time. Build. Classify. Revert.

This skill guards **oracle sensitivity** at the unit/integration driver layers ([test-strategy.md](../../references/testing/test-strategy.md)).

## Preconditions

- Tree clean. Dirty tree makes revert ambiguous.
- Committed green baseline. Broad revert returns to `HEAD`; uncommitted green work is not safe.
- Delegate the full gate through `/al-build` and require green. Red baseline → survivors carry no signal.
- Target is production code; not tests, not generated `.rdlc` or `.xlf`, not captions / labels / tooltips.
- Enough scope to plan. `/al-mutate` builds the mutation plan from caller scope, changed files, task context, and requested target; `/al-implement` does not pre-plan sites.
- No refactor in flight. Land the reshape green, commit, then mutate — a shape still moving stales every classification.

Any precondition fails → **Stop**, surface the gap.

## Plan

**Plan first, execute second.** The host owns the plan — included sites, skipped sites, one operator per qualifying site. Workers execute the approved plan only, one mutant per worker; a worker never adds, removes, or replaces a mutant.

Sites qualify by provenance: code that arrived without a red. That means legacy paths, tests written after their code, branches a refactor introduced, and work absorbed without its own red (`deviations:` is the breadcrumb). Unknown provenance counts as no red. A reshape only moves covered behaviour — its old red still holds — so of reshaped code, only what the reshape *added* qualifies. Never qualify a site by reading its tests and judging the assertions rigorous; that judgment is the one mutation replaces.

Ties break toward mutating where a fault costs most: irreversible writes, ledger entries, status flips other code keys off. Trivial code — pure delegation, accessors, single-line init — skips. Each skip is a recorded claim, "this behaviour has failed a test", for the report and the cross-check to attack.

[tdd.md](../../references/testing/tdd.md) homes the operator catalogue, the one-operator-per-qualifying-site selection heuristics, the two AL operators that risk a stillborn, and the reachability check — an unreached line routes to `/al-refine` (add coverage) or `/al-refactor` (delete the dead branch), never to a killer test.

Cross-check every non-trivial plan via a rubber-duck consult before execution ([rubber-duck-review.md](../../references/rubber-duck-review.md)): *"what mutations are missing or misaligned? AND does this surface any of the eight replan triggers? Return a bulleted list."*

## Execution

**One mutation, one build, one revert.** Verify the tree matches `HEAD` before the next mutation — batched mutations conflate the signal, and one un-reverted mutation poisons every later classification.

**A kill is behavioural, never a compile error.** Make the mutant compile, then let behaviour catch it. The evidence rules live in Classification below.

The gate is `/al-build`, invoked by `al-mutant-cycle` itself while the mutation is applied. `-UnitTestOnly` applies only when `unitTestApp` is configured and the site is genuinely unit-layer. Every other site — integration, page/TestPage, install/publish, permissions, container-state behaviour — uses the full gate. The final closeout is always the full gate.

**Survivors continue the plan.** A survivor fails the current mutation pass, not the task. Keep executing approved mutants after revert proof. A reached survivor exposing a test gap gets its killer test as TDD work the user resumes via `/al-implement` — name it as the next step, never write it here. Full plan rerun only when the new test or fix changes shared decision logic.

A green pass with no survivors and no equivalences prompts a plan check: "nothing worth mutating" is a plan claim, recorded as skip rationale, never a result.

**Equivalence needs a specific reason.** "Looks equivalent" fails; the recorded reason protects future readers from re-chasing the un-killable mutant.

**Survive compaction.** Keep the approved plan and per-mutant verdicts in the session todo list — one todo per site, description carries the verdict; todos survive compaction, this skill's injected body does not. After a compaction, re-read this skill, verify the tree matches `HEAD`, and resume from the todo state.

## Delegation

**Invoke the named `al-mutant-cycle` custom agent once per approved mutant — the pass stays sequential.** Wait for its returned evidence, classify and record the verdict yourself, close the completed thread, then invoke the next. Never one invocation for the whole plan: a single run holding many cycles accumulates gate output until it misclassifies, and a mid-run failure loses every verdict it held. The agent's own body carries the worker rules.

The host owns plan generation and approval, preflight facts (baseline SHA, clean-tree proof), classification from the relayed evidence, per-mutant verdict recording (the session todos), survivor/equivalence judgment, the final full-gate closeout, the `.output` report, and any killer tests.

`al-mutant-cycle` unavailable → report `BLOCKED`, name it as the missing agent, and stop. No generic-subagent substitution.

The spawn prompt carries exactly what the caller alone knows:

- the one mutant — file, site, operator, and the exact edit to apply;
- the gate variant — full, or `-UnitTestOnly`;
- the baseline SHA;
- the authoritative artifact paths, marking the summary for mechanical expansion: `.output/TestResults/summary.json (expand: resultFile where passed=false)`.

The caller — never the worker — judges whether a relayed `summary.json` is this attempt's own: the gate may leave an earlier run's file untouched when the attempt stops before result emission, so corroborate a present-but-unexpected summary against the exit code and the appended timing line before treating it as this attempt's result. `missing` means the path is absent — the worker never substitutes.

The final full-gate closeout is the host's own `/al-build` run, never a mutant cycle.

## Classification

**Classify from the relayed evidence, never the exit code alone.**

- `outcome:"error"` proves only that the gate did not reach a test verdict — compile, publish, container, and other thrown failures all share it:
  - An explicit compiler/parser diagnostic naming the mutated file and the mutated line or construct → `invalid_stillborn`. A stillborn is a mutation-coverage gap, not a pass. Re-plan a *compiling* operator at that site so a test must answer. The site closes only on a test-caught kill or a genuine survivor. A non-zero stillborn count blocks the clean verdict, exactly like a survivor. Record the diagnostic, confirm the clean revert, continue.
  - Publish, container, stale-container, connection, or other documented infrastructure evidence → the retry path in Infra recovery below.
  - Missing timing/artifact evidence, an ambiguous diagnostic, or any other `outcome:"error"` → `blocked_infra_unknown`; stop after the clean revert proof. Never stillborn, never killed.
- `outcome:"failed"` is `killed` only with a named failing test or a mutated-path assertion/exception in the relayed evidence. Without that evidence the kill claim is unestablished — never `killed`. AL Runner's own exit-3 compile error maps to `outcome:"failed"`; the app is analyzer-compiled before AL Runner runs, so that combination is contradictory → `not_classified_runner_contract`, never killed.
- `outcome:"passed"` → `survived` or `equivalent_candidate`.
- AL Runner `ERROR` / exit 2 during a mutant → `not_classified_runner_contract` — not killed, not survived, not equivalent. The full gate is no fallback: it also runs AL Runner first. Record the exact runner output, confirm the clean revert, continue; the host judges evidence sufficiency after the pass.
- Container/tooling failure never counts as killed.

## Infra recovery inside a live mutant

A retry answers a documented `/al-build` infrastructure failure only — container connect, publish, stale container state. It never answers the mutant's own doing. The worker always reverts after its one attempt, so a retry is a fresh `al-mutant-cycle` invocation for the *same* mutant instructions. First retry: restart the container, then invoke again. Infrastructure failure again: recreate the container, then invoke once more. The retry changes nothing else — same mutant, same gate scope. Container state repairs only through restart or recreate, never by hand. Infrastructure failure after the recreate retry → `blocked_infra_repeat`. Stop after confirming the clean tree the last revert left. Retried attempts classify under Classification above.

## Report

**Write the durable session report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`** — ignored output, not committed. Survivors and stillborns are the actionable sections, one row per site with classification and next action — killer-test direction for a survivor, the re-planned compiling operator for a stillborn. Killed mutants each name the catching test. Equivalent candidates carry their specific reason; the host confirms. Include plan rationale, skipped-site rationale, baseline SHA, per-mutant gate command and `outcome`, recovery attempts, the final full-gate result, and counts: killed / survived / equivalent / stillborn / unclassified / blocked.

The task file gets the `Closeout` mutation verdict shape from [task-grammar.md](../../references/task-grammar.md).

The frontmatter stamp reads off the verdict. A **clean verdict** — no survivors and no unresolved stillborns, or every remaining item a documented equivalence — flips the task `done` per [task-lifecycle.md](../../references/task-lifecycle.md), which homes the same-Edit `phase: mutated` stamp, the dependent opens, and the repair exception. An **open verdict** — survivor, unresolved stillborn — stamps `phase: mutated` only; `status:` stays `ready-for-implementation` until the follow-up round closes clean. Target already `status: done` (a post-hoc rigor run): a clean verdict stamps `phase: mutated` only, and a survivor routes its killer test through the repair exception — `/al-implement` re-entry under the originating `T-NNN`, never a demotion of `done`.

Emit the Gate report once at closeout, per [GROUND-RULES.md](../../references/GROUND-RULES.md): rigor proved (or not) for the behaviour under test, soft spots that remain by design, and the user's call. The task-file `Closeout` verdict lands alongside it.

## Next step

End by naming the concrete next move, read off the verdict:

- **Clean verdict** → the task flipped `done` above; name the slice gate: more `ready-for-implementation` tasks in the slice → `Next: /al-implement` (next task); slice-done → `Next: /al-code-review` per-slice — the review gate runs before the verify task is opened.
- **Reached survivor exposing a test gap** → `Next: /al-implement` to write the killer test, then rerun the survivor site; the task stays `ready-for-implementation` until the round closes clean.
- **Unresolved stillborn** → the host re-plans a *compiling* operator at that site and reruns it — not a clean handoff; the site closes only when the re-planned mutant is test-caught or genuinely survives.
- **Unreached-line / missing-coverage survivor** → `Next: /al-refine` (add coverage).
- **Blocked** → `Next: /al-steer`.

If state can't be read, fall back to `/al-code-review`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (the rigor step the user runs after reshape), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-code-review` on a clean verdict (slice/feature gate); `/al-implement` for a reached survivor exposing a test gap (resume TDD for the killer test) or for the next `ready-for-implementation` task; `/al-refine` only for unreached-line or missing-coverage cases |
| **Spawns**         | `al-researcher` for BaseApp behaviour needed to classify a survivor; `al-mutant-cycle` custom agent — one supplied mutate→gate→revert cycle per approved mutant |
| **Calls directly** | `/al-build` (full-gate closeout) — the only skill it invokes; rubber-duck consult cross-checks non-trivial mutation plans before execution ([rubber-duck-review.md](../../references/rubber-duck-review.md)) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/grill-me` (classification call needs the user) |
