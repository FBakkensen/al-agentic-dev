---
name: al-review
description: Use whenever /mattpocock-skills:code-review runs on AL code for a slice with an Azure DevOps work item, a child PBI or the Original work item itself, or when a landed AL slice is judged against its work item's Gherkin and proof. A plain AL code review with no work item belongs to /bcquality:al-code-review.
---

# al-review - the AL layer of mattpocock-skills:code-review

In: `/mattpocock-skills:code-review` over an AL slice. The entry owns the process: the fixed point, its Spec and Standards sub-agents, and the per-axis summary. This addition feeds both axes the Azure DevOps and AL inputs, adds a Correctness axis, and sets the findings grammar. Read-only: report evidence, and edit no code, work item, or design. It runs no gate; missing proof is a finding.

When this addition loads first, invoke `/mattpocock-skills:code-review` with the `Skill` tool and run beside it.

## The work item

Find the executable work item's id: an `AB#<id>` in the entry's commit list, the id in the branch name or the request, or a receipt under `.output/receipts/`. It is a child PBI, or the Original work item itself when the request has one slice. Read it, then its parent Original work item, by id with `mcp__plugin_al-agentic-dev_ado__wit_work_item` (`get`, expand `Relations`). The receipt is `.output/receipts/<executable id>.md`.

With no Azure DevOps work item in play, hand the review to `/bcquality:al-code-review` and return its findings report unchanged; the rest of this addition does not apply.

## Spec axis

▶ opus · the entry's Spec sub-agent brief, with the executable work item's Acceptance Criteria (`Behavior` Gherkin and `Test specification`), the Original work item's Description (Repro Steps on a Bug), the receipt, and the checks below → Spec findings in the grammar below

The sub-agent reads the receipt's `verified:` / `assumed:` / `unresolved:` entries first and spot-checks every `verified:` pointer, the gate pointer included. An undeclared platform assumption that behavior depends on is Blocking; a declared assumption or unanswered question is classified by its consequence. It judges:

- every Gherkin scenario reaches its named BPMN outcome
- the Gherkin and AAA proof start from the Original work item's Trigger and cover its Success and Minimal guarantees
- AAA cases cover the scenario branches with independent expected values
- tests exercise the caller-visible module interface rather than private internals
- Building Block Level 1 ownership matches the code
- the implementation change map includes every changed production object, explains every connection, and separates proof objects
- Level 2, when present, matches proven internals; its absence is valid for a simple module
- permissions, translations, upgrade impact, and breaking surface are covered

## Standards axis

Brief the entry's Standards sub-agent to name each baseline smell in BC vocabulary: codeunit, procedure, table, field, event subscriber. Beside it:

▶ sonnet · bcquality:al-code-review over the diff scope → its findings report

Translate that report into the grammar below, beside the smell lines, citing the bcquality rule in `📍 Proof:`. A finding that breaks behavior, data, upgrade, or permissions is Blocking; the rest are Non-Blocking.

## Correctness axis

Classify the built-in `/code-review`'s findings over the same fixed point. When the work that invoked this review already ran it, take those findings; otherwise run `/code-review` at effort `high` with the `Skill` tool, without `--fix`.

## Findings

Confirm every BC object, table, field, procedure, event, enum value, dialog text, or platform claim you judge through a lookup in this session.

Report `## Spec`, `## Standards`, and `## Correctness` unmerged. Deduplicate by root cause inside one axis only. In each, report only actionable findings, Blocking before Non-Blocking:

`⛔ Blocking - <title>` or `⚖️ Non-Blocking - <title>`

Then one line each:

`⚡ Breaks:` violated behavior or contract

`📍 Proof:` file and line, test, work-item section, or verified platform evidence; show the failing case or reproducible path when possible

`🔧 Fix:` smallest complete correction

The review is done when each of the three sections lists its findings or says `none`. The entry's per-axis summary closes it; no line merges the axes into one verdict.
