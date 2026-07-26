# AL Testability

## Earned seams

AL Runner runs your own tables, fields, triggers, and AL logic for real in-memory, so record logic is unit-testable as written. Only a dependency on MS BaseApp / SA *behaviour* it cannot run — posting, number series, HTTP, SA services — earns a seam; the auto-stub report detects which ([test-layout.md](test-layout.md)). Two over-applications:

- **Prop seam** — a 1:1 interface over a BaseApp routine extracted only to stub it: a fake BC that passes where the platform would not. A real seam names a domain dependency you could vary (provider, API, environment); intentional BC coupling belongs in an earned integration test, not a prop.
- **Temp-record for testing** — `temporary` records, including lower codeunits taking `var TempRecord: Record X temporary` to keep database side-effects high in the call stack, are a design choice (purity, transaction shape), never a testability requirement: AL Runner runs real-table `Insert`, `Modify`, `Delete`, and `Get` in-memory.

## Three-phase decoupling

The technique for a *genuine* seam — whether any seam is earned at all is **Earned seams**' call. Each phase lands compilable on its own, and existing callers never change.

**Phase 1, extract internal procedures.** One responsibility per `internal procedure`, no decisions in the same procedure as a DB call: `Find*` reads, `Edit*` pure field assignments, `Modify*` writes, one external dependency per wrapper.

**Phase 2, extract interface.** An `Access = Internal` interface containing only the procedures to inject in tests.

### Phase 3, inject via self-overload

The production codeunit implements its own interface; `OnRun()` passes `This` (self), and existing `Codeunit.Run()` callsites stay untouched — the **Implementer Injection** pattern — its catalogue entry lives in [../bc-patterns.md](../bc-patterns.md).

```al
codeunit 50100 "App PurchInvEdit" implements "IPurchInvEdit"
{
    trigger OnRun()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        This: Codeunit "App PurchInvEdit";
    begin
        DoEditPurchInvHeader(PurchInvHeader, Rec, This);
    end;

    internal procedure DoEditPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
        var Rec: Record "Purch. Inv. Header"; Edit: Interface "IPurchInvEdit")
    begin
        Edit.FindPurchInvHeader(PurchInvHeader, Rec);
        Edit.EditPurchInvHeader(PurchInvHeader, Rec);
        Edit.ModifyPurchInvHeader(PurchInvHeader, Rec);
    end;
}
```

For public-facing procedures without `OnRun`, add a separate `internal` overload accepting the interface; the public entry point stays backward-compatible while the overload becomes unit-testable.

## Interfaces over Handled events

Use interfaces when the goal is testability, Handled events when the goal is extensibility across apps: event subscribers in a test app fire globally — no per-test injection; interface parameters inject per call.

## Zero `Library*` calls in unit tests

A unit test that calls `Library - Sales`, `Library - ERM`, or a project `Lib*` factory to prepare the SUT reveals production code still coupled to BC infrastructure. Assign fields directly:

```al
PurchInvHeader."Payment Reference" := 'REF-001';
// no Insert(), no Library call required
```

## Three default seams

When three-phase decoupling declares an interface, match it to one of the three default seams before minting a new one.

| Seam | Interface | Production impl | Stub impl |
|---|---|---|---|
| System environment | `"IEnvironment"` | `"App Environment"` | `"Stub Environment"` |
| External APIs | `"IApiRequest"` | `"App Api Request"` | `"Stub Api Request"` |
| Standard Application | `"IFinance"` (example) | `"App Finance"` | `"Stub Finance"` |

Route by what the test cannot run: BC runtime / OS environment → `IEnvironment`; an external HTTP API → `IApiRequest`; standard BC G/L or finance ops → `IFinance` (or `IPosting`, `ISales` per seam); only a record's own data fields → no seam — AL Runner runs the real record.

### Naming convention

Interface `"I<Concept>"`; production impl `"App <Concept>"`, ships in the production app; stub impl `"Stub <Concept>"`, ships in the consuming test app — never in the production app. Multiple stub variants: `"Stub <Variant> <Concept>"` (e.g., `"Stub Production Environment"`). Apply your AppSource prefix to every object name when shipping; examples here drop it.

### Stub location rule

The interface's `.Interface.al` file location decides: interface in the production app → stub in each consuming test app's `Stubs/<InterfaceName>/` folder; interface in a test app → stub co-locates with the test codeunit. Each consuming test app owns its own doubles (**The layout**, [test-layout.md](test-layout.md)); production owns none.

### IEnvironment

```al
interface "IEnvironment"
{
    procedure SystemEnvironment(): Enum "System Environment"
    procedure ThisCompanyName(): Text[30]
    procedure IsEvaluationCompany(): Boolean
}
```

### IApiRequest

Test how your code reacts to the response, not whether the API works: the stub is setup-then-return — configure status code and content before the SUT runs.

```al
interface "IApiRequest"
{
    procedure Send(RequestMethod: Enum "Api Method"; RequestUrl: Text; Payload: Text;
        SecretKey: SecretText; var ResponseStatusCode: Integer; var ResponseContent: Text)
}
```

### IFinance

Hides BaseApp G/L calls — `Gen. Journal Line` `Validate()` and `Insert(true)`, number-series allocation, posting-setup reads — so finance logic is assertable without G/L accounts, bank accounts, or posting setup in the database. All parameters are `var`; the stub returns data by overwriting the caller's variables, the same setup-then-return pattern as `IApiRequest`.

## Change detection: compare the persisted row, never `xRec`

A field `OnValidate` that gates on "did this value actually change" re-`Get`s the persisted row. `xRec` holds the prior value only from the UI. From code — engine recalc, web service, background session, a programmatic `Validate(Field, Value)` — `xRec` is empty or `= Rec`, so `if Rec.X <> xRec.X` is correct on the page and silently wrong off it. A `GuiAllowed` patch does not fix it. Inside `OnValidate`, before `Modify`, the database still holds the old value:

```al
PriorRec.SetLoadFields("X");          // SetLoadFields satisfies PC0030 on the Get
if PriorRec.Get(Rec."Primary Key") then
    if PriorRec."X" = Rec."X" then
        exit;                          // no real change → do not cascade / recompute
```

The persisted-row comparison behaves identically from UI, code, API, and background, and is unit-provable — AL Runner leaves `xRec` unwired on a code-path field `OnValidate`. alguidelines' No. Series pattern ships the `xRec` change-guard as canonical. This rule wins. The `al-review-bc` lens carries the check.

## Five kinds of test double

Meszaros kinds — Dummy, Stub, Fake, Spy, Mock. Use the simplest kind that makes the test pass, and name the kind exactly: a double is a "mock" only when it verifies call contracts. The three default seams take a **Stub**.

### Double naming

The file prefix names the kind — `StubIConverter.Codeunit.al`, `SpyILogger.Codeunit.al`, `MockIPurchInvEdit.Codeunit.al`; each double's home follows the **Stub location rule** above.
