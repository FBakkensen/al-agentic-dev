# al-agentic-dev

Twenty-three Agent Skills that carry a Microsoft Dynamics 365 Business Central feature from a rough idea to a merged branch — domain interview, event model, architecture, task breakdown, TDD, mutation testing, code review, and a guided user walk, with a scripted compile-publish-test gate underneath.

They are harness-neutral. Every skill is a `SKILL.md` with two frontmatter keys and no file crossing a folder boundary, so the same folder runs in Claude Code, GitHub Copilot CLI, VS Code Copilot, and Codex. No custom agents, no hooks, no plugin manifests.

You drive; nothing auto-chains. A skill that moves a task hands its outcome to `/al-routing`, which records the state and presents the moves that are open. State lives on disk — `CONTEXT.md` and `docs/adr/` at the repo root, `specs/<NNN>-<slug>/` and its `tasks/` folder on the feature branch — so every skill starts cold.

## Install

### Azure DevOps organization

The plugin uses the organization-neutral Azure DevOps MCP endpoint. To bind it to your organization, add this server to `~/.copilot/mcp-config.json`, replacing `YOUR_ORGANIZATION`:

```json
{
  "mcpServers": {
    "azure-devops": {
      "type": "http",
      "url": "https://mcp.dev.azure.com/YOUR_ORGANIZATION",
      "tools": [
        "core_list_projects",
        "wit_backlog",
        "wit_query",
        "wit_work_item",
        "wit_work_item_comment_write",
        "wit_work_item_link_write",
        "wit_work_item_write"
      ]
    }
  }
}
```

This repository lives on GitHub Enterprise at `9altitudes.ghe.com`. Pass the full URL and the host is unambiguous, whatever your `gh` is pointed at:

```
npx skills add https://9altitudes.ghe.com/gtm-general/al-agentic-dev --skill '*'
```

You need `gh` authenticated to the instance — check with `gh auth status -h 9altitudes.ghe.com`.

### Pinning to a release

`npx skills` only parses the `@tag` suffix on the `owner/repo` shorthand, and it resolves that shorthand against whichever host your `gh` currently defaults to. To pin, point it at this instance for that one command:

```bash
# bash / zsh — scoped to the single command
GH_HOST=9altitudes.ghe.com npx skills add gtm-general/al-agentic-dev@v1.0.0 --skill '*'
```

```powershell
# PowerShell — $env: is process-wide, so restore it afterwards
$prev = $env:GH_HOST
$env:GH_HOST = '9altitudes.ghe.com'
try   { npx skills add gtm-general/al-agentic-dev@v1.0.0 --skill '*' }
finally { $env:GH_HOST = $prev }
```

Leaving `GH_HOST` set would send your *next* `npx skills add` to this instance too, which is why it is scoped rather than exported.

### Update

```
npx skills update
```

No host handling here at all: the lockfile records each skill's fully resolved source URL, so every skill updates from wherever it came from.

### Install one skill

Name it instead of `'*'`. Every skill is self-contained, so that works — `/al-provision`, `/al-validate-breaking-changes`, and `/al-user-verification` declare `/al-build` as a prerequisite *skill*, which is a name and not a path.

## The skills

| Skill | What it does |
|---|---|
| [`/al-agentic-dev-overview`](docs/al-agentic-dev-overview.md) | This tour, plus the user-level snippet install below. |
| `/al-routing` | The state engine — records each skill's outcome on the task files and derives the open moves. |
| [`/al-next`](docs/al-next.md) | Names the open moves when you resume a session or ask what is next. |
| [`/al-grill-adr`](docs/al-grill-adr.md) | Grills the idea in BC vocabulary, writes `CONTEXT.md`, earns domain ADRs. |
| [`/al-event-model`](docs/al-event-model.md) | Settles the user journey as `event-model.md` — Role, Action, Business Event, View, Status. |
| [`/al-design`](docs/al-design.md) | Settles the architecture as `architecture.md`, comparing candidates with you. |
| [`/al-scope`](docs/al-scope.md) | Cuts `architecture.md` into slices and one task file per unit of work. |
| [`/al-refine`](docs/al-refine.md) | Opens one task into a Test Specification or a Verification Plan. |
| [`/al-implement`](docs/al-implement.md) | Drives one task through TDD — red→green, or a green-born test proved by mutation. |
| [`/al-refactor`](docs/al-refactor.md) | Reshapes production and test code while the gate stays green. |
| [`/al-code-review`](docs/al-code-review.md) | Reviews at slice-done and before merge, splitting rework from change requests. |
| [`/al-user-verification`](docs/al-user-verification.md) | Walks a slice's verify task with you, one scenario at a time, recordings included. |
| [`/al-build`](docs/al-build.md) | Compiles, publishes, runs the tests — the gate every other skill reaches through. |
| [`/al-provision`](docs/al-provision.md) | Runs the feature's first task, refreshing compiler, symbols, and baseline. |
| [`/al-validate-breaking-changes`](docs/al-validate-breaking-changes.md) | Runs the feature's last task, validating the shipped surface against that baseline. |
| [`/al-quiz`](docs/al-quiz.md) | Quizzes you on what just landed, one question at a time. |
| `/al-visualize` | Renders a decision or a landed change as a read-only HTML decision surface you read beside the chat interview. |
| [`/al-sync-main`](docs/al-sync-main.md) | Rebases the branch onto main and renumbers object and field collisions. |

## The pipeline

```
/al-grill-adr → /al-event-model → /al-design → /al-scope → /al-provision
   → /al-refine → /al-implement → /al-refactor
   → /al-code-review → /al-user-verification → /al-validate-breaking-changes
```

`/al-event-model` runs for user- or API-facing features only; backend-only features go straight to `/al-design`. `/al-refine` through `/al-refactor` runs once per task; `/al-code-review` and `/al-user-verification` run once per slice, with `/al-code-review` again across the whole feature before merge. `/al-validate-breaking-changes` is the feature's last task. `/al-quiz` and `/al-sync-main` run whenever you want them.

Full walkthrough, including the branch points: [docs/pipeline.md](docs/pipeline.md).

## The reply-shape snippet

`/al-agentic-dev-overview` will, on request, install the reply-shape rules these skills assume — one sentence before the first tool call, one question per message, outcome first when finishing. It writes them to `~/.agents/AGENTS.md` and mirrors them into `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.copilot/copilot-instructions.md` inside `<!-- al-agentic-dev:start -->` / `<!-- al-agentic-dev:end -->` markers, so a re-run rewrites only that block. This is user level only — it never writes into the repository you are working in.

## Requirements

`/al-build` runs a scripted toolchain and needs PowerShell 7.2+, Docker Desktop, the .NET SDK, Node.js 22+ with `npx` on PATH, and BcContainerHelper, plus an `al-build.json` in the consumer repo root. The rest of the skills are prose and need nothing beyond the harness. See [docs/al-build.md](docs/al-build.md).

The four interview skills — `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-refine` — escalate to `/al-grilling` when an answer itself needs pressure. It ships with the set, adapted with minimal edits from [mattpocock/skills](https://github.com/mattpocock/skills)' `grilling`. Nothing here depends on a skill it doesn't ship.
