# al-user-verification

## What it is for

Walks one slice's Verification Plan with you. You are the runner; the agent is the guide. It drives everything mechanical — containers, publish, replays, Contract clients, the work item — and turns each plan element into one concrete instruction you perform in the BC Web Client.

Your eyes are the oracle. You never open the work item.

## When you reach for it

- The slice's verify task, its Verification Plan populated and the slice's review stamp on it.

That marker comes from [`/al-code-review`](al-code-review.md) at slice-done. Without it the slice has not been reviewed, and the walk does not start.

[`/al-build`](al-build.md) is a prerequisite skill — every container spawn, publish, and replay runs through it.

## What it produces

A verified slice, or a blocked verify task naming exactly what failed.

- **Recordings.** Scenarios marked `Record: yes` are the ones no AL test layer can automate — a control add-in, a canvas, web-client-only behaviour. You record them in Settings ⚙ → Page Scripting and hand back the `.yml`; the agent replays each on a fresh container. The recorder is the generator; nobody authors a `.yml` by hand.
- **The walk.** One scenario at a time, as a card: the business punchline, the actions to perform, then the checks one at a time. You are always asked what you *see* before the expected value is named — *"What does the Status field show now?"*, never *"Does Status say Open?"*. A led question hides the defect the walk exists to catch.
- **A durable record.** One line per example lands on the work item as the walk's partial-run record as you go, so a session boundary does not erase the walk. Re-entry restarts only the in-flight scenario.

Functional outcomes gate — a Status value, a cue count, an HTTP status, an error. Usability observations never gate; they become new tasks in the same slice.

Everything passing is reported to `/al-routing`, which settles the task and opens the next slice. A functional fail stops the walk on the spot; the repair lands red-first through [`/al-implement`](al-implement.md), and the walk resumes at the failed scenario.

The recording format ships as `RECORDING-FORMAT.md` inside the skill.
