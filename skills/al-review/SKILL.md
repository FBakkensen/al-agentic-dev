---
name: al-review
description: Read a diff against its bullet and the BC ground — ledger first, standards and spec side by side, blast radius proven by running code — and return a verdict without touching a line. Reach for it when a diff is ready for judgment.
disable-model-invocation: true
---

# al-review — verdict, never edits

In: a diff since a fixed point, its frontier bullet when one exists, and al-implement's receipt when one exists. A diff without a bullet is a legal run — the Spec axis is skipped and named in the verdict, never invented. Review returns findings and edits nothing; fixes belong to the execution blocks. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Ledger first

The first stop is the receipt's assumptions ledger. Every `verified:` pointer is spot-checked at its source; every `assumed:` claim is judged for the risk it carries. An undeclared assumption the read uncovers — platform behavior the diff depends on that no ledger line names — is the cardinal failure, always Blocking. No receipt → the ledger stop is named absent and the sweep below carries the weight.

## Two axes, side by side

Spec runs as an al-review-lens invocation — the dimension's definition and sources in the prompt; the parent owns judgment. It reads the diff against what the bullet asked: nothing more, nothing missing.

Standards executes the BCQuality Entry protocol: read `.bcquality/skills/entry.md` and follow it over the repo's clone — task-context goal review, inputs pr-diff, technologies [al], all three layers; the index rebuilt as entry.md directs. The dispatched al-code-review runs its leaves per its own execution discipline, one al-knowledge-leaf child per leaf with its domain-filtered index slice. The DO roll-up feeds the verdict mechanically: `domain: style` and aesthetic-only findings land as refactor food; consequence domains — security, upgrade, breaking changes, error handling, events, performance, data modeling — land under the finding classes; DO severity informs, the classes here decide. The parent reads the diff against the repo's `docs/patterns.md` itself where it exists. The two axes sit side by side, never merged — counts and the worst finding per axis, and the roll-up's suppressed count on the Standards line: a skip is named, never hidden.

## The anatomy sweep

The parent sweeps the six AL anatomy axes itself, never one agent per axis: schema/upgrade, events, permissions, XLF translations, breaking-change baseline, tests. Each axis lands in the verdict named with news or closed as clear.

## Blast radius

What breaks beyond the diff: callers, subscribers of touched events, data the diff reshapes, flows that reach the changed objects without naming them. Name the one safety fact most of the risk hangs on and prove it by running code — a focused test or an /al-build run — never by prose. Unproven stays named unproven.

## Verdict

Every BC name in a finding is confirmed by a lookup in the current session, never recalled. A shape observation appears in this verdict only when the shape will produce wrong behavior — then it is a finding; beauty is never a finding. Consequence-bearing idiom violations — locking, Commit discipline, TransferFields traps — stay findings; a shape observation whose only cost is aesthetics goes to the one Refactor food line. A generic-CS name on a shipped surface — an object, table, field, procedure, or event name — is a finding, not refactor food: AL names are permanent API, and a wrong name produces wrong integrations and a breaking rename later. "No blocking issues found" is a legal verdict.

```
## al-review verdict — <diff scope>
Ledger: re-checked | absent — undeclared assumptions: none | <each one, Blocking>
Standards: <count + worst finding + suppressed count> · Spec: <count + worst finding> | skipped — no bullet
Anatomy: schema/upgrade · events · permissions · XLF · baseline · tests — news or clear per axis
Blast radius: <the safety fact> — proven by <the run> | unproven
Findings: Blocking / Non-Blocking
Refactor food: none | <one line>
```

The verdict returns to the caller — posted to the bullet's work item where Azure DevOps is wired, mirrored to `.output/receipts/<diff-scope>.md` always. The run is done when the ledger stop, both axes or the named skip, all six anatomy axes, and the blast-radius fact appear in it.
