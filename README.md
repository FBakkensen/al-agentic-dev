# al-agentic-dev

A GitHub Copilot plugin that carries a Microsoft Dynamics 365 Business Central feature from a rough idea to a merged branch — domain interview, event model, architecture, work-item scoping, TDD, mutation testing, code review, and a guided user walk, with a scripted compile-publish-test gate underneath.

One install brings the whole surface: twenty-five Agent Skills, three packaged custom agents (`al-review-lens`, `al-spec-reviewer`, `al-knowledge-leaf`), and two bundled MCP servers — NAB AL Tools for XLF translation and Microsoft Learn for current Microsoft documentation.

You drive; nothing auto-chains. A skill that moves a task hands its outcome to `/al-routing`, which records the state and presents the moves that are open. `CONTEXT.md`, `docs/adr/`, and the feature's `specs/` artifacts live in git; task state lives in Azure DevOps work items under the customer's root work item, bound per repo by `al-ado.json` — so every skill starts cold.

## Requirements

- Windows, PowerShell 7.2+
- GitHub Copilot CLI, authenticated to `9altitudes.ghe.com` (`gh auth status -h 9altitudes.ghe.com`)
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Node.js 22+ with `npx` on PATH — runs the bundled NAB AL Tools MCP server
- Azure DevOps access, authenticated with `az login` — task state lives in work items
- In each consumer repo: `al-build.json` at the root for the build gate, and `al-ado.json` naming `organization`, `project`, `rootWorkItemId`, and `areaPath` for the work-item binding

The skills other than `/al-build` are prose and need nothing beyond Copilot itself.

## Install

