# al-agentic-dev

A GitHub Copilot plugin for Microsoft Dynamics 365 Business Central development: a scripted compile-publish-test gate with containers, coverage, and breaking-change validation underneath, plus the two platform-knowledge clones and a visual steering surface.

One install brings the Agent Skills, two packaged custom agents (`al-review-lens`, `al-knowledge-leaf`), and three bundled MCP servers. NAB AL Tools handles XLF translation, Microsoft Learn supplies current Microsoft documentation, and bc-code-intelligence covers BC idioms and patterns.

The set is mid-rebuild: the earlier 26-skill pipeline is retired, and each new plugin version ports proven skills back in as real work needs them. Git history is the donor archive.

## Requirements

- Windows, PowerShell 7.2+
- GitHub Copilot CLI, authenticated to `9altitudes.ghe.com` (`gh auth status -h 9altitudes.ghe.com`)
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Company Portal-managed Node.js 20+ at `C:\Program Files\nodejs` — runs the bundled stdio MCP servers
- In each consumer repo: `al-build.json` at the root for the build gate

The planning flow uses Azure DevOps work-item tools when available. `/al-event-model` installs its locked BPMN renderer on first use.

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
copilot plugin list      # al-agentic-dev@al-agentic-dev (v2.4.13)
copilot skill list       # the 25 skills, under "Plugin skills"
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

The Original User Story and its direct Vertical-slice children live in Azure DevOps, so install and authenticate the Azure DevOps MCP server per its own documentation. `Original` names the User Story that carries the request in this workflow; structural parents above it remain unchanged. The plugin deliberately does not bundle the server: the connection is yours. Without it, planning skills show the exact work-item fields needed and stop; they do not create a competing file-based design record.

### Web Client walkthrough

`/al-walkthrough` requires the consumer repository to declare a Business Central workspace MCP for each worktree. The MCP must expose its `bc_*` Web Client tools in the Copilot session and use the worktree's branch and `al-build.json` configuration.

Keep that MCP declaration in the consumer repository. A user-level MCP starts without one authoritative AL repository, while concurrent worktrees can require different containers and configuration.

After changing branches or `al-build.json`, restart the workspace MCP or Copilot session before running `/al-walkthrough`.

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
| `/al-azure-devops-attachments` | Uploads local files through Azure CLI credentials, attaches them to an Azure DevOps work item, and guides the user through authentication when needed. |
| `/al-commit` | Stages the full worktree and creates the maximum number of independently valid commits with scoped Azure DevOps links. |
| `/al-pull-request` | Pushes the current branch and creates or updates its ready pull request with the landed change and available proof. |
| `/al-grill-adr` | Anchors one Original Azure DevOps User Story, preserves the original request verbatim, settles domain vocabulary, and records hard-to-reverse business rules. |
| `/al-event-model` | Adds the process contract and exhaustive BPMN map, renders it through locked bpmn-js tooling into local review HTML, and supplies Runtime scenarios to `/al-arc42`. |
| `/al-design` | Defines deep-module boundaries and the arc42 Building Block Level 1 with black box contracts; implementation details stay open. |
| `/al-scope` | Keeps an only slice on the Original User Story; with several, creates one direct child User Story per proven outcome. |
| `/al-test-design` | Writes the reviewed AAA test specification after any Gherkin behavior in Acceptance Criteria. |
| `/al-implement` | Implements reviewed AAA cases through the Level 1 interface, runs `/al-build`, writes the receipt, and adds Level 2 only when code proves stable internals. |
| `/al-refactor` | Tidies green code or performs a named deepening reshape with behavior frozen, updating Level 2 only when internal structure changes. |
| `/al-review` | Returns a read-only verdict against Gherkin, AAA proof, Level 1 ownership, and the accuracy or justified absence of Level 2. |
| `/al-walkthrough` | Walks Gherkin scenarios in the running Web Client through the consumer repository's workspace MCP, preserving observed versus expected evidence. |
| `/al-next` | Reconciles landed code, Original User Story design, direct child slices, receipts, and the next executable item without creating implementation work items. |
| `/al-pr-shepherd` | Drives one open PR to merge — CI watched, Copilot findings fixed, main merged in with intent-preserving conflict resolution — merging only on your explicit go. |
| `/al-orchestrate` | Runs one executable item with reviewed AAA through implementation, bounded refactoring, and read-only review in child sessions. |

Two read-only reviewer agents ride under `agents/` — `al-review-lens` and `al-knowledge-leaf`, serving `/al-review`'s fan-out. `al-grill-me` (mattpocock/skills, MIT) and `al-unslop` (pstack, MIT) are pinned forks: their bodies stay donor text except the al- namespace, provenance pinned at the donor SHAs, and a content fix belongs upstream. `al-grilling` and `al-wait-what` began with the mattpocock donor text and are now maintained here. The two agents' pins follow the model tiers — `al-review-lens` at execution, `al-knowledge-leaf` at mechanical — and a `▶` line's tier override wins at dispatch.

Third-party formats and runtime dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

**Migrating from v1:** the Page Scripting recording and replay machinery is gone — `/al-walkthrough` through the consumer repository's workspace MCP replaces the slice-end verification walk.

## The hooks

`hooks.json` ships two hooks, the second carrying three blocks:

- **ask_user deny** (preToolUse): the ask_user tool is denied with a redirect — questions land in the reply itself, as plain text, with lettered options and the recommendation marked.
- **Session context** (sessionStart): every new or resumed session receives the reply-shape rules and the model tiers — a `# Model tiers` table read from `~/.copilot/al-agentic-dev/models.json`, falling back per tier to the shipped defaults in `skills/al-setup-models/models.default.json` with a `Defaults in use — run /al-setup-models to set your models.` line, followed by the dispatch rule for `▶ <tier> · <vehicle> · <brief> → <return>` lines. When the working directory is an AL repo (an `app.json` at the root or one directory level deep), the Speak BC vocabulary rule also applies: Insert not create, Post not submit, Ledger Entry not transaction, and so on. In a non-AL directory the vocabulary rule stays out.

One platform caveat: the Copilot CLI currently honors only the **last** sessionStart `additionalContext` across all hook sources, so a user-level sessionStart context hook and this plugin's cannot both inject today — whichever loads last wins.

**Migrating from v1:** earlier versions installed these reply-shape rules as a managed block in `~/.copilot/copilot-instructions.md` (between `<!-- al-agentic-dev:start -->` / `<!-- al-agentic-dev:end -->` markers). Delete that block — the hook replaces it, and the plugin never writes user files.

Re-prove injection after any hooks.json change: `pwsh tests/hooks/Invoke-HookSmoke.ps1` (two paid runs; see tests/README.md).
