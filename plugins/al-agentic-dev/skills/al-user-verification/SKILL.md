---
name: al-user-verification
allowed-tools: ["execute", "read"]
description: Guide the user through one slice's `ready-for-verification` verify task in the `tasks/` folder for AL/Business Central — punchline-first, one scenario at a time, in chat. The user walks the non-recorded Journey Examples in their own browser and reports what they see; the agent runs containers, the pre-flight recording batch, and Contract checks, asks one check at a time (ask-before-reveal), records, and routes. Functional outcomes gate; usability observations become findings → tasks.
---

# /al-user-verification — Walk a slice's Verification Plan

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

**User is the runner; agent is the guide.** The agent operates everything mechanical — container spawns, publish, the pre-flight replay batch, Contract examples, status flips, the transcript — and turns each `Record: no` Journey Example and each Exploration Charter into single concrete instructions the user performs in the BC Web Client. The user's eyes are the oracle; the user never reads the task file or the plan grammar — they click, look, and answer. No AL writes, no `/al-build` run, no codebase walk; one carve-out: page-ID and option/enum value-range lookups for deep links and structured questions.

The walk does both halves of checking vs testing ([`test-strategy.md`](../../references/testing/test-strategy.md)): **functional/observable** outcomes — a Status value, a cue count, an HTTP status, an error — **gate** the verify task; **subjective usability** outcomes become **findings → tasks**, never a gate. Two guards against leading the witness: **ask-before-reveal** — the agent asks what the user sees before naming the expected value — and a rubber-duck review of the written verdict for coverage.

Run the plan in order: pre-flight the recording batch, run Contract examples against the named client, then guide the user — one scenario at a time, in chat, punchline first — through the `Record: no` Journey Examples and the Exploration Charters. All functional checks pass + pre-flight green (or the recordings glob empty) + rubber-duck reconciled or skipped per [`rubber-duck-review.md`](../../references/rubber-duck-review.md) → flip `done` and open the next slice — or, on the last slice, hand off to `/al-code-review` per-feature. A functional fail or a current-slice pre-flight red → flip `blocked` with trigger #8; a prior-slice pre-flight red → flip `blocked` with trigger #4; both route `/al-steer` (*Pre-flight failure routing*, *Functional fail*). Every flip follows the surgical-edit discipline and `review: clean` strip rules in [`task-lifecycle.md`](../../references/task-lifecycle.md).

Read before guiding: [`task-grammar.md`](../../references/task-grammar.md) — the `Verification Plan` grammar, the `Record:` flag, the Closeout shape; [`test-strategy.md`](../../references/testing/test-strategy.md) — layer ownership and the checking-vs-testing frame; [`task-lifecycle.md`](../../references/task-lifecycle.md) — status flips, strip rules, and the replan triggers.

## What gets walked vs replayed

The `Record:` flag decides the runner; its semantics live in [`task-grammar.md`](../../references/task-grammar.md).

