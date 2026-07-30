# bc-replay recordings — gestures to coach, YAML to read

Two jobs: coach the user through a repeatable recording, and read the `.yml` when a replay reds.

**No official schema exists.** The format was reverse-engineered from the BC web-client bundle on v28 and validated by replay, stable across `28.1.x`. A platform version bump alone is not a reason to re-derive. Re-derive only when a replay red is a grammar *shape* mismatch — a nesting or step type the player rejects — never a missing control or a dialog.

---

## The recorder, end to end

1. Web Client → **Settings ⚙ → Page Scripting**. The pane opens on the right.
2. **Record** on the control bar, then perform the scenario's gestures. The recorder captures each step live.
3. Assertions and value captures go in via right-click → **Page Scripting** (table below).
4. **Save** → the `.yml` downloads. On an HTTP container the browser leaves it as `Unconfirmed <name>.crdownload` — the bytes are complete; copy it out of Downloads and hand back the path.
5. Replay on a fresh container. Green seals the scenario; red is classified below.

The recording user needs the **`PAGESCRIPTING - REC`** permission set; the container's `admin`/SUPER user carries it. (`PAGESCRIPTING - PLAY` covers replay.)

## Repeatability rules — coach one per card, before recording

A recording guards regressions only if it greens on clean data every time. The recorder captures *gestures*, so how the user performs the scenario decides whether it re-runs. Each rule is the gesture that replaces the brittle thing.

- **No. Series — let it auto-assign.** Leave the No. blank; the series fills it and replay assigns a fresh one each run. A typed `C00010` collides on the second replay (`already exists`).
- **Need a value later? Capture it.** Right-click the source control → **Page Scripting → Copy**; at the target → **Paste**, or → **Validate → is equal to clipboard entry**. This is how "create an order, then find *that* order" stays repeatable.
- **Anchor a just-created row by value, never by position.** A new row inserts *above* the current row, and "click row 3" drifts with demo data — the *Anchoring a just-created row* section holds the two gestures.
- **Validate the stored field, not the rounded display.** Two fields linked by a conversion round on the stored side (a typed `80` reads back `79.99999`) and Validate has no tolerance. Validate the canonical field, or pick values that round-trip exactly (markup `100` ↔ margin `50`).
- **Uniqueness comes from Power Fx, not a magic string.** Where a field genuinely needs a unique value, set a Power Fx expression via the step's **… → Properties** (`"Customer " & Today()`). Power Fx is for real expressions, not for faking uniqueness a No. Series should own.
- **One written grid row per page visit.** A pending row commits on row-leave; a second new-row gesture before leaving silently discards the first. Add one row → leave and re-open → add the next. Reading a cell straight after typing it reads the blank placeholder.
- **Start self-contained, from the Role Center.** Replay starts from a fresh session, so a recording captured mid-flow reds with `Unexpected page`. Begin at the role center or a deep link and navigate in.
- **Answer the dialogs the scenario triggers.** Click through a Confirm or an `Error()` *during recording* so the answer is captured. An unanswered dialog hangs replay. An *unexpected* dialog is a finding, not a gesture.

## Observable Check → recorder gesture

| Check shape | Gesture |
|---|---|
| A field equals a value | right-click control → **Page Scripting → Validate → Current Value** |
| A field equals a captured value | **Validate → is equal to clipboard entry**, after a Copy |
| A value reused downstream | **Copy** the source, **Paste** into the target |
| "Only when there are no rows…" | right-click column → **Add conditional steps when → Row count → is 0** |
| A `Message()` toast appeared | trigger it during recording; the recorder captures the assertion |
| A unique or derived input | **… → Properties** on the step → Power Fx expression |

## What stays out of a recording

Look-and-feel, error-message tone, and accessibility encode in no assertion — they belong in a Usability Review. A recording that doubles a test a lower AL layer already runs is waste; the `Record:` flag was assigned at scope time and the walk honours it.

---

## Envelope

```yaml
name: Smoke - new item validates No.   # display name; defaults to "Recording"
description: ...                       # REQUIRED — a recording without it is rejected
telemetryId: e8f45a3f-...              # recorder-generated GUID
start:
  profile: ORDER PROCESSOR             # only `profile` is read; set as the ?profile= start param
parameters: { ... }
timeout: 120                           # SECONDS
test: { skip: "flaky on CI" }          # optional passthrough: fail | fixme | skip
steps: [ ... ]                         # REQUIRED
```

