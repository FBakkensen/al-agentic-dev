# al-agentic-dev

A GitHub Copilot plugin for Microsoft Dynamics 365 Business Central development: a scripted compile-publish-test gate with containers, coverage, and breaking-change validation underneath, plus the two platform-knowledge clones and a visual steering surface.

One install brings the whole surface: the Agent Skills, two packaged custom agents (`al-review-lens`, `al-knowledge-leaf`), and three bundled MCP servers — NAB AL Tools for XLF translation, Microsoft Learn for current Microsoft documentation, and bc-code-intelligence for BC idioms and patterns.

The set is mid-rebuild: the earlier 26-skill pipeline is retired, and each new plugin version ports proven skills back in as real work needs them. Git history is the donor archive.

## Requirements

- Windows, PowerShell 7.2+
- GitHub Copilot CLI, authenticated to `9altitudes.ghe.com` (`gh auth status -h 9altitudes.ghe.com`)
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Node.js 22+ with `npx` on PATH — runs the bundled NAB AL Tools MCP server
- In each consumer repo: `al-build.json` at the root for the build gate

The skills other than `/al-build` are prose and need nothing beyond Copilot itself — except `/al-walkthrough`, which needs the one-time [Web Client walkthrough](#web-client-walkthrough-business-central-mcp) install.

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
copilot plugin list      # al-agentic-dev@al-agentic-dev (v1.12.0)
copilot skill list       # the 20 skills, under "Plugin skills"
copilot mcp list         # Plugin servers: nab-al-tools, microsoft-learn, bc-code-intelligence
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

The frontier lives in Azure DevOps work items, so install and authenticate the Azure DevOps MCP server per its own documentation — `/al-next` works the work items through its tools. The plugin deliberately does not bundle it: the server connection is yours, not the plugin's. Without it, `/al-next` keeps the frontier in `docs/frontier.md`, explicitly second-class.

### Web Client walkthrough (business-central-mcp)

`/al-walkthrough` drives the running Web Client through [business-central-mcp](https://github.com/SShadowS/business-central-mcp) (MIT, BC27/BC28 wire-compatible) — the client's native WebSocket protocol, structured field reads, no browser. The plugin deliberately does not bundle this one either: the container URL and credentials it needs are your machine's. One-time, user-level: add the `business-central` entry to `~/.copilot/mcp-config.json` (merge into `mcpServers` when the file already has one), and keep the key name `business-central` — tool ids derive from it (`business-central-bc_open_page` and so on):

```json
{
  "mcpServers": {
    "business-central": {
      "type": "stdio",
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-Command",
        "$n=(git rev-parse --abbrev-ref HEAD) -replace '[/\\\\]','-' -replace '[^\\w-]',''; $c=@{username='admin';password='P@ssw0rd'}; $f=Join-Path (git rev-parse --show-toplevel) 'al-build.json'; if(Test-Path $f){$j=(Get-Content $f -Raw|ConvertFrom-Json).container; if($j.username){$c.username=$j.username}; if($j.password){$c.password=$j.password}}; $env:BC_BASE_URL='http://'+$n+'/BC'; $env:BC_USERNAME=$c.username; $env:BC_PASSWORD=$c.password; $env:BC_APPLICATION_ID='NAV'; [Console]::OutputEncoding=[Text.Encoding]::UTF8; npx -y business-central-mcp"
      ]
    }
  }
}
```

The inline wrapper resolves everything per session at launch, in the session's working directory: the agent container name from the current git branch, sanitized exactly as `/al-build` does (`/` and `\` become `-`, every other non-word character drops); the credentials from the consumer repo's root `al-build.json` (`container.username` / `container.password`, defaulting to `admin` / `P@ssw0rd`); then `BC_BASE_URL=http://<container>/BC`.

Two behaviors worth knowing:

- `BC_APPLICATION_ID=NAV` is load-bearing on the on-prem BcContainerHelper artifacts `/al-build` provisions. With the default `FIN`, sign-in and the WebSocket upgrade succeed and the session then dies inside the OpenSession RPC with `NavCancelCredentialPromptException` — a misleading failure the package's own README documents.
- The server starts fine with no container up: the session loads, the `bc_*` tools appear, and only their calls fail until the branch container exists. No restart is needed once it does.

Verify from a consumer repo whose branch container is up: `bc_list_companies` answers with the container's companies.

## Migrating from `npx skills add`

Earlier versions of this set installed as loose per-user skill folders. Those copies load **before** plugin skills and silently mask every plugin update, forever — same name, stale text wins, no warning. Remove them once and the plugin takes over.

**1. Detect.** List what the legacy installer left behind (only folders whose names this set has ever shipped — your other personal skills are untouched):

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

**4. Install fresh** per [Install](#install), then verify: `copilot plugin list` shows the plugin, `copilot skill list` shows its skills under **Plugin skills** and none of them under *Personal skills*, and `copilot mcp list` shows `nab-al-tools`, `microsoft-learn`, and `bc-code-intelligence` as plugin servers.

## The skills

| Skill | What it does |
|---|---|
| [`/al-build`](docs/al-build.md) | Compiles, publishes, runs the tests — plus provisioning, breaking-change validation, and the container lifecycle. |
| `/al-clone-bcapps` | Clones Microsoft's W1 source at the matching BC version into `.bcapps/` for reading and searching platform code. |
| `/al-clone-bcquality` | Clones Microsoft's BCQuality knowledge base into `.bcquality/` and builds its knowledge index. |
| `/al-visualize` | Draws the BC-anatomy delta — objects, events, flows as boxes and connections — on the Copilot app's side-panel canvas; al-next invokes it when the shape changed. |
| `/al-grilling` | Interviews you one consequential decision at a time, rebuilding the context and visual relationships from each earlier answer. |
| `/al-grill-me` | Starts the grilling interview over a plan or design. |
| `/al-wait-what` | Stops the flow and reconnects the last message to prior decisions with plain language and a useful visual. |
| `/al-unslop` | Cuts AI tells from any writing; applies to every reply and artifact. |
| `/al-miner` | Mines session history for repeated failures and steering corrections; proposes standing lessons with evidence, never landing them itself. |
| `/al-lookup` | Answers one platform question with a source pointer — Microsoft Learn, bc-code-intelligence, the BCApps clone, or the BCQuality index — and grows the repo's precedent map. |
| `/al-implement` | Drives one frontier bullet to landed code — red-green at its pre-agreed seams, /al-build as the checker — and closes on a receipt with the gate verdict and the assumptions ledger. |
| `/al-refactor` | Reshapes green code with behavior frozen — the routine tidy pass after every green, or a named deepening goal that upgrades to the full reshape (subtract first, migrate callers before deleting) — and proves the hold with the full gate. |
| `/al-review` | Reads a diff ledger-first — standards through the BCQuality Entry protocol, spec side by side, the six AL anatomy axes, blast radius proven by running code — and returns a Blocking/Non-Blocking verdict without touching a line; beauty is never a finding, it lands on the one Refactor food line. |
| `/al-walkthrough` | Walks a landed slice in the running Web Client through `business-central-mcp` — scenarios confirmed with you first, observed vs expected verbatim per scenario, closing with pass/fail and a hand-reproduction recipe. |
| `/al-next` | The loop transition: capsule, delta drawn, design reconciled, one grilling round, frontier reshaped and the next bullet sharpened — the frontier in Azure DevOps work items, or docs/frontier.md without that wiring. |
| `/al-grill-adr` | The pipeline entry: interviews a fresh feature idea until the vocabulary is unambiguous — CONTEXT.md at the repo root, hard-to-reverse business rules as ADRs, big fog charted as decision items on the frontier. |
| `/al-design` | The architecture conversation in BC shapes — modules, seams, tables, extensions — writing the living docs/design.md that /al-next reconciles. |
| `/al-event-model` | The living eventing picture — publishers, subscribers, business events through posting — in docs/event-model.md, updated the moment understanding changes. |
| `/al-scope` | Cuts the settled design into tracer-bullet work items with blocking edges, quizzes until the cut is approved, and creates the frontier /al-next maintains. |
| `/al-pr-shepherd` | Drives one open PR to merge — CI watched, Copilot findings fixed, main merged in with intent-preserving conflict resolution — merging only on your explicit go. |
| `/al-orchestrate` | Runs one ready bullet through the whole loop — implement, refactor, review, the tidy beat skipped only when implement reports nothing to tidy — pausing only at declared decisions and ending at the review verdict. |

Two read-only reviewer agents ride under `agents/` — `al-review-lens` and `al-knowledge-leaf`, serving `/al-review`'s fan-out. `al-grill-me` (mattpocock/skills, MIT) and `al-unslop` (pstack, MIT) are pinned forks: their bodies stay donor text except the al- namespace, provenance pinned at the donor SHAs, and a content fix belongs upstream. `al-grilling` and `al-wait-what` began with the mattpocock donor text and are now maintained here.

**Migrating from v1:** the Page Scripting recording and replay machinery is gone — `/al-walkthrough` through `business-central-mcp` replaces the slice-end verification walk.

## The hooks

`hooks.json` ships two hooks:

- **ask_user deny** (preToolUse): the ask_user tool is denied with a redirect — questions land in the reply itself, as plain text, with lettered options and the recommendation marked.
- **Session voice** (sessionStart): every new or resumed session receives the reply-shape rules as additional context, and — only when the working directory is an AL repo (an `app.json` at the root or one directory level deep) — the Speak BC vocabulary rule: Insert not create, Post not submit, Ledger Entry not transaction, and so on. In a non-AL directory the vocabulary rule stays out.

One platform caveat: the Copilot CLI currently honors only the **last** sessionStart `additionalContext` across all hook sources, so a user-level sessionStart context hook and this plugin's cannot both inject today — whichever loads last wins.

**Migrating from v1:** earlier versions installed these reply-shape rules as a managed block in `~/.copilot/copilot-instructions.md` (between `<!-- al-agentic-dev:start -->` / `<!-- al-agentic-dev:end -->` markers). Delete that block — the hook replaces it, and the plugin never writes user files.

Re-prove injection after any hooks.json change: `pwsh tests/hooks/Invoke-HookSmoke.ps1` (two paid runs; see tests/README.md).
