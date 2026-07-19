---
name: al-quiz
description: Quiz the developer on recently landed AL/Business Central changes — one question at a time, in chat — to keep their mental model in contact with the codebase. Use after a long agentic run, before merging a feature, when returning to a project after time away, or standalone on any diff, slice, or object area the user names.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-quiz, Stay in contact with the codebase

Agentic work can land before the developer absorbs it. This skill tests the human model of what shipped; `/al-code-review` judges the diff and `/al-user-verification` walks behaviour.

Read-only: no status write, durable artifact, or gate. The user invokes it; no skill does.

## Scope

Use the named scope. Otherwise quiz the work least likely absorbed: recent branch commits, a completed slice, the feature before merge, or a named legacy object area. Read the diff plus relevant `Test Specification` and `Contract notes`; ask from shipped behaviour, not plans.

## The quiz

Ask one chat question, wait, then give the punchline. On a miss, correct it against named objects and procedures. Ask-before-reveal: options must not expose the answer.

Ask only questions whose wrong answer costs something: seam placement, test-pinned edge cases, existing paths, and shipped contracts. Skip grep trivia. Prefer "what happens when …" to "what is …".

Scale depth to scope. Stop once answers show a sound model; do not chase a fixed count. The user may stop, skip, or go deeper at any question.

## Verdict

Close with the model verdict: sound, or named decisions held incorrectly with one-line corrections anchored in objects ([voice-contract.md](../../references/voice-contract.md)). Questions are witness elicitation, not lettered decisions. A miss cluster can warrant `/al-code-review` or a task-file walk. Record nothing.

## Composition

| | |
|---|---|
| **Runs after**     | anything — typically `/al-implement`/`/al-refactor` runs the user watched loosely, feature-done before merge, or time away from the project |
| **Hands off to**   | nothing — advisory; a miss-cluster may motivate `/al-code-review` or `/al-steer` |
| **Calls directly** | none |
| **Replan venue**   | not applicable — no plan is touched |