`description` and `steps` are the only hard requirements. `log:` is engine-appended on replay (`start`, `duration`, `video`, per-step `error`) — never author it.

## The `target:` locator

A `target:` — and the `source:` on `page-shown` / `page-closed` / `copy-*` — is an **ordered list** walking from a page down to a control:

```yaml
target:
  - page: Sales Order          # first element, carries runtimeRef
    runtimeRef: b1s6
  - part: SalesLines           # optional page part…
  - page: Sales Order Subform  # …and its own page name
  - repeater: Control1         # optional repeater, by control name
  - field: Description         # the leaf
```

Leaf kinds are `field:` (a control) and `action:` (an action). Special page forms: `page: lookup:<Field>` for a drilldown lookup page, and a role-center action as `page: <X> Role Center` + `action: <name>`.

**Targets bind to the AL control name, not the display caption** — `field: Profit %` binds a column captioned *Margin %*. Captions land in `description:` only. `Field '<name>' was not found.` means the named control isn't rendered at replay, usually because the surface moved. Confirm the control name from the page AL, or re-record.

## `runtimeId` / `runtimeRef`

File-local correlation tokens, not server control IDs. A `page-shown` mints `runtimeId: <tok>`; every later step acting on that open page carries `runtimeRef: <tok>`. They need only be internally consistent. A `runtimeRef` with no matching `page-shown` is a correlation break; never renumber a token without updating every reference.

## Step types

19 top-level `type:` values. Three are containers carrying nested `steps:` — `scope`, `for-each`, `include`. `navigate` / `invoke` / `input` / `focus` / `validate` / `close-page` are actions; `page-shown` / `page-closed` are observed results the recorder emits paired with them.

```yaml
- type: navigate          # open a page
  target: [ { page: Item List } ]
- type: page-shown        # observed; mints runtimeId
  source: { page: Item List }
  modal: false            # true for drilldowns, RunModal pages, dialogs
  runtimeId: b71
- type: focus
  target: [ {page, runtimeRef}, {field: No.} ]
- type: input
  target: [ {page, runtimeRef}, {field: Template} ]
  value: false            # literal, or =PowerFx. `=""` is empty string
- type: invoke            # action, lookup, drilldown, row-select
  target: [ {page, runtimeRef}, {action: Control_New} ]
  invokeType: New         # SystemAction enum NAME
  silent: true            # optional: suppress the expected page/dialog
  parameters: {}          # a repeater row-select: { AlwaysCommit: true }, and no invokeType
- type: close-page
  target: [ {page, runtimeRef} ]
- type: page-closed
  source: { page: Item List }
  runtimeId: b71
- type: wait
  time: 1000              # MILLISECONDS
- type: validate          # assert a control value
  target: [ {page, runtimeRef}, {field: No.} ]
  operation: "<>"         # default `=` when omitted
  value: ""
```

`invokeType` is the platform `SystemAction` enum member name: `New`, `Edit`, `DrillDown`, `Lookup`, `Refresh`, `RunReport`, `CloseOk`, `Cancel`, `Yes`, `No`, `SortColumn`, `FilterByColumn`. Opening a card from a list row is `invokeType: Edit` with `parameters: { AlwaysCommit: false }`.

Containers and the richer steps:

```yaml
- type: scope             # nested steps run only if the condition holds; omit condition to group
  condition: { ... }
  steps: [ ... ]
- type: for-each          # once per repeater row; a variant iterates the selection
  target: [ {page, runtimeRef}, {repeater: Control1} ]
  steps: [ ... ]
- type: include
  name: setup
  file: ./includes/setup.yml     # relative to THIS file's directory, recursive, cycles rejected
- type: set-current-row   # RELATIVE-ONLY; can silently fail to move
  target: [ {page, runtimeRef}, {repeater: Control1} ]
  targetRecord: { relative: 1 }
- type: copy-value        # to the page-scripting clipboard
  source: [ {page, runtimeRef}, {repeater: Control1}, {field: Description} ]
  name: Item List - Description  # later read as Clipboard.'Item List - Description'
  valueType: string
- type: copy-rows
  source: [ {page, runtimeRef}, {repeater: Control1} ]
  name: Items
  scope: current          # current | all
- type: message           # ASSERT a Message() toast — assert-only, never invoked
  automationId: ...
  text: ...               # optional; automationId alone replays green
- type: autofill
  action: invoke          # invoke | accept | reject | change
  target: [ {page, runtimeRef}, {field: ...} ]
- type: filter            # recorder filter-pane artifact — author filters via the composition below
- type: run-prompt        # Copilot prompt; SaaS tenants only. Outputs land in Variables.
```

