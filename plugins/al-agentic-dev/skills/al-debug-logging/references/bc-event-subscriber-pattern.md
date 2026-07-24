# Probing standard BC and production flows via event subscribers

**No source access → subscribe to a published event and emit the probe from the subscriber.** Reference for `/al-debug-logging` when the observed code is in BaseApp, the System Application, a third-party app, or an extension you cannot edit. With source access, probe in place instead — closer to the decision, easier to remove.

## Find the event

Use the `bc-standard-reference` agent to locate published events around the suspected path. Take events on both sides of the operation (`OnBefore*` and `OnAfter*`) so `telemetry.jsonl` order reveals the path.

## Pattern

The subscriber lives in a non-shipping extension of your project, so it never reaches production. Event IDs carry the `DEBUG-BC-` prefix, keeping subscriber probes distinct from in-place `DEBUG-*` probes. A subscriber may omit the publisher's trailing parameters. Declare the leading parameters up to the last one it uses. Probing `Sales-Post`'s `OnAfterPostSalesDoc`:

```al
codeunit 50190 "Debug SalesPost Subscriber"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure OnAfterPostSalesDoc(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20])
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage('DEBUG-BC-SALESPOST-DONE', 'Investigation', StrSubstNo('SalesInvHdrNo=%1', SalesInvHdrNo));
    end;
}
```

Run the harness that exercises the flow — post a document, run a workflow, open a page action. Capture follows the harness ([telemetry-workflow.md](telemetry-workflow.md)); a test via `/al-build` lands in `.output/TestResults/*/telemetry.jsonl`:

```text
rg "DEBUG-BC-" .output/TestResults/*/telemetry.jsonl
```

Once capture is verified working, a probe that never fires is evidence, not failure: the silence proves the path never ran — read it before adding probes.

Investigation complete → delete the subscriber codeunit. It is scaffolding, never production code.

## Hygiene

The same-publisher constraint ([telemetry-workflow.md](telemetry-workflow.md)) applies unchanged. A `DEBUG-ENTRY` probe in your harness paired with `DEBUG-BC-*` probes in the subscriber gives per-scenario timelines.
