---
name: al-debug-logging
description: Temporarily add `DEBUG-*` `FeatureTelemetry.LogUsage` probes to AL code to inspect runtime state via `.output/TestResults/*/telemetry.jsonl`. Use when runtime behaviour diverges from source and tests alone can't reveal which path ran. Probes are temporary; remove before delivery.
allowed-tools: ["read", "edit"]
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-debug-logging — temporary runtime probe loop

Add `DEBUG-*` `FeatureTelemetry.LogUsage` probes, exercise one AL path, read `telemetry.jsonl`, then remove the probes. One question per iteration. Final state → zero `DEBUG-*` calls in tree.

## Precondition

`rg "DEBUG-" -g "*.al"` must return nothing. Existing `DEBUG-*` calls are leftover scaffolding → **Stop.** Finish or remove the prior investigation first.

## Flow

1. **Hypothesis.** Name the specific question — which branch, which subscriber, which code path.
2. **Probe.** One or two `FeatureTelemetry.LogUsage` calls. Prefix every event ID `DEBUG-`. Place inside the chosen branch, not around the decision. Binary branch → two peer probes, one per branch.
3. **Run.** Exercise the AL path: page action, posted document, web service call, install/upgrade codeunit, job queue task, event subscriber, or test via `/al-build`. Harness is whatever fires the code.
4. **Inspect.** Run `rg "DEBUG-" .output/TestResults/*/telemetry.jsonl` for the `/al-build` harness; other harnesses capture elsewhere. Silent probes → **Stop.** See `references/telemetry-workflow.md` for the capture path and same-publisher cause.
5. **Refine or remove.** Answered → delete probes. Unanswered → move or add a peer at the next decision. Report probe ID, emitted value, and the named code path it proves ran (pre-send check 3, [voice-contract.md](../../references/voice-contract.md)).

## Canonical probe

```al
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
begin
    FeatureTelemetry.LogUsage('DEBUG-PRICING-FALLBACK', 'Investigation', StrSubstNo('UnitPrice=%1', SalesLine."Unit Price"));
end;
```

**Drop list.** Log counts, IDs, enum values, and booleans — shape, never contents. No full record bodies, PII, credentials, tokens, or secrets; one prediction per probe, never a trace dump. Use stable descriptive suffixes (`DEBUG-PRICING-FALLBACK`), never numeric (`DEBUG-1`); use `FeatureTelemetry.LogUsage`, never `Session.LogMessage`.

**`DEBUG-ENTRY` for correlation.** When several probes fire across multiple runs (multi-test, repeated subscriber, BaseApp shared code), emit `DEBUG-ENTRY` at the start of a scope you control. Everything between two `DEBUG-ENTRY` entries belongs to the first scope.

## Edge cases

| Situation | Action |
|---|---|
| Probes never appear | Same-publisher constraint → see `references/telemetry-workflow.md`. Confirm harness ran. |
| Too much noise | Remove confirmed-wrong branches. Add `DEBUG-ENTRY` to scope. |
| Code lives in BaseApp / third-party / unmodifiable extension | Temporary event subscriber probe → see `references/bc-event-subscriber-pattern.md`. |

**Hand-off state: zero `DEBUG-*` in tree.** `rg "DEBUG-" -g "*.al"` returns nothing. An intentionally retained probe carries an issue/scope comment so the next pass knows it is deliberate.

## Next step

Probes are gone; the runtime answered the question. `Next:` return to the skill that needed the insight — usually `/al-implement` (resume the red→green case the path uncertainty stalled) or `/al-refine` (the spec assumption is now settled). Probes silent / question still open → `Next: /al-steer`.

## Composition

- `/al-build` — runs test harness, produces `.output/TestResults/*/telemetry.jsonl`.
- `bc-standard-reference` agent — finds BaseApp events for subscriber-based probes.

## Out of scope

- Long-lived production telemetry. Probes are scaffolding.
- Diagnosing without a hypothesis.
