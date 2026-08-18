# Task Description body

A pipeline task is an Azure DevOps work item; its fields, tags, states, links, and `Task:` title prefix are `/al-routing`'s schema. The Title names the behaviour; a verify task uses `Task: Verify <slice outcome>`. The Description opens with a human overview paragraph, then a `<details>` fold-out whose summary is `Test Specification` or `Verification Plan` holds the agent body on that same item — never a comment fallback, never a markdown file, never a canvas copy. `/al-refine` writes the body — a `Test Specification` on an `al-technical` task, a `Verification Plan` on an `al-verify` task — and later skills read it and edit named body fields. Ops tasks (`al-provision`, `al-breaking-change`) stop at the description paragraph; their run results live in the work item's comment log, not the body.

Skills parse these shapes, so field names and structure are exact.

## Shape rules

1. The body opens with the bare labeled line `Test Specification:` or `Verification Plan:`. Sections under it are `##`; cases and examples inside a section are `###`.
2. A section is a `##` heading when it holds entries another section or skill references by ID or by name. Everything else is a bare labeled line.
3. A block runs from its labeled line to the next column-0 line that is a `## ` or `### ` heading or a `<Label>:` line. Bullets open with `-` and table rows with `|`, so neither closes a block.
4. Sections appear in the order the table below declares.
5. A case header carries the handle other sections reference: the AL test procedure name in `AAA Cases`, which `Covered By` cells name; the ID plus a short name in the verify sections, which the walk's `🚶 Walk:` comments name.
6. Inside a case, `Scope:` comes first, then the remaining scalar fields, then the bullet blocks in execution order.
7. `; ` separates multiple values in a field. Rationale that needs writing down lands in `Contract notes:`, never as an inline comment. A `Contract notes:` bullet is one sentence — a decision, a grounded fact, a push-up justification, or an accepted-survivor ruling; what happened during a run belongs in the commit message, never here.
8. A `Contract notes:` bullet carries a glyphed lede naming its kind, the emoji between the dash and the lede so the lede stays greppable: `- 🔎 Researched:` a grounding citation, `- 🏛️ Precedent:` a `.bcapps/` verdict, `- ⬆️ Push-up` a layer justification, `- ✅ Accepted:` a survivor ruling. A bullet of no listed kind stays plain; an emoji outside these slots stays out.

## Section order

| Section | Kind | Present when |
|---|---|---|
| `## New and Modified Objects` | technical | always — the `New and Modified Objects: none` labeled line counts |
| `Contract notes:` | both | the task carries proof decisions the coverage tables cannot hold |
| `## Expected Behaviors` **or** `## Decision Matrix` | technical | always — exactly one |
| `## AAA Cases` | technical | always |
| `Deviations:` | technical | implementation absorbed an assumption inline |
| `## Journey Examples` | verify | the slice is BC Web Client-facing |
| `## Contract Examples` | verify | the slice is API or external-client-facing |
| `## Usability Review` | verify | optional; earned by new workflows, changed workflows, and error-guidance changes |

Walk results — partial-run lines, closeout lines, waivers, absorptions — live in the work item's `🚶 Walk:` and closing comments, never in the body; `/al-user-verification` and `/al-routing` own their wording.

## Sections that carry structure

**`## New and Modified Objects`** — the production AL surface the task lands, at signature level, bodies omitted. One object per landing line with a `New:` or `Modified:` lede; `New:` means the object is absent from the workspace at this task's start, `Modified:` means present, including an object an earlier task in the same feature landed. Procedures carry the full signature, visibility, and one tag: `— P` pure (decided from parameters alone) or `— S` side-effecting (touches the database or any external state, reads included). Fields carry their AL type; events carry the publisher signature. Test codeunits and test procedures live in `AAA Cases` and `Covered By`. A test-only task writes the labeled line `New and Modified Objects: none` in place of the section.

**`## Expected Behaviors`** — columns exactly `ID`, `Expected Behavior`, `Covered By`, IDs `B1`, `B2`, `B3`. The coverage table for non-branching behaviour, a guard, a simple flow.

**`## Decision Matrix`** — first column `Case` with IDs `R1`, `R2`, `R3`, last column `Covered By`, domain columns between. The coverage table for a branching rule, policy, calculation, or status combination. Domain columns prefer project language and BC display labels; exact AL names enter where ambiguity matters. A row landing in BC state, page behaviour, or a public procedure needs an integration procedure proving the wiring, unless another row's integration procedure already covers that path.

One coverage table per technical task, and `Covered By` holds AL test procedure names only.

**`## AAA Cases`** — every `Unit` case, then every `Integration` case, ascending coverage ID inside each scope. `Unit` proves an isolated decision on the AL Runner; `Integration` proves BC runtime, database, event, page, posting, install, or permission wiring in a container. Each case carries exactly one `Scope:`, a `Covers:` naming `B#` or `R#` from the same body, and `Arrange:` / `Act:` / `Assert:` bullet blocks with at least one bullet each — business state first, one business action, observable outcomes including expected errors.

