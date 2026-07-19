# Probing standard BC and production flows via event subscribers

Reference for `/al-debug-logging` when the observed code is in BaseApp, the System Application, a third-party app, or another extension you cannot edit. In-place `DEBUG-*` probes need source access; subscribe to events the inaccessible code publishes and emit `DEBUG-*` `FeatureTelemetry.LogUsage` from the subscriber. The subscriber is a probe attached to a real published extension point.

Any BC subsystem that publishes events can be observed this way. When you control the source, prefer an in-place probe: closer to the decision and easier to remove.

## Find the event

Use `bc-standard-reference` to locate published events near the suspected behaviour. Find events on both sides of the branch (`OnBefore*` and `OnAfter*` for one operation) so `telemetry.jsonl` order reveals the path.

## Pattern

Place the subscriber codeunit in a non-shipping extension of your project (so it does not reach production). Prefix every emitted event ID with `DEBUG-BC-` so cleanup is one `rg`:

```al
codeunit 50XXX "Debug [Subsystem] Subsc"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"[BC Codeunit]", '[EventName]', '', false, false)]
    local procedure OnAfter[Event](var [Params])
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage(
            'DEBUG-BC-[SUBSYSTEM]-[EVENT]',
            '[Investigation]',
            StrSubstNo('[Shape, not contents]: %1', [RelevantValue]));
    end;
}
```

Run the harness that exercises the BaseApp flow — post a document, run a workflow, or open a page action — then read `.output/TestResults/*/telemetry.jsonl`:

```text
rg "DEBUG-BC-" .output/TestResults/*/telemetry.jsonl
```

```powershell
Select-String -Path .output/TestResults/*/telemetry.jsonl -Pattern "DEBUG-BC-"
```

Investigation complete → delete the subscriber codeunit. It is scaffolding, never production code.

A negative result answers the question. A subscriber to the `Price Calculation - V16` event `OnAfterFindLines` once never fired in `telemetry.jsonl`: V16 was not enabled, so the fix belonged in test setup, not the calculator. A probe need not catch an event to provide evidence.

## Hygiene

The `DEBUG-BC-*` prefix distinguishes subscriber probes from in-place `DEBUG-*` probes and from production telemetry. The same-publisher constraint applies — the subscriber's extension publisher must match the Telemetry Logger's, see [telemetry-workflow.md](telemetry-workflow.md). A `DEBUG-ENTRY` probe in your harness paired with `DEBUG-BC-*` probes in the subscriber gives per-scenario timelines.
