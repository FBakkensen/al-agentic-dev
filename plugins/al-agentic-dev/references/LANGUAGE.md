# Architectural vocabulary

## One term per concept

Use these terms exactly; never substitute "component," "service," "API," "boundary," "class," or "entity." This is the shared language of `/al-design`, `/al-refactor`, and `/al-code-review`. It sits beside the BC pattern catalogue (`bc-patterns.md`) without replacing it.

Each term keeps its published definition — Module, Depth, and Leverage from Ousterhout, **Seam** from Feathers, **Connascence** from Page-Jones, **Command-Query Separation** from Meyer, **Functional core, imperative shell** from Bernhardt, **Slice** from Event Modeling (Dymitruk), **Vertical Slice Architecture** from Bogard. The entries below state only this project's AL/BC binding and the aliases it rejects (_Avoid_).

## Terms

**Module**
A folder under `src/<module>/` holding a cohesive unit (codeunits, tables, pages, permissions) for one bounded responsibility, with exactly one interface. Scale-agnostic: a single codeunit up to a multi-table feature slice. The whole AL app stays one shipped artifact — "module" names an in-app structural unit, never the `.app` package. Realises Vertical Slice Architecture: feature folder, not layered architecture.
_Avoid_: component, service, unit, package.

**Interface**
Everything a caller must know to use the module correctly: signatures, invariants, ordering constraints, error modes, required setup, performance characteristics, events published and subscribed. Wider than AL `interface` objects — that keyword declares one *kind* of seam, never the whole knowable surface.
_Avoid_: API, signature, contract (too narrow).

**Implementation**
What is inside the module: codeunit bodies, table triggers, page actions, internal codeunits. Reach for "adapter" when the seam is the topic; "implementation" otherwise.
_Avoid_: internals (overloaded), guts.

**Depth**
A property of the interface, not the implementation. Never a lines ratio — that rewards padding the body.

**Seam** _(Feathers)_
Where behaviour can be altered without editing in place. A module has an *external seam* (its interface, where callers cross) and *internal seams* (private to the implementation, used by its own unit tests). AL shapes: a published `IntegrationEvent` (with optional `IsHandled`), an AL `interface` object plus an Implementer codeunit, a table-extension field, an event subscriber attaching to a publisher, and a `List of [Interface I…]` / `Dictionary of [Text, Interface I…]` collection (BC 2025 W1, runtime 15.0) where adapters self-register via `.Add()`.
_Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter**
A concrete codeunit satisfying an interface at a seam — a *role*, not substance: an `App Deposit Slip Printer` and a `Stub Deposit Slip Printer` are two adapters at the same seam. AL code shapes live in [testability.md](testing/testability.md).
_Avoid_: implementation (when you mean role, say adapter), driver, plugin.

**Leverage**
What callers get from depth: one implementation pays back across N call sites and M tests — why a façade earns its place.
_Avoid_: reuse (too vague; reuse can be shallow copy-paste).

**Locality**
What maintainers get from depth: change, bugs, and verification concentrate at one place.
_Avoid_: cohesion (related, but locality is about *where the change lands*).

**Connascence** _(Page-Jones)_
The coupling grammar — what kind, how strong. AL instances: connascence of meaning is a magic `Code[20]` or status string two procedures interpret in lockstep; of execution order, `SetLoadFields` after `SetRange`, or `repeat` with no `Find` before it. Refactor rule: prefer weaker connascence over stronger; where strong connascence is unavoidable, localize it in one module. The structural lens's reason to introduce an enum, a parameter record, or a guard.
_Avoid_: "tight coupling" (names the symptom, not the kind or strength), "dependency" (too generic).

**Command-Query Separation (CQS)** _(Meyer)_
A procedure is either a **command** (causes an effect — `Insert`/`Modify`/`Delete`, telemetry, error, event — and returns nothing) or a **query** (returns a value and has no observable effect), never both. Distinct from the functional core, imperative shell split: a query that reads the database is a shell read. Only a query whose result depends solely on its parameters belongs in the core. Canonical violation: a *business* procedure that `Modify`s a record *and* returns a computed total — a caller cannot read the total without also posting.
**AL carve-out.** BC platform contracts that legitimately return a value *and* touch state are NOT violations — do not flag them: `Get` / `Find*` (return found-status, populate the record), `Codeunit.Run` / `[TryFunction]` (return success Boolean, effects by design), `NoSeries` next-number (returns the number, advances the series). The smell is a business query that modifies state as an incidental side effect, never these.
_Avoid_: "getter/setter" (too OO, misses the no-effect guarantee), "side-effect-free" (only half — names the query, not the command).

**Functional core, imperative shell** _(Bernhardt)_
The pure core — decisions computed from parameters alone, no DB, no external calls — is the unit-test surface; `Access = Internal` makes it test-accessible without crossing the external interface. The shell performs the reads (`Get`/`Find*`, events subscribed) and the writes (`Insert` / `Modify` / `Delete`, telemetry, errors, events published), passing read results into the core as parameters. Technical proof has two surfaces: Integration tests cross the external interface end-to-end; Unit tests target the core directly with stubbed collaborators. See [tdd.md](testing/tdd.md), [task-grammar.md](task-grammar.md), and [testability.md](testing/testability.md).
_Avoid_: treating the split as a label slapped on an existing tangle — the split *is* the refactor.

