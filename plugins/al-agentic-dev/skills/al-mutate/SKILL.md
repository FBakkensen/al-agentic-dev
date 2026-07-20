---
name: al-mutate
description: "Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run the script-backed build gate, classify, revert, report killed/surviving/equivalent mutants. The rigor step the user runs after `/al-refactor` on whatever arrived without a red, or standalone on legacy code before `/al-refactor`."
allowed-tools: ["execute", "read", "edit"]
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Each survivor is a real coverage gap or a documented equivalence.

**Layer.** Guards **oracle sensitivity** at the unit/integration driver layers (see [`test-strategy.md`](../../references/test-strategy.md)): mutation proves an assertion actually *catches* the fault, not merely runs green.

## Preconditions

- Tree clean. Dirty tree makes revert ambiguous.
- Committed green baseline. Broad revert returns to `HEAD`; uncommitted green work is not safe.
- Baseline full `/al-build` green. Red baseline → survivors carry no signal.
- Target is production code; not tests, not generated `.rdlc` or `.xlf`, not captions / labels / tooltips.
- Enough scope to plan. `/al-mutate` builds the mutation plan from caller scope, changed files, task context, and requested target; `/al-implement` does not pre-plan sites.

Any precondition fails → **Stop**, surface the gap.

## Workflow

**Plan first, execute second.** Host `/al-mutate` chooses included sites, skipped sites, and one operator per qualifying site. Cross-check non-trivial plans via a rubber-duck consult before worker execution ([rubber-duck-review.md](../../references/rubber-duck-review.md)): *"what mutations are missing or misaligned? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet. Workers execute the approved plan only, one mutant per worker; a worker does not add, remove, or replace mutants.

**One mutation, one build, one revert.** Apply one mutation. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the selected gate. Classify. Revert with `git checkout -- .`. Verify tree matches `HEAD` before next mutation. Batched mutations conflate signal; un-reverted mutations poison production and corrupt every subsequent classification. The verify step catches a silent failed revert.

**Survivors are the artifact.** Green pass with no survivors and no equivalences → either perfect tests or no unproven logic worth mutating; the latter belongs in the plan, not the result.

**Survive compaction.** A long mutation run outlives the context window: keep the approved mutation plan and per-mutant verdicts in the session todo list (one todo per mutation site, description carries the verdict) — todos survive context compaction; this skill's injected body does not. After a compaction, re-read this skill, verify the tree matches `HEAD`, and resume from the todo state.

**Equivalence needs a specific reason.** "The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment" is an equivalence reason; "looks equivalent" is not. The recorded reason protects future readers from chasing the un-killable mutant.

**A red is a killed mutant.** The strongest mutation is deleting the code — and TDD ran it first: the test failed while the production code did not yet exist. Mutation testing asks the same question after the fact. Ask it only where it was never asked: code that arrived without a red — legacy paths, tests written after their code, branches a refactor introduced, work absorbed without its own red (`deviations:` is the breadcrumb). Never answer it by reading the tests and finding the assertions rigorous; that judgment is the one mutation exists to replace.

**A kill is behavioural, never a compile error** — the exact symmetry of the red, which fails on an assertion, not a compile error (`tdd.md`: Red phase, Scaffold-before-Red). The mutation-time analogue of "deleting the code" removes *behaviour while preserving compilation*: comment out an assignment whose variable still reads, not one whose removal breaks the build. A mutant the compiler rejects never ran — it forces no test to answer, so it proves nothing about the assertions. Force the kill onto a test the way Scaffold forces the red onto an assertion: make the mutant compile, then let behaviour catch it.

**The red guards a behaviour, not lines.** Reshape moves code; the test that once failed against the rule still fails wherever the rule lives now. Only what the reshape added never failed anything. When you can't tell how code arrived, it arrived without a red — and the tie breaks harder toward mutating the more a fault costs to catch: irreversible writes, ledger entries, status flips other code keys off. Trivial code (pure delegation, accessors, single-line init) does not host hidden bugs; the first caller catches regressions regardless of assertion strength. Each skip is a recorded claim — "this behaviour has failed a test" — for the report and the cross-check to attack.

**One operator per qualifying site.** Pick operator most likely to expose underassertion at *that* site: boundary flip in money math, guard inversion in validation chain, statement removal in posting subscriber, `Validate()` bypass when field trigger carries contract. Operator catalogue and selection heuristics in [tdd.md](../../references/tdd.md). No fallback operators. No worker-invented alternate mutation.

**Reachability before mutation.** Confirm at least one test exercises target line. Survivor on unreached line is not coverage gap, it is dead code or missing coverage; route to `/al-refine` (add coverage) or `/al-refactor` (delete dead branch).

