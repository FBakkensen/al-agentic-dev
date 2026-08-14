---
name: al-quiz
description: Quiz the developer, one question at a time, on AL/Business Central code that recently landed — testing their mental model, not the code. Reach for it before merge, after a long agentic run, or on returning after time away.
disable-model-invocation: true
---

# al-quiz — quiz the developer, not the code

**The subject under test is the developer.** The code is on disk either way; what nobody has checked is whether the person who now owns it could have written it. So this skill runs no gate and flips no task — the result lives in the developer's head when it closes, and its one possible write is the follow-up task below. Your first line names that this run wants a standard-class model or above — the user picked the model and weighs the mismatch. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Scope

Quiz the work least likely to have been absorbed: whatever the user names, or else the branch's commits since main, a slice whose tasks are settled, the whole feature before merge, or a legacy object area the user points at. Task frontmatter (`/al-routing`'s schema) is read only to find that scope. Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch.

Read the diff first, then the `Test Specification`, `Verification Plan`, and `Contract notes` of the tasks covering it. Every question comes from what shipped — a developer who can recite the plan has proved nothing about the code.

## Ask

**One question per message, with lettered options, then wait for the answer.** Distractors are plausible wrongs — the seam the logic almost landed on, the guard that looks sufficient — and no option carries a recommendation: the witness gets no hint. Take the answer, then give the punchline. Where the scope's structure carries the questions, `/al-visualize` can put the scope in view as a steering surface; each question stays here, in chat.

Ask where a wrong answer would cost something:

- which seam the logic landed on, and what breaks when it moves;
- the edge case a test pins, named by its AAA case;
- the existing path the change reroutes;
- the contract a dependent app or integration leans on.

*What happens when …* tests the model. *What is …* tests reading.

Correct a miss on the spot, in one line, against the object, procedure, or contract that carries it — the correction is what the developer walks away with. Then move to new ground rather than re-asking the same one.

Scale the number of questions to the scope and stop once the answers show a sound model.

## Close

A sound model → name the answers that demonstrated it. Gaps → name each decision held incorrectly, each with its one-line correction. Misses clustered on one object are worth naming as an area to re-read together. Put the verdict in view through `/al-visualize` as a steering surface — each miss and its correction pinned, clean where the model held.

Where the misses land on shipped behaviour rather than on how it was built and a feature's `tasks/` folder owns the area, offer a follow-up task in its slice — on the user's yes, write it yourself as a new open technical task per `/al-routing`'s schema and commit it under its own `T-NNN` prefix. Outside any feature, the gap stays a named correction in chat.

Outcome: the developer's model of the landed change, tested in chat and corrected where it was wrong.

Then `/al-next` — or `/al-routing` when a follow-up task was written.
