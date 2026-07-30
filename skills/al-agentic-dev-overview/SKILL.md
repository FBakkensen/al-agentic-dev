---
name: al-agentic-dev-overview
description: Tour of the AL agentic-dev toolkit and where to start. Use when the user asks what these skills are, or when the user asks to install or update the reply-shape snippet at user level. Detects only the kind of place it runs in — mid-feature, /al-next names the open moves from tasks/.
---

# AL agentic dev — the tour

These skills carry a Business Central feature from a rough idea to a merged branch. You drive; nothing auto-chains. A skill that moves a task hands its outcome to `/al-routing`, which records it and presents the open moves. State lives on disk — `CONTEXT.md` and `docs/adr/` at repo root, `specs/<NNN>-<slug>/` and its `tasks/` folder on the feature branch — so every skill starts cold.

## The tour

Emit five sections in order, one screen in total; the skills table below is reference for follow-up questions, never emitted whole.

1. One line naming what the toolkit is — the user drives, nothing auto-chains.
2. **Pipeline** — the flow below.
3. **Support skills** — one line: `/al-routing`, `/al-next`, `/al-build`, `/al-quiz`, `/al-grilling`, `/al-sync-main`.
4. **Start here** — the line the detection picks. Search the tree for `app.json`; it is rarely at the repo root. Found beside a `specs/<NNN>-<slug>/` folder at repo root → mid-feature, run `/al-next`. Found without `specs/` → cold start, begin at `/al-grill-adr` — a crystallised idea may skip it, most gain from it. Not found → `cd` into the AL repo, then re-run. Detection names the kind of place only; the open moves belong to `/al-next`.
5. **Snippet** — only when the check below finds a home missing or stale: the final paragraph, on its own, naming the stale homes and the words that run the install — "install the snippet".

## Pipeline

```
/al-grill-adr → /al-event-model → /al-design → /al-scope
   → /al-provision → /al-clone-bcapps → /al-clone-bcquality
   → /al-refine → /al-implement → /al-refactor → /al-mutate
   → /al-code-review → /al-user-verification → /al-validate-breaking-changes
```

`/al-event-model` runs for user- or API-facing features only; backend-only features go straight to `/al-design`. `/al-refine` through `/al-mutate` runs once per task; `/al-code-review` and `/al-user-verification` run once per slice, with `/al-code-review` again across the whole feature before merge. `/al-quiz` and `/al-sync-main` run whenever you want them. Whichever of `/al-event-model` or `/al-design` runs first creates the branch and the spec folder.

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
| `/al-clone-bcquality` | Runs its third step, cloning Microsoft's BCQuality knowledge base into `.bcquality/`. |
| `/al-validate-breaking-changes` | Runs the feature's last task, validating the shipped surface against that baseline. |
| `/al-quiz` | Quizzes you on what just landed, one question at a time. |
| `/al-grilling` | Stress-tests one answer at a time; the interview skills escalate to it. |
| `/al-sync-main` | Rebases the branch onto main and renumbers object and field collisions. |

## The reply-shape snippet

[AGENTS-SNIPPET.md](AGENTS-SNIPPET.md) holds the reply-shape rules these skills assume. The check behind the tour's Snippet section: `~/.agents/AGENTS.md` must equal the snippet file, and each mirror — `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.copilot/copilot-instructions.md` — must carry it verbatim between `<!-- al-agentic-dev:start -->` and `<!-- al-agentic-dev:end -->`; a home missing or differing is stale. The check gates the offer only — when the user asks, install regardless, at user level only, keeping it out of the repository being worked on.

1. Write the snippet to `~/.agents/AGENTS.md`, the canonical home.
2. Mirror it into the other three homes, wrapped in the two markers. A re-run replaces what sits between them and leaves the rest of each file as it was. Once a harness reads `~/.agents/AGENTS.md` directly, drop its mirror.

The tour emitted is the outcome; its Start here line is the user's next move — mid-feature, `/al-next`.