**No mutation during refactor in flight.** Land refactor green, commit, then mutate. Shape still moving produces classifications that drift; survivor lists go stale before report ships.

**Unit-layer gating via `-UnitTestOnly`.** Use the narrowest meaningful gate. When `unitTestApp` configured and the site is genuinely P-layer, run `test.ps1 -UnitTestOnly` (AL Runner). Integration-only behaviour, page/TestPage behaviour, install/publish behaviour, permissions, AppSource/public surface, or container-state behaviour uses full `test.ps1`. Final closeout is always full `test.ps1`.

**Compile failure is not a kill.** `outcome:"error"` only proves that the gate did not reach a pass/fail test verdict: the build gate uses it for compile, publish, container, and other thrown failures. Classify `invalid_stillborn` only when the relayed bounded output contains an explicit compiler/parser diagnostic that identifies the mutated file and line or construct. It does not count as killed and it does not close the site. A publish, container, infrastructure, missing-artifact, or otherwise ambiguous `outcome:"error"` follows the infra recovery/blocked path below — never `invalid_stillborn`, never killed. Stillborn is a mutation-coverage gap, not a pass: the host re-plans a *compiling* operator at that site so a test must answer — only a test-caught kill or a genuine survivor closes it. Record the compiler diagnostic, broad revert, prove clean tree, continue.

**Runner contract is unclassified.** AL Runner `ERROR` / exit 2 during a mutant → `not_classified_runner_contract`, not killed, not survived, not equivalent. Full gate is not fallback when full gate also runs AL Runner first. Record exact runner output, broad revert, prove clean tree, continue. Host judges evidence sufficiency after the pass.

**Survivors continue the plan.** A survivor fails the current mutation pass, not the task. Keep executing approved mutants after revert proof. A reached real-gap survivor needs a killer test — that is TDD work the user resumes via `/al-implement` (write killer test, prove RED/GREEN, run `/al-build`, rerun the survivor site); name it as the next step, do not run it here. Full plan rerun only when the new test or fix changes shared decision logic.

## Delegation

Invoke the named `al-mutant-cycle` custom agent once per approved mutant — the pass stays sequential: invoke it for one approved mutant, wait for its returned evidence, classify and record the verdict yourself, then invoke it for the next. Never one invocation for the whole plan; a single run holding many mutate-build-revert cycles accumulates gate output until it misclassifies, and a mid-run failure loses every verdict it held. Host owns plan generation, plan approval, preflight (baseline SHA, clean-tree proof), classification from the relayed evidence, per-mutant verdict recording (the session todos), survivor/equivalence judgement, task-block verdicts, the final full `test.ps1` closeout, the `.output` report assembled from the recorded verdicts, and any killer tests. Each invocation owns exactly one mutate-build-recovery-revert cycle and returns its observed evidence only — command, exit code, relayed gate artifacts, revert outcome — never a classification label; that judgment is the host's. **`al-mutant-cycle` unavailable** → report `BLOCKED`, name `al-mutant-cycle` as the missing agent, and stop; no generic-subagent substitution (see [delegation.md](../../references/delegation.md)). Each spawn prompt is self-contained — the worker rules below plus the one mutant (file, site, operator, gate flags, baseline SHA) — and includes verbatim: findings must name file, object, and the observed fact; no verdict words without the check that produced them ([voice-contract.md](../../references/voice-contract.md) Relaying subagent findings).

Every spawn prompt must name the summary path: `.output/TestResults/summary.json`. Mark it for mechanical expansion as `expand: resultFile where passed=false`; add `telemetryFile where passed=false` only when the host will use telemetry for classification. The worker reads that one summary only after its one gate command, then follows only those caller-marked literal fields in encounter order. A relayed missing summary or expanded artifact means the path is absent — the worker never searches for, globs, or substitutes another file. `test.ps1` may leave an earlier run's `summary.json` untouched when this attempt stops before result emission (e.g. a compile failure); corroborate a present-but-unexpected summary against the gate command's own exit code and appended timing evidence before treating it as this attempt's result. Do not supply or accept globbed, guessed, or alternate artifact paths.

After each invocation returns its evidence, classify the mutant yourself (see Classification below), close the completed thread, and record the verdict before invoking the next mutant or resuming judgement, killer-test work, or closeout.

