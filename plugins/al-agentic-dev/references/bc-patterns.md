# BC/AL design patterns

Match each module against this catalogue and adopt a pattern only where it fits. A simple module fits none — a plain procedure on a focused codeunit is the default. A pattern that needs explaining means the module shape is wrong — reshape, do not rename. Fuller pattern docs: https://alguidelines.dev/docs/patterns/.

## Façade

A single `Access = Public` codeunit fronting a cluster of `Access = Internal` workers, canonical in System Application modules (Azure Blob Services, Barcode, Cryptography Management). Use it for a functional group with a distinct API that callers should never reach past. The two-adapter rule ([LANGUAGE.md](LANGUAGE.md)) applies only when the façade fronts a swappable subsystem. Façade-without-seam is legitimate when the value is locality and discoverability. When external apps must extend the subsystem, hiding implementation hides extension points — choose Generic Method or Event Bridge instead.

**_Avoid_:** **Middle Man** (Fowler) — façade procedures that forward call-by-call to one internal codeunit. Fails **The deletion test** ([LANGUAGE.md](LANGUAGE.md), Principles): either deepen, or delete and let callers depend on the internal codeunit directly.

## Event Bridge

A dedicated codeunit containing only `IntegrationEvent` publishers, raised by every implementation of a shared AL `interface` and named to match it (`"IScale"` → `"IScale Triggers"` — the shared prefix is the discoverability hook). Use it when two or more implementations need shared, consistent events that external apps may subscribe to. A single implementation fails **The two-adapter rule** ([LANGUAGE.md](LANGUAGE.md)) — wait for the second.

**_Avoid_:** **Per-implementation event drift** — an adapter publishing its own events; subscribers bind to that adapter and the contract breaks the moment a second adapter ships. Only events that apply across all adapters belong on the bridge.

## Generic Method

A three-layer structure for one significant business operation whose contract includes extensibility — document posting, large batch jobs, anything other apps will hook:

1. **UI layer**: dialogs and interaction behind a `HideDialog` parameter.
2. **Event layer**: `OnBefore` / `OnAfter` integration events with `IsHandled` flags.
3. **Method layer**: the business logic in a `Do…` procedure.

The method codeunit's entry procedure is `internal`. External callers reach it through a public wrapper procedure on the entity's table (or a codeunit). That wrapper is the IntelliSense-discoverable surface. Skip validation, helpers, and trivial logic — the three-layer overhead is wasted on a small operation with no extension story.

**_Avoid_:** **Validation dressed as Generic Method** — speculative generality (Fowler): three layers around a validation procedure or helper, where the events get no subscribers and the `Do…` procedure is the only thing that ever runs. Use a plain procedure on a focused codeunit.

## Template Method

A skeleton algorithm in a template codeunit with variant steps delegated to AL `interface` implementations. Use it for related problems sharing identical workflows (document posting, report generation, data export). **The two-adapter rule** ([LANGUAGE.md](LANGUAGE.md)) must hold — one variant is just a codeunit. When implementations diverge in shape (one export writes header + lines, the other header only), use separate templates.

**_Avoid_:** **The wrong abstraction** (Metz) — flattening genuinely different workflows into one template by stuffing differences into wide `interface` parameters or `case`-on-type branches inside adapters. Split into two templates the moment a variant carries shape-changing branches.

## Implementer Injection

A self-injection seam for testability: the production codeunit implements its own AL `interface`, so tests inject a stub while existing callers stay untouched. Use it when refactoring legacy code that mixes DB calls with decisions and the seam must land without a breaking change. The mechanics and AL code live in [testability.md](testing/testability.md) Phase 3. The stub adapter in each consuming test app is the second adapter (**The layout**, [test-layout.md](testing/test-layout.md)). Skip greenfield code where the interface is the contract from day one — accept the interface on the public procedure directly, no overload ceremony. Skip seams that will not ship a second adapter. Skip dependencies AL Runner runs for real: supported record operations alone earn no seam (**Earned seams**, [testability.md](testing/testability.md)).

**_Avoid_:** **Speculative generality** (Fowler) — declaring an interface and implementing it once just to "be testable" without ever shipping a second adapter.

## Error Handling

Structured error *collection* on the `ErrorInfo` framework (BC v20+). Mark the collecting procedure `ErrorBehavior(ErrorBehavior::Collect)`. Raise each failure via `Error(ErrorInfo)` with `Collectible = true`. Check `HasCollectedErrors` / `GetCollectedErrors` and surface all failures together at the end. Pre-v20, `TryFunctions` plus `GetLastErrorText` is the fallback. Use it where users need all failures at once: mass import, document posting with many lines, batch validation. Skip single validations. Skip flows that should fail fast — where the first failure invalidates everything that follows.

**_Avoid_:** **Silent collection** — errors gathered but never surfaced, or surfaced where users do not read; the user thinks the operation succeeded.

## API Register Fieldset

Track which fields the API request body actually carried, so the API can distinguish *unset* from *set-to-default*. Store field numbers in a temporary `Field` record during `OnValidate`. Read the fieldset in `OnInsertRecord` / `OnModifyRecord`. Use it for mandatory-field enforcement, Insert-vs-Modify distinctions, blocking specific fields during certain operations, and applying templates without overwriting API-provided data. Skip internal callers and UI flows — they carry no absent-vs-default ambiguity.

**_Avoid_:** **Treating defaults as absent** — assuming a field's default value means the caller did not send it. The bug stays invisible until a customer sets a field to its default deliberately.

## Delegate API Operation

Move Insert / Modify / Delete out of API pages into a dedicated codeunit. Page triggers (`OnInsertRecord`, `OnModifyRecord`, `OnDeleteRecord`) delegate to internal procedures taking record parameters and return `false`. That gives explicit control over the order of business logic relative to record persistence. Use it when logic must run before persistence, default values must be set during `Insert`, temporary buffers are involved, or `OnValidate` triggers must operate on records that already exist. Skip plain persistence without ordering needs.

**_Avoid_:** **Stale response record** — the codeunit writes a local copy but never assigns final state back to the record parameter, so the API response disagrees with the persisted row.

## Command Queue

Sequential execution of independent processes. The shape: an `ICommand` AL `interface` declaring `Execute()`, a Queue codeunit owning the entries, one adapter per command handling its own errors. Use it when several independent processes must run in sequence (posting multiple orders, cascading operations). The queue lives in memory only.

**_Avoid_:** **In-memory queue for durable work** — Command Queue for operations that must survive a service restart (long-running posting batches, scheduled jobs). Durable work takes Job Queue Entries or persisted command tables.

## No. Series

BC's standard numbering for master records and documents needing automatic numbers with manual-override semantics. The shape: a `Code[20]` number field plus a field holding the `No. Series` code. `OnInsert` draws only when `"No." = ''` — a manual number is never overwritten. Inside that guard: validate setup, assign `"No. Series" := Setup."Document Nos.";`, keep a related previous series via `if NoSeries.AreRelated(Setup."Document Nos.", xRec."No. Series") then "No. Series" := xRec."No. Series";`, then `"No." := NoSeries.GetNextNo("No. Series");`. The number field's `OnValidate` calls `NoSeries.TestManual()` when users override. Legacy `NoSeriesMgt.TryGetNextNo` is `NoSeries.PeekNextNo` in the modern codeunit. Skip permanently-recorded entries (`Entry No.` on ledger entries is sequence-stamped at posting time, not drawn from a series) and mutable working data (`Line No.` on journal lines is line ordering, not identity).

**_Avoid_:** **Legacy `NoSeriesManagement`** — deprecated on BC v24+ in favour of codeunit `"No. Series"`.
