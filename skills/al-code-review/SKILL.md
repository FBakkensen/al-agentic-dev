---
name: al-code-review
description: Review a settled slice or feature diff across the AL review dimensions, land the rework, and settle change requests with the user. Run it at the slice-done and feature-done gates, or on the fix diff of a verification-walk repair.
disable-model-invocation: true
---

# /al-code-review — the review gate

Code still in flight belongs to `/al-implement`; this gate reviews what has landed. Your first line names that this run wants a standard-class model or above — the user picked the model and weighs the mismatch. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Baseline

Start on a clean tree, then identify the scope below and select its newest `✅ Gate:` comment per `/al-routing`'s receipt rule — its commit an ancestor of `HEAD`, the diff since it empty. Match → `🔎✅ Green gate reused — AB#1204 @ abc123 (full).`; no match → `🔎🔧 Gate required — no compatible green receipt.`, then run `/al-build -AllTests` green. A red gate or unrelated uncommitted work → name the gap and stop. An uncertain baseline makes every finding a guess, and this run's fix commits would land on top of the pollution. The knowledge pass reads the `.bcquality/` clone: missing → name `/al-clone-bcquality` and stop, before the gate rather than after it.

- **Slice-done** — every `AB#<id>` commit of the slice story's technical tasks, from the first through the last one settled.
- **Feature-done** — the whole branch against `main`, after every task but the breaking-change task is settled.
- **Repair** — the fix commits of one named repair episode from a verification walk, reviewed against the check that failed; this scope reports its verdict and stamps nothing.

