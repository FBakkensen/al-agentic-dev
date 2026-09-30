---
name: al-review
description: Use after AL implementation or refactoring when the diff needs a ledger-first verdict against Gherkin, AAA proof, and module contracts without editing code.
---

# al-review - judge the landed slice

In: the diff, receipt, and the executable Original User Story or a child User Story plus its Original User Story. Read the executable item's reviewed `Test specification` from Acceptance Criteria. Read-only: report evidence and make no code, work-item, or design edits.

Usually ask none: report findings, and make uncertainty explicit.

## Ledger first

Read the receipt's `verified:` / `assumed:` / `unresolved:` entries first. Spot-check every verified pointer. An undeclared platform assumption that behavior depends on is Blocking; classify a declared assumption or unanswered question by its consequence.

## Inspect the contracts

Trace every changed call site, data flow, commit boundary, subscriber, and proof surface. Confirm every BC object, table, field, procedure, event, enum value, dialog text, or platform claim through lookup in this session.

Judge:

- every Gherkin scenario reaches its named BPMN outcome
- the Gherkin and AAA proof start from the Original User Story's Trigger and cover its Success and Minimal guarantees
- AAA cases cover the scenario branches with independent expected values
- tests exercise the caller-visible module interface rather than private internals
- Building Block Level 1 ownership matches the code
- the implementation change map includes every changed production object, explains every connection, and separates proof objects
- Level 2, when present, matches proven internals; its absence is valid for a simple module
- permissions, translations, upgrade impact, and breaking surface are covered

▶ haiku · /al-build gate on the reviewed scope for missing test evidence, WARN_AS_ERROR as the repository states → summary.json verdict, per-runner totals, exact red cause

## Parallel lenses

Launch these together in the background while the contract inspection above proceeds; wait only where the verdict needs their findings:

▶ sonnet · al-review-lens with the one dimension `User Story contract` — the checks above as its definition — the diff scope, work items, receipt, and relevant sources → its findings

For standards, read `.bcquality/skills/entry.md` and follow its Entry protocol with goal `review`, inputs `pr-diff`, technologies `[al]`, and all three layers; then one line per selected leaf:

▶ haiku · al-knowledge-leaf with the leaf path, diff scope, READ and DO paths, and the domain-filtered index slice its contract requires → the leaf's DO report

Deduplicate by root cause.

## Verdict

Report only actionable findings, Blocking before Non-Blocking:

`⛔ Blocking - <title>` or `⚖️ Non-Blocking - <title>`

Then one line each:

`⚡ Breaks:` violated behavior or contract

`📍 Proof:` file and line, test, work-item section, or verified platform evidence; show the failing case or reproducible path when possible

`🔧 Fix:` smallest complete correction

End with the verdict: `blocking`, `non-blocking only`, or `no blocking issues found`. One optional `Refactor food:` line is the only home for aesthetics.
