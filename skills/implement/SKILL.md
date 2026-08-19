---
name: implement
description: Drive one frontier bullet to landed code through red-green at its pre-agreed seams, closing with a receipt that carries the gate verdict and the assumptions ledger. Reach for it when a bullet is refined and ready to build.
disable-model-invocation: true
---

# implement — one bullet to landed code

In: one frontier bullet — its test spec and pre-agreed seams ride on it — and the living design, which constrains architecture and data structure only; implementation details are yours, discovered in flight. Either input missing → name what is missing and stop. A bullet without seams is a decision point raised now, not a mid-run interview. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## The loop

Red at a pre-agreed seam, the smallest green, then the next vertical slice. Tests exercise behavior through public seams with independent expected values — an assert that restates the implementation proves nothing. Mid-loop checks run /al-build's unit mode; the full gate runs once, at the end. Load the idiom capsules matching the work type when they exist — the miner grows them; today there are none.

## Verify or declare

About to write code that depends on platform behavior not verified in this session: lookup it, or the claim enters the ledger as assumed. Every BC object, table, field, procedure, event, or enum value name is confirmed by a lookup in the current session, never recalled. BC vocabulary binds every line written — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method. Reach for the platform before writing code; an interface with a single implementation is indirection, not a seam.

## Stuck goes to the duck

The same failure twice, or a result that contradicts the spec, sends the failure evidence to the rubber-duck agent — the task tool's read-only complementary-model critic, agent_type rubber-duck — before a third retry. The GitHub Copilot app engine ships no duck: there the checkpoint skips and the receipt says so.

## Decision points

A change in behavior beyond the bullet stops the run and surfaces as one plain-text question; the answer resumes or reshapes the run. Everything else lands without chat.

## Close

Commit the work with a plain descriptive message naming the bullet. Emit the receipt — posted to the bullet's work item where Azure DevOps is wired, mirrored to `.output/receipts/<bullet>.md` always — and stop; the caller owns the next block.

```
## implement receipt — <bullet>
Built: one line per landed change, BC object names exact
Gate: /al-build verdict — mode named, per-runner totals from summary.json
Ledger:
  verified: <claim> — <Learn URL | BCApps file+line | topic id | article path>
  assumed: <claim> — not verified
Decision points: none | each one raised and the call made
Duck: not consulted | <verdict> | absent in this engine — checkpoint skipped
Commits: <hashes>
```

The run is done when every landed change appears under Built, every platform dependency sits in the ledger as verified or assumed, and the closing gate is green.
