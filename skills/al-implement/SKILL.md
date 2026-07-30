---
name: al-implement
description: Drive one refined task red→green through TDD, one AAA case at a time. Run it when the router names a task for implementation, or to land the red-first repair of a verification-walk defect.
disable-model-invocation: true
---

# Drive one task red → green

One task per session. Consume its `Test Specification`, stop at green. Reshaping the diff is `/al-refactor`'s work and rigor is `/al-mutate`'s; neither is chained from here. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## Before any code

Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch. The task this skill takes is `kind: technical` with a populated `Test Specification`. Missing its specification, `/al-refine` writes it first. Another `kind:` is declined — `/al-routing`'s ladder names its skill. Task-file state is `/al-routing`'s; this skill edits only the task body.

A task whose behaviour is already proved is re-entered by one named repair alone, settled tasks included: a functional fail from a verification run — its failed check is the red, written as a test at the layer that can catch it. It lands red-first, commits under the owning `T-NNN`, and moves no task-file state. At green, the user runs `/al-code-review` on the fix diff under its repair scope, then resumes `/al-user-verification` at the failed scenario.

Read `architecture.md` and name the seam in BC vocabulary — the procedure to extract, the event to subscribe, the interface to implement, the page action to wire. Production names and signatures arrive minted in the task's `New and Modified Objects`; test codeunit and procedure names are yours to mint.

## Writing AL here

Every BC object, table, field, procedure, event, and enum value name comes from a lookup run in this session — search the workspace source and symbols, or read the official BC documentation. Recall is fiction. `.bcapps/` is the pattern library, not a name oracle: before shaping a procedure, read how its precedent implements the behaviour — the `Precedent` verdict the task or `architecture.md` carries, or the nearest System Application neighbour — and take its signature shape, error style, and event placement; default search skips gitignored folders. A `reused:` verdict binds: the implementation calls the Microsoft object, and writing a parallel one is a stop below. A name you mint earns a zero-hit collision lookup first: objects against workspace declarations, fields against the target table and its extensions, procedures against the target object.

BC vocabulary: Insert not create, Modify not update, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, codeunit not class, procedure not method. TDD, red/green, and AAA keep their own names.

Production thrift: reach for the platform before writing code — a FlowField over a setup table, a table relation or permission entry over validation code, an enum over a hand-rolled status. An `interface` arrives with its second implementation, not before. A deliberate shortcut carries a one-line comment naming its ceiling and the upgrade path. Trust-boundary validation, posting and ledger correctness, and permission checks stay at full strength.

## One AAA case at a time

Work the cases in the specification's order: every `Unit` case first, then every `Integration` case, ascending coverage ID within each scope. One case reaches green before the next begins.

1. **Scaffold** the test codeunit and the production procedure the case names, empty, build green.
2. **Red.** Write just enough test to fail on a `Library Assert` call. A compile error, or a runtime error the `Act` never survived, is not a red — clear it, then reach the assertion. Production stays behaviour-free: the delta this case exists to force is unwritten.
3. **Green.** Write the smallest production change that passes the case, with the test text left as the red had it.

## Unit or Integration is the runner's verdict

AL Runner runs your own tables, fields, triggers, and AL logic for real in-memory, so record behaviour is unit-provable as written — assign fields directly and keep `Library - Sales` and its siblings out of unit tests. Everything inside an `.app` dependency auto-stubs instead: `Sales-Post` executes as a no-op, `GetResponseOrDefault` returns `false`. Where an assertion's truth rides on what a stubbed object really returns, that case is `Integration` — reclassify it rather than wrapping a BaseApp routine in a 1:1 interface built only to stub it. An observable `Commit()` is `Integration` too.

A case that moves to `Integration` mid-cycle earns one `Contract notes` line: what `Unit` could not hold, and the seam that would push it back down. A wrong expected value is a different animal — that changes the `Test Specification` contract, so stop: name the contested value in chat, write nothing to the task file, and the user settles the contract before a re-run.

Where current code is too tangled for the Unit seam the case needs, anchor today's behaviour in an Integration characterization test first, extract the seam, then add the Unit case.

## Test codeunit contract

`Subtype = Test`, `TestPermissions = Disabled`, `Access = Internal`. Every `[Test]` calls `Initialize()` as its first statement — that reset is what makes a case portable between AL Runner and the container. Handlers live on the test codeunit naming them; `[HandlerFunctions('…')]` binds by string literal, so renaming a handler is a text search first. Assertions are `Library Assert` only, `AreNearlyEqual` where `Round()` leaves a residual. Add `[TransactionModel(TransactionModel::AutoCommit)]` only when the code under test calls `Commit()`, with a comment naming which one; under the default that `Commit()` fails and every side effect vanishes into a false green.

One short PascalCase procedure per case, BaseApp style: `RuleSetWithBlockedRecordThrowsError`. Test-data literals carry UPPER_SNAKE role tokens (`CLONE_BASE_SRC`), distinct across procedures and inside the target field's width.

## Gate once, at task close

Run the full gate through `/al-build` after the last case; a gate between `Unit` cases re-proves the same tree. Read a red there by class: a container or publish failure is infrastructure and `/al-build` owns the recovery; a test green under AL Runner and red under the container is a placement or runner-semantics mismatch, not a production defect; anything else is an ordinary regression — repair the production code and re-gate.

## Reconcile, then hand over

At full green, the handoff certifies that the task file matches what landed. Before it:

- Every AAA case header carries its actual AL test procedure name, and every `Covered By` cell names those procedures.
- `New and Modified Objects` matches the diff — objects, fields, signatures, visibility, placement in the module map.
- `Scope:` and `Covers:` are final; discoveries land as one-fact bullets in `Contract notes`, each grounding citation among them as `Researched: <fact> → <source>`.
- A shipped surface is a one-way door: new objects take IDs from the workspace's ID allocator, and a shipped field goes `ObsoleteState: Pending` → `Removed` rather than being renamed in place.

Commit at green under the task's `T-NNN` prefix — the slice review selects its diff by those prefixes — so the tree is clean for what comes next.

## Apply a decision, or stop on a new one

Apply and continue: build scaffolding, a permission-set entry, an object ID, a caption, a local rename, a field on an object the task already names, reusing a seam a sibling task established. Where one rests on an assumption nobody blessed, append one line to the task body's `Deviations:` block — never edited away.

Stop when the work makes a new decision: a new table, a new event publisher, a genuinely new seam, a `.bcapps/` find that Microsoft already ships what the task is building, a production object the assertions require that `New and Modified Objects` never named, a public-surface rename, a code path that needs its own case rather than an appended assertion, or a task that no longer matches the feature Goal. Name the decision in chat and leave the task file untouched; the user re-runs once it settles.

## Close

Name the task green and the behaviour it now proves — one line, no build counts; those live in the commit and the task file.

Then `/al-routing`; a repair green stays inside its episode, following the repair path above.
