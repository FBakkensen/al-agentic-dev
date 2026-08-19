---
name: refactor
description: Reshape working code toward a named deepening goal while behavior stays frozen — subtract first, migrate callers before deleting, prove the hold with the full gate. Reach for it when green code needs a better shape.
disable-model-invocation: true
---

# refactor — same behavior, better shape

In: working code behind a green gate, a named deepening goal, and the living design as context. No goal → name what is missing and stop. Behavior is frozen for the whole run: a change in behavior is a decision point that stops the run and surfaces as one plain-text question — a reshape that changes behavior is not a refactor. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Subtract first

Remove dead weight before adding structure: unused procedures and variables, duplicate validation, stub references. Rerun the checks on the simpler base — /al-build's unit mode — before the deepening move. What remains to build is smaller than it looked.

## The deepening move

Work toward the named goal in caller-safe steps: the new shape lands first, callers migrate one by one, and the old path is deleted only when nothing names it. The smallest structure the goal justifies wins; an interface with a single implementation is indirection, not a seam. Load the idiom capsules matching the work type when they exist — the same seam implement loads; today there are none.

## Verify or declare

A reshape that depends on platform behavior not verified in this session: lookup it, or the claim enters the ledger as assumed. Every BC object, table, field, procedure, event, or enum value name is confirmed by a lookup in the current session, never recalled. BC vocabulary binds every line written — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method.

## Close

/al-build runs the full gate once, at the end. Behavior held means the per-runner totals match the starting green — or every difference is explained — and the breaking-change baseline stays silent. Commit with a plain descriptive message naming the goal. Emit the receipt and stop — the caller owns the next block.

```
## refactor receipt — <goal>
Reshaped: one line per move, BC object names exact
Gate: /al-build full-gate verdict — per-runner totals from summary.json
Behavior held: totals against the starting green + the baseline's silence
Ledger:
  verified: <claim> — <Learn URL | BCApps file+line | topic id | article path>
  assumed: <claim> — not verified
Decision points: none | each one raised and the call made
Commits: <hashes>
```

The run is done when every move appears under Reshaped, nothing names the deleted paths, and the closing gate is green with the baseline silent.
