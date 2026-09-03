---
name: al-setup-models
description: "Use when the model tiers need setting or changing — a new session reports Defaults in use, the user names which model runs a tier, or a model in the map no longer exists in the task tool's model list."
---

# al-setup-models — write the model map

In: the built-in map in [models.default.json](models.default.json) beside this file, any `tier=model` pairs on the invocation line, and the user's existing `~/.copilot/al-agentic-dev/models.json` when present. Out: that file written, and the `# Model tiers` block every later session receives. This skill writes only outside the repository.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Show the map

Read the built-in file. Apply each `tier=model` pair from the invocation line to its row. Show three rows as `tier · model · effort · what it is for`:

- `frontier` — design, judgment, verdicts, uncertain work
- `execution` — writing code and tests from a brief
- `mechanical` — running gates, commits, renders, lookups, knowledge leaves

When the existing file differs from the proposal, show its rows beside the proposal. Ask one question: **A** adopt the map as shown (recommended), **B** change rows.

## Change rows

On B, list the models the `task` tool's `model` parameter description offers in this session — the names and the efforts each supports come from that description, never from recall. Ask one question per row the user wants changed, lettered from that list with the built-in value marked. An effort outside the chosen model's set is corrected in the proposal and named, not asked. Return to the map once every changed row is settled.

## Write the file

Create `~/.copilot/al-agentic-dev/` when absent and write `models.json`:

```json
{"version":1,"tiers":{"frontier":{"model":"<model>","effort":"<effort>"},"execution":{"model":"<model>","effort":"<effort>"},"mechanical":{"model":"<model>","effort":"<effort>"}}}
```

Show the written file. The sessionStart hook reads it at every session start; a missing or unparseable tier falls back to the built-in row and the injected block names it.

## Close

Close with the `# Model tiers` block as the hook will inject it — the three rows, then the dispatch rule — and two facts: this session uses the map from now; every later session gets it at start. Agent pins, the plugin install, and per-repo overrides stay out.