Came here from an older install? Do [Migrating from `npx skills add`](#migrating-from-npx-skills-add) first — leftover copies silently mask everything below.

### As a marketplace (recommended)

This repository doubles as its own plugin marketplace through `.github/plugin/marketplace.json`, which is what keeps `copilot plugin update` working later:

```
copilot plugin marketplace add https://9altitudes.ghe.com/gtm-general/al-agentic-dev
copilot plugin install al-agentic-dev@al-agentic-dev
```

The full URL matters: the `owner/repo` shorthand always resolves against GitHub.com, and this repository lives on GitHub Enterprise.

### Directly from the repository

```
copilot plugin install https://9altitudes.ghe.com/gtm-general/al-agentic-dev
```

Same plugin, no marketplace registration — and no catalog for `copilot plugin update` to check against, which is why the marketplace form is recommended.

### Verify

```
copilot plugin list      # al-agentic-dev@al-agentic-dev (v1.1.0)
copilot skill list       # the 25 skills, under "Plugin skills"
copilot mcp list         # Plugin servers: nab-al-tools, microsoft-learn
```

The skills must appear under **Plugin skills**. Any of them listed under *Personal skills* is a leftover legacy copy shadowing the plugin — go to [Migrating from `npx skills add`](#migrating-from-npx-skills-add).

### Update

```
copilot plugin update al-agentic-dev
```

### Enable per repository — Copilot app, CLI, and cloud agent

A consumer repo can declare the plugin in `.github/copilot/settings.json`, committed to the repository. Copilot CLI (which the GitHub Copilot app runs on) and the Copilot cloud agent read the same two keys, auto-install the plugin for everyone who works in that repository, and scope it there:

```json
{
  "extraKnownMarketplaces": {
    "al-agentic-dev": {
      "source": {
        "source": "git",
        "url": "https://9altitudes.ghe.com/gtm-general/al-agentic-dev"
      }
    }
  },
  "enabledPlugins": {
    "al-agentic-dev@al-agentic-dev": true
  }
}
```

The auto-install runs when Copilot starts in a trusted checkout of that repository; a user-level install through the commands above works everywhere regardless.

### Azure DevOps MCP server

Task state lives in Azure DevOps work items, so install and authenticate the Azure DevOps MCP server per its own documentation — the pipeline needs its work-item tools available in every session that runs `/al-routing`, `/al-scope`, `/al-next`, or `/al-orchestrate`. The plugin deliberately does not bundle it: the server connection is yours, not the plugin's.

## Migrating from `npx skills add`

Earlier versions of this set installed as loose per-user skill folders. Those copies load **before** plugin skills and silently mask every plugin update, forever — same name, stale text wins, no warning. Remove them once and the plugin takes over.

**1. Detect.** List what the legacy installer left behind (only folders whose names this plugin ships — your other personal skills are untouched):

```powershell
$plugin = 'al-agentic-dev-overview','al-build','al-clone-bcapps','al-clone-bcquality','al-code-review',
  'al-design','al-event-model','al-grill-adr','al-grilling','al-implement','al-knowledge-pass','al-next',
  'al-orchestrate','al-provision','al-quiz','al-refactor','al-refine','al-routing','al-scope','al-spec-review',
  'al-sync-main','al-user-verification','al-validate-breaking-changes','al-visualize','babysit-pr'
foreach ($dir in "$HOME\.agents\skills", "$HOME\.copilot\skills") {
  if (Test-Path $dir) { Get-ChildItem $dir -Directory | Where-Object Name -in $plugin }
}
```

`copilot skill list` shows the same problem from the other side: these names under *Personal skills* instead of *Plugin skills*.

**2. Remove.** Delete every folder the detection listed. Nothing else in those directories belongs to this plugin.

**3. Remove leftover direct installs.** If `copilot plugin list` shows an `al-agentic-dev` installed from a local path or an old source, uninstall it — after closing every Copilot session first. While any session holds the plugin's MCP processes, the uninstall fails with `os error 32` (files held open); it succeeds once the sessions are gone.

```
copilot plugin uninstall al-agentic-dev
```

**4. Install fresh** per [Install](#install), then verify: `copilot plugin list` shows the plugin, `copilot skill list` shows all 25 skills under **Plugin skills** and none of them under *Personal skills*, and `copilot mcp list` shows `nab-al-tools` and `microsoft-learn` as plugin servers.

## The skills

| Skill | What it does |
|---|---|
| [`/al-agentic-dev-overview`](docs/al-agentic-dev-overview.md) | This tour, plus the user-level reply-shape snippet install. |
| `/al-routing` | The state engine — records each skill's outcome on the Azure DevOps work items and derives the open moves. |
| [`/al-next`](docs/al-next.md) | Names the open moves when you resume a session or ask what is next. |
| [`/al-grill-adr`](docs/al-grill-adr.md) | Grills the idea in BC vocabulary, writes `CONTEXT.md`, earns domain ADRs. |
| [`/al-event-model`](docs/al-event-model.md) | Settles the user journey as `event-model.md` — Role, Action, Business Event, View, Status. |
| [`/al-design`](docs/al-design.md) | Settles the architecture as `architecture.md`, comparing candidates with you. |
| [`/al-scope`](docs/al-scope.md) | Cuts `architecture.md` into slices and one work item per unit of work. |
| `/al-orchestrate` | Conducts a scoped feature from the feature session — spawns slice workspaces, runs each skill as its own conversation, relays questions, merges slice PRs on Clean. |
| [`/al-refine`](docs/al-refine.md) | Opens one task into a Test Specification or a Verification Plan. |
| [`/al-implement`](docs/al-implement.md) | Drives one task through TDD — red→green, or a green-born test proved by mutation. |
| [`/al-refactor`](docs/al-refactor.md) | Reshapes production and test code while the gate stays green. |
| [`/al-code-review`](docs/al-code-review.md) | Reviews at slice-done and before merge, splitting rework from change requests. |
| `/al-knowledge-pass` | Runs BCQuality's knowledge pass over a scoped diff; the review skills invoke it mid-run. |
| `/al-spec-review` | Blind-reads a just-written spec artifact against its sources; the writing skills invoke it at close. |
| `/al-visualize` | Draws what a run settled or landed as a steering surface on the Copilot app's side-panel canvas. |
| [`/al-user-verification`](docs/al-user-verification.md) | Walks a slice's verify task with you, one scenario at a time, recordings included. |
| [`/al-build`](docs/al-build.md) | Compiles, publishes, runs the tests — the gate every other skill reaches through. |
| [`/al-provision`](docs/al-provision.md) | Runs the provision task's first step, refreshing compiler, symbols, and baseline. |
| `/al-clone-bcapps` | Runs its second step, cloning Microsoft's W1 source at the matching BC version into `.bcapps/`. |
| `/al-clone-bcquality` | Runs its third step, cloning Microsoft's BCQuality knowledge base into `.bcquality/`. |
| [`/al-validate-breaking-changes`](docs/al-validate-breaking-changes.md) | Runs the feature's last task, validating the shipped surface against that baseline. |
| [`/al-quiz`](docs/al-quiz.md) | Quizzes you on what just landed, one question at a time. |
| `/al-grilling` | Stress-tests one answer at a time; the interview skills escalate to it. |
| [`/al-sync-main`](docs/al-sync-main.md) | Syncs the branch with main and renumbers object and field collisions. |
| `/babysit-pr` | Drives an open PR to a clean review state — Copilot review, findings, CI — and never merges. |

## The pipeline

```
/al-grill-adr → /al-event-model → /al-design → /al-scope → /al-provision
   → /al-refine → /al-implement → /al-refactor
   → /al-code-review → /al-user-verification → /al-validate-breaking-changes
```

`/al-event-model` runs for user- or API-facing features only; backend-only features go straight to `/al-design`. `/al-refine` through `/al-refactor` runs once per task; `/al-code-review` and `/al-user-verification` run once per slice, with `/al-code-review` again across the whole feature before merge. `/al-validate-breaking-changes` is the feature's last task. `/al-quiz` and `/al-sync-main` run whenever you want them. From `/al-scope`'s close, `/al-orchestrate` conducts everything after the entry chain — one workspace per slice, one fresh conversation per skill run — and hands you only what needs you.

Full walkthrough, including the branch points: [docs/pipeline.md](docs/pipeline.md). How a feature ships as a stack of slice PRs, and the two one-time repository settings that stack needs: [docs/stacked-delivery.md](docs/stacked-delivery.md).

## The reply-shape snippet

`/al-agentic-dev-overview` will, on request, install the reply-shape rules these skills assume — one sentence before the first tool call, one question per message, outcome first when finishing. It writes them to `~/.copilot/copilot-instructions.md` inside `<!-- al-agentic-dev:start -->` / `<!-- al-agentic-dev:end -->` markers, so a re-run rewrites only that block. This is user level only — it never writes into the repository you are working in.
