---
name: al-scope
description: Cut the settled design into tracer-bullet work items with blocking edges — synthesized from what is already answered, quizzed until the cut is approved, landed in the frontier store. Type it when the design is settled and no frontier exists yet.
disable-model-invocation: true
---

# al-scope — the frontier is born

Synthesize, never re-interview: the cut comes from `docs/design.md`, `docs/event-model.md`, and the conversation so far — a question those already answer is never asked again. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Tracer bullets

Each bullet cuts through the whole stack — complete, demoable, context-sized — along AL object and test seams: a bullet lands whole objects with their tests, never a layer. Blocking edges are real dependencies, not sequencing habits. A wide refactor runs expand-contract instead of pretending to be a bullet.

## Quiz until approved

Present the cut — the bullets, the edges, what was deliberately left out — and quiz granularity, merges, and splits until the user approves it. The cut is the user's call; the synthesis is this skill's work.

## Land the frontier

The approved bullets land in the store: Azure DevOps work items with native blocking links, through the azure-devops MCP work-item tools; without that wiring, `docs/frontier.md` — one bullet per line with its state and `after:` edges, second-class. al-scope creates the frontier; al-next maintains it from here.

## Pass end

Hand the cut frontier to the rubber-duck agent before the bullets land — another voice in, the user decides. The GitHub Copilot app engine ships no duck: the pass says the checkpoint skipped. Close naming the store and the bullet count; the session rolls into the first /al-next or /al-implement as the user chooses.
