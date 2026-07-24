# Test specification grammar

Generated task files keep this grammar's field names and shapes exactly — skills parse them. The grammar defines the per-task `Test Specification` and `Verification Plan` sections (`specs/<NNN>-<slug>/tasks/NNN-T-MMM-<slug>.md`). `/al-refine` writes them; `/al-implement`, `/al-mutate`, `/al-code-review`, `/al-page-script`, and `/al-user-verification` read them.

## Technical task: Test Specification

One primary coverage table per technical task; multiple unrelated behaviour groups mean a low-cohesion task — split or route through `/al-steer`.

| Task shape | Coverage table | IDs |
|---|---|---|
| Non-branching behaviour, guard, simple flow | `Expected Behaviors` | `B1`, `B2`, `B3` |
| Branching rule, policy, calculation, status combination | `Decision Matrix` | `R1`, `R2`, `R3` |

### Acceptance Intent

Include only when the task has business-facing behaviour: one short paragraph naming the business outcome the tests protect. Behaviour-preserving refactors do not require it.

```markdown
Acceptance Intent:
Release blocking protects posting readiness by preventing Sales Orders from being released when Customer state violates release policy.
```

### New and Modified Objects

Every technical task names the production AL surface it lands — objects, fields, procedure signatures, events — so `/al-implement` consumes signatures instead of minting them mid-TDD. Production objects only: test codeunits and test procedures live in `AAA Cases` and `Covered By`, never here. A test-only task (red-suite rework, characterization additions) writes the labeled line `New and Modified Objects: none` in place of the `###` section. Any other state is a `/al-refine` defect: both forms absent, or a section heading with neither entries nor the `none` line. The inline document-integrity check (`../doc-integrity.md`) blocks the `ready-for-implementation` flip on it.

Keep entries at signature level and omit bodies; TDD writes the bodies. One object per landing line, `New:` or `Modified:` lede. Procedures carry full signature, visibility (`internal` / `local` / public), and one tag: `— P` for pure (a decision computed from parameters alone — no DB, no external calls) or `— S` for side-effecting (touches the database or any external state, reads included), per `architecture.md`. Fields carry AL type. Events carry the full publisher signature.

Lede semantics: `New:` = object not in the workspace at this task's start — a fresh extension object on an existing base is `New:` with `extends <base>`. `Modified:` = object already in the workspace, including objects an earlier task in the same feature landed; an object another open task's section already mints is also `Modified:` here — one `New:` owner per object, ordering via `depends_on:`. Any new object a listed signature references (enum, interface) earns its own `New:` entry.

Boundary at implementation time: a production object the task's assertions require but the section never named is replan trigger #2 (**Replan triggers**, `../task-lifecycle.md`); build-gate scaffolding the assertions never observe (permission set entry, object ID, caption) absorbs as trivia per `/al-implement`. A change whose only effect is behaviour inside a procedure an open sibling task owns is trigger #4 (sibling now wrong), not a `Modified:` entry.

```markdown
### New and Modified Objects

- New: codeunit `Release Policy`
  - `internal procedure IsReleaseBlocked(Customer: Record Customer): Boolean` — P
  - Publishes `OnAfterEvaluateReleasePolicy(Customer: Record Customer; IsBlocked: Boolean)` — S
- New: tableextension `Customer Release Ext` extends `Customer`
  - Field: `Release Blocked` (Boolean)
```

Ground minted names per the minted-name clause of the grounding rules (`../GROUND-RULES.md`).

### Contract notes

Include only when the task carries proof decisions and constraints the coverage tables cannot hold.

| Qualifying content |
|---|
| Oracle design |
| Push-up justification — every `Integration` case, `Record: yes` E2E, and `Contract` example (**Every push-up earns a justification**, [test-strategy.md](test-strategy.md)) |
| Seam or test-double decisions |
| Binding mechanics |
| Transaction model |
| Red-suite rework |
| The task's `Researched:` grounding citations (`../GROUND-RULES.md`) |

