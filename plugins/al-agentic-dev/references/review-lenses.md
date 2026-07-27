# Review lenses

Eleven read-only lens agents identify findings, `al-review-judge` classifies them, and the calling skill applies. A lens never classifies, never edits, and never writes workflow state.

One agent per concern. The caller declares which artifact is under review, and that declaration — not the lens's name — decides which of the lens's rules apply.

## Modes

| Mode | Artifact under review | Caller |
|---|---|---|
| `code-review` | Landed AL production and test code at a slice or feature gate | `/al-code-review` |
| `refactor` | One task's diff, reshaped while observable behaviour stays identical | `/al-refactor` |
| `architecture` | `architecture.md`, before any task exists | the design gate |
| `test-spec` | One technical task's `Test Specification` | the refine gate |
| `verification-plan` | One verify task's `Verification Plan` | the refine gate |

## Membership

| Lens | `code-review` | `refactor` | `architecture` | `test-spec` | `verification-plan` |
|---|---|---|---|---|---|
| `al-review-compliance` | x | x | x | x | x |
| `al-review-coverage` | | | x | x | x |
| `al-review-structural` | | x | x | x | x |
| `al-review-bc` | x | x | x | | |
| `al-review-perf` | x | x | | | |
| `al-review-appsource` | x | | x | | |
| `al-review-bugscan` | x | | | | |
| `al-review-comments` | x | | | | |
| `al-review-simplify` | | x | | | |
| `al-review-objects` | | | | x | |
| `al-review-assertions` | | | | x | |
| **Lenses per gate** | **6** | **5** | **5** | **5** | **3** |

`al-review-appsource` in `code-review` mode runs on a per-feature scope only; a per-slice review leaves it unspawned.

## Invocation

The caller sends two declared fields, then the payload:

```
Mode: <one of the five mode values>
Scope: <what the payload covers — per-slice diff, per-feature diff, task diff, or the artifact path>
```

Then the diff or artifact plus the context that lens needs. `al-review-perf` also receives the changed `.al` files.

The caller owns membership: it spawns only the lenses its mode's column marks. A lens invoked with a missing or unrecognised `Mode:`, or with a mode outside its own row, returns exactly:

```
LENS INVOCATION ERROR: missing or unrecognised Mode
```

as its only line — never its sentinel, never a finding block.

A lens's own `al-researcher` call carries `Use: routine`: a finding is ephemeral and the caller decides what survives it. `architecture` mode is the exception. What a lens confirms there stays in an artifact `/al-scope` decomposes into every task of the feature, so the call carries `Use: durable artifact architecture.md` and a `SINGLE-SOURCE` verdict settles nothing — the same bar the design gate holds itself to.

## Terminal states

| State | Shape | The caller reads it as |
|---|---|---|
| Findings | sentinel, `Mode:` echo, one or more finding blocks | judge these |
| Clean | sentinel, `Mode:` echo, a line saying the lens found nothing | judged and clear |
| Capability skipped | `perf scan skipped: al-performance MCP not available` alone | degraded coverage, named in the report — never clean |
| Invocation error | the invocation-error line alone | a failed lens and a gate gap |
| Failed or empty | no sentinel, no recognised line | a failed lens and a gate gap |

A failed lens is reported, never silently retried and never counted as clean.

## Sentinels

Line 1 of a successful return is the lens's sentinel; line 2 echoes `Mode: <value>` so the judge can confirm every lens judged the same artifact.

| Lens | Sentinel |
|---|---|
| `al-review-compliance` | `COMPLIANCE FINDINGS` |
| `al-review-coverage` | `COVERAGE FINDINGS` |
| `al-review-structural` | `STRUCTURAL FINDINGS` |
| `al-review-bc` | `BC FINDINGS` |
| `al-review-perf` | `PERFORMANCE FINDINGS` |
| `al-review-appsource` | `PUBLIC-SURFACE FINDINGS` |
| `al-review-bugscan` | `CORRECTNESS FINDINGS` |
| `al-review-comments` | `COMMENT AND HISTORY FINDINGS` |
| `al-review-simplify` | `SIMPLIFY FINDINGS` |
| `al-review-objects` | `OBJECT FINDINGS` |
| `al-review-assertions` | `ASSERTION FINDINGS` |

## Finding shape

Every lens returns raw labeled blocks, lede first — never a fix plan, never an application order:

- **Finding:** the observed concern, one line.
- **Where:** the address inside the artifact under review. Code names the file, object, and procedure, adding a line number only when it sharpens the fact; a plan names the document section plus the row, case, or example id. Review findings are ephemeral, so these pointers are exempt from names-as-citation in `GROUND-RULES.md`.
- **Why:** the rule or risk at this lens's altitude.
- **Source:** this lens's goal, plus the topic or pattern id when one was matched.

A concern a lens sees but its mode does not own returns as an **Out-of-scope:** block naming the gate that owns it. Out-of-scope notes never reach `al-review-judge`; the calling skill routes them.

