---
name: al-implement
description: Drive one refined task through TDD, one AAA case at a time — red→green, or a green-born test proved by mutation. Run it when the router names a task for implementation, or to land the red-first repair of a verification-walk defect.
disable-model-invocation: true
---

# Drive one task red → green

One task per session. Consume its `Test Specification`, stop at green. Your first line names the model class this run wants — the task's stamped tier, standard when absent — and the user, who picked the model, weighs the mismatch. Reshaping the diff is `/al-refactor`'s work, not chained from here. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## Before any code

Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch. The task this skill takes is `kind: technical` with a populated `Test Specification`. Missing its specification, `/al-refine` writes it first. Another `kind:` is declined — `/al-routing`'s ladder names its skill. Task-file state is `/al-routing`'s; this skill edits only the task body.

A task whose behaviour is already proved is re-entered by one named repair alone, settled tasks included: a functional fail from a verification run — its failed check is the red, written as a test at the layer that can catch it. It lands red-first, commits under the owning `T-NNN`, and moves no task-file state. At green, the user runs `/al-code-review` on the fix diff under its repair scope, then resumes `/al-user-verification` at the failed scenario.

Read `architecture.md` and name the seam in BC vocabulary — the procedure to extract, the event to subscribe, the interface to implement, the page action to wire. Production names and signatures arrive minted in the task's `New and Modified Objects`; test codeunit and procedure names are yours to mint.

## Writing AL here

Every BC object, table, field, procedure, event, and enum value name comes from a lookup run in this session — search the workspace source and symbols, or read the official BC documentation. Recall is fiction. `.bcapps/` is the intentionally gitignored pattern library, not a name oracle: before shaping a procedure, read how its precedent implements the behaviour — the `Precedent` verdict the task or `architecture.md` carries, or the nearest System Application neighbour — and take its signature shape, error style, and event placement. Missing → stop, naming `/al-clone-bcapps`; otherwise default workspace search can omit the clone, so use a search mode or direct file reading that includes it. A `reused:` verdict binds: the implementation calls the Microsoft object, and writing a parallel one is a stop below. A name you mint earns a zero-hit collision lookup first: objects against workspace declarations, fields against the target table and its extensions, procedures against the target object.

BCQuality is the intentionally gitignored rule set. `.bcquality/knowledge-index.json` carries one row per article with its `domain` and `keywords`; missing → name `/al-clone-bcquality` and stop. Default workspace search can omit the clone, so use a search mode or direct file reading that includes it, and it is one minified line — parse it as JSON rather than reading or searching it by line. Before the first case, narrow to the domains the task touches and read those articles. The articles are written for the container runtime — AL Runner is a non-Microsoft unit runner they do not document — so this skill's runner semantics and test codeunit contract override a colliding article. An article that moved a decision lands as a `🔎 Researched:` bullet in `Contract notes`; elsewhere it stays silent.

BC vocabulary, in code and in every line written to the task file: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, codeunit not class, procedure not method. TDD, red/green, and AAA keep their own names. A name you mint is derived, never invented: its noun from a `CONTEXT.md` term, the BC baseline, or an `event-model.md` Action, Business Event, or Status, its verb from BC's own set, confirmed in `.bcapps/` where the clone is present. A term no source names is a vocabulary gap two interviews missed: settle it as one question, land it in `CONTEXT.md` per its format — committed on its own with a plain descriptive message, apart from the task's `T-NNN` commits — then continue.

Production thrift: reach for the platform before writing code — a FlowField over a setup table, a table relation or permission entry over validation code, an enum over a hand-rolled status. An `interface` arrives with its second implementation, not before. A deliberate shortcut carries a one-line comment naming its ceiling and the upgrade path. Trust-boundary validation, posting and ledger correctness, and permission checks stay at full strength.

Any `#pragma`, temporary or permanent, requires explicit user approval before it enters the diff.

## One AAA case at a time

Work the cases in the specification's order: every `Unit` case first, then every `Integration` case, ascending coverage ID within each scope. One case reaches green before the next begins.

1. **Scaffold** the test codeunit and the production procedure the case names, empty, build green.
2. **Red.** Write just enough test to fail on a `Library Assert` call. A compile error, or a runtime error the `Act` never survived, is not a red — clear it, then reach the assertion. Production stays behaviour-free: the delta this case exists to force is unwritten.
3. **Green.** Write the smallest production change that passes the case, with the test text left as the red had it.

