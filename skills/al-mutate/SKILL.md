---
name: al-mutate
description: Prove the tests catch faults by breaking AL production code one site at a time and watching the gate. Run it after a refactor lands.
disable-model-invocation: true
---

# al-mutate

A suite that passes a broken program proves nothing. Break the program on purpose, one site at a time, and see whether the tests notice. Your first line names that a standard-class model serves this run — the survivor-kill tests are its only new AL. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## Before the first mutation

Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch. The tree is clean and the green baseline is committed — revert returns to `HEAD`, so uncommitted work is not safe. Evaluate the task's clean full-gate receipt: its commit is an ancestor of `HEAD` and the diff since it names only this task file. Match → `🔎✅ Green gate reused — T-123 @ abc123 (full).`; no match → `🔎🔧 Gate required — no compatible green receipt.`, then run `/al-build` green. Survivors measured against a red baseline carry no signal. Mutate production AL only: not tests, not generated `.rdlc` or `.xlf`, not captions, labels, or tooltips. Let a reshape in flight land green and commit first — a shape still moving stales every classification. Anything missing here: name it and stop.

## Plan the sites first

Sites qualify by provenance: **code that arrived without a red**. Legacy paths, tests written after their code, branches a refactor introduced, work absorbed inline (the task file's `Deviations:` block is the breadcrumb). Unknown provenance counts as no red. A reshape only moves behaviour its old red already covered, so of reshaped code only what the reshape *added* qualifies. Qualify on provenance alone — reading the tests and judging the assertions rigorous is the very judgment mutation exists to replace.

Break ties toward the site where a fault costs most: irreversible writes, Ledger Entries, status flips other code keys off. Skip pure delegation, accessors, and single-line init, and record each skip as the claim it is — "this behaviour has already failed a test" — for the report to carry. Confirm a test reaches a line before mutating it; an unreached line is a coverage hole, not a mutation site — write it yourself as a new open technical task in the same slice per `/al-routing`'s schema, naming the uncovered site, committed at write under its own `T-NNN` prefix; a covering test or deleting the dead branch is that task's call.

One operator per qualifying site, picked to expose underassertion *there*:

- flip a boolean condition or invert a guard;
- swap `=` for `<>`, or widen or narrow a comparator (`>` → `>=`);
- swap `+` for `-` in money or quantity math;
- replace a literal with a neighbouring value;
- replace an assigned value where the variable is read later, so the wrong value flows;
- drop `Validate()` for direct field assignment — BC-specific, it bypasses the field trigger.

Two edits usually fail to compile in AL and waste the round: removing an assignment, which leaves an unused or unwritten local, and inserting an early `exit`, which makes the code after it unreachable. Prefer the wrong-value and guard-flip forms above; they reach the same behaviour and compile. Skip obvious equivalences — `x >= 1` and `x > 0` are the same over integers.

## Run one mutant at a time

Apply the mutation, run the full gate with `/al-build`, classify it, then revert the tree to `HEAD` before the next site. A kill is behavioural.

| Verdict | Evidence |
|---|---|
| `killed` | the gate goes red with a named failing test, or an assertion or error on the mutated path |
| `survived` | the gate stays green and the mutation changed reachable behaviour |
| `equivalent` | green, with a specific written reason the mutant cannot behave differently |
| `stillborn` | the compiler rejected the mutant — a hole in the pass, not a pass. Re-plan a *compiling* operator at that site and rerun it; the re-planned mutant's own verdict — killed, survived, or equivalent — settles the site |
| `gate-error` | the gate failed on infrastructure. Recover the container through `/al-build` and retry the same mutant once more; still failing, stop on a reverted tree |

A survivor fails its own mutation, not the run — keep going through the planned sites. "Nothing worth mutating" is a plan claim, never a result: on a pass with no survivors and no equivalences, re-open the skip list once and either re-justify each skip or mutate it, until every site carries a settled verdict or a recorded claim.

## Close

Report the killed / survived / equivalent / stillborn / gate-error counts, then the actionable rows — each stillborn with the compiling operator that replaces it, each equivalence with its reason. Name the baseline SHA, and the catching test for every kill.

Then put every survivor to the user first, one at a time: kill it now, or accept it — no kill is written while a ruling is open, so the whole damage picture is in view before any work starts. Rulings in, write each kill — re-apply the mutation, write the test that goes red on it, revert the mutation, run `/al-build` green, and commit that kill under the owning `T-NNN` prefix at its green; every BC object, table, field, procedure, event, and enum value name in that test comes from a lookup run this session, never recall. An acceptance lands as one `- ✅ Accepted:` sentence in the task body's `Contract notes:` naming the site and the user's reason — the ruling, not the hunt — committed with the last ruling. Report the committed `HEAD` from the last kill's full green; a pass without kills retains its incoming receipt.

The pass closes when every survivor is killed or accepted, no stillborn is unsettled, and every equivalence is documented.

Outcome: the tests are proved to catch faults at the mutated sites, or the survivors name exactly where they do not.
Then `/al-routing`.
