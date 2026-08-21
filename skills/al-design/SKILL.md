---
name: al-design
description: The architecture conversation in BC shapes — master data, document, journal and posting — settling modules, seams, tables, and extensions into the living design document. Open it for a new feature's shape, or re-open it when discovery bends the old one.
disable-model-invocation: true
---

# al-design — the shape before the code

A human conversation, never automated: sketch the shape before code, and when implementation reports repeated friction, the sketch is wrong — redesign here rather than bolt on guards. The conversation owns architecture and data structure only — which tables and extensions, which Base App seams — and never pre-decides implementation details; those are al-implement's, discovered in flight. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Connect the dots

Ask one substantive question per message. Before it, name the earlier answers and verified facts that cause or constrain it, translated from tactical names into business concepts and relationships. Use one compact text diagram or table when flow, grouping, sequence, boundaries, ownership, or competing consequences are easier seen than described. Explain why the decision comes next. Each option states what changes, what stays possible, and where responsibility lands, plus material risk or reversibility when relevant; mark the recommendation. Exact AL names are secondary coordinates when they help locate, distinguish, or verify something.

## Speak in BC shapes

The first question of any pass: which canonical shape is this — master data with entries, a document flavor, a journal plus a posting extension, setup, dimensions, a number series? The vocabulary lives in `docs/patterns.md`: the canonical BC shapes, each with this repo's own example once one exists — created lazily, and when a shape gains its first example here, this pass writes that line. Every Base App seam, table, or object the conversation names is verified through lookup, never recalled.

## Deep modules, real seams

A module earns its place by hiding substantial behavior behind a small interface. Apply the deletion test in imagination: complexity that vanishes was a pass-through; complexity that reappears across callers earned its keep. A seam needs real variation — one adapter is hypothetical, two are a seam. Compare candidate shapes in the conversation before one is chosen: the user picks with the trade-offs visible.

## The living design

The artifact is `docs/design.md`, committed with a plain descriptive message: the feature's BC shape in one sentence, the module map with a one-line interface each, the seams with both adapters named, the tables and extensions, and the open questions. A mid-feature discovery legally rewrites it — re-entry from al-next's drill is a normal move, not an exception. al-next reconciles this document against the code every loop.

## Pass end

Hand the pass's design delta to the rubber-duck agent — another voice in, the user decides. The GitHub Copilot app engine ships no duck: the pass says the checkpoint skipped. The session continues in the conversation that opened it.
