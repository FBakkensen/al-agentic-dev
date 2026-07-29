---
name: al-user-verification
description: Walk one slice's Verification Plan with the user in the BC Web Client — record and replay the framework-limited scenarios, then guide the rest one scenario at a time. Run it when al-next names a verify task ready for verification.
disable-model-invocation: true
---

# Walk a slice's Verification Plan

The user is the runner; you are the guide. You drive everything mechanical — containers, publish, replays, Contract clients, the task file — and turn each plan element into one concrete instruction the user performs in the BC Web Client. Their eyes are the oracle; they never open the task file.

**Ask what the user sees before naming what you expect.** *"What does the Status field show now?"*, never *"Does Status say Open?"* — a led question hides the defect the walk exists to catch.

Functional outcomes gate: a Status value, a cue count, an HTTP status, an error. Usability outcomes never gate.

## Preconditions

The task this skill takes is the slice's `kind: verify` task with a populated `Verification Plan` and the review gate's stamp on it — `/al-routing` routes it here only in that state, and task-file state stays `/al-routing`'s throughout. An empty plan, a missing stamp, or a Contract Example whose named client is unconfigured — stop and name which.

Login is the user's. Hand over the Web Client URL and the throwaway container credentials from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`), local container hosts only. The user cannot reach the URL → stop and fix the environment first.

## What the plan holds

| Element | Runner | Gates on |
|---|---|---|
| Journey Example `Record: yes` | the user records it, you replay | replay green |
| Journey Example `Record: no` | the user walks it, check by check | reported value vs `Observable Checks` |
| Contract Example | you run the named client | captured output vs `Observable Checks` |
| Exploration Charter | the user wanders the prompts and narrates | nothing — findings only |

## Record the framework-limited scenarios

`Record: yes` marks AL-driven UI behaviour no AL test layer can pin — a web-client-only surface, a page flow whose check is what the user sees. Control add-ins, canvases, and embedded surfaces are invisible to the recorder and belong in an Exploration Charter. Most slices carry none and go straight to pre-flight. Work the ones still missing their `.yml`, one card at a time.

A card carries the business punchline, the example's `Action` bullets, its `Observable Checks` phrased as recorder gestures, and the one repeatability rule that scenario most needs — gestures and rules in [RECORDING-FORMAT.md](RECORDING-FORMAT.md). The user records and hands back the downloaded `.yml`'s absolute path; /al-build's import lands it at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` and names the path you replay.

**The recorder is the generator; never author a `.yml`.** One carve-out: a surgical, approval-gated edit to a recorder-produced file — bump a `wait`, fix one `operation:`, add a missed Validate — when that is plainly the shortest path to green.

Replay each on a fresh container through /al-build and read any red per RECORDING-FORMAT.md. A brittle recording — a hardcoded No., a positional row pick, an unanswered dialog — gets coached into a re-record. A recording that faithfully replays wrong behaviour is a defect — treat it as a functional fail: write the fail line in `Partial-run record:` naming the recorded check, run the same repair episode as a walk fail, then re-record; the green replay appends its pass line. Green seals the scenario and opens the next card; the last card's green is reported to `/al-routing`, whose stamp marks the recordings sealed.

## Pre-flight the batch

Fresh container and publish through /al-build, then replay every recording in one batch — this slice's and every prior slice's, so a cross-slice collision surfaces before the user is invited in. No recordings → skip it. Red → stop and read it per RECORDING-FORMAT.md: brittleness re-records, faithful wrong behaviour takes the repair episode above — a human's time is not worth spending against a red build.

## Guide the walk

Fresh container and publish through /al-build first — a later spawn kills the user's session mid-walk. Run the Contract Examples yourself against their named client and keep the request and response verbatim.

Open with what the user is in for: task id, slice slug and its `event-model.md` step, how many scenarios they walk, how many the replay already confirmed, a time estimate, and that the container work runs minutes rather than seconds. Then hand over the URL, the credentials, and a deep link to the starting page — `http://<container>/BC/?page=<id>`, the page ID read from the page AL.

One scenario open at a time. Each `Record: no` Journey Example becomes one card — punchline, Do bullets, then its checks one at a time:

> **Scenario 1 of 3 — Releasing a blocked customer's order should be refused.**
> *Do these in the Web Client, then I'll ask what you see.*
>
> **Do**
> - Open the Sales Order for the blocked customer
> - Choose **Release**

The punchline names the business outcome and stops short of the expected value. Where the observable is a closed set — an option or enum like `Status` — offer its full value range plus *"Something else — describe"*; counts, error text, and HTTP bodies take free text. Take the user's words verbatim against the example's `Observable Checks` rather than inferring what the AL should have done.

For an Exploration Charter, give the charter sentence and its prompts, let the user wander and narrate, then classify each remark as functional fail or usability finding and say which in one line, so a misfile is catchable. An unexpected surface — a flicker, a sudden navigation, the wrong page — earns a question: which screen are they on, re-orient by deep link, re-run the scenario's remaining checks. Reproducible unexpected navigation gates; a one-off flicker is a finding.

## Close the walk

Append one line per completed example to a `Partial-run record:` block in the task body as you go — `V1 — pass — observed: <verbatim> — asked: "<question as posed>"`, plus `expected:` and an evidence path on a fail. A session boundary erases the chat; this survives it, and re-entry restarts only the in-flight scenario, from its first action, since fresh containers wiped its data. Re-entry onto a trailing fail line asks first whether the fix landed and its diff was reviewed — no fix yet → `/al-implement` is still the move; landed but unreviewed → `/al-code-review` on the fix diff — either way, without re-walking. A check with no reported value, a bare yes/no, or a pass resting on a led question is a gap — re-ask it.

**A functional fail stops the walk, and no state moves** — the fail line in `Partial-run record:`, referencing the user's screenshot under `.output/verification/T-NNN/`, is the durable evidence. A defect — the observed value contradicts the plan — is fixed inline: the user runs `/al-implement`, whose red is this failed check, `/al-code-review` reviews the fix diff under its repair scope, and the walk resumes at the failed scenario; frontmatter holds still through the whole episode. Behaviour that matches the plan but is no longer what the user wants is a change request: write it as a new open technical task in the same slice per `/al-routing`'s schema, matching its sibling task files down to the description — and whether the walk continues past it is the user's call.

**Every functional check passing and the pre-flight green** → collapse `Partial-run record:` into `Closeout:` — one line per example with its outcome, replay-confirmed scenarios included — and write each usability finding as a new open technical task in the same slice per `/al-routing`'s schema.

The slice is verified on the user's own screen and the next slice is open — or the walk is paused on a named functional failure, with `/al-implement` as the user's next move.

Then `/al-routing` on a clean walk; a paused walk stays inside its episode.
