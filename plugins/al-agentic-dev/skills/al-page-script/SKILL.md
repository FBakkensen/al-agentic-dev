---
name: al-page-script
allowed-tools: ["execute", "read"]
description: Guide the user to record the slice's framework-limited E2E Journey Examples in BC's Page Scripting recorder — one scenario at a time in chat, punchline-first. The user records and downloads the `.yml`; the agent replays each on a fresh container and classifies reds. Recordings are reserved for behaviour no AL test layer can automate (generation-time push-down). Prerequisite to `/al-user-verification`.
---

# /al-page-script — Guide the user to record a slice's bc-replay recordings

Reads the verify task's `Verification Plan` Journey Examples marked `Record: yes` from its file under `tasks/`. Guides the user — one scenario at a time, in chat, punchline first — to record each in BC's built-in **Page Scripting (Preview)** recorder.

The user performs the gestures, validates the outcomes, downloads the `.yml`, and hands back the path. The agent replays it on a fresh container and classifies any red. Green opens the next scenario.

**The recorder is the generator — the agent never authors `.yml`.** The bc-replay YAML format is reverse-engineered and undocumented; the recorder is the intended producer. The agent coaches the recording and reads the replay.

One carve-out: a surgical, approval-gated edit to an existing recorder-produced file (bump a `wait`, fix one `operation:`, add a missed Validate) when that is plainly the shortest path to green — ask, edit, replay. Everything else routes back to a guided re-record.

This is the E2E apex of the test pyramid. A Journey Example records only when `/al-refine` marked it `Record: yes` — the framework-limited call, per [`test-strategy.md`](../../references/testing/test-strategy.md)'s generation-time push-down; most slices get zero. The `Verification Plan` grammar and the `Record:` flag live in [`test-specification.md`](../../references/testing/test-specification.md).

The oracle is bc-replay's equality/visibility checks and is oracle-limited: a recording can pass against broken code the platform absorbs. A red never gets faked green (*Failure classification*).

Two skill-local references: [`references/recorder-gestures.md`](references/recorder-gestures.md) — the gestures the agent coaches per card, and the repeatability rules; [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md) — the YAML format, read to classify a replay red or scope a surgical edit.

## Preconditions

The target task is `kind: verify` at `status: ready-for-verification`, with a populated `Verification Plan` containing at least one Journey Example marked `Record: yes`.

| State read | Route |
|---|---|
| Branch does not match `^\d{3}-` | **Stop** — a verify task only exists inside an in-flight feature |
| Task is not `kind: verify` | **Stop**, `Next: /al-steer T-NNN` |
| `status: ready` | **Stop**, `Next: /al-refine T-NNN` |
| `ready-for-verification` with an empty `Verification Plan` | **Stop**, `Next: /al-steer T-NNN` — status and proof disagree |
| No `Record: yes` Journey Example (all `Record: no`, `Contract`, or `Exploration`) | **Stop**, `Next: /al-user-verification T-NNN` — this slice needs no recording |
| `status: blocked` | **Stop**, `Next: /al-steer T-NNN` |
| `status: done` | The task is finished; do not regenerate its recordings here |
| `review: clean` missing from the verify task's frontmatter | **Stop**, `Next: /al-code-review T-NNN` — `review: clean` is the durable per-slice review evidence; page-script is a verification pre-flight, not the code-review gate |
| Recordings already exist at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` for every `Record: yes` example | **Stop**, `Next: /al-user-verification T-NNN` — regeneration is a replan call (route via `/al-steer`); silently overwriting loses the replay-proven state the pre-flight depends on |
| A partial set (some scenarios recorded, some not) | Resume at the first un-recorded `Record: yes` example |

- The recording user needs the **`PAGESCRIPTING - REC`** permission set (Microsoft Learn); the container's `admin`/SUPER user carries it. If a restricted user reds the recorder at start, surface the exact permission and re-enter. (`PAGESCRIPTING - PLAY` covers replay and already works.)
- Login is the user's. Hand the Web Client URL and the throwaway dev credentials ready to paste: `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`) — user-authorized, non-secret. Local container hosts only (`http://<container>/BC/`), never `*.dynamics.com` or any non-local host. If the user cannot reach the handed URL, **Stop**: confirm the container is up (if not, re-spawn via `new-agent-container.ps1` then publish via `publish-apps.ps1`) and that the user's machine resolves the container hostname; then resume.

## Output path

`pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` — one file per recorded scenario. Flat folder at repo root; `<NNN>` matches the spec folder number, `<slug>` the feature slug, `<slice>` the verify task's `slice:` value, `NN` the Journey Example's order within the slice (`01`, `02`, …). Double underscore between feature slug and slice slug, and before the scenario number. `pagescript-replay.ps1`'s batch glob is `pagescripts/recordings/*.yml`; every per-scenario file joins it automatically.

## The recording session

### Opener, sized for a human

Announce the verify task: `T-NNN` id, slice slug + its `event-model.md` step, the count of `Record: yes` scenarios and a rough time, plus the infra wait before it — container spawn and publish run minutes, not seconds; say so, so the user isn't poised over a URL that hasn't arrived. Then spawn, publish, and hand the user the entry (URL + credentials + deep link).

### Container choreography

One container exists at a time: `new-agent-container.ps1` destroys and recreates the branch-named agent container from the snapshot, so every spawn is clean state. The rhythm per scenario:

1. **Record** on whatever container is up — the one the prior replay left running. Recording captures gestures, so its accumulated data does not matter.
2. **Replay on clean state.** When the user pastes the downloaded `.yml`, spawn fresh (`new-agent-container.ps1` → `publish-apps.ps1`) — wiping the records the user just made — then replay (`pagescript-replay.ps1 -File`). That clean-state replay is the **repeatability gate**: a recording that hardcoded a value or picked a row positionally reds here and gets re-recorded. `pagescript-replay.ps1` only spawns when the container is unhealthy, so the fresh spawn must precede it.
3. **Batch pre-flight.** After the final scenario greens, spawn fresh once more and batch-replay this slice's recordings plus every prior slice's (`pagescript-replay.ps1`, no `-File`) — catches cross-file collisions before commit.

