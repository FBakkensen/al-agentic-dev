---
name: al-quiz
description: Quiz the developer on recently landed AL/Business Central changes to keep their mental model in contact with the codebase. Use after a long agentic run, before merging a feature, when returning to a project after time away, or standalone on any diff, slice, or object area the user names.
---

# /al-quiz, Stay in contact with the codebase

`/al-code-review` judges the diff and `/al-user-verification` walks behaviour; `/al-quiz` checks whether the developer's mental model matches either.

Read-only: no gate. The user invokes it; no skill does.

## Scope

**Quiz the work least likely absorbed.** Use the scope the user names. Otherwise pick recent branch commits, a completed slice, the feature before merge, or a named legacy object area. Read the diff plus relevant `Test Specification` and `Contract notes`. Ask from shipped behaviour, not plans.

## The quiz

**One question, wait, then the punchline.** Questions are ask-before-reveal per [GROUND-RULES.md](../../references/GROUND-RULES.md). On a miss, correct it against the named object, procedure, or contract.

- Ask only questions whose wrong answer costs something: seam placement, test-pinned edge cases, existing paths, and shipped contracts. Prefer "what happens when …" to "what is …".
- Scale depth to scope. Stop once answers show a sound model.

## Verdict

**Record nothing.** Close with the developer's demonstrated model. A sound verdict names the answers that demonstrate it. An unsound one names each decision held incorrectly, with a one-line correction.

## Composition

| | |
|---|---|
| **Runs after**     | anything — typically `/al-implement`/`/al-refactor` runs the user watched loosely, feature-done before merge, or time away from the project |
| **Hands off to**   | nothing — advisory; a pattern of misses may motivate `/al-code-review` or `/al-steer` |
| **Calls directly** | none |
| **Replan venue**   | not applicable — no plan is touched |
