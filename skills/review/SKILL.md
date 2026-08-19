---
name: review
description: Read a diff against its bullet and the BC ground — ledger first, standards and spec side by side, blast radius proven by running code — and return a verdict without touching a line. Reach for it when a diff is ready for judgment.
disable-model-invocation: true
---

# review — verdict, never edits

In: a diff since a fixed point, its frontier bullet when one exists, and implement's receipt when one exists. A diff without a bullet is a legal run — the Spec axis is skipped and named in the verdict, never invented. Review returns findings and edits nothing; fixes belong to the execution blocks. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Ledger first

The first stop is the receipt's assumptions ledger. Every `verified:` pointer is spot-checked at its source; every `assumed:` claim is judged for the risk it carries. An undeclared assumption the read uncovers — platform behavior the diff depends on that no ledger line names — is the cardinal failure, always Blocking. No receipt → the ledger stop is named absent and the sweep below carries the weight.

## Two axes, fanned out

Standards and Spec run as parallel al-review-lens invocations — one dimension per invocation, its definition and sources in the prompt; the parent owns judgment. Standards reads the diff against BC idioms and the BCQuality rules — al-knowledge-leaf runs each BCQuality review leaf the diff's domains select from `.bcquality/knowledge-index.json`. Spec reads the diff against what the bullet asked: nothing more, nothing missing. The two verdicts sit side by side, never merged — counts and the worst finding per axis.

## The anatomy sweep

The parent sweeps the six AL anatomy axes itself, never one agent per axis: schema/upgrade, events, permissions, XLF translations, breaking-change baseline, tests. Each axis lands in the verdict named with news or closed as clear.

## Blast radius

What breaks beyond the diff: callers, subscribers of touched events, data the diff reshapes, flows that reach the changed objects without naming them. Name the one safety fact most of the risk hangs on and prove it by running code — a focused test or an /al-build run — never by prose. Unproven stays named unproven.

## Verdict

Every BC name in a finding is confirmed by a lookup in the current session, never recalled. Style nitpicks belong to the analyzers in the build gate, not here. "No blocking issues found" is a legal verdict.

```
## review verdict — <diff scope>
Ledger: re-checked | absent — undeclared assumptions: none | <each one, Blocking>
Standards: <count + worst finding> · Spec: <count + worst finding> | skipped — no bullet
Anatomy: schema/upgrade · events · permissions · XLF · baseline · tests — news or clear per axis
Blast radius: <the safety fact> — proven by <the run> | unproven
Findings: Blocking / Non-Blocking / Suggestion
```

The verdict returns to the caller. The run is done when the ledger stop, both axes or the named skip, all six anatomy axes, and the blast-radius fact appear in it.