A test born green — the behaviour already exists: a characterization test, a case over code absorbed earlier without a red — takes mutation as its red. Inject one compiling fault into the production site the case targets, watch the test go red, revert the fault, and confirm green. A test no fault forces red is not a real test: strengthen the assertion until it bites, and keep the strengthened text. Per fault, run the case's own scope — a `Unit` case the unit suite, an `Integration` case all tests; the full gate stays at task close. Faults that work: flip a guard, swap `=` for `<>`, widen a comparator, `+` for `-` in money or quantity math, replace a literal with a neighbour, drop `Validate()` for direct assignment, `Modify(true)` → `Modify(false)`. Removing an assignment or inserting an early `exit` fails to compile and wastes the round.

## Unit or Integration is the runner's verdict

AL Runner runs your own tables, fields, triggers, and AL logic for real in-memory, so record behaviour is unit-provable as written — assign fields directly and keep `Library - Sales` and its siblings out of unit tests. Everything inside an `.app` dependency auto-stubs instead: `Sales-Post` executes as a no-op, `GetResponseOrDefault` returns `false`. Where an assertion's truth rides on what a stubbed object really returns, that case is `Integration` — reclassify it rather than wrapping a BaseApp routine in a 1:1 interface built only to stub it. An observable `Commit()` is `Integration` too.

A case that moves to `Integration` mid-cycle earns one `Contract notes` line: what `Unit` could not hold, and the seam that would push it back down. A wrong expected value is a different animal — that changes the `Test Specification` contract: ask the user in chat and wait, then write the settled value into the specification and continue the cycle.

Where current code is too tangled for the Unit seam the case needs, anchor today's behaviour in an Integration characterization test first, extract the seam, then add the Unit case.

## Test codeunit contract

`Subtype = Test`, `TestPermissions = Disabled`, `Access = Internal`. Every `[Test]` calls `Initialize()` as its first statement — that reset is what makes a case portable between AL Runner and the container. `AreNearlyEqual` where `Round()` leaves a residual. A `[TransactionModel]` attribute carries a comment naming the `Commit()` it exists for. Handler wiring, assertion choice, and transaction-model selection follow BCQuality's `testing` articles.

One short PascalCase procedure per case, BaseApp style: `RuleSetWithBlockedRecordThrowsError`. Test-data literals carry UPPER_SNAKE role tokens (`CLONE_BASE_SRC`), distinct across procedures and inside the target field's width.

## Gate once, at task close

Run the full gate through `/al-build -AllTests` after the last case; a gate between `Unit` cases re-proves the same tree. Read a red there by class: a container or publish failure is infrastructure and `/al-build` owns the recovery; a test green under AL Runner and red under the container is a placement or runner-semantics mismatch, not a production defect; anything else is an ordinary regression — repair the production code and re-gate.

## Reconcile, then hand over

At full green, the handoff certifies that the task file matches what landed. Before it:

- Every AAA case header carries its actual AL test procedure name, and every `Covered By` cell names those procedures.
- `New and Modified Objects` matches the diff — objects, fields, signatures, visibility, placement in the module map.
- `Scope:` and `Covers:` are final; discoveries land as one-fact bullets in `Contract notes`, each grounding citation among them as `🔎 Researched: <fact> → <source>`.
- Every `Contract notes:` bullet is one sentence; a bullet that grew a history is rewritten to its surviving decision, the history going to the commit message.
- A shipped surface is a one-way door: new objects take IDs from the workspace's ID allocator, and a shipped field goes `ObsoleteState: Pending` → `Removed` rather than being renamed in place.

Commit at green under the task's `T-NNN` prefix — the slice review selects its diff by those prefixes — so the tree is clean for what comes next. Report that committed `HEAD` and the full-gate result to `/al-routing`; it records the clean-gate receipt, including on a repair green.

## Apply a decision, or ask on a new one

Apply and continue: build scaffolding, a permission-set entry, an object ID, a caption, a local rename, a field on an object the task already names, reusing a seam a sibling task established. Where one rests on an assumption nobody blessed, append one line to the task body's `Deviations:` block — never edited away.

A new decision pauses the cycle: ask it in chat as one question and wait. An answer that keeps the task's contract — a production object the assertions require that `New and Modified Objects` never named, a code path that needs its own case rather than an appended assertion, a public-surface rename — lands in the `Test Specification` by this run, and the cycle continues. An answer that reopens the architecture — a new table, a new event publisher, a genuinely new seam, a `.bcapps/` find that Microsoft already ships what the task is building, a BCQuality rule the task's named surface violates, a task that no longer matches the feature Goal — ends the run: roll the working tree back to the last commit and name the owning skill; holding work uncommitted until green is what keeps that rollback clean.

## Close

Name the task green and the behaviour it now proves — one line, no build counts; those live in the commit and the task file. Put the landed change in view through `/al-visualize` — the component diff of what this task added and modified, `Deviations:` among its risks; a repair green draws its fix diff the same way before rejoining its episode.

Then `/al-routing`; a repair green stays inside its episode, following the repair path above.