## Dialogs

Message = assert via `message`, never invoked. Confirm = `invoke invokeType: Yes` or `No`. Error = catch with `page-shown`, dismiss with `invoke invokeType: Ok`.

An `Error()` dialog is a composition, not a step type:

```yaml
- type: page-shown            # the catch — MUST immediately follow the triggering step
  source:
    page: null
    automationId: 00000000-0000-0000-0800-0000836bd2d2   # platform Error-dialog id
    caption: Error            # documentation only; the matcher ignores caption
  modal: true
  runtimeId: b4e
- type: invoke
  target: [ { page: null, automationId: 00000000-0000-0000-0800-0000836bd2d2, runtimeRef: b4e } ]
  invokeType: Ok
- type: page-closed
  source: { page: null }
  runtimeId: b4e
```

An uncaught dialog reds with `Invalid state: Unexpected error dialog.` on the first later step carrying a foreign `runtimeRef`. `page-shown` is the only exempt step type, so it is the only catcher. Anonymous-dialog matching reads `automationId` or `runtimeRef` and ignores `caption:`; with neither, `No page found`. Confirm/Message's `8da61efd-…` id does **not** match Error's.

Error text is not assertable — the caption is the literal `Error` and there is no `contains` operator.

Converting a `message` step into the Confirm pattern reds with `No page found … but no form was found`: a Confirm blocks for an answer, a Message is never answered.

## Column filter

`FilterByColumn` plus the Apply Filter dialog, recorder-verbatim:

```yaml
- type: invoke
  target:
    - page: Item List
      runtimeRef: pg1
    - repeater: Control1
    - field: No.
  invokeType: FilterByColumn
  parameters: { UseAdvancedFiltering: true }
- type: page-shown
  source:
    page: null
    automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7   # platform Apply-Filter dialog id
  modal: true
  runtimeId: flt1
- type: input
  target: [ { page: null, automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7, runtimeRef: flt1 }, { field: No. } ]
  value: "1000"
- type: invoke                # the dialog's OK — leaf is `action: null`, NO invokeType
  target: [ { page: null, automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7, runtimeRef: flt1 }, { action: null } ]
- type: page-closed
  source: { page: null }
  runtimeId: flt1
```

Never author a filter as a `part: null` / `page: null` / `{scope: filter}` spacer chain — that reds `Part 'null' was not found.` These three anonymous-dialog ids are platform-generated: stable within a platform version, re-harvest on a BC bump if one reds as a reference mismatch.

## Editable-grid new-row lifecycle

- A new row with a typed value commits on **row-leave** — clicking another row, or `close-page`.
- Leaving a pending row via a second `invoke action: Control_New` **discards** the buffer: no error, the row never inserts, downstream `validate`s read fewer rows than authored.
- A grid `input` advances the cursor onto the trailing blank placeholder, so an immediate `validate` reads the placeholder (`Was expecting '37.5' but got '0'`). Re-open the page or re-anchor first.
- A new row inserts **above** the current row (AutoSplitKey midpoint), never at the bottom.

## Anchoring a just-created row

Row selection is never serialized — the recorder emits no step for clicking a row. Under replay `set-current-row` is relative-only and can silently fail to move, leaving the cursor on the prior row while the `validate` reads the wrong record, with no error. Positional walks are safe only when every row asserts the same expected value (the `for-each` pattern). For a distinguishing read, anchor by value:

- **SortColumn toggle** — `invoke invokeType: SortColumn` on the No. column with `parameters: { sortOrder: 1 }` then `sortOrder: 2` forces a re-sort ending descending, cursor on the highest No. Works only because a No. Series sorts monotonic-ascending; any other sort key silently anchors the wrong row.
- **Column-filter pin** — the composition above, with a `copy-value`-captured No. as the filter value. Exact row, sort-independent.

## Operators, conditions, Power Fx

The operator enum is complete: `=` (default when omitted), `<>`, `>`, `>=`, `<`, `<=`, and `isTrue` (the value is treated as a Power Fx expression). There is **no** `contains` or `startsWith`.

A `scope.condition` takes one of three shapes:

```yaml
condition: { type: value, target: [...], operation: "=", value: Bicycle }
condition: { type: page-shown, source: { page: Confirm }, runtimeId: c1 }   # "optional page"
condition: { type: powerFx, expression: <expr> }
```

