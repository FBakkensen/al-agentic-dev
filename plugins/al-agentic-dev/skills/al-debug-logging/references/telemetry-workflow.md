# Temporary debug logging workflow

**A passing assertion does not prove the path ran; probes do.** Reference for `/al-debug-logging`: the same-publisher constraint, the capture path, and `DEBUG-ENTRY` correlation.

## Same-publisher constraint

**Capture requires the emitting code and the Telemetry Logger to live in extensions with the same publisher in `app.json`.** `FeatureTelemetry.LogUsage` is captured by a Telemetry Logger codeunit subscribed to platform telemetry events; a publisher mismatch keeps every probe silent.

Probes silent:

1. Confirm the harness ran (test pass/fail, document posted, codeunit invoked).
2. Check the publisher of the extension where the probe lives matches the publisher hosting the Telemetry Logger.
3. Verify a `Telemetry Logger` codeunit exists and is registered as a subscriber in that publisher's extension.

The constraint is on publishers, not on test-vs-app. Production, test, upgrade, install, and subscriber code all emit, as long as the publisher matches.

## Capture path

The capture path depends on the harness. Probes work under any harness in the same publisher; `/al-build` is convenient because its BC test runner reliably produces `telemetry.jsonl`.

- `/al-build` test harness → `.output/TestResults/*/telemetry.jsonl`. Inspect with:

  ```text
  rg "DEBUG-" .output/TestResults/*/telemetry.jsonl
  ```

- Any other harness — page action, posted document, web service, install/upgrade, job queue, manual subscriber trigger — produces no `telemetry.jsonl`. Capture via Application Insights, the BC server's telemetry sink, or a local Telemetry Logger codeunit writing to a known path. Confirm where the host environment surfaces `FeatureTelemetry` events before running.

Useful fields per entry: `eventId`, `message`, `customDimensions`, `callStack`; when a test was the harness, `testCodeunit` and `testProcedure`. Use `Format()` for non-text values in messages or custom dimensions.

## Correlate with `DEBUG-ENTRY`

**Everything between two `DEBUG-ENTRY` entries belongs to the first scope.** When probes fire across multiple runs — multi-test, repeated subscriber, shared BaseApp code — emit `DEBUG-ENTRY` (or `DEBUG-<Scope>-START`) at the start of the scope you control:

```al
FeatureTelemetry.LogUsage('DEBUG-ENTRY', 'Investigation', 'PostScenario: invoice with item charge');
```

```
DEBUG-ENTRY            -> PostScenario: invoice with item charge
DEBUG-POSTING-LINES    -> Count=3
DEBUG-PRICING-FALLBACK -> UnitPrice=0
DEBUG-ENTRY            -> PostScenario: credit memo
DEBUG-POSTING-NOLINES  -> No lines path
```
