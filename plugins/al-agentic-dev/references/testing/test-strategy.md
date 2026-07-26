# Test strategy — the execution pyramid

Cover behaviour at the lowest layer that can cover it. Every push-up above that floor earns a justification. Sibling axes: [tdd.md](tdd.md) (the red-green cycle), [test-layout.md](test-layout.md) (placement). Task file grammar: [task-grammar.md](../task-grammar.md).

## The five layers

| Layer | Mechanism | Oracle | Role | Owning skill(s) |
|---|---|---|---|---|
| **Unit** | AL-Runner (fast, in-process) | assertion, isolated | red-first driver | `/al-implement` (`-UnitTestOnly`), `/al-build` |
| **Integration** | container + TestPage | assertion, transactional rollback | red-first driver | `/al-implement`, `/al-build` |
| **E2E** | bc-replay page-script on a fresh container, user-recorded in BC's Page Scripting recorder | assertion, oracle-limited | UI regression guard, reserved for behaviour no lower layer can automate | `/al-page-script` (guides the recording); batch run by `/al-user-verification` |
| **Contract** | Postman, curl, integration harness, or named client | assertion, client-facing | API/client regression guard | `/al-user-verification`; harness named by `Verification Plan` |
| **Exploratory** | guided user walk — the user drives the real client | the user's sapient judgement | usability oracle (findings → tasks) | `/al-user-verification` |

AL-Runner is the fast pre-gate; the container is authoritative and runs both isolated decision and TestPage `[Test]` codeunits. Placement mechanics — the two-peer-test-app layout, the AL Runner capability map, isolation semantics, the authoring contract — live in [test-layout.md](test-layout.md).

## Push tests down

Push-down fires at generation time, not only on a failure: behaviour a Unit or Integration test can pin gets its check there; the slow layers hold only what no lower layer can reach. E2E and Contract checks and Exploratory testing are written after the code from verify-task examples — regression guards, never red-first drivers.

`/al-refine` makes the call when it sets a Journey Example's `Record:` flag (**The `Record:` flag**, [task-grammar.md](../task-grammar.md)): `Record: yes` only where AL Runner / TestPage genuinely cannot reach the behaviour — the walls: control add-ins, canvas, rendering, web-client-only behaviour. A recording that doubles a lower test is pure cost.

Pushing down can cost a seam whose only justification is testability (**Earned seams**, [testability.md](testability.md)). That judgment has two homes: the right design up front (`/al-design`) and refactor-to-push-down (`/al-refactor`).

## Every push-up earns a justification

A test placed above the deepest layer that could check the behaviour is a push-up. It owes two facts: why the layer below cannot hold it, and what reaching that layer would cost — a named seam (**Earned seams**, [testability.md](testability.md)), or the wall that makes it impossible.

Scope is exactly the layers that check above their floor: `Integration` (could be `Unit` if a seam isolated the MS-logic collaborator), `Record: yes` E2E (the wall is the flag's own meaning), and `Contract` (client-only behaviour a TestPage cannot see). Not `Record: no` E2E — the pushed-down state — and not `Exploration`, which has no checkable form to push down to. A wall is informational; a costs-a-seam push-up is the real decision: build the seam, or accept the slower test.

The justification is surfaced and committed, never silent:

| Stage | Behaviour |
|---|---|
| `/al-refine` | Proposes scope, surfaces every push-up in chat ([the Push-up report](#the-push-up-report)), records each as a `Contract notes` line ([task-grammar.md](../task-grammar.md)), and commits nothing — its handoff stop is the user's review point. |
| `/al-implement` | Gates: before writing a test above the blessed scope — a planned `Unit` case reclassified to `Integration` on an AL-Runner wall, or a new `Integration` case emerging mid-TDD — it stops for commitment: build the seam, or accept `Integration`. |
| Unattended | Autopilot flips `status: blocked` and routes `/al-steer`; `/al-code-review --fix` stays mute and reports `cannot fix — escalate`. |
| `/al-code-review` | Audits the recorded justification: a push-up with no wall and no named seam is a finding. |

### The Push-up report

A lede verdict line carries the counts — `N tests above their floor — M cost a seam, K are walls`. One labeled line per push-up names its scope, the case/example handle, why the layer below cannot hold it, and the seam-or-wall. It covers exactly the push-up scope above. `/al-refine` emits it as its own chat section, `/al-implement` emits one push-up's line as a Stop, and `/al-code-review` reports an unjustified push-up as an ordinary finding.

## The three feedback rules

A failure routes to the layer whose oracle can pin it.

**Push-down.** Add the red test at the cheapest layer that can pin the missed fault, fix there, and leave the higher test as the guard. A production bug surfaced by a page-script or contract red routes down to `/al-implement` for a Unit or Integration red test + TDD fix; fix at the higher layer only behind a wall. The surviving guard asserts the contract your extension depends on across the seam — the event fired with the parameters you consume, a field you read populated, the status you branch on transitioned, your side-effect landed after MS processing. Standard BaseApp/SA behaviour is Microsoft's to test, and branching logic a Unit case already pins is duplication — strip both, keep the seam-level obligation.

**Oracle sensitivity.** An oracle insensitive to a fault class is a wrong-layer symptom, not a defect to fix in place. bc-replay re-reads the page-bound `Rec` exactly as a TestPage does, so it is insensitive to the stale-bound-`Rec` fault class: such a recording is a false net. Push down to a layer with a sensitive oracle, or escalate.

**Checking vs testing.** Usability is un-checkable by construction and belongs to the exploratory layer. The same guided walk does both: `/al-user-verification` gates on the checkable outcomes the user reads off the screen, routes usability judgements to findings → tasks, and guards leading-the-witness with ask-before-reveal plus the rubber-duck coverage review.

## Nested loops

Run the cheapest loop that can produce the next proof; the slower loops guard and explore after the code exists.

| Loop | Cadence | Mechanism | Role |
|---|---|---|---|
| **Inner** | seconds–minutes, red-first | `/al-implement` + AL-Runner/TestPage | drives design |
| **Middle** | minutes | `/al-page-script` and contract checks on a fresh environment | guard, written after the code |
| **Outer** | sapient | `/al-user-verification` — the user drives the real BC Web Client | checkable outcomes gate the slice; usability emits findings → tasks |