## Behavioural decomposition

Module, Interface, Implementation, Depth, Seam, and Adapter describe static structure. Behavioural terms describe what the feature *does*: a slice is decomposed *behaviourally* (one initiated behaviour), a module *structurally* (one cohesive responsibility); one slice typically lives across one or more modules, and one module participates in one or more slices.

**Slice** _(Event Modeling)_
One initiated behaviour expressed as **trigger → command → event → state → view**; the unit of architectural decomposition, sitting between the Solution slot and the Module map slot in `architecture.md`.

| Pattern | Trigger |
|---|---|
| **Command** | page action, report request *(user-initiated)* |
| **Automation** | event subscriber, Job Queue, install/upgrade *(system-initiated)*; most common AL pattern |
| **Translation** | API page, web service, webhook *(external-system-initiated)* |
| **View** | page render, FlowField, report layout *(read-only)* |

Settlement is two-artifact for user/API-facing slices. User-facing slots (Role, Action, Business Event, View, Status; BC vocabulary at external-observer altitude, no AL pub/sub) settle in `event-model.md` via `/al-event-model`. AL realisation (trigger object, command codeunit, publication or subscription, state modification, view rendering) settles in `architecture.md` via `/al-design`. Backend-only slices (Job Queue, install / upgrade, scheduled task) skip `event-model.md`: the trigger-source slot carries them and AL realisation settles in `architecture.md` directly. The pattern qualifies the slice in `architecture.md`: `Slice (Automation): trigger ...`.
_Avoid_: user story (too unstructured), use case (too OO), flow (already used for the diagram).

**Vertical slicing**
Per-task / per-PR rule: every `kind: technical` task in the `tasks/` folder ships tests + production code together — never data-only, logic-only, or wire-up-only — and always leaves the system green. Lower-altitude than Vertical Slice Architecture: folder structure is VSA, per-task discipline is vertical slicing.
_Avoid_: horizontal phasing (the opposite, rejected by name), layer-by-layer build, big-bang integration.

## Pillars

Four pillars make AL unit-testable; `/al-design` (test strategy), `/al-implement` (TDD cycle), and `/al-refactor` (legacy code without tests) cite them. Each is homed in [testability.md](testing/testability.md):

- **Pillar 1: decoupling production from BC infrastructure** — [Zero `Library*` calls in unit tests](testing/testability.md#zero-library-calls-in-unit-tests).
- **Pillar 2: three-phase refactor with self-overload injection** — [Three-phase decoupling](testing/testability.md#three-phase-decoupling).
- **Pillar 3: three default seams for environment-style dependencies** — [Three default seams](testing/testability.md#three-default-seams).
- **Pillar 4: test double taxonomy and naming** — [Five kinds of test double](testing/testability.md#five-kinds-of-test-double).

## BC translations

| Architectural term | Common AL realisation | _Avoid_ saying |
|---|---|---|
| Module | folder under `src/<module>/` | "module" = `.app` |
| Interface | the public-by-contract surface a caller sees | "interface" = the AL `interface` keyword |
| Seam | published event, AL `interface` seam declaration, Implementer injection point, table-extension field | "boundary" |
| Adapter | implementing codeunit, event-subscriber codeunit, mock codeunit | "class" |
| Implementation | codeunit body, table triggers, page actions | "internals" |
| Codeunit | AL's procedure container; *plays the role of* an adapter or holds implementation | "class" — codeunits have no inheritance; say **codeunit**, or **adapter** when role is what matters |
| Table | AL's persisted record schema; *plays the role of* an entity but with BC semantics (Insert / Modify / Delete triggers, FlowFields, FlowFilters, primary key, SystemId) | "entity" bare — it loses the BC semantics; say **table** or **record** |
| AL `interface` object | a single seam *declaration*, the contract row of an Implementer-pattern seam; never the whole architectural Interface | TS/C# `interface` keyword (different lifecycle, different runtime) |
| Slice | the trigger / command / event / state / view chain naming one initiated behaviour | "user story" (slices include non-user triggers) |

## Principles

- **The deletion test.** Delete the module in imagination: complexity vanishes → it was a pass-through, delete it for real; complexity reappears across N callers → it was earning its keep. Does not apply when the seam is a published event with no in-tree callers.
- **The two-adapter rule.** One adapter means a hypothetical seam; two adapters mean a real one. No seam (AL `interface` plus Implementer codeunit, or a publishable event plus its first subscriber) until at least two adapters justify it — typically production + test, or two real production variants.
- **Two technical test surfaces, both first-class.** Integration tests cross the external seam via `Access = Public`, exercising the shell. Unit tests live *inside* the module, calling the core's internal procedures directly — AL's `Access = Internal` is test-accessible from the same app, and Microsoft's BaseApp tests do this throughout. `Test Specification` scope (`Unit` or `Integration`) decides which surface each AAA case uses.
- **Internal seams stay private.** When unit tests have to reach past `Access = Internal`, reshape — split the responsibility into a smaller internal codeunit — rather than weaken visibility for the test's sake.
- **The interface is the test surface.** Callers and tests cross the same seam — the external seam for Integration tests and production callers, an internal seam for Unit tests. Wanting to test *past* the interface means the module is probably the wrong shape.
