# Rubber-duck review

The rubber-duck consult is an independent read on a non-trivial artifact. Spawn the harness-provided **rubber-duck agent** through the task tool as `agent_type: "rubber-duck"`. The harness pairs it to a different model family than the session — the cross-family pairing avoids the common-mode failure same-family self-review invites. A skill consults it autonomously mid-step, no user round-trip.

When the `rubber-duck` agent type is unavailable, state `Rubber-duck review skipped: <reason>` once and continue — no retry, no invented findings.

## Pass the artifact, not the question

The caller composes the artifact body the reviewer sees — the `Test Specification`, `Verification Plan`, mutation list, refactor checklist, walk verdict, or must-fix list — and asks for a bulleted list of gaps, shape `[artifact section] [missing concern] [why it matters]`. Leading questions ("did you consider…") collapse to confirmation.

Consult only on a real, non-trivial artifact the caller is ready to reconcile per bullet.

## Reconcile the return verbatim

Each returned bullet is reconciled as written: accepted (artifact updated) or rejected (rationale stated in session). Editorialising the return is silent self-review of the second opinion.

A bullet contradicting primary-source evidence in hand (the file says X, the user said Y) goes back in one more consult — "I found X, you suggest Y, which constraint breaks the tie?" — never a silent switch to the duck's answer.

## Veto (`/al-code-review` only)

`/al-code-review` sends every round's must-fix survivor list. A duck refutation of a must-fix finding drops it from the fix queue and escalates to the user — a veto on autonomous fixing, not another opinion to weigh.
