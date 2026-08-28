---
name: al-review
description: Use after AL implementation or refactoring when the diff needs a ledger-first verdict against Gherkin, AAA proof, and module contracts without editing code.
---

# al-review - judge the landed slice

In: the diff, receipt, and the executable Original User Story or a child User Story plus its Original User Story. Read the executable item's reviewed `Test specification` from Acceptance Criteria. Read-only: report evidence and make no code, work-item, or design edits.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Usually ask none: report findings, and make uncertainty explicit.

## Ledger first

Read the receipt's `verified:` / `assumed:` entries first. Spot-check every verified pointer. An undeclared platform assumption that behavior depends on is Blocking; an unresolved declared assumption is classified by its consequence.

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

Run /al-build in `UnitTestOnly` mode for missing unit evidence or `AllTests` mode for missing integration evidence.

## Parallel lenses

Dispatch `al-review-lens` once with one dimension named `User Story contract`, its full definition being the checks above, the diff scope, work items, receipt, and relevant sources.

For standards, read `.bcquality/skills/entry.md` and follow its Entry protocol with goal `review`, inputs `pr-diff`, technologies `[al]`, and all three layers. Dispatch one `al-knowledge-leaf` per selected leaf with the leaf path, diff scope, READ and DO paths, and domain-filtered index slice its contract requires.

These parallelize in full-capability subagents; when subagents are unavailable, apply them in one pass. Deduplicate by root cause.

## Verdict

Report only actionable findings:

`⛔ Blocking - <title>` or `⚖️ Non-Blocking - <title>`

Then one line each:

`⚡ Breaks:` violated behavior or contract

`📍 Proof:` file, line, test, work-item section, or verified platform evidence

`🔧 Fix:` smallest complete correction

End with the verdict: `blocking`, `non-blocking only`, or `no blocking issues found`. One optional `Refactor food:` line is the only home for aesthetics.