Mixed state, a squash that hides the `AB#` ids, or an ambiguous range is one lettered question to the user. The tasks are Azure DevOps work items — evidence: read their Descriptions and fields through `azure-devops-wit_work_item` (the schema is `/al-routing`'s) rather than inferring state from the diff.

## Ground every AL judgment

- Every BC object, table, field, procedure, event, or enum value you name in a finding or write in a fix comes from a lookup you run this session — grep the workspace, view the symbol packages, or quote the docs through the microsoft-learn tools (microsoft_docs_search, microsoft_docs_fetch). Recall is not evidence. `.bcapps/` is the intentionally gitignored pattern library: read how Microsoft implements the behaviour a finding touches before judging it. Missing → stop, naming `/al-clone-bcapps`; a workspace-wide grep skips the gitignored clone, so point grep at `.bcapps/` explicitly and view its files directly.
- Write BC vocabulary: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, procedure not method, codeunit not class.
- Hold production code to AL thrift: reach for the platform before writing code, keep no `interface` with a single implementation, and let a deliberate shortcut carry a one-line comment naming its ceiling and its upgrade path.
- Thrift governs production code only. Test thoroughness, trust-boundary validation, posting and ledger correctness, and permission checks stay at full strength.

## The review passes

Two passes over the scoped diff. The first is BCQuality's: `/al-knowledge-pass` on the scoped diff returns the findings, or the one line naming the domain that stopped it; a stop there stops this run — an unjudged domain makes the verdict narrower than it claims.

The second pass fans out — the dimensions below, which reach what no leaf can see: the task's proof, the project's baselines, the shape of the code. Each dimension runs as one `al-review-lens` invocation through the task tool — the dimension's definition, the diff scope, and its sources in the prompt — the invocations parallelized in one batch. A returned `clean` names its dimension judged; each returned finding is a proposed class this run's disposition settles.

- **Correctness** — logic faults a fresh read exposes, plus an identifier whose claim is false: a `Get…` that mutates, an `Is…` that does not reflect the state it names.
- **Assertion rigor** — a test that would pass whether or not the behaviour under test works: an `Assert` restating the `Act`, an expected value the test derives for itself, an assertion on error text where the promised outcome is a state change.
- **Proof coverage** — behaviour the task's Test Specification claims that no case proves, and every decision branch, error path, and boundary the code admits with no case behind it.
- **Red-verdict rigor** — logic no red ever proved: a branch a reshape added, an assumption absorbed mid-task, an edit on an untested path. Recommend a test task on the owning slice — `/al-implement` proves each green-born test by mutation; this is a recommendation, never rework.
- **Precedent** — new code paralleling behaviour Microsoft ships in `.bcapps/` where the module's `Precedent` verdict in `architecture.md` is missing or says `none`; a `reused:` verdict the code quietly walked away from.
- **Public surface** *(feature scope)* — a new table field or page action added without the user having chosen to lock a promise `AS0011` and `AS0007` will not let you unmake; base-app modification where an event subscriber, table extension, or interface implementation intercepts instead.
- **Structure** — a procedure mixing decision logic with I/O splits along that line; a procedure that both writes a record and returns a computed value; feature envy, primitive obsession, and a `case` chain duplicated where an enum or dispatcher belongs.
- **Naming and compliance** — every introduced name traces to a `CONTEXT.md` term, the BC baseline, or an `event-model.md` Action, Business Event, or Status, its verb to BC's own set — an untraceable name (a `Mutate`, a `Manager`, a noun no source names) is a finding — and artifact prose in the diff (task bodies, `architecture.md`) answers to the same vocabulary; a decision that contradicts a settled ADR or crosses a stated module boundary; diff behaviour traceable to no `Expected Behaviors` row, `Decision Matrix` row, or AAA case.
- **Comments and history** — a change that breaks an invariant a modified file's comment states, or that undoes a fix the commit history names.
- **Simplification** — duplication, dead code, redundant procedures, and speculative generality. Run the deletion test on every shallow object in the diff: what is lost if it goes away.

## Disposition

Rank the survivors of both passes by the consequence of shipping the diff as it stands; rank orders the queue and chooses nothing. Present each survivor as a glyphed headline — `⛔` defect, `⚖️` change request, `⚠️` recommendation — over three slots of one line each: `⚡ Breaks:`, `📍 Proof:`, `🔧 Fix:`. A leaf finding is a survivor like any other. Decision evidence is the task's Test Specification, `architecture.md`, `event-model.md`, `CONTEXT.md`, the ADRs, behaviour the user already verified, and explicit rulings in this session.

- **Defect** — a bug or implementation-quality problem whose correction needs no user decision. It lands in this run.
- **Change request** — the proposed resolution would override a recorded user decision, or establish business or architecture intent nobody has decided. The user settles it.

### Land the defects

- A behavioural defect routes to `/al-implement`: hand it the missing AAA case and the owning task, watch the assertion fail on a real red, then let it make the case pass. Commit opening with the originating `AB#<id>` and re-run `/al-build -AllTests`. Work-item state stays untouched — a repair is not a pipeline step.
- A provably non-semantic defect — a comment, local rename, dead code, or equivalent query shape — lands directly, gates, and commits standalone. A red gate reverts it and it re-enters as behavioural.
- A fix that would overturn behaviour the user already verified is a change request. A defect whose fix exceeds this run reverts, and the close puts it to the user as one proposed technical task — created on their yes per `/al-routing`'s schema on the owning slice, carrying the failing case this review wrote as its red. Declining the task rules that the behaviour stands: the finding re-enters as a change request, settled and recorded in the artifact whose expectation it overturns. Difficulty reclassifies nothing — a hard fix is a task, never a lesser defect.

### Interview the change requests

Interview every change request before implementing any ruling, one per message, highest impact first. State the impact, business or architecture choice, consequences, and recommendation. On a slice or feature scope, `/al-visualize` may put the scoped change in view as a steering surface — the change requests its open calls — while each request is still settled here, one per message. Name modules, boundaries, public objects, interfaces, events, or other AL concepts when they make the current or proposed architecture legible; keep paths, line numbers, private procedures, code snippets, lookup mechanics, and knowledge-article details out unless the user asks. One answer settles only the request in front of the user.

After every request is settled, apply its ruling:

- **Do it now** — record the ruling in its decision artifact and land the change on the defect terms above.
- **Write a task** — create one on the slice story whose decision it changes, per `/al-routing`'s schema. Create it only because the user chose it.
- **Keep the current behaviour** — record the ruling in its decision artifact, so the same request does not return.

Each ruling lands as it settles: a created task is a work item and needs no repo commit; a ruling recorded in a decision artifact commits with a plain descriptive message, apart from the defect commits. Technical evidence belongs in the resulting commit or the work item's comments, not the interview.

## Re-review and close

Re-review the updated diff exactly once, running both passes from scratch. A finding still standing after it is reported — one comment on the owning work item — not fixed again.

A clean gate is no defect left and no open change request.

Keep the pass churn out of chat. Name each defect commit. Report each change request as `Impact:` / `Ruling:` / `Outcome:`. A slice or feature verdict that landed defects or settled change requests also goes up as a steering surface through `/al-visualize`; a clean gate and a repair verdict close plain.

**Outcome:** the diff is reviewed, every defect has landed green or become a task the user accepted, and every change request has a ruling. Report the committed `HEAD` from its last durable full green when the review changed the tree; a clean no-change review retains its selected receipt.
Then `/al-routing` on a slice or feature verdict; a repair verdict closes back into the paused walk.
