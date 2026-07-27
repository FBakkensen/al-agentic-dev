# Rubber-duck review

The rubber-duck consult is adversarial critique of a judgment call, never a re-check of finished work. Spawn the harness-provided **rubber-duck agent** through the task tool as `agent_type: "rubber-duck"`. The harness pairs it to a different model family than the session — the cross-family pairing avoids the common-mode failure same-family self-review invites. A skill consults it autonomously mid-step, no user round-trip.

## Two consult sites, and no others

| Site | What it challenges | Why the duck and not the session |
|---|---|---|
| `/al-design` | the recommended architecture candidate, before the user picks | a judgment call between viable options, with no gate that can settle it |
| `/al-code-review` | every `MUST-FIX` survivor, before autonomous rework lands | a veto that licenses the agent to change code without asking |

Everywhere else, the gate is the check: `/al-build` for code, the review fleet plus `al-review-judge` for written artifacts, the user's own eyes for `/al-user-verification`. A consult added on top of an existing gate buys a second opinion on work already proven and costs a full agent round-trip. Adding a third site means retiring one of these two or naming the gate it replaces.

## Pass the artifact, not the question

The caller composes the body the reviewer sees — the candidate comparison, or the must-fix list — and asks for a bulleted list of gaps, shape `[artifact section] [missing concern] [why it matters]`. Leading questions ("did you consider…") collapse to confirmation.

## Reconcile the return verbatim

Each returned bullet is reconciled as written: accepted (artifact updated) or rejected (rationale stated in session). Editorialising the return is silent self-review of the second opinion.

A bullet contradicting primary-source evidence in hand (the file says X, the user said Y) goes back in one more consult — "I found X, you suggest Y, which constraint breaks the tie?" — never a silent switch to the duck's answer.

## Veto (`/al-code-review` only)

`/al-code-review` sends every round's must-fix survivor list. A duck refutation of a must-fix finding drops it from the rework queue and escalates to the user — a veto on autonomous fixing, not another opinion to weigh.

## Unavailable

`/al-design` states `Rubber-duck review skipped: <reason>` once and continues — no retry, no invented findings; the user still picks the candidate. `/al-code-review` reports `BLOCKED` and stops, because no `MUST-FIX` lands autonomously without the veto.
