# Rubber-duck review — the cross-check discipline

How a skill gets an independent read on a non-trivial artifact: consult the **built-in
rubber-duck agent** (ask in plain language — "rubber-duck this Test Specification" — or the
user runs `/rubber-duck`; the harness may also consult it on its own). The rubber duck runs
on a different model family than the session by design, so it catches what same-family
self-review confirms. It is a harness built-in: no skill wraps it, no script dispatches it,
and it is not spawned through the task tool.

The consult is one of the moves a skill may make **autonomously** mid-step, no user
round-trip — load-bearing for the cheap-model goal: a smaller model running a pipeline
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

## Fail closed, do not fake

If the consult cannot run, the caller says so in one line — `Rubber-duck review skipped:
<reason>` — and continues its own work: no halt, no retry loop, no invented findings. The
cross-check is a checkpoint, not a hard gate; a missing one is recoverable, faking one is
not.

## Veto semantics (al-code-review only)

`/al-code-review` sends every round's must-fix survivor list. A refutation from the duck
is a **veto on autonomous action**: the refuted finding drops out of the fix queue and
escalates to the user rather than being auto-fixed on cross-family doubt.
