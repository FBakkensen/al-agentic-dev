---
name: al-code-review
description: Review a settled slice or feature diff across the AL review dimensions, land the rework, and settle change requests with the user. Run it at the slice-done and feature-done gates, or on the fix diff of a verification-walk repair.
disable-model-invocation: true
---

# /al-code-review — the review gate

Code still in flight belongs to `/al-implement`; this gate reviews what has landed. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## Baseline

Run the gate with `/al-build` and require green on a clean tree. A red gate or unrelated uncommitted work → name the gap and stop. An uncertain baseline makes every finding a guess, and this run's fix commits would land on top of the pollution. The BCQuality corpus is the other baseline: no `.bcquality/` means the knowledge pass cannot run and the verdict would be narrower than it claims → name `/al-clone-bcquality` and stop.

Scope is one of three diffs:

- **Slice-done** — every `T-NNN` commit of the technical tasks sharing one `slice:`, from the first through the last one settled.
- **Feature-done** — the whole branch against `main`, after every task but the breaking-change task is settled.
- **Repair** — the fix commits of one named repair episode from a verification walk, reviewed against the check that failed; this scope reports its verdict and stamps nothing.

Mixed state, a squash that hides the `T-NNN` prefixes, or an ambiguous range is one lettered question to the user. Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch. Task files are evidence — read their bodies and their frontmatter (the schema is `/al-routing`'s) rather than inferring state from the diff.

## Ground every AL judgment

- Every BC object, table, field, procedure, event, or enum value you name in a finding or write in a fix comes from a lookup you run this session — search the workspace, read the symbol packages, or quote the docs. Recall is not evidence. `.bcapps/` is the pattern library: read how Microsoft implements the behaviour a finding touches before judging it — default search skips gitignored folders.
- Write BC vocabulary: Insert not create, Modify not update, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, procedure not method, codeunit not class.
- Hold production code to AL thrift: reach for the platform before writing code, keep no `interface` with a single implementation, and let a deliberate shortcut carry a one-line comment naming its ceiling and its upgrade path.
- Thrift governs production code only. Test thoroughness, trust-boundary validation, posting and ledger correctness, and permission checks stay at full strength.

## The review passes

Two passes over the scoped diff. The first is BCQuality's: `.bcquality/microsoft/skills/review/al-code-review.md` names one review leaf per knowledge domain in its `sub-skills:` frontmatter — run every leaf it lists against the diff, each per its own instructions, resolving the paths inside those files against `.bcquality/`. Every leaf runs: each decides its own applicability, and pre-judging which ones have something to say is the documented way to make them underreport. A leaf that ends partial or failed leaves its domain unjudged — name it and stop, rather than counting silence as clean. If your harness supports subagents, one leaf per subagent holds each context to a single domain — full-capability subagents running the same model as this conversation; otherwise run them one at a time.

The second pass is yours — the dimensions below, which reach what no leaf can see: the task's proof, the project's baselines, the shape of the code. If your harness supports subagents, these parallelize under the same subagent rule; otherwise apply them in one pass.

- **Correctness** — logic faults a fresh read exposes, plus an identifier whose claim is false: a `Get…` that mutates, an `Is…` that does not reflect the state it names.
- **Assertion rigor** — a test that would pass whether or not the behaviour under test works: an `Assert` restating the `Act`, an expected value the test derives for itself, an assertion on error text where the promised outcome is a state change.
- **Proof coverage** — behaviour the task's Test Specification claims that no case proves, and every decision branch, error path, and boundary the code admits with no case behind it.
- **Red-verdict rigor** — logic no red ever proved: a branch a reshape added, an assumption absorbed mid-task, an edit on an untested path. Name `/al-mutate` on the owning task; this is a recommendation, never rework.
- **Precedent** — new code paralleling behaviour Microsoft ships in `.bcapps/` where the module's `Precedent` verdict in `architecture.md` is missing or says `none`; a `reused:` verdict the code quietly walked away from.
- **Public surface** *(feature scope)* — a new table field or page action added without the user having chosen to lock a promise `AS0011` and `AS0007` will not let you unmake; base-app modification where an event subscriber, table extension, or interface implementation intercepts instead.
- **Structure** — a procedure mixing decision logic with I/O splits along that line; a procedure that both writes a record and returns a computed value; feature envy, primitive obsession, and a `case` chain duplicated where an enum or dispatcher belongs.
- **Naming and compliance** — every introduced name against BC vocabulary and the project's own terminology in `CONTEXT.md`, the ADRs, `architecture.md`, and `event-model.md`; a decision that contradicts a settled ADR or crosses a stated module boundary; diff behaviour traceable to no `Expected Behaviors` row, `Decision Matrix` row, or AAA case.
- **Comments and history** — a change that breaks an invariant a modified file's comment states, or that undoes a fix the commit history names.
- **Simplification** — duplication, dead code, redundant procedures, and speculative generality. Run the deletion test on every shallow object in the diff: what is lost if it goes away.

## Disposition

Rank the survivors of both passes by the consequence of shipping the diff as it stands; rank orders the queue and chooses nothing. A leaf finding is a survivor like any other. Decision evidence is the task's Test Specification, `architecture.md`, `event-model.md`, `CONTEXT.md`, the ADRs, behaviour the user already verified, and explicit rulings in this session.

- **Defect** — a bug or implementation-quality problem whose correction needs no user decision. It lands in this run.
- **Change request** — the proposed resolution would override a recorded user decision, or establish business or architecture intent nobody has decided. The user settles it.
- Code, comments, the current diff, and a knowledge article are technical evidence, not user decisions.

### Land the defects

- A behavioural defect goes red first: write the missing AAA case, watch it fail on a real assertion, then make it pass. Commit under the originating `T-NNN` prefix and re-run `/al-build`. Task-file state stays untouched — a repair is not a pipeline step.
- A provably non-semantic defect — a comment, local rename, dead code, or equivalent query shape — lands directly, gates, and commits standalone. A red gate reverts it and it re-enters as behavioural.
- A fix that would overturn behaviour the user already verified is a change request. A defect that cannot reach green reverts and leaves the review red; difficulty does not turn it into a user decision.

### Interview the change requests

Interview every change request before implementing any ruling, one per message, highest impact first. State the impact, business or architecture choice, consequences, and recommendation. On a slice or feature scope, `/al-visualize` may put the scoped diff in view — the architectural change drawn, the change requests as its open-decision cards — while each request is still settled here, one per message. Name modules, boundaries, public objects, interfaces, events, or other AL concepts when they make the current or proposed architecture legible; keep paths, line numbers, private procedures, code snippets, lookup mechanics, and knowledge-article details out unless the user asks. One answer settles only the request in front of the user.

After every request is settled, apply its ruling:

- **Do it now** — record the ruling in its decision artifact and land the change on the defect terms above.
- **Write a task** — create one on the `slice:` whose decision it changes, per `/al-routing`'s schema. Create it only because the user chose it.
- **Keep the current behaviour** — record the ruling in its decision artifact, so the same request does not return.

Technical evidence belongs in the resulting commit or task, not the interview.

## Re-review and close

Re-review the updated diff exactly once, running both passes from scratch. A finding still standing after it is reported, not fixed again.

A clean gate is no defect left and no open change request.

Keep the pass churn out of chat. Name each defect commit. Report each change request as `Impact:` / `Ruling:` / `Outcome:`. A slice or feature verdict that landed defects or settled change requests also goes up drawn through `/al-visualize` — the reviewed diff with each ruling on it; a clean gate and a repair verdict close plain.

**Outcome:** the diff is reviewed, the defects have landed green, and every change request has a ruling.
Then `/al-routing` on a slice or feature verdict; a repair verdict closes back into the paused walk.
