---
name: al-agentic-dev-overview
description: User-facing orientation for the al-agentic-dev plugin — pipeline diagram, 20-skill catalogue plus the custom agents, persistence layers, and cold-start guidance. Use when the user asks "what is al-agentic-dev", "what skills are in here", "show me the pipeline", "where do I start from scratch", or wants a tour. Pure static emit; does not inspect repo state. For state-aware navigation mid-feature ("what should I do next"), the dispatcher should prefer /al-steer.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-agentic-dev-overview, Plugin tour

Read `../../references/overview.md` from this skill's base directory. Emit it verbatim as the whole response. Write nothing and inspect no repository state.

Static tour → what the plugin contains. `/al-steer` → current state and next action. Route "what's next?" and "where are we?" to `/al-steer`; do not tour.

## Next step

Orientation only. `Next: /al-steer` for a state-aware read of the current feature.
