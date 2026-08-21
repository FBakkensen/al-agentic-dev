---
name: al-scope
description: Use when a settled design needs cutting into approved tracer-bullet work items with blocking edges.
---

# al-scope — the frontier is born

Synthesize, never re-interview: the cut comes from `docs/design.md`, `docs/event-model.md`, and the conversation so far — a question those already answer is never asked again. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Connect the dots

Ask one substantive question per message. Before it, name the earlier answers and verified facts that cause or constrain it, translated from tactical names into business concepts and relationships. Use one compact text diagram or table when flow, grouping, sequence, boundaries, ownership, or competing consequences are easier seen than described. Explain why the decision comes next. Each option states what changes, what stays possible, and where responsibility lands, plus material risk or reversibility when relevant; mark the recommendation. Exact AL names are secondary coordinates when they help locate, distinguish, or verify something.

## Tracer bullets

Each bullet cuts through the whole stack — complete, demoable, context-sized — along AL object and test seams: a bullet lands whole objects with their tests, never a layer. Blocking edges are real dependencies, not sequencing habits. A wide refactor runs expand-contract instead of pretending to be a bullet.

## Quiz until approved

Present the cut — the bullets, the edges, what was deliberately left out — and quiz granularity, merges, and splits one decision at a time until the user approves it. The cut is the user's call; the synthesis is this skill's work.

## Land the frontier

The approved bullets land in the store: Azure DevOps work items with native blocking links, through the azure-devops MCP work-item tools; without that wiring, `docs/frontier.md` — one bullet per line with its state and `after:` edges, second-class. al-scope creates the frontier; al-next maintains it from here.

## Pass end

Hand the cut frontier to the rubber-duck agent before the bullets land — another voice in, the user decides. The GitHub Copilot app engine ships no duck: the pass says the checkpoint skipped. Close naming the store and the bullet count; the session rolls into the first /al-next or /al-implement as the user chooses.
