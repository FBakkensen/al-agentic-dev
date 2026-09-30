# al-agentic-dev

A Claude Code plugin for Microsoft Dynamics 365 Business Central development: a scripted compile-publish-test gate with containers, coverage, and breaking-change validation underneath, plus the two platform-knowledge clones and a visual steering surface.

One install brings the Agent Skills, a `SessionStart` hook, and two bundled MCP servers: Microsoft Learn supplies current Microsoft documentation, and the Azure DevOps server reads and writes work items. It also installs three Base plugins it builds on: `mattpocock-skills`, `bcquality`, and the AL language server.

The set is mid-rebuild: the earlier 26-skill pipeline is retired, and each new plugin version ports proven skills back in as real work needs them. Git history is the donor archive.

## Requirements

- Windows, PowerShell 7.2+
- Claude Code
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Company Portal-managed Node.js 22+ at `C:\Program Files\nodejs` — `npx` for the al-build gate, the Azure DevOps MCP server, and the al-event-model BPMN renderer
- Azure CLI, signed in with `az login` — the bundled Azure DevOps MCP server authenticates through it
- The VS Code AL extension (`ms-dynamics-smb.al`) — the AL language server exits without it
- In each consumer repo: `al-build.json` at the root for the build gate

`/al-event-model` installs its locked BPMN renderer on first use.

## Install

Add this repository as a marketplace, then install the plugin:

```
/plugin marketplace add fbakkensen/al-agentic-dev
/plugin install al-agentic-dev@al-agentic-dev
```

The marketplace also lists the `bcquality` and `al-language-server-go-windows` Base plugins, so adding it is the only setup. `mattpocock-skills` installs from `claude-plugins-official`, which Claude Code registers on the first interactive session.

Claude Code asks for your Azure DevOps organization (`ado_org`, for example `naveksaas`) when it enables the plugin. The bundled `ado` MCP server connects to it. From Claude Code 2.1.269 you can change the value later in the `/config` panel.

### Verify

Run `/plugin` and confirm `al-agentic-dev` is installed at version `0.9.0`, then run `/mcp` and confirm `microsoft-learn` and `ado` are connected.

### Update

Third-party marketplaces do not auto-update by default, so update the installed plugin yourself: select **Update now** in its `/plugin` Installed details, or run

```
claude plugin update al-agentic-dev@al-agentic-dev
```

Restart Claude Code to apply the update. `/plugin marketplace update al-agentic-dev` refreshes only the marketplace listing.

### Azure DevOps

The Original User Story and its direct Vertical-slice children live in Azure DevOps. `Original` names the User Story that carries the request in this workflow; structural parents above it remain unchanged. The plugin bundles the `ado` MCP server and authenticates it through the Azure CLI. Without it, planning skills show the exact work-item fields needed and stop; they do not create a competing file-based design record.

### Web Client walkthrough

`/al-walkthrough` requires the consumer repository to declare a Business Central workspace MCP for each worktree. The MCP must expose its `bc_*` Web Client tools in the Claude Code session and use the worktree's branch and `al-build.json` configuration.

Keep that MCP declaration in the consumer repository. A user-level MCP starts without one authoritative AL repository, while concurrent worktrees can require different containers and configuration.

After changing branches or `al-build.json`, restart the workspace MCP or Claude Code session before running `/al-walkthrough`.

Verify from a consumer repo whose branch container is up: `bc_list_companies` answers with the container's companies.

## Coming from the Copilot version

Earlier versions were a GitHub Copilot plugin, which does not run in Claude Code, and before that a set of loose per-user skill folders installed with `npx skills add`. Claude Code loads loose skills from `~/.claude/skills`, so a leftover copy there sits beside this plugin's skills under the same names; copies under `~/.agents` and `~/.copilot` are stale and unused.

**1. Detect.** List what those installers left behind (only folders whose names this set has ever shipped — your other personal skills are untouched):

```powershell
$plugin = 'al-agentic-dev-overview','al-arc42','al-build','al-clone-bcapps','al-clone-bcquality','al-code-review',
  'al-design','al-event-model','al-grill-adr','al-grill-me','al-grilling','al-implement','al-knowledge-pass','al-next',
  'al-orchestrate','al-provision','al-quiz','al-refactor','al-refine','al-routing','al-scope','al-spec-review',
  'al-sync-main','al-unslop','al-user-verification','al-validate-breaking-changes','al-visualize','al-wait-what','babysit-pr'
foreach ($dir in "$HOME\.agents\skills", "$HOME\.copilot\skills", "$HOME\.claude\skills") {
  if (Test-Path $dir) { Get-ChildItem $dir -Directory | Where-Object Name -in $plugin }
}
```

**2. Remove.** Delete every folder the detection listed. Nothing else in those directories belongs to this plugin.

**3. Remove the Copilot plugin.** If you installed the Copilot version, close every Copilot session, then uninstall it. While a session holds the plugin's MCP processes, the uninstall fails with `os error 32`.

```
copilot plugin uninstall al-agentic-dev
```

**4. Install fresh** per [Install](#install).

## The skills

| Skill | What it does |
|---|---|
| [`/al-build`](docs/al-build.md) | Compiles, publishes, runs the tests — plus provisioning, breaking-change validation, and the container lifecycle. |
| `/al-clone-bcapps` | Clones Microsoft's W1 source at the matching BC version into `.bcapps/` for reading and searching platform code. |
| `/al-clone-bcquality` | Clones Microsoft's BCQuality knowledge base into `.bcquality/` and builds its knowledge index. |
| `/al-arc42` | Applies the official arc42 v9.0-EN subset to Level 1, Runtime View, and proven Level 2 content, then writes a local architecture review HTML and Azure DevOps artifacts. |
| `/al-lookup` | Answers one platform question with a source pointer — Microsoft Learn, the BCApps clone, or the BCQuality index — and grows the repo's precedent map. |
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
| `/al-pr-shepherd` | Drives one open PR to merge — CI watched, review findings fixed, main merged in with intent-preserving conflict resolution — merging only on your explicit go. |

Third-party formats and runtime dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

**Coming from v1:** the Page Scripting recording and replay machinery is gone — `/al-walkthrough` through the consumer repository's workspace MCP replaces the slice-end verification walk.

## The hook

`hooks/hooks.json` ships one `SessionStart` hook. It runs `hooks/Write-SessionStart.ps1`, which injects the delegation rules from `hooks/session-start.md` in every session: a `▶ <model> · <brief> → <return>` line in a skill is one `Agent` call on `opus`, `sonnet`, or `haiku`, and every child runs in the lead's worktree and branch.
