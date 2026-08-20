---
name: al-implement
description: Drive one frontier bullet to landed code through red-green at its pre-agreed seams, closing with a receipt that carries the gate verdict and the assumptions ledger. Reach for it when a bullet is refined and ready to build.
disable-model-invocation: true
---

# al-implement — one bullet to landed code

In: one frontier bullet — its test spec and pre-agreed seams ride on it — and the living design, which constrains architecture and data structure only; implementation details are yours, discovered in flight. Either input missing → name what is missing and stop. A bullet without seams is a decision point raised now, not a mid-run interview. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## The loop

Work the test spec in seam-clusters — the AAA cases that share one seam and one Arrange, cut from the spec in flight. Each cluster earns its red as one batch before its green. Every /al-build run executes the full suite, so pipeline the proofs: one run confirms the previous cluster green and the next cluster red — N clusters cost N+1 runs, regression riding every run. Name unit mode while the cluster's tests run under AL Runner; name the full gate when they need the container. A test that arrives green at its red run is checked against existing coverage — redundant drops, live earns a mutation proof: break the implementation, watch the red, restore. Tests exercise behavior through public seams with independent expected values — an assert that restates the implementation proves nothing. Load the idiom capsules matching the work type when they exist — al-miner grows them; today there are none.

## Verify or declare

About to write code that depends on platform behavior not verified in this session: lookup it, or the claim enters the ledger as assumed. Every BC object, table, field, procedure, event, or enum value name is confirmed by a lookup in the current session, never recalled. BC vocabulary binds every line written — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method. Reach for the platform before writing code; an interface with a single implementation is indirection, not a seam.

## Stuck goes to the duck

The same failure twice, or a result that contradicts the spec, sends the failure evidence to the rubber-duck agent — the task tool's read-only complementary-model critic, agent_type rubber-duck — before a third retry. The GitHub Copilot app engine ships no duck: there the checkpoint skips and the receipt says so.

## Decision points

A change in behavior beyond the bullet stops the run and surfaces as one plain-text question; the answer resumes or reshapes the run. Everything else lands without chat.

## Close

The closing gate is the last full-gate green run that no edit follows — any change after it, however small, reopens the gate. Commit the work with a plain descriptive message naming the bullet. Emit the receipt — posted to the bullet's work item where Azure DevOps is wired, mirrored to `.output/receipts/<bullet>.md` always — and stop; the caller owns the next block.

```
## al-implement receipt — <bullet>
Built: one line per landed change, BC object names exact
Tidy: <shape debts noticed in flight — naming, dead scaffolding, duplication, idiom polish | none>
Gate: /al-build verdict — mode named, per-runner totals from summary.json
Ledger:
  verified: <claim> — <Learn URL | BCApps file+line | topic id | article path>
  assumed: <claim> — not verified
Decision points: none | each one raised and the call made
Duck: not consulted | <verdict> | absent in this engine — checkpoint skipped
Commits: <hashes>
```

The run is done when every landed change appears under Built, every platform dependency sits in the ledger as verified or assumed, and the closing gate is green.