| Plan element | Here | Gate |
|---|---|---|
| Journey Example `Record: yes` | **replayed** in the pre-flight batch (spawn #1) | replay green |
| Journey Example `Record: no` | **walked** by the user, card by card, ask-before-reveal | observed value vs `Observable Checks` |
| Contract Example | agent runs the named client/harness, no user involvement | captured output vs `Observable Checks` |
| Exploration Charter | user wanders the prompt, narrates | usability → findings/tasks (never gates) |

## Preconditions

The target task is `kind: verify` at `status: ready-for-verification` with a populated `Verification Plan`.

| State read | Route |
|---|---|
| Branch does not match `^\d{3}-` | **Stop** — a verify task only exists inside an in-flight feature |
| `status: ready` | **Stop**, `Next: /al-refine T-NNN` |
| `ready-for-verification` with an empty `Verification Plan` | **Stop**, `Next: /al-steer T-NNN` — status and proof disagree |
| `status: blocked` | **Stop**, `Next: /al-steer T-NNN` |
| `status: done` | The task is finished; do not reopen it here |
| `review: clean` missing from the verify task's frontmatter | **Stop**, `Next: /al-code-review T-NNN` — the durable per-slice review evidence ([`task-lifecycle.md`](../../references/task-lifecycle.md)) is absent |
| No `event-model.md` alongside the tasks | **Stop**, `Next: /al-steer T-NNN` — verify tasks exist only for user/API-facing features; this is a contract violation |
| A `Record: yes` example without its recording at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` | **Stop**, `Next: /al-page-script T-NNN` |
| `Contract Examples` present but the named client/harness missing or unconfigured | **Stop** — name the exact blocker |
| `Partial-run record:` present in the task body | Resume at example granularity (*Partial walks*) |

- The partial-run record is a `Partial-run record:` labeled block in the verify task's body. Each completed example appends one line: `V#|C#|X# — pass|fail — observed: <verbatim values> — asked: "<questions as posed>"`; fail lines add `expected: <value>` and the evidence path.
- A plan with no `Record: yes` examples — only `Record: no`, `Contract`, or `Exploration` — is valid. The pre-flight batch still runs when `pagescripts/recordings/*.yml` holds any prior slice's recording; skip it only when that glob is empty.
- **A human drives every walkable scope.** `Record: no` Journey Examples and Exploration Charters are user-driven; there is no agent-driven substitute. Contract-only plans have no walk — every check is agent-run against captured client output. Degraded verification never flips `done`.
- **Login is the user's.** Surface the Web Client URL and the throwaway dev credentials ready to paste: `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`). Local container hosts only — never `*.dynamics.com`. User cannot reach the container URL → **Stop**, fix environment, re-enter.

## Container lifecycle

Up to three `new-agent-container.ps1` spawns per cycle — two when `pagescripts/recordings/*.yml` is empty. Fresh-each-time isolates verification from prior state and leaves the next consumer a clean container.

**Spawn #1 (pre-flight).** `new-agent-container.ps1` → `publish-apps.ps1` → `pagescript-replay.ps1` (batch mode, every `pagescripts/recordings/*.yml`) whenever that glob matches any file. The batch runs this slice's recordings plus every prior slice's, so it catches both current-slice regressions and cross-slice collisions before the user is invited in. Green → spawn #2. Red → *Pre-flight failure routing*, then spawn #3 and exit. Glob empty → skip spawn #1, go straight to spawn #2.

**Spawn #2 (contract check + guided walk).** Only on pre-flight green (or the recordings glob empty). `new-agent-container.ps1` → `publish-apps.ps1` → Contract examples (agent-run) → guided walk when walkable scope exists. Hand the user:

- Web Client URL: `http://<container-name>/BC/`
- Credentials per the Preconditions login grant
- Deep link to the starting page: `http://<container-name>/BC/?page=<id>` (page ID read from the page AL)

This handover lives here and only here — spawn #2 recreates the container, so a user invited in earlier gets their session killed mid-walk. Contract-only plan → no handover, no walk; the gate judges captured client output.

**Spawn #3 (exit).** Always runs at end of cycle, pass or fail. `new-agent-container.ps1` only — leaves a fresh container for the next consumer. The skill exits after the spawn returns.

Invocations (`al-build` is a sibling skill in the same plugin; substitute `<this-skill-dir>` with this skill's base directory, announced at skill activation):

- container spawn (any): `pwsh "<this-skill-dir>/../al-build/scripts/new-agent-container.ps1"`
- publish all apps (spawn #1, #2): `pwsh "<this-skill-dir>/../al-build/scripts/publish-apps.ps1"`
- batch replay (spawn #1): `pwsh "<this-skill-dir>/../al-build/scripts/pagescript-replay.ps1"`

## Workflow

### Opener, sized for a human

The opener tells the user what they will do and how long it takes — nothing else. Announce:

- the verify task: `T-NNN` id, slice slug + its `event-model.md` step
- counts by what the user will do: scenarios to walk (`Record: no`), exploration charters, and (run agent-side first) contract examples
- how many `Record: yes` scenarios will be confirmed by replay rather than walked, so the user knows the slice's full coverage
- the estimated walk length (*"3 scenarios, ~5 minutes"*)
- the infra wait before it: container spawns and publish run minutes, not seconds — say so

No URL or credentials yet — that handover happens inside spawn #2. Status stays `ready-for-verification` while guiding. One scenario open at a time.

### Guide the walk — punchline first, ask before revealing

Each `Record: no` Journey Example becomes one card: punchline, Do bullets, then checks one at a time. The **punchline** names the business outcome being checked — without the expected field value, which would lead the witness. The **Do** bullets are the example's `Action`. The next card opens only after this scenario's checks are answered.

> **Scenario 1 of 3 — Releasing a blocked customer's order should be refused.**
> *Open the Web Client (link above) and do these — then I'll ask what you see.*
>
> **Do**
> - Open the Sales Order for the blocked customer
> - Choose **Release**

**Functional checks (gate).** Ask for the observed value before naming the expected one: *"What does the Status field show now?"*, never *"Does Status say Open?"*. Closed enumerable field (an option/enum like `Status`) → `AskUserQuestion` with the field's full value range plus *"Something else — describe"*. Open-ended observables (counts, error text, HTTP bodies) → free-text question. Record observed-vs-expected verbatim from the user's words, checked against the example's `Observable Checks`. Never infer the value from what the AL "should" do. These questions are the ask-before-reveal carve-out in [GROUND-RULES.md](../../references/GROUND-RULES.md); options never reveal the expected value.

**Usability (findings).** For Exploration Charters, give the charter punchline and prompts, then let the user wander and narrate. Classify each remark — functional fail vs usability finding — and confirm the classification in one line so a misfile is catchable.

Mid-walk edges:

- An action whose expected outcome has its checks listed later → wait for the check; the action alone never gates.
- The user reports an unexpected surface (flicker, sudden navigation, wrong page) → ask what screen they're on, re-orient via deep link, re-run the in-flight scenario's remaining checks. Reproducible unexpected navigation is a functional observation — the View state gates; a one-off flicker is a usability finding.

### Pre-flight failure routing (spawn #1 red)

- **Current slice's recording red** — a fragile recording or a regression since its green. Stamp `**Replan flag**: trigger #8 (verification failed)`. `/al-steer` picks: guided re-record via `/al-page-script`, or a `fixes:` task for a real defect.
- **Prior slice's recording red** — the current slice broke a prior user-facing surface. Stamp `**Replan flag**: trigger #4 (sibling now wrong)`. `/al-steer` picks: regenerate the recording via `/al-page-script` (intentional surface change), rewrite the prior `Verification Plan` via `/al-refine` (invalid contract), or a `fixes:` task (unintended regression).
- **Mixed red** — one root cause more often than two. The transcript names every failed recording, both flags stamped, `/al-steer` picks.

Flip `status: blocked`, route `/al-steer T-NNN`, run spawn #3, exit.

### Functional fail: stop the scenario, flip blocked, route

First functional fail in any `Record: no` Journey Example or Contract example, or a functional failure during Exploration: stop — no later checks in the scenario, no later scenarios.

- Walk/Exploration fail → the user saves a screenshot under `.output/verification/T-NNN/` (gitignored; the agent cannot persist a chat-pasted image); the `Partial-run record:` line references that path so `/al-steer` finds it in a later session.
- Contract fail → the captured request/response is the evidence.

Append the fail line to `Partial-run record:` (line shape from *Preconditions*): which example (`V#`, `C#`, or `X#`) and which step/check/prompt, observed vs expected verbatim, the screenshot path, `**Replan flag**: trigger #8 (verification failed)`. Flip `status: blocked` and route `/al-steer T-NNN`. Surface the failure and stop — the fix is `/al-steer`'s to propose. A usability finding is never a functional fail.

### Rubber-duck review before the gate

The gate reviews coverage and routing — it does not re-see the screen. All checkable examples pass → before flipping `done`, consult the rubber-duck agent on the written verdict per [rubber-duck-review.md](../../references/rubber-duck-review.md). Tell the user they're free first — the review can take minutes.

The artifact carries, per scenario/charter:

- the instruction given
- the exact question as posed — verbatim, including any structured-question options offered and any follow-ups asked while triaging a remark
- the user's verbatim reported observation (or captured client output)
- the expected value
- the evidence reference
- usability findings with their classification

Plus the list of `Record: yes` scenarios confirmed by replay, with the pre-flight result. The question goes in as asked — a neutral paraphrase of a led question hides exactly the defect this gate exists to catch.

The review asks:

- was every observable check and prompt asked and answered with an observed value
- were the replay-confirmed scenarios accounted for
- did any pass rest on a led question, a bare yes/no, or an inferred value
- was every user remark routed correctly (functional vs usability)

Reconcile: a real coverage gap → re-ask that check; a real routing gap → re-classify and re-state the verdict.

### Pass: advance per check, flip on the functional gate

The gate flips on the user's own reported observations plus replay-confirmation of the recorded scenarios (Contract-only: captured client output); the user can halt or veto at any step.

- **Check passes** → next check.
- **Last check of a scenario** → append the scenario's line to `Partial-run record:` in the line shape from *Preconditions* — the rubber-duck artifact needs the questions verbatim, and a session boundary erases the chat transcript. Then the next scenario/charter.
- **All checkable examples pass + pre-flight green (or the recordings glob empty) + rubber-duck reconciled or skipped per reference** → flip `status: done` (`phase:` stays as `/al-page-script` left it — `page-scripted`, or `planned` when the plan had no recordings). Collapse `Partial-run record:` into the Closeout shape from [`task-grammar.md`](../../references/task-grammar.md), including the `Record: yes` scenarios as replay-confirmed.
- **Usability findings** → candidate task files in the slice, named `NNN-T-MMM-<slug>.md` with a fresh `T-MMM` id and a run-order prefix per the gap rule in [`task-lifecycle.md`](../../references/task-lifecycle.md), frontmatter `status: ready`, `kind: technical`, same `slice:`. Non-gating; `/grill-me` adjudicates ambiguous ones. They queue after the next slice's opened tasks unless the user promotes one.
- **Next slice** → flip every technical task in the next slice (whose first task carries `depends_on:` this verify task) from `blocked` to `ready`. The cross-slice gate is the only mechanism that opens the next slice.

### Partial walks survive session boundaries

Re-entry resumes at scenario granularity:

- An interrupted session leaves the verify task at `ready-for-verification` with the incrementally appended `Partial-run record:` inline.
- Completed walk scenarios stay closed — their verdicts stand on the record.
- The in-flight scenario restarts from its first action. Re-entry spawns fresh containers, so the data its earlier actions created is gone; re-ask only that scenario's checks.
- Closed scenarios whose data the in-flight one depends on: re-drive their *actions* as setup without re-asking their checks.
- Contract examples re-run on every spawn #2; the recording batch re-runs in spawn #1. Only walk scenarios stay closed.

## Gate event

Emit the task-close gate report once, when the verify task flips `done` — the verify-task variant (Did / Was / Fits / Next) homed in [GROUND-RULES.md](../../references/GROUND-RULES.md) § House shapes. This skill's payload, in BC vocabulary:

- what the user confirmed by walking, and what the `Record: yes` scenarios confirmed by replay
- the usability findings surfaced (→ candidate tasks)
- the evidence — transcript, replay result, saved screenshots
- the rubber-duck outcome (reconciled / skipped)
- the handoff per *Next step*

On failure (flip to `blocked`): one stop line naming scenario / check / observed-vs-expected, a state table (verify task id, scenarios completed, scenario blocked on), next action `/al-steer T-NNN`.

## Next step

End by naming the concrete next move, read off current state — naming it never auto-invokes it. The status flips and same-feature `blocked` → `ready` opens above are state writes this skill owns inline.

- **Verify pass, next slice opened** (its technical tasks flipped `ready`) → `Next: /al-refine T-NNN` on the next slice's first task.
- **Verify pass, last slice** → `Next: /al-code-review` per-feature (its clean pass opens the `kind: breaking-change` task → `/al-validate-breaking-changes`).
- **Functional fail or pre-flight red** (verify task `blocked`) → `Next: /al-steer T-NNN`.

State can't be read → **Stop.** The verify task's state is unreadable — any route named from it would be a guess. `Next: /al-steer`.

## Composition

| | |
|---|---|
| **Invoked by**     | user. Suggested by `/al-page-script` (batch pre-flight green, recordings committed — or a plan with no `Record: yes` examples); `/al-steer` (state-read routing on a `ready-for-verification` verify task whose recordings are in place) |
| **Runs after**     | `/al-page-script` recorded every `Record: yes` Journey Example, and `/al-code-review` per-slice stamped `review: clean` at slice-done (preserved through refine) |
| **Hands off to**   | next slice's technical tasks opened to `ready` for `/al-refine`; or — if last slice — `/al-code-review` per-feature → its clean pass opens the `kind: breaking-change` task → `/al-validate-breaking-changes`. `/al-steer` on failure (after `status: blocked`). Usability findings → candidate tasks in the slice. |
| **Uses**           | `new-agent-container.ps1` (up to three spawns per cycle), `publish-apps.ps1` (spawn #1, #2), `pagescript-replay.ps1` (spawn #1's batch pre-flight), Web Client deep links + `al-build.json` credentials, the rubber-duck agent ([rubber-duck-review.md](../../references/rubber-duck-review.md)), [`../../references/task-grammar.md`](../../references/task-grammar.md) (`Verification Plan` grammar, `Record:` flag, Closeout), [`../../references/testing/test-strategy.md`](../../references/testing/test-strategy.md) (layers + checking-vs-testing), [`../../references/task-lifecycle.md`](../../references/task-lifecycle.md) (status flips, strip rules, replan triggers, gap rule) |
| **Replan venue**   | `/al-steer` — trigger #4 (pre-flight prior-slice red), trigger #8 (pre-flight current-slice red or functional fail) |
| **Spawns**         | `al-researcher` for BC surface behaviour to verify against authoritative evidence |
| **Sidebands**      | `/grill-me` (adjudicate an ambiguous usability finding, or whether an observation matches the expected outcome) |
