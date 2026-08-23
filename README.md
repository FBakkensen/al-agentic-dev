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

The planning flow uses Azure DevOps work-item tools when available. `/al-event-model` installs its locked BPMN renderer on first use, and `/al-walkthrough` needs the one-time [Web Client walkthrough](#web-client-walkthrough-business-central-mcp) install.

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
copilot plugin list      # al-agentic-dev@al-agentic-dev (v2.4.4)
copilot skill list       # the 22 skills, under "Plugin skills"
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

The Feature and its direct Vertical-slice children live in Azure DevOps work items, so install and authenticate the Azure DevOps MCP server per its own documentation. The plugin deliberately does not bundle it: the server connection is yours, not the plugin's. Without it, planning skills show the exact work-item fields needed and stop; they do not create a competing file-based design record.

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
$plugin = 'al-agentic-dev-overview','al-arc42','al-build','al-clone-bcapps','al-clone-bcquality','al-code-review',
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
| `/al-arc42` | Applies the official arc42 v9.0-EN subset to Level 1, Runtime View, and proven Level 2 content, then writes a local architecture review HTML and Azure DevOps artifacts. |
| `/al-grilling` | Interviews you one consequential decision at a time, rebuilding the context and visual relationships from each earlier answer. |
| `/al-grill-me` | Starts the grilling interview over a plan or design. |
| `/al-wait-what` | Stops the flow and reconnects the last message to prior decisions with plain language and a useful visual. |
| `/al-unslop` | Cuts AI tells from any writing; applies to every reply and artifact. |
| `/al-miner` | Mines session history for repeated failures and steering corrections; proposes standing lessons with evidence, never landing them itself. |
| `/al-lookup` | Answers one platform question with a source pointer — Microsoft Learn, bc-code-intelligence, the BCApps clone, or the BCQuality index — and grows the repo's precedent map. |
| `/al-grill-adr` | Anchors one Azure DevOps Feature, preserves the original request verbatim, settles domain vocabulary, and records hard-to-reverse business rules. |
| `/al-event-model` | Adds the process contract and exhaustive BPMN map, renders it through locked bpmn-js tooling into local review HTML, and supplies Runtime scenarios to `/al-arc42`. |
| `/al-design` | Defines deep-module boundaries and the arc42 Building Block Level 1 with black box contracts; implementation details stay open. |
| `/al-scope` | Keeps an only slice on the Feature; with several, creates one direct child User Story per proven outcome, each with Gherkin Acceptance Criteria. |
| `/al-test-design` | Turns approved Gherkin into a user-reviewed AAA test specification at the caller-visible module interface before implementation. |
| `/al-implement` | Implements reviewed AAA cases through the Level 1 interface, runs `/al-build`, writes the receipt, and adds Level 2 only when code proves stable internals. |
| `/al-refactor` | Tidies green code or performs a named deepening reshape with behavior frozen, updating Level 2 only when internal structure changes. |
| `/al-review` | Returns a read-only verdict against Gherkin, AAA proof, Level 1 ownership, and the accuracy or justified absence of Level 2. |
| `/al-walkthrough` | Walks Gherkin scenarios in the running Web Client through `business-central-mcp`, preserving observed versus expected evidence. |
| `/al-next` | Reconciles landed code, Feature design, direct child slices, receipts, and the next executable item without creating implementation work items. |
| `/al-pr-shepherd` | Drives one open PR to merge — CI watched, Copilot findings fixed, main merged in with intent-preserving conflict resolution — merging only on your explicit go. |
| `/al-orchestrate` | Runs one executable item with reviewed AAA through implementation, bounded refactoring, and read-only review in child sessions. |

Two read-only reviewer agents ride under `agents/` — `al-review-lens` and `al-knowledge-leaf`, serving `/al-review`'s fan-out. `al-grill-me` (mattpocock/skills, MIT) and `al-unslop` (pstack, MIT) are pinned forks: their bodies stay donor text except the al- namespace, provenance pinned at the donor SHAs, and a content fix belongs upstream. `al-grilling` and `al-wait-what` began with the mattpocock donor text and are now maintained here.

Third-party formats and runtime dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

**Migrating from v1:** the Page Scripting recording and replay machinery is gone — `/al-walkthrough` through `business-central-mcp` replaces the slice-end verification walk.

## The hooks

`hooks.json` ships two hooks:

- **ask_user deny** (preToolUse): the ask_user tool is denied with a redirect — questions land in the reply itself, as plain text, with lettered options and the recommendation marked.
- **Session context** (sessionStart): every new or resumed session receives the reply-shape rules and an instruction to invoke `/al-unslop` before writing any reply or artifact. When the working directory is an AL repo (an `app.json` at the root or one directory level deep), the Speak BC vocabulary rule also applies: Insert not create, Post not submit, Ledger Entry not transaction, and so on. In a non-AL directory the vocabulary rule stays out.

One platform caveat: the Copilot CLI currently honors only the **last** sessionStart `additionalContext` across all hook sources, so a user-level sessionStart context hook and this plugin's cannot both inject today — whichever loads last wins.

**Migrating from v1:** earlier versions installed these reply-shape rules as a managed block in `~/.copilot/copilot-instructions.md` (between `<!-- al-agentic-dev:start -->` / `<!-- al-agentic-dev:end -->` markers). Delete that block — the hook replaces it, and the plugin never writes user files.

Re-prove injection after any hooks.json change: `pwsh tests/hooks/Invoke-HookSmoke.ps1` (two paid runs; see tests/README.md).
