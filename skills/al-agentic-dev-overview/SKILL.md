---
name: al-agentic-dev-overview
description: Tour of the AL agentic-dev toolkit and where to start. Use when the user asks what these skills are, or when the user asks to install the reply-shape snippet at user level. Reads no repository state — mid-feature, /al-next names the next move from tasks/.
---

# AL agentic dev — the tour

These skills carry a Business Central feature from a rough idea to a merged branch. You drive; nothing auto-chains. A skill that moves a task hands its outcome to `/al-routing`, which records it and presents the open moves. State lives on disk — `CONTEXT.md` and `docs/adr/` at repo root, `specs/<NNN>-<slug>/` and its `tasks/` folder on the feature branch — so every skill starts cold.

## Pipeline

```
/al-grill-adr → /al-event-model → /al-design → /al-scope
   → /al-provision → /al-clone-bcapps
   → /al-refine → /al-implement → /al-refactor → /al-mutate
   → /al-code-review → /al-user-verification → /al-validate-breaking-changes
```

`/al-event-model` runs for user- or API-facing features only; backend-only features go straight to `/al-design`. `/al-refine` through `/al-mutate` runs once per task; `/al-code-review` and `/al-user-verification` run once per slice, with `/al-code-review` again across the whole feature before merge. `/al-quiz` and `/al-sync-main` run whenever you want them.

## The skills

| Skill | What it does |
|---|---|
| `/al-agentic-dev-overview` | This tour, plus the user-level snippet install below. |
| `/al-routing` | The state engine — records each skill's outcome on the task files and derives the open moves. |
| `/al-next` | Names the open moves when you resume a session or ask what is next. |
| `/al-grill-adr` | Grills the idea in BC vocabulary, writes `CONTEXT.md`, earns domain ADRs. |
| `/al-event-model` | Settles the user journey as `event-model.md` — Role, Action, Business Event, View, Status. |
| `/al-design` | Settles the architecture as `architecture.md`, comparing candidates with you. |
| `/al-scope` | Cuts `architecture.md` into slices and one task file per unit of work. |
| `/al-refine` | Opens one task into a Test Specification or a Verification Plan. |
| `/al-implement` | Drives one task red→green, Unit cases before Integration cases. |
| `/al-refactor` | Reshapes production and test code while the gate stays green. |
| `/al-mutate` | Injects one mutation at a time to prove the tests bite. |
| `/al-code-review` | Reviews at slice-done and before merge, splitting rework from change requests. |
| `/al-user-verification` | Walks a slice's verify task with you, one scenario at a time, recordings included. |
| `/al-build` | Compiles, publishes, runs the tests — the gate every other skill reaches through. |
| `/al-provision` | Runs the provision task's first step, refreshing compiler, symbols, and baseline. |
| `/al-clone-bcapps` | Runs its second step, cloning Microsoft's W1 source at the matching BC version into `.bcapps/`. |
| `/al-validate-breaking-changes` | Runs the feature's last task, validating the shipped surface against that baseline. |
| `/al-quiz` | Quizzes you on what just landed, one question at a time. |
| `/al-grilling` | Stress-tests one answer at a time; the interview skills escalate to it. |
| `/al-sync-main` | Rebases the branch onto main and renumbers object and field collisions. |

## Cold start — nothing written down yet

From the default branch with no `specs/<NNN>-<slug>/` folder, start at `/al-grill-adr` and follow the pipeline above. Whichever of `/al-event-model` or `/al-design` runs first creates the branch and the spec folder. A crystallised idea may skip `/al-grill-adr`; most gain from it.

## The reply-shape snippet

[AGENTS-SNIPPET.md](AGENTS-SNIPPET.md) holds the reply-shape rules these skills assume. Install it when the user asks, at user level only — keep it out of the repository being worked on.

1. Write the snippet to `~/.agents/AGENTS.md`, the canonical home.
2. Mirror it into `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.copilot/copilot-instructions.md`, wrapped in `<!-- al-agentic-dev:start -->` and `<!-- al-agentic-dev:end -->`.

A re-run replaces what sits between those two markers and leaves the rest of each file as it was. Once a harness reads `~/.agents/AGENTS.md` directly, drop its mirror.

The user has the map and the entry point for the work in front of them.

Then `/al-next`.
