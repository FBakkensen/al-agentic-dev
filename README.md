# al-agentic-dev

A Claude Code plugin for Microsoft Dynamics 365 Business Central development. It adds the AL specifics to the engineering skills you already use, and ships a scripted compile-publish-test gate.

## What gets installed

One install brings these.

| Component | Comes from | What it gives you |
|---|---|---|
| `al-agentic-dev` | this marketplace | The AL skills below, `SessionStart` and `SubagentStart` hooks that load each AL addition beside its entry skill, and the opt-in `al-agentic-dev:AL` output style |
| `mattpocock-skills` | `claude-plugins-official` | The engineering skills you type: grilling, spec, tickets, implement, TDD, code review |
| `bcquality` | `microsoft/BCQuality` | Microsoft's AL quality knowledge and review skills |
| `al-language-server-go-windows` | `SShadowS/al-lsp-for-agents` | Symbols and compiler diagnostics for `.al` files |
| `microsoft-learn` MCP server | bundled | Current Microsoft documentation |
| `ado` MCP server | bundled | Azure DevOps work items in the organization `naveksaas`, through your Azure CLI sign-in |

## How it works

`mattpocock-skills` owns the process; this plugin adds only what is specific to AL. You type the step you know, such as `/mattpocock-skills:to-spec`. In an AL repository, Claude Code loads that step's AL addition, `/al-to-spec`, beside it: the `SessionStart` hook tells the main session, and the `SubagentStart` hook tells each subagent.

The Base plugins (`mattpocock-skills`, `bcquality`, and the AL language server) are never copied into this plugin and are not pinned, so each updates on its own.

## The flow

| Entry skill | AL addition |
|---|---|
| `/mattpocock-skills:setup-matt-pocock-skills` | `/al-setup-matt-pocock-skills` |
| `/mattpocock-skills:grill-with-docs` | `/al-grill-with-docs` |
| `/mattpocock-skills:to-spec` | `/al-to-spec` |
| `/mattpocock-skills:to-tickets` | `/al-to-tickets` |
| `/mattpocock-skills:implement` | `/al-implement` |
| `/mattpocock-skills:tdd` | `/al-tdd` |
| `/mattpocock-skills:codebase-design` | `/al-codebase-design` |
| `/mattpocock-skills:code-review` | `/al-review` |
| `/simplify` | `/al-simplify` |
| `/mattpocock-skills:improve-codebase-architecture` | `/al-improve-codebase-architecture` |
| `/mattpocock-skills:diagnosing-bugs` | `/al-diagnosing-bugs` |
| `/mattpocock-skills:wayfinder` | `/al-wayfinder` |
| `/mattpocock-skills:prototype` | `/al-prototype` |
| `/mattpocock-skills:research` | `/al-research` |

For an effort too large for one session, `/mattpocock-skills:wayfinder` plans it as a map of decision tickets before `to-spec`.

When a reply does not land, type `/mattpocock-skills:wait-what`. It re-pitches the reply in ASD-STE100 Simplified Technical English with the `CONTEXT.md` terms that `/al-grill-with-docs` keeps.

Skills you type directly:

| Skill | What it does |
|---|---|
| [`/al-build`](docs/al-build.md) | The scripted gate: compiles every app through the analyzer gate and runs the tests through AL Runner (`test.ps1`), runs container tests for `containerTestApps` (`container-test.ps1`), and handles provisioning, breaking-change validation against the Release, and the container lifecycle. |
| `/al-arc42` | Writes settled architecture in the official arc42 v9.0-EN format, with a local architecture review HTML. |
| `/al-walkthrough` | Walks an implemented work item's Gherkin scenarios in the Business Central Web Client of the branch's agent container. |
| `/al-next` | Reconciles landed code with the Original work item's design, its child slices, and their receipts, and names the next executable item. |
| `/al-pr-shepherd` | Drives one open pull request to merge: your comments and CI review findings worked, main merged in, policies read. Completing it is your go. |
| `/al-lookup` | Answers one platform question with a source pointer and grows the repository's precedent map. |
| `/al-webclient` | Loads the Web Client driving rules before any browser call that touches Business Central. |
| `/al-environment-data` | Reads data, GET only, from a SaaS sandbox's API or the branch's agent container. |
| `/al-group-by-feature-into-namespaces` | Groups an app's and its test apps' objects by feature into namespaces under the app's root namespace, applies the map you agree through `/al-build`, and switches the module gate on. |

