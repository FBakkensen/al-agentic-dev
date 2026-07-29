---
name: al-code-review
description: Review a settled slice or feature diff across the AL review dimensions, land the rework, and settle change requests with the user. Run it at the slice-done and feature-done gates, or on the fix diff of a verification-walk repair.
disable-model-invocation: true
---

# /al-code-review — the review gate

Code still in flight belongs to `/al-implement`; this gate reviews what has landed.

## Baseline

Run the gate with `/al-build` and require green on a clean tree. A red gate or unrelated uncommitted work → name the gap and stop. An uncertain baseline makes every finding a guess, and this run's fix commits would land on top of the pollution.

Scope is one of three diffs:

- **Slice-done** — every `T-NNN` commit of the technical tasks sharing one `slice:`, from the first through the last one settled.
- **Feature-done** — the whole branch against `main`, after every task but the breaking-change task is settled.
- **Repair** — the fix commits of one named repair episode from a verification walk, reviewed against the check that failed; this scope reports its verdict and stamps nothing.

Mixed state, a squash that hides the `T-NNN` prefixes, or an ambiguous range is one lettered question to the user. Task files under `tasks/` are evidence — read their bodies and their frontmatter (the schema is `/al-routing`'s) rather than inferring state from the diff.

## Ground every AL judgment

- Every BC object, table, field, procedure, event, or enum value you name in a finding or write in a fix comes from a lookup you run this session — search the workspace, read the symbol packages, or quote the docs. Recall is not evidence. `.bcapps/` is the pattern library: read how Microsoft implements the behaviour a finding touches before judging it — default search skips gitignored folders.
- Write BC vocabulary: Insert not create, Modify not update, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, procedure not method, codeunit not class.
- Hold production code to AL thrift: reach for the platform before writing code, keep no `interface` with a single implementation, and let a deliberate shortcut carry a one-line comment naming its ceiling and its upgrade path.
- Thrift governs production code only. Test thoroughness, trust-boundary validation, posting and ledger correctness, and permission checks stay at full strength.

## The review dimensions

Apply all of them to the scoped diff. If your harness supports subagents, these parallelize; otherwise apply them in one pass.

- **Correctness** — logic faults a fresh read exposes, plus an identifier whose claim is false: a `Get…` that mutates, an `Is…` that does not reflect the state it names.
- **Assertion rigor** — a test that would pass whether or not the behaviour under test works: an `Assert` restating the `Act`, an expected value the test derives for itself, an assertion on error text where the promised outcome is a state change.
- **Proof coverage** — behaviour the task's Test Specification claims that no case proves, and every decision branch, error path, and boundary the code admits with no case behind it.
- **Red-verdict rigor** — logic no red ever proved: a branch a reshape added, an assumption absorbed mid-task, an edit on an untested path. Name `/al-mutate` on the owning task; this is a recommendation, never rework.
- **BC anti-patterns** — a hand-roll of what shipped BC already provides: a setup table plus management codeunit where a field plus FlowField serves, validation code where a table relation or permission-set entry serves, a status pattern where an enum serves, and new code paralleling behaviour Microsoft ships in `.bcapps/` where the module's `Precedent` verdict is missing or says `none`. `if Rec.X <> xRec.X` gating a cascade in a code-reachable `OnValidate` is the standing trap — programmatic `Validate`, background work, and engine recalc supply an empty `xRec`, so compare the persisted row.
- **AppSource contract** *(feature scope)* — a new public procedure, table field, or page action locks a promise `AS0011` and `AS0007` will not let you unmake; base-app modification where an event subscriber, table extension, or interface implementation intercepts instead; a rename or drop of shipped surface that skips `ObsoleteState: Pending`.
- **Performance** — locking, read, and memory cost in the touched procedures: a `Modify` inside a loop over a full set, a missing `SetLoadFields`, a whole-record read where an existence check serves, a `Commit` inside a transaction the caller owns.
- **Structure** — a procedure mixing decision logic with I/O splits along that line; a procedure that both writes a record and returns a computed value; feature envy, primitive obsession, and a `case` chain duplicated where an enum or dispatcher belongs.
- **Naming and compliance** — every introduced name against BC vocabulary and the project's own terminology in `CONTEXT.md`, the ADRs, `architecture.md`, and `event-model.md`; a decision that contradicts a settled ADR or crosses a stated module boundary; diff behaviour traceable to no `Expected Behaviors` row, `Decision Matrix` row, or AAA case.
- **Comments and history** — a change that breaks an invariant a modified file's comment states, or that undoes a fix the commit history names.
- **Simplification** — duplication, dead code, redundant procedures, and speculative generality. Run the deletion test on every shallow object in the diff: what is lost if it goes away.

## Disposition

Rank the survivors by the consequence of shipping the diff as it stands; rank orders the queue and chooses nothing. Baselines are the task's Test Specification, `architecture.md`, `event-model.md`, `CONTEXT.md`, the ADRs, and behaviour the user has already verified.

- **Rework** — resolving it restores the code's conformance to a baseline and changes no baseline. It lands in this run.
- **Change request** — resolving it would contradict baselined content, or establish content no baseline yet holds. The user settles it.
- A finding whose baseline you cannot name is asking you to write one: change request. The diff cannot authorize itself — a comment or document this diff wrote is no baseline for this diff.

### Land the rework

- Behaviour-changing rework goes red first: write the missing AAA case, watch it fail on a real assertion, then make it pass. Commit under the originating `T-NNN` prefix and re-run `/al-build`. Task-file state stays untouched — a repair is not a pipeline step.
- Provably non-semantic rework — a comment, a local rename, formatting that moves no decision logic — lands directly, gates, and commits standalone. A red gate reverts it and it re-enters as behaviour-changing.
- A behaviour-changing finding inside a slice the user has already walked is a change request, because an autonomous fix invalidates the walk. Non-semantic rework still lands.
- Rework that cannot reach green reverts and joins the change requests, so the tree stays green.

### Settle the change requests

Talk them through in the live session, one conversation at a time worst-first, clustered by the baseline decision they contest. Each ends on one of three outcomes, and the user may close the remainder in one ruling:

- **Do it now** — the user reclassifies it as rework; it lands on the terms above.
- **Write a task** — write it yourself as a new open technical task on the `slice:` whose baseline it contests, per `/al-routing`'s schema; the gate holds until it settles. In the repair scope there is no gate to hold: the task lands, and whether the paused walk resumes past it is the user's call.
- **Keep the code** — the user rules the baseline wrong; the finding clears here and the baseline edit is separate work.

## Re-review and close

Re-review the updated diff exactly once, applying the dimensions from scratch. A finding still standing after it is reported, not fixed again.

A clean gate is no rework left and no open change request.

Keep the dimension churn out of chat. Report each survivor as `Finding:` / `Where:` / `Action:`, name each rework commit, and name each change request with the outcome it reached.

**Outcome:** the diff is reviewed, the rework has landed green, and every change request has a ruling.
Then `/al-routing` on a slice or feature verdict; a repair verdict closes back into the paused walk.