**`## Journey Examples`** (`V1`, `V2`) and **`## Contract Examples`** (`C1`, `C2`) — the verify plan's acceptance checks. Scopes: `E2E` for a BC Web Client workflow, `Contract` for an API or external client, `Usability` for a guided usability walk. `Record: yes` marks behaviour no AL test layer can automate (control add-in, canvas, web-client-only); every other Journey Example is `Record: no`. The first kind is recorded and replayed, the second walked. `Role`, `Action`, and `Observable Checks` apply to both — the checks are the grounded values the walk or the replay reads off the screen. A Contract example names its `Client:` instead of a `Role:`.

**`## Usability Review`** (`U1`, `U2`) — each item carries `Scope: Usability`, one `Judge:` sentence, and a `Prompts:` block of two to four bullets.

**`Deviations:`** — one line per assumption absorbed inline during implementation, appended, never edited away; the breadcrumb marking behaviour that arrived without a red, whose tests are proved by mutation.

## Language

Write the body in the reader's language: project domain terms from `CONTEXT.md` first, BC display labels second, exact AL object, field, page, procedure, event, and API names only where traceability or ambiguity demands them. In prose slots, show the thing — the page, the field, the command, the number — one sentence per fact. `New and Modified Objects` is the deliberate exception — exact names and signatures are its whole content. Where the Design story has a happy path, a `Verification Plan` speaks its Role, Action, Business Event, View, and Status vocabulary.

Both examples below show a work item's Description after `/al-refine` has filled the body; the item's fields, tags, and links are `/al-routing`'s schema and omitted here. The Title stands above each.

## Worked example — technical task

Title: `Task: Flag Purchase Lines whose receipt date passes the Vendor tolerance`

```markdown
Measure each `Purchase Line`'s `Expected Receipt Date` against the agreed date and the
Vendor's tolerance in days, returning the overdue days, so release can warn the Purchase
Agent before the Purchase Order reaches the Vendor.

Test Specification:

## New and Modified Objects

- Modified: codeunit `Receipt Date Policy`
  - `internal procedure OverdueDays(ExpectedReceiptDate: Date; AgreedDate: Date; ToleranceDays: Integer): Integer` — P

Contract notes:
- Zero Integration cases — the policy decides from parameters alone; the successor wiring task proves it.
- 🔎 Researched: `Vendor."Lead Time Calculation"` is a DateFormula, not an Integer → Learn al-vendor-table.
- 🏛️ Precedent: none in System App / apps — no shipped policy measures receipt dates against a per-Vendor tolerance.
- ✅ Accepted: the `ToleranceDays < 0` guard mutant is equivalent — `Validate` blocks negatives upstream (user ruling).

## Decision Matrix

| Case | Expected Receipt Date | Agreed Date | Tolerance Days | Overdue Days | Covered By |
|---|---|---|---:|---:|---|
| R1 | 10 March | 10 March | 3 | 0 | AllowsReceiptDateOnAgreedDate |
| R2 | 13 March | 10 March | 3 | 0 | AllowsReceiptDateInsideTolerance |
| R3 | 14 March | 10 March | 3 | 1 | FlagsReceiptDatePastTolerance |

## AAA Cases

### AllowsReceiptDateOnAgreedDate
Scope: Unit
Covers: R1
Arrange:
- Purchase Line expects receipt on the agreed date.
- Vendor tolerance is 3 days.
Act:
- Evaluate the receipt date.
Assert:
- Overdue days is 0.

### AllowsReceiptDateInsideTolerance
Scope: Unit
Covers: R2
Arrange:
- Purchase Line expects receipt 3 days after the agreed date.
- Vendor tolerance is 3 days.
Act:
- Evaluate the receipt date.
Assert:
- Overdue days is 0.

### FlagsReceiptDatePastTolerance
Scope: Unit
Covers: R3
Arrange:
- Purchase Line expects receipt 4 days after the agreed date.
- Vendor tolerance is 3 days.
Act:
- Evaluate the receipt date.
Assert:
- Overdue days is 1.
```

## Worked example — verify task

Title: `Task: Verify the Purchase Agent sees late receipt dates at release`

```markdown
User-facing slice `flag-late-receipt-date`: the Purchase Agent releases a `Purchase Order`,
and every line whose `Expected Receipt Date` passes the Vendor tolerance surfaces a warning
naming the line and its overdue days while release still completes.

Verification Plan:

Contract notes:
- ⬆️ Push-up `V2` `Record: yes` — the warning renders in a notification no AL test layer observes.

## Journey Examples

### V1 WarnsOnLateReceiptDateAtRelease
Scope: E2E
Record: no
Role: Purchase Agent
Action:
- Open the Purchase Order Card for an order with one line 4 days past the Vendor tolerance.
- Choose `Release`.
Observable Checks:
- The warning names the late Purchase Line and 1 overdue day.
- Purchase Order Status is `Released`.

### V2 ClearsWarningWhenReceiptDateCorrected
Scope: E2E
Record: yes
Role: Purchase Agent
Action:
- Set the late line's Expected Receipt Date 3 days after the agreed date.
Observable Checks:
- The warning clears without reopening the page.

## Usability Review

### U1 WarningTellsThePurchaseAgentWhatToFix
Scope: Usability
Judge: whether the release warning tells the Purchase Agent which line to move and by how much.
Prompts:
- Is the late Purchase Line identifiable without opening another page?
- Is the overdue amount expressed in a unit the agent acts on?
- Does the flow leave the agent at a useful correction point?
```