## Judge fence

`al-review-judge` receives the same `Mode:` from the caller — authoritative, not inferred from any lens. Three extra classification rules apply in `code-review` mode only: a spec-scope violation, a diff-added BC construct class carrying no `Researched:` grounding citation, and a substantiated `HIGH` scanner severity. The other modes classify on the plain cost criteria plus, in the three plan modes, the contractual-defect rule the judge's own body carries.

## A blocking finding on a plan

The three plan modes — `architecture`, `test-spec`, `verification-plan` — review a document before any code exists, so there is no rework queue, no commit, and nothing to revert. A surviving `MUST-FIX` holds the artifact's status flip until the artifact itself changes.

The calling skill reports each survivor under one disposition:

| Disposition | Meaning | Route |
|---|---|---|
| self-resolvable | regenerating this artifact fixes it | the same live session revises |
| upstream | the artifact cannot fix it from here — a missing `architecture.md` slot, an ADR conflict, a wrong slice boundary, a missing `event-model.md` step | `Next: /al-steer` |

Authority splits on the line the interview drew ([user-involvement.md](user-involvement.md)). A `MUST-FIX` against something the agent decided holds the flip on the terms above. A `MUST-FIX` against a decision the user settled in the interview holds nothing: the lens read the artifact blind and cannot see that the pick was made rather than guessed. Report it, name the decision it argues against, and carry it into the question below as one more revision the user can take. Keeping the decision as it stands clears the finding, which then rides in the close alongside the nits. The calling skill ran the interview and holds that provenance — where compaction has cost it, the finding counts as agent-made and blocks.

A finding of either disposition may also carry a plugin-gap record, printed when this machine let through a failure class it should have prevented:

```
Plugin gap: <the gate that let it through>
Let through: <the failure class>
Would have caught it: <the rule or check that was absent>
```

The record reaches the maintainer and stops there — no ledger, no artifact, no follow-up task.

Then one lettered question: regenerate against every finding, regenerate against a named subset and hold the gate on the rest, or escalate to `/al-steer` naming the upstream artifact. On the answer the same live session revises. A self-resolvable finding never routes to `/al-steer`, which could only route back here, and the skill never re-invokes itself — a fresh invocation carries no context the live session lacks.

One re-review per run, spawning a complete fresh fleet and judging its batch from scratch. A `MUST-FIX` still standing after it keeps the disposition it already had: report it, stop regenerating, leave the flip unearned, and route `/al-steer` only where the evidence names an upstream artifact. A failed repair does not make a self-inflicted finding upstream.

An incomplete fleet holds the flip on the same terms — a lens or judge that reaches no terminal state is coverage this gate never had, and it prints the plugin-gap record. `SHOULD-FIX` rides in the close as nits. Lens churn stays out of chat.

## A finding on code

The two code modes — `code-review` and `refactor` — review landed code, so every surviving finding gets a disposition. The code is the configuration item. The task spec, `architecture.md`, `event-model.md`, `CONTEXT.md`, ADRs, and user-verified behaviour are baselines — baselines by existence, not by register. A historical spec under `specs/` binds unless a later one overwrote it.

A finding is **`rework`** when resolving it restores the code's conformance to a baseline without modifying or extending any baseline's content. A finding is a **`change request`** when resolving it would contradict baselined content, or establish content no baseline yet contains. Conformance findings are rework; baseline findings are change requests; and a finding whose baseline you cannot name is asking you to write one — escalate. The change cannot authorize itself: a comment, doc, or artifact the diff under review wrote is not a baseline for that diff.

Severity routes nothing here. A `MUST-FIX` and a `SHOULD-FIX` survivor take the same test — a `SHOULD-FIX` baseline variance is rework and gets fixed. `NO-ACTION` drops. The calling skill applies its whole rework queue autonomously: a finding the agent may simply fix never reaches the user; only a finding that needs the user's authority does.

The change-request residue is grilled at the close, in the live session — the skill never hands the residue to a fresh invocation, which carries no context the live session lacks. One conversation at a time, in the judge's `Rank:` order. The unit of grilling is the contested baseline decision, not the finding: change requests contradicting the same baselined content, or establishing the same missing content, merge into one conversation whose outcome dispositions them all. Each conversation converges on one of three terminal outcomes — terminal states of a dialogue, never an opening menu:

| Outcome | Meaning | Route |
|---|---|---|
| Do it now | the user reclassifies the finding as rework | fixed in this run, covered by the single re-review |
| Write a task | the resolution is authorized as scheduled work | a new task in `specs/<branch>/tasks/`; the gate holds until it is `done` |
| Keep the code, fix the baseline | code and baseline disagree and the user rules the baseline wrong | cleared at this gate; the baseline update is replan work — `Next: /al-steer` citing trigger #6 ([task-lifecycle.md](task-lifecycle.md)) |

At any point the user may close the remainder in one ruling — write tasks for the rest — and each remaining conversation becomes one task.