Other skills call these:

| Skill | What it does |
|---|---|
| `/al-commit` | Stages the full worktree and creates the maximum number of independently valid commits. |
| `/al-clone-bcapps` | Clones Microsoft's BCApps source at the matching BC version for reading platform code. |
| `/al-azure-devops-attachments` | Uploads local files and attaches them to an Azure DevOps work item. |

`/al-pull-request` runs when you ask for a pull request from the current branch: it creates or updates the ready pull request, with the landed change and available proof.

## Requirements

- Windows and PowerShell 7.2+
- Claude Code
- VS Code with the AL extension `ms-dynamics-smb.al` — the AL language server exits without it
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Node.js 22+ with `npx` on PATH (npm comes with it) — `npx` starts the `ado` MCP server, the `/al-build` gate runs on it, and the `/al-to-spec` BPMN renderer runs `npm ci` and exports its review images through an installed Edge, Chrome, or Chromium
- The Azure CLI, signed in with `az login` — the `ado` MCP server authenticates through it
- The GitHub CLI `gh` 2.99.0 or later, signed in with `gh auth login` — for a Consumer repository whose Tracker or Code host is GitHub
- The Azure Boards app, connected to the GitHub organization `naveksadk` — for a GitHub pull request whose Tracker is Azure DevOps, so its `AB#<id>` links resolve
- Playwright CLI: `npm install -g @playwright/cli@latest` — one of the drivers `/al-walkthrough` uses for the Web Client
- In each Consumer repository, `al-build.json` at the root, for the build gate

A claude.ai login is optional. It is used only for the Artifact fallback.

## Install

Add the marketplaces of the Base plugins first, because this plugin depends on plugins from them, then add this marketplace and install:

```
/plugin marketplace add microsoft/BCQuality
/plugin marketplace add SShadowS/al-lsp-for-agents
/plugin marketplace add fbakkensen/al-agentic-dev
/plugin install al-agentic-dev@al-agentic-dev
```

`mattpocock-skills` installs from `claude-plugins-official`, which Claude Code registers on the first interactive session.

The `ado` MCP server is fixed to the Azure DevOps organization `naveksaas` and connects with your Azure CLI sign-in. No prompt appears. It is the only `ado` server skills should see, so do not configure another one in your own settings.

### Opt-ins

Both go in your own settings. No Consumer repository commits either.

- The `al-agentic-dev:AL` output style — Speak BC vocabulary for every BC operation and record, and a diagram for questions that turn on structure. In `~/.claude/settings.json`:

  ```json
  { "outputStyle": "al-agentic-dev:AL" }
  ```

- Plain-text questions: the deny rule turns off the `AskUserQuestion` choice dialog, so skills ask in the chat as plain text. In `~/.claude/settings.json` or `.claude/settings.local.json`:

  ```json
  { "permissions": { "deny": ["AskUserQuestion"] } }
  ```

## Verify

Run `/plugin` and confirm `al-agentic-dev`, `mattpocock-skills`, `bcquality`, and `al-language-server-go-windows` are enabled. Then run `/mcp` and confirm `microsoft-learn` and `ado` are connected.

## Set up a repository

In each Consumer repository, run `/mattpocock-skills:setup-matt-pocock-skills` once. It asks where your issues live, which triage labels to use, and where the domain docs sit, and writes them under `docs/agents/`. Its AL addition then proposes the work item types and fields of that Tracker for the AL skills' verbs, and you confirm or correct them in the draft, so `docs/agents/issue-tracker.md` answers each verb for your Tracker. Any Tracker works: for one other than GitHub or Azure DevOps, the setup answers the verbs from your own description.

## Update

Update each plugin you want to refresh:

```
claude plugin update al-agentic-dev@al-agentic-dev
claude plugin update bcquality@bcquality
claude plugin update al-language-server-go-windows@al-lsp-for-agents
claude plugin update mattpocock-skills@claude-plugins-official
```

A Base plugin updates when its maintainers publish an update, not on every commit.

## Known limits

- The `ado` MCP server is Windows-only.
- The AL language server installs inert on other systems.

Third-party formats and runtime dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md).
