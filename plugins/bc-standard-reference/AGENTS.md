# bc-standard-reference

Locate canonical Business Central Standard behaviour (BaseApp, System Application, APIV2) — events, codeunits, tables, pages, tests.

*Dev-time only — this file never ships. The shipped surface is `agents/` and `references/`; see the root `AGENTS.md` "Shipped artefacts vs dev-time files".*

## Layout

Agent-only plugin — the worker is a declarative custom agent (`.agent.md`), no skill.

```
agents/
└── bc-standard-reference.agent.md   # the agent; reads ../references/ at the plugin root
references/
├── repo-structure.md
├── search-patterns.md
└── scenarios.md
```

## Editing rules

- **Canonical mirror**: `fbakkensen/bc-w1`. Any rename or move requires updating `agents/bc-standard-reference.md` and all three reference files in lockstep.
- **Heuristic tool-agnostic, mechanism is `gh`**: *what* to find and *how to reason about it* stays method-neutral. But the mirror is reached through the `gh` CLI (`gh search code`, `gh repo read-file`, `gh repo read-dir` — preview commands as of gh 2.95.0), never web fetch/scrape of repo content. Web tools serve only the Microsoft Learn cross-check and the `gh`-unavailable fallback. Don't re-genericize the mirror mechanism back to "any browse method" — that reintroduces the slow web-scrape path this plugin was fixed away from. The agent's `tools:` envelope (`read, search, execute, web, al-symbols-mcp/*` — Copilot aliases) is what it *may* reach; `execute` is there for `gh`.
- **Reference split**: `repo-structure.md` (paths), `search-patterns.md` (heuristics), `scenarios.md` (walkthroughs). Keep the split — don't merge. References live at plugin level so the agent reads them from the plugin root's `references/` directory.
- **Composition**: `al-research` agent (the al-agentic-dev agent) reaches this agent as its BaseApp source. When renaming, update `al-research`'s Sources list in lockstep.
