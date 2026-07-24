---
name: al-agentic-dev-overview
description: User-facing orientation for the al-agentic-dev plugin — pipeline diagram, 19-skill catalogue plus the custom agents, persistence layers, and cold-start guidance. Use when the user asks "what is al-agentic-dev", "what skills are in here", "show me the pipeline", "where do I start from scratch", or wants a tour. Pure static emit; does not inspect repo state. For state-aware navigation mid-feature ("what should I do next"), the dispatcher should prefer /al-steer.
---

# /al-agentic-dev-overview, Plugin tour

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

**A tour answers "what is this plugin?"; only `/al-steer` answers "where are we?".** "Where do I start from scratch", with no `specs/` folder yet, is a tour question — the overview's cold-start section answers it. Route mid-feature state questions — "where are we?", "what's next?", a blocked task — to `/al-steer`, which reads branch, `tasks/`, and commits, and stop; do not tour.

For a tour request: read `../../references/overview.md` from this skill's base directory and emit it verbatim as the whole response. Write nothing; inspect no repository state. The emitted overview itself names `/al-steer` as the state-aware next step.