Any `value:`, `time:`, or condition is a literal unless prefixed with `=`, which makes it Power Fx. Namespaces: `Parameters.` (the `parameters:` block), `Session.`, `Clipboard.` (`copy-*` keys), `Variables.` (`run-prompt` outputs). Single-quote any name containing spaces or dots. `Today()`, `&`, `+`, and the comparison set are demonstrated.

The `parameters:` block keys are the parameter names; each carries `type: string`, an optional `default:` used at replay, and a `description:` shown when unset. An unset parameter prompts at replay. To pass a value into an `include`, define the parameter in both files.

## Locator shapes by page kind

The vocabulary is page-type-agnostic; the page kind changes which elements appear, not the grammar.

| Page kind | Shape (leaf in **bold**) |
|---|---|
| List, Journal, Worksheet | `page` → `repeater` → **`field`** |
| Card | `page` → **`field`** — FastTab grouping is not in the path |
| Document with lines subpage | `page` → `part` → `page`(subform) → `repeater` → **`field`** |
| FactBox | `page` → `part` → `page`(factbox) → **`field`** |
| Action | `page` → **`action: <ControlName>`** — `Control_New`, `Action37`, `Post`; promotion is UI-only |
| Lookup / peek | `source.page: lookup:<Field>` or `peek:<Field>` |
| Request page (report) | not `page:`-navigable — `invoke invokeType: RunReport` on the report action → `page-shown` (`modal: true`) → `invoke invokeType: Cancel` |
| Analysis / Query page | open via a list or role-center action; close with `invoke invokeType: CloseOk` |
| Confirm / Error / Apply Filter | `page: null` + `automationId` (`modal: true`) — see *Dialogs*, *Column filter* |
| Role Center | navigate via `page: <X> Role Center` + `action:`; a cue drilldown nests through `part` → `page` → `action` |
| Wizard (NavigatePage) | `page-shown` (`modal: true`), then `invoke action: ActionBack`/`ActionNext`/`ActionFinish`, which swap content in place with no per-step `page-shown` |

**Show more / Show less and FastTab expand-collapse are not recorded** — they are client-side density toggles and produce zero steps. They need not be: the player resolves controls through the logical page model, not the rendered DOM, so a Show-less-hidden field is still reachable by name. Never try to author a Show-more step.

---

## Reading a failure

A failing replay exits non-zero, but classify from the artifacts, never the exit code or console alone. They split across two locations:

- The **`results`** folder under `pagescripts` (cleaned per run) holds `results.xml` (JUnit) and `playwright-report/` — open it with `npx playwright show-report`.
- **`test-results/dist-player--<hash>-<recording>-yml--chromium/`**, also under `pagescripts`, holds the diagnosis artifacts, written on failure only:
  - `error-context.md` — an accessibility snapshot of the *frozen surface* at failure. An unexpected dialog is visible here. A hang with no error string is almost always a platform Confirm sitting open (`RecordChangeDialog`: "Your change might update related records…", default focus No).
  - `replay-log.yml` and `attachments/Replay-log-<hash>.yml` — the full step list with engine-appended `log:` blocks; the failing step carries an inline `error:` node, e.g. `error: { type: reference, message: "Field 'X' was not found.", target: [...] }`.
  - `video.webm` — the run.

With retries enabled, `error-context.md` freezes the *last* attempt while `replay-log.yml` carries the failing step; the replay-log `error:` node is authoritative for which step failed.

An `error:` node is a locator, shape, or missing-control problem. A timeout with an open dialog in `error-context.md` is the unexpected-dialog case.

`Unexpected page. Was expecting '<X>' but got '<role center>'` means the recording is not self-contained — it assumed a page was already open. That is a re-record from the role center, not an edit.

A `timeout: 600`-only green is a smell, not a tuning need. The default per-test cap is 120 seconds; a scenario needing more usually has an unanswered dialog eating the clock, or is too long and wants splitting.

## Scoping a surgical edit

- Keep the token invariant: never renumber a `runtimeId` without updating every `runtimeRef`.
- `copy-*` take `source:`; everything else takes `target:`. Containers nest through `steps:`.
- The interpreter is server-side and version-bound, so a surgical edit is done when it replays green on a fresh container — not when it reads correctly.

## Isolating a red

A red buried in a long recording masks its cause, and every full replay costs minutes. Drop `timeout:` low so a hang fails fast, reduce to a minimal repro, then name the cause.