Bullets with one fact per landing line, lede word first.

```markdown
Contract notes:
- Oracle: handler-absence — a dialog with no declared handler fails the run.
- No Message handler on the Yes path — a surviving completion Message fails the run.
- Push-up `BlocksSalesOrderReleaseWhenRuleEnabled` Integration — the real `Release` crosses the posting seam a `Unit` auto-stub would falsify; costs a seam: an `IFinance` double around the release call, not built for one case.
- Zero Unit cases — structural wall: both W entries self-inject the production Confirm, leaving no unit seam.
- Decision surface proved: T-001.
- Transaction: service commits before first dialog → `[TransactionModel(TransactionModel::AutoCommit)]`.
- Red-suite rework: `PostsWithCompletionMessage` sheds its `MessageHandler` for a Yes ConfirmHandler — part of this task's green gate.
- Researched: `FindSet(true)` required for modify-in-loop → Learn al-record-findset.
```

Provenance ("settled:", "rubber-duck added", "resolved by user decision") follows **Workflow lives in the commit** (`../GROUND-RULES.md`); cross-task retelling trims to a pointer — `proved: T-001` — not the story. `Researched: <fact> → <source>` is not provenance but the grounding trace, the one citation that lands here; `/al-code-review` audits its absence on construct-touching tasks.

### Out of automated reach

Include only when the task leaves claims no automated layer proves. Each bullet names the claim and its destination — code-review invariant, verify-task journey, or accepted gap. A claim without a destination is a hole, not a note. `/al-code-review` reads this section as its invariant list.

```markdown
Out of automated reach:
- `GuiAllowed()` silent branch — container sessions are interactive; code-review invariant.
- Drill from list row to card — verify-layer outcome; V-task journey.
```

### Expected Behaviors

```markdown
### Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Blank prompt is rejected before generation starts | RejectsBlankPrompt |
| B2 | Whitespace-only prompt is rejected before generation starts | RejectsWhitespacePrompt |
| B3 | Non-blank prompt proceeds to generation | AllowsNonBlankPrompt |
```

`Covered By` contains AL test procedure names only, semicolon-separated when multiple.

### Decision Matrix

```markdown
### Decision Matrix

| Case | Release Blocking Enabled | Customer Blocked | Expected Release | Sales Order Status | Covered By |
|---|---:|---:|---|---|---|
| R1 | No | Yes | Released | Released | AllowsReleasePolicyWhenRuleDisabled |
| R2 | Yes | Yes | Blocked | Open | BlocksReleasePolicyWhenRuleEnabled; BlocksSalesOrderReleaseWhenRuleEnabled |
```

Columns prefer project/domain language and BC display labels; exact object or field names only when ambiguity matters, for example `Customer Blocked (Customer.Blocked)`. Each row requires `Covered By` — one or more procedures across scopes. A row that lands in BC state, page behaviour, or a public procedure requires an integration procedure proving the wiring even when a unit procedure proves the decision — except where another row's integration procedure already proves the same wiring path (in the example, `BlocksSalesOrderReleaseWhenRuleEnabled` proves the release wiring, so `R1` carries a unit procedure only).

### AAA Cases

Every technical task has `AAA Cases`, listed in execution order — all `Unit`, then all `Integration`, ascending coverage ID within each scope (Task execution order, [tdd.md](tdd.md)).

| Scope | Mechanism | Use |
|---|---|---|
| `Unit` | AL-Runner | Isolated decision proof. Fast red-first foundation. |
| `Integration` | Container AL tests, including TestPage | BC runtime, database, event, page, posting, install, permission, or wiring proof. |