The final full `test.ps1` closeout is the host's own gate run, never a mutant cycle, and routes exactly like `/al-build`'s: delegate to the named `al-gate-runner` custom agent — bounded executor role (see [delegation.md](../../references/delegation.md)) — so its verbose output stays out of the main session. **Already inside an agent** mid-workflow (this skill running as a spawned subagent itself) → run `test.ps1` directly inline instead; nested custom-agent spawning does not happen, and this is not model substitution since no new spawn occurs — the same rule the per-mutant `al-mutant-cycle` worker path already follows, unchanged. **`al-gate-runner` unavailable** for a fresh spawn → report `BLOCKED`, name `al-gate-runner` as the missing agent, and stop; no generic-subagent substitution.

`al-mutant-cycle` is fixed to the Sonnet worker role — the cycle makes a transient source edit and relays the gate result for the host to classify (see [delegation.md](../../references/delegation.md)).

### Worker rules

```
Guard: before applying the mutant, snapshot `.output/logs/build-timing.jsonl` (record whether it exists and, when it does, its current byte length or line count). Then prove `git status --short` empty, `git diff --quiet HEAD` clean, and `git rev-parse HEAD` exactly equal to the host-provided baseline SHA. Any mismatch — a dirty tree, or `HEAD` not exactly that baseline SHA — stops before applying the mutant; report the mismatch and do not edit.

Apply the one assigned mutant only. Do not edit source/spec/tasks/config except the assigned transient production mutation. Do not commit. Do not invoke `/al-build` as a nested skill. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the assigned flags, exactly once. Do not rerun, diagnose, or substitute the gate.

Relay the gate command, its observed exit code, and only the `.output/logs/build-timing.jsonl` line appended beyond the pre-mutation snapshot — verbatim, never a pre-existing line, never simply the file's newest line — and the caller-supplied `.output/TestResults/summary.json` marked `expand: resultFile where passed=false`. Add `telemetryFile where passed=false` only when the host explicitly marks it for classification. Read the summary only after this gate attempt; mechanically relay only the caller-marked literal fields from failing runs, in encounter order, and label each missing supplied or expanded artifact `missing`. The timing line's existing `outcome`, `steps`, and `tests` fields are the failure-phase evidence; do not derive a cause from them. Do not interpret, classify, or label the mutant — that judgment is the host's.

After the attempt, always run `git checkout -- .`, then prove `git diff --quiet HEAD` and empty `git status --short` before returning — including when the gate failed or could not start. This broad revert is explicitly authorized only inside `/al-mutate` after committed clean baseline proof. Stop and report if the revert itself cannot be completed.

Return the relayed gate command, exit code, appended timing line, artifact content, bounded output excerpt, and revert outcome in the reply — never a verdict word. Write `.output/TestResults/**` only (the gate produces it); the mutation report is host-assembled. `.output` is not committed.
```

### Classification (host)

Classify the mutant from the relayed evidence, never the exit code alone. `outcome:"error"` is unclassified until the bounded output and timing `steps` evidence establish a phase:

- Explicit compiler/parser diagnostic naming the mutated file and the mutated line or construct → `invalid_stillborn`; the compiler caught the mutation before a test could answer. Record that diagnostic and re-plan a compiling operator later.
- Publish, container, stale-container, connection, or other documented infrastructure evidence → the retry path below.
- Missing timing/artifact evidence, an ambiguous diagnostic, or any other `outcome:"error"` → `blocked_infra_unknown`; stop after the clean revert proof. Do not count it as killed or stillborn.

`outcome:"failed"` may be `killed` only with a named failing test or mutated-path assertion/exception in the relayed JUnit/output evidence. `outcome:"passed"` is `survived` or `equivalent_candidate`. AL Runner's own exit-3 compile error maps to `outcome:"failed"`; because the app is analyzer-compiled before AL Runner runs, that combination is contradictory → `not_classified_runner_contract`, never killed.

### Infra recovery inside a live mutant

Documented `/al-build` infra-red only: container connect, publish, stale container state — not the mutant's own doing. `al-mutant-cycle` always reverts after its one attempt, so a retry is a fresh invocation for the *same* mutant instructions, not a rerun inside a live cycle. Restart the container, invoke `al-mutant-cycle` again for the same mutant. Still infra-red → recreate the container, invoke it once more. Do not change the mutant. Do not switch gate scope. Do not edit container state manually.

Classify the retried attempt with the same evidence rule: only an explicit compiler/parser diagnostic naming the mutated file and line or construct is `invalid_stillborn`, **not killed**. A named test/mutated-path assertion or exception behind `outcome:"failed"` is `killed`; passes are `survived` or `equivalent_candidate`. Publish, container, infrastructure, or ambiguous `outcome:"error"` never becomes a stillborn. Infra-red remains after the recreate retry → `blocked_infra_repeat`, stop after confirming the clean tree the last revert left. Unknown or ambiguous tooling failure → `blocked_infra_unknown`, stop after recording the evidence and confirming the clean tree.

Container/tooling failure never counts as killed.

## Report

Write durable session report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. It is ignored output, not committed. Survivors and stillborns are the actionable sections, one row per site with classification and next action — killer-test direction for a survivor, the re-planned compiling operator for a stillborn. Killed mutants map site to the catching **test**; a "kill" with no named catching test is not a kill, it is a stillborn or a mislabeled survivor. Equivalent candidates carry specific reason; host confirms. Only an explicit mutation-tied compiler/parser diagnostic appears in the stillborn count; publish/container/infrastructure/ambiguous failures appear as blocked recovery evidence. A non-zero stillborn count blocks the clean verdict the same way a survivor does — its action is a host re-plan of a compiling operator, not a killer test. Include plan rationale, skipped-site rationale, baseline SHA, per-mutant gate command and `outcome`, recovery attempts, final full-gate result, and counts: killed / survived / equivalent / stillborn / unclassified / blocked.

The task file gets the `Closeout` mutation verdict shape from [test-specification.md](../../references/test-specification.md): borderless two-column table (baseline SHA, report path, mutant count with a rationale lede, killed, survivors, stillborn when non-zero, final full-gate result) plus labeled `Survivor:` / `Why kept:` lines per survivor and `Stillborn:` / `Re-planned:` lines per stillborn. One fact per landing line; no prose wall, no full mutation table in the task file.

The frontmatter stamp depends on the verdict. **Clean verdict** (no survivors and no unresolved stillborn, or every remaining item a documented equivalence) → stamp `status: done` and `phase: mutated` in the same Edit — the task is finished; nothing further intended. **Anything open** (survivor, unresolved stillborn) → stamp `phase: mutated` only; `status:` stays `ready-for-implementation` until the follow-up round closes the gap. Target already `status: done` (a post-hoc rigor run — a `/al-code-review` rigor note, an early-closed task, legacy code): clean verdict → stamp `phase: mutated` only, `status:` is already terminal; survivor → report it and route the killer test to `/al-implement` re-entry under the originating `T-NNN` — never demote `done`. Overwrite the existing `phase:` value; add the line after `status:` if absent. See [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) and [voice-contract.md](../../references/voice-contract.md).

At the `done` flip, open any **same-slice technical** task whose `depends_on:` is now fully `done` and carries no replan flag, `blocked` → `ready`; name each opened `T-NNN` in the Gate report. The slice verify task is the exception — never opened here; it waits behind the per-slice `/al-code-review` gate.

Emit the Gate report once at pass close, rendered box-first and passed through the pre-send checks, naming rigor proved (or not) for user-facing behaviour under test, soft spots that remain by design, and the user's call; the task-file `Closeout` mutation verdict lands alongside it.

## Next step

End by naming the concrete next move, read off the verdict:

- **Clean verdict** (no survivors and no unresolved stillborn, or every remaining item a documented equivalence) → the task flipped `done` above; name the slice gate: more `ready-for-implementation` tasks in the slice → `Next: /al-implement` (next task); slice-done (all slice technical tasks `done`, either slice type) → `Next: /al-code-review` per-slice — the review gate runs before the verify task is opened.
- **Reached real-gap survivor** → `Next: /al-implement` to resume TDD and write the killer test, then rerun the survivor site; the task stays `ready-for-implementation` until the round closes clean.
- **Unresolved stillborn** (a planned mutation the compiler rejected) → host re-plans a *compiling* operator at that site and reruns it; not a clean handoff. Only when the re-planned mutant runs and is test-caught or genuinely survives does the site close.
- **Unreached-line / missing-coverage survivor** → `Next: /al-refine` (add coverage). **Blocked** (infra-repeat, replan-class) → `Next: /al-steer`.

If state can't be read, fall back to `/al-code-review`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (the rigor step the user runs after reshape), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-code-review` on a clean verdict (slice/feature gate); `/al-implement` for a reached real-gap survivor (resume TDD for the killer test) or for the next `ready-for-implementation` task; `/al-refine` only for unreached-line or missing-coverage cases |
| **Spawns**         | `al-mutant-cycle` custom agent — one supplied mutate→gate→revert cycle per approved mutant; `al-gate-runner` custom agent — the final full `test.ps1` closeout, same routing as `/al-build` |
| **Calls directly** | none — the rubber-duck consult cross-checks non-trivial mutation plans before execution ([rubber-duck-review.md](../../references/rubber-duck-review.md)) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BaseApp behaviour for survivor classification), `/grill-me` (classification call needs the user) |
