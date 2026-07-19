# Rubber-duck review — the cross-check discipline

How a skill gets an independent read on a non-trivial artifact: consult the **rubber-duck
agent**, spawned through the task tool as `agent_type: "rubber-duck"` (or the user runs
`/rubber-duck`; the harness may also consult it on its own). The rubber duck runs on a
different model family than the session by design — its pairing is gpt↔claude — so it
catches what same-family self-review would only wave through.

**Fallback when the agent type is missing.** `rubber-duck` drops out of the task tool's
`agent_type` enum on some session models (the pairing is gpt↔claude only). Spawn
`general-purpose` with a critic prompt on the *other* model family instead — a GPT-family
session → `claude-fable-5`; a Claude-family session, or any other family →
`gpt-5.6-terra` — at medium reasoning. The family rule is the contract; look up current IDs
in the task tool's model list when either pinned model rotates.

There is no skip path: the consult happens at every checkpoint that calls for it, by one
route or the other. Only if the task tool itself cannot spawn at all does the caller state
`Rubber-duck review skipped: <reason>` in one line and continue — no halt, no retry loop,
no invented findings.

The consult is one of the moves a skill may make **autonomously** mid-step, no user
round-trip — load-bearing for the worker-model goal: a smaller model running a pipeline
skill leans on the independent read to stay honest.

## Pass the artifact, not the question

The caller composes the artifact body the reviewer sees — the `Test Specification`,
`Verification Plan`, mutation list, refactor checklist, walk verdict, or must-fix list —
and asks for a bulleted list of gaps, shape `[artifact section] [missing concern]
[why it matters]`. The value is "what does another reader notice in this artifact", not a
verdict on the caller's framing; leading questions ("did you consider...") collapse to
confirmation.

## Preconditions

- Artifact is real and non-trivial. Round-tripping a one-line decision trains the caller
  to ignore the gate.
- Caller can reconcile per bullet when output arrives. Consulting the duck then ignoring
  the result is worse than not consulting.

## Verbatim out, verbatim in

What the duck returns is what the caller reconciles — bullets stay bullets, each accepted
(artifact updated) or rejected (rationale stated in session). Editorialising the return is
silent self-review of the second opinion.

## Do not fold to pushback automatically

If the duck contradicts primary-source evidence the caller has already gathered (the file
says X, the user said Y), the caller surfaces the conflict in one more consult — "I found
X, you suggest Y, which constraint breaks the tie?" — instead of silently switching to the
duck's answer. Reconcile beats deferring; a second opinion is input, not an override of
evidence in hand.

## Veto semantics (al-code-review only)

`/al-code-review` sends every round's must-fix survivor list. A refutation from the duck
is a **veto on autonomous action**: the refuted finding drops out of the fix queue and
escalates to the user rather than being auto-fixed on cross-family doubt.