```markdown
### AAA Cases

#### BlocksReleasePolicyWhenRuleEnabled
Procedure: `BlocksReleasePolicyWhenRuleEnabled`
Scope: Unit
Covers: R2
Arrange:
- Release-blocking policy is enabled.
- Customer state is blocked.
Act:
- Evaluate release policy.
Assert:
- Policy returns blocked release outcome.

#### BlocksSalesOrderReleaseWhenRuleEnabled
Procedure: `BlocksSalesOrderReleaseWhenRuleEnabled`
Scope: Integration
Covers: R2
Arrange:
- Sales Order exists for blocked Customer.
- Release-blocking policy is enabled.
Act:
- Release the Sales Order.
Assert:
- Blocked-customer error is raised.
- Sales Order remains `Open`.
```

| Field | Rule |
|---|---|
| Header | Matches `Procedure`. |
| `Procedure` | The exact AL test procedure name — `/al-refine` proposes it, `/al-implement` reconciles it to the actual name. |
| `Scope` | Exactly one per case; behaviour needing both scopes gets two cases. An `Integration` case is a push-up — its justification lands in `Contract notes` (**Every push-up earns a justification**, [test-strategy.md](test-strategy.md)), and `/al-implement` gates a *new* or *reclassified* `Integration` case on it before the test is written. |
| `Covers` | References `B#` or `R#` from the same `Test Specification`. |
| `Arrange` | Bullet block, at least one bullet; business state first, helper names only when the helper or seam matters. |
| `Act` | Bullet block, at least one bullet; one business action — multiple execution steps may execute that one action. |
| `Assert` | Bullet block, at least one bullet; observable outcomes by default, expected errors included; internal call assertions only in `Unit` cases where a double or spy is the behaviour boundary. |

## Verify task: Verification Plan

Include only subsections that apply: BC Web Client-facing verify tasks require at least one `E2E` example, API/client-facing verify tasks at least one `Contract` example. `Exploration` is optional, recommended for new workflows, changed workflows, and error-guidance changes.

| Scope | Mechanism | Use |
|---|---|---|
| `E2E` | BC Web Client workflow: either user-recorded (Page Scripting recorder → bc-replay) or user-walked in `/al-user-verification` | BC Web Client workflow acceptance check. |
| `Contract` | Postman, curl, integration harness, or named client | API or external-client acceptance check. |
| `Exploration` | Guided user walk (user drives the browser, agent guides) | UX/usability judgement and observational testing. |

### The `Record:` flag (E2E only)

Every Journey Example carries `Record: yes` or `Record: no` — the generation-time push-down call (**Push tests down**, [test-strategy.md](test-strategy.md)).

| Flag | Meaning | Route |
|---|---|---|
| `Record: yes` | No AL test layer can automate the behaviour (control add-in, canvas, web-client-only) | `/al-page-script` guides the user to record it as a `.yml` regression guard |
| `Record: no` | A Unit or Integration test already pins the regression — recording would double a lower test | The user walks it in `/al-user-verification` for acceptance |

A slice with zero `Record: yes` examples legitimately skips `/al-page-script`. Push-up classification and justification follow **Every push-up earns a justification** ([test-strategy.md](test-strategy.md)), recorded in the Push-up report and `Contract notes`. `Observable Checks` are mandatory for both flags — the grounded gating values the user-walk checks against, which `event-model.md` alone does not carry for edge and error cases.

### Journey Examples

`Journey Examples` holds the `E2E` examples; every example carries the `Record:` flag.

```markdown
### Journey Examples

#### V1 BlocksReleaseFromSalesOrderPage
Scope: E2E
Record: no                  # an Integration test pins the block; user walks it for acceptance
Role: Sales Processor
Action:
- Open Sales Order for blocked Customer.
- Choose `Release`.
Observable Checks:
- Blocked-customer error is visible.
- Sales Order Status remains `Open`.

#### V2 ReleaseRefreshesCanvasFactbox
Scope: E2E
Record: yes                 # factbox repaint is canvas — no AL test layer can assert it
Role: Sales Processor
Action:
- Open the released Sales Order.
Observable Checks:
- The status canvas factbox shows `Released`.
```

IDs: `V1`, `V2`, `V3`. `Record:` is mandatory on every E2E example; `Role` / `Action` / `Observable Checks` apply to both flag values (the recorder encodes the checks as Validate steps; the walk reads them off the screen).

