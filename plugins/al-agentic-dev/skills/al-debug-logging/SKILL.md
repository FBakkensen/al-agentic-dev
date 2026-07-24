---
name: al-debug-logging
description: Temporarily add `DEBUG-*` `FeatureTelemetry.LogUsage` probes to AL code to inspect runtime state via `.output/TestResults/*/telemetry.jsonl`. Use when runtime behaviour diverges from source and tests alone can't reveal which path ran. Probes are temporary; remove before delivery.
allowed-tools: ["execute", "read", "edit", "search"]
---

# /al-debug-logging — temporary runtime probe loop

Hypothesis-driven debugging with probes as scaffolding. One question per iteration.

## Precondition

`rg "DEBUG-" -g "*.al"` returns nothing. Existing `DEBUG-*` calls are leftover scaffolding → **Stop.** Finish or remove the prior investigation first.

## Flow

1. **Hypothesis.** Name the specific question — which branch, which subscriber, which code path.
2. **Probe.** One or two `FeatureTelemetry.LogUsage` calls, event IDs prefixed `DEBUG-`, placed inside the chosen branch, never wrapped around the decision. Binary branch → two peer probes, one per branch.
3. **Run.** Exercise the path with whatever harness fires the code: a test via `/al-build`, a page action, a posted document, a web service call, an install/upgrade codeunit, a job queue task.
4. **Inspect.** `/al-build` harness → `rg "DEBUG-" .output/TestResults/*/telemetry.jsonl`; other harnesses capture elsewhere (`references/telemetry-workflow.md`). Probes silent → **Stop.** The same-publisher cause is in the same reference.
5. **Refine or remove.** Answered → delete the probes; report probe ID, emitted value, and the named code path it proves ran. Unanswered → move the probe or add a peer at the next decision.

## Canonical probe

**Log the minimum scalar that tests one prediction.** A count, a record's `No.`, an enum value, a boolean, one field value — never record bodies, PII, credentials, tokens, or secrets. Stable descriptive suffixes (`DEBUG-PRICING-FALLBACK`), never numeric (`DEBUG-1`). `FeatureTelemetry.LogUsage`, never `Session.LogMessage`.

```al
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
begin
    if SalesLine."Unit Price" = 0 then
        FeatureTelemetry.LogUsage('DEBUG-PRICING-FALLBACK', 'Investigation', StrSubstNo('LineNo=%1', SalesLine."Line No."));
end;
```

Probes firing across multiple runs need a scope boundary: emit `DEBUG-ENTRY` — mechanics in `references/telemetry-workflow.md`.

## Edge cases

| Situation | Action |
|---|---|
| Probes never appear | Same-publisher constraint → `references/telemetry-workflow.md`. Confirm the harness ran. |
| Too much noise | Remove confirmed-wrong branches. Scope with `DEBUG-ENTRY`. |
| Code lives in BaseApp / a third-party / an unmodifiable extension | Temporary event subscriber probe → `references/bc-event-subscriber-pattern.md`. |

## Hand-off state

Zero `DEBUG-*` in tree: `rg "DEBUG-" -g "*.al"` returns nothing.

## Next step

Answered → `Next:` return to the skill that needed the insight — usually `/al-implement` (resume the red→green case the path uncertainty stalled) or `/al-refine` (the spec assumption is now settled). Probes silent / question still open → `Next: /al-steer`.

## Composition

- `/al-build` — runs the test harness, produces `.output/TestResults/*/telemetry.jsonl`.
- `bc-standard-reference` agent — finds BaseApp events for subscriber probes.