Invocations (`al-build` is a sibling skill in the same plugin; substitute `<this-skill-dir>` with this skill's base directory, announced at skill activation):

- spawn fresh container: `pwsh "<this-skill-dir>/../al-build/scripts/new-agent-container.ps1"`
- publish all apps: `pwsh "<this-skill-dir>/../al-build/scripts/publish-apps.ps1"`
- replay one file: `pwsh "<this-skill-dir>/../al-build/scripts/pagescript-replay.ps1" -File pagescripts/recordings/<…>__NN.yml`
- batch replay: `pwsh "<this-skill-dir>/../al-build/scripts/pagescript-replay.ps1"` (no `-File`)

### Per-scenario card

Each `Record: yes` Journey Example becomes one card — punchline first, then the actions and validations the user performs, then a recording-coaching tip. One card at a time; the next opens only after this scenario replays green.

> **Scenario 1 of 2 — A posted sales order locks its lines.**
> *Recorder on (Settings ⚙ → Page Scripting). Do these, then Save → download the `.yml` and paste me the path.*
>
> **Do**
> - Open **Sales Orders** → **New** → pick a customer → add one line
> - **Post** → **Ship and Invoice**
>
> **Check** (right-click the control → *Page Scripting → Validate*)
> - **Status** *is* `Released`
> - The posted line is locked (read-only)
>
> *Recording tip: let the No. auto-assign — don't type one. (More in recorder-gestures.)*
>
> → Download, paste me the path. I'll replay it on a fresh container.

The **Do** bullets are the example's `Action`; the **Check** bullets are its `Observable Checks`, each phrased as the recorder gesture that asserts it. The tip carries the one repeatability rule that scenario most needs ([`recorder-gestures.md`](references/recorder-gestures.md)) — stated before the user records, so the recording is born repeatable rather than patched after.

### Replay and seal

Read the replay artifacts, never the exit code alone: a red writes `error-context.md` (an ARIA snapshot of the frozen surface — where an unexpected dialog is visible) and `replay-log.yml` (the failing step carries an inline `error:` node) — locations and reading order in [`bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md), *Reading a failure*. Green → the scenario seals; move the `.yml` to its committed path and advance to the next card. Red → *Failure classification*.

Batch-green → commit every per-scenario file. Batch-red names which `.yml` collided → classify (typically a bad recording — the new scenario seeds a record a prior recording assumed absent; re-record it to use the No. Series). If a prior `.yml` reds because a control it targets no longer exists — the surface legitimately moved — that is a `/al-steer` decision (regenerate or quarantine), not this skill's.

## Failure classification

A replay red is a question: is the recording wrong, or is the system? Isolate before you debug — a red buried in a long recording masks its cause, and every full replay costs minutes. Reduce it to a minimal repro (drop `timeout:` low so a hang fails fast), name the cause, then act.

Page-script diagnoses and routes — it does not edit production, create tasks, or flip status. Three outcomes:

- **Bad recording → re-record in-loop (the default fix).** The recording is brittle or wrong: it hardcoded a No. that collided on fresh replay, picked a row positionally, forgot to answer a dialog it triggered, or asserted the displayed field instead of the stored one. Diagnose in chat and coach a re-record from the repeatability rules in [`recorder-gestures.md`](references/recorder-gestures.md) — *"sort newest-first before picking the row"*, *"let the No. auto-assign"*.

  When the fix is a single well-understood transform on the existing file, the surgical-edit carve-out applies. Re-recording a 30-step scenario to add one assertion is waste, not discipline.

- **Real production bug → route `/al-steer`.** The recording is valid and replays the real behaviour, but the asserted behaviour is wrong: Status flips wrong, the Business Event doesn't fire, the factbox doesn't refresh. A lower layer could pin it — status unchanged, `Route: /al-steer T-NNN`.

  `/al-steer` opens the integration fix task and strips `review: clean`. `/al-implement` drives the fix red-first, and the slice owes a re-review (`/al-code-review`) before sign-off. This recording re-greens once the fix lands.

  An *unexpected* platform dialog is this case when an AL pattern triggers it. An *expected* dialog the recording forgot to answer is a bad recording — re-record to answer it.

- **Oracle-blind or unscriptable → route `/al-steer`.** Oracle-blind: the recording's green is a false green — it passes against code you know is broken. bc-replay re-reads the bound `Rec` exactly as a TestPage does, so its oracle is blind to that fault class — delete or quarantine the recording and pin the fault where an oracle can see it; never trust the green.

  Unscriptable: the check asks for a judgment no assertion encodes — look-and-feel, error-message tone, accessibility.

  Status unchanged, `Route: /al-steer T-NNN`. `/al-steer` decides whether the example reopens for `/al-refine` or becomes an `Exploration Charter` for `/al-user-verification`.

## Gate event

Once, when the slice's recordings land committed. The verify task's `status:` stays `ready-for-verification` and keeps `review: clean` — the commit adds recordings and no production AL, so the per-slice review still vouches for the slice diff. `phase: page-scripted` is stamped on its frontmatter (overwrite `phase: planned`), the durable record that the recording batch finished.

The gate report names the slice (slug + `event-model.md` step), the count of scenarios recorded, the user surface each exercises (Page action), and `Next: /al-user-verification T-NNN`. A routing failure stops with one line naming scenario / step / observed-vs-expected, a state table (verify task id, scenarios recorded, scenario blocked on), and the next action.

**Advisor checkpoint.** Final check on the recordings as they will be committed — the batch-pre-flight-green set, not a mid-fight draft a re-record superseded. Each recording joins every future slice's pre-flight; a fragile or wrongly-asserting one multiplies false-red across the feature.

## Next step

End by naming the concrete next move, read off current state:

- **Batch pre-flight green, recordings committed** → `Next: /al-user-verification T-NNN`.
- **Production-bug or oracle-blind/unscriptable red** → `Next: /al-steer T-NNN` (*Failure classification*).
- **Bad recording** → re-record in-loop; resume at the failing scenario.

If state can't be read, fall back to `/al-user-verification T-NNN`.

## Composition

| | |
|---|---|
| **Invoked by**     | user. Suggested by `/al-refine` (after writing a `Verification Plan` with `Record: yes` examples and no recordings yet) or `/al-code-review` per-slice on a re-review (verify task already `ready-for-verification`, plan intact); `/al-steer` (state-read routing on a `review: clean` verify task with un-recorded `Record: yes` examples) |
| **Runs after**     | `/al-refine` filled the `Verification Plan` and marked the framework-limited examples `Record: yes`; `/al-code-review` per-slice stamped `review: clean` at slice-done (preserved through refine) |
| **Hands off to**   | `/al-user-verification` on green — every `Record: yes` scenario recorded, batch pre-flight green. `/al-steer` on a production-bug or oracle-blind/unscriptable red (*Failure classification*). |
| **Uses**           | `new-agent-container.ps1`, `publish-apps.ps1`, `pagescript-replay.ps1` (*Container choreography*), BC's Page Scripting recorder driven by the user, Web Client deep links + `al-build.json` credentials, [`references/recorder-gestures.md`](references/recorder-gestures.md), [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md), [`../../references/testing/test-specification.md`](../../references/testing/test-specification.md), [`../../references/testing/test-strategy.md`](../../references/testing/test-strategy.md) |
| **Replan venue**   | `/al-steer` — both red routes land here, status unchanged; mechanics in *Failure classification* |
| **Sidebands**      | `/al-research` (BC surface behaviour an example asserts), `/grill-me` (intent on an example step the user must adjudicate) |