### Contract Examples

```markdown
### Contract Examples

#### C1 RejectsReleaseWithoutCustomerNo
Scope: Contract
Client: Postman collection `tests/postman/sales-order-release.json`
Action:
- Send release request without `Customer No.`
Observable Checks:
- HTTP status is `400`.
- Response body identifies missing Customer No.
- Sales Order remains `Open`.
```

IDs: `C1`, `C2`, `C3`.

### Exploration Charters

One charter sentence and 2-4 prompts — no exact click script, no expected subjective verdict. Usability findings become follow-up tasks unless a functional failure is observed.

```markdown
### Exploration Charters

#### X1 ReleaseErrorTextGuidesNextAction
Scope: Exploration
Charter: Judge whether the release-blocking error tells the Sales Processor what to fix next.
Prompts:
- Is the blocked Customer named or discoverable?
- Is the next action clear?
- Does the flow return the user to a useful place?
```

IDs: `X1`, `X2`, `X3`.

## Language and grounding

Write tasks in the reader's language; exactness enters only where traceability demands it:

1. Project domain language from `CONTEXT.md`.
2. BC display labels.
3. Exact AL object, field, page, procedure, event, or API names — only for traceability or ambiguity.

`New and Modified Objects` is the deliberate exception: exact AL names and signatures are its whole content.

Ground exact BC-specific names in current workspace symbols/source or authoritative documentation before writing them into a task. Grounding evidence stays in chat — except `Researched:` bullets, which land in `Contract notes` per the grounding rules (`../GROUND-RULES.md`).

If `event-model.md` exists, `Verification Plan` wording uses its Role, Action, Business Event, View, and Status vocabulary.

## Closeout summaries

Completed tasks keep the final `Test Specification` or `Verification Plan`; closeout proof stays concise and citation-free.

### Technical closeout

```markdown
Closeout:
- Unit: `AllowsReleasePolicyWhenRuleDisabled`, `BlocksReleasePolicyWhenRuleEnabled`
- Integration: `BlocksSalesOrderReleaseWhenRuleEnabled`
- Build: full gate green

Mutation verdict:

| | |
|---|---|
| Baseline | `2d02629f` |
| Report | `.output/mutation-report/20260605-214958.md` |
| Mutants | 5 — release guard chain, blocked-state boundary, status flip |
| Killed | 4 (all by named tests) |
| Survivors | 1 |
| Stillborn | 1 → re-planned to a compiling operator, then killed |
| Final gate | full green |

Survivor: `SetRecFilter()` removal in `OpenReleasedOrder`.
Why kept: outside the pinned contract — the event model pins that the order's card opens, not its rowset; a killer test would pin presentation. Net: the slice verify journey probes card scoping.
Stillborn: early-`exit` in `ApplyReleaseGuard` made the guard body unreachable — a compile error, no test ran.
Re-planned: guard-condition flip at the same site, then killed by `BlocksReleasePolicyWhenRuleEnabled`.
```

The mutation verdict is a borderless two-column field/value table. Each survivor gets labeled `Survivor:` / `Why kept:` lines stating the gap → killer-test direction, the equivalence reason, or the accepted gap and the net that catches it. Each stillborn gets labeled `Stillborn:` / `Re-planned:` lines naming the site, why it failed to compile, and the compiling operator it was re-planned to — no test ran, so a stillborn is never a kill. One fact per line. Tasks where mutation ran with zero survivors and zero stillborns collapse the labeled lines and keep the table.

The verdict table and labeled lines are the only mutation content in the per-task file; the full mutation table lives in the `.output` report.

### Verify closeout

Verify closeout carries one line per verify example with its outcome.

```markdown
Closeout:
- E2E: `V1` user walk green
- E2E: `V2` page-script replay green
- Contract: `C1` Postman collection green
- Exploration: `X1` produced 1 follow-up UX task, no functional failures
```
