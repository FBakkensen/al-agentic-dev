# al-agentic-dev

A Claude Code plugin for Microsoft Dynamics 365 Business Central development. It is an add-on to three Base plugins: [mattpocock-skills](https://github.com/mattpocock/skills) for engineering discipline, `bcquality` for Microsoft's AL quality knowledge, and the AL language server. You type the mattpocock-skills steps you already know; in an AL repository, each step also loads its AL addition, which adds only the AL and Azure DevOps specifics. The plugin also ships a scripted compile-publish-test gate with containers, coverage, and breaking-change validation.

One install brings the Agent Skills, a `SessionStart` hook, and two bundled MCP servers: `microsoft-learn` supplies current Microsoft documentation, and `ado` reads and writes Azure DevOps work items.

## Requirements

- Windows and PowerShell 7.2+
- Claude Code
- VS Code with the AL extension `ms-dynamics-smb.al` — the AL language server exits without it
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Node.js 22+ with `npx` on PATH — `npx` starts the `ado` MCP server, and the BPMN renderer in `/al-to-spec` runs on it
- The Azure CLI, signed in with `az login` — the `ado` MCP server authenticates through it
- Playwright CLI: `npm install -g @playwright/cli@latest` — one of the drivers `/al-walkthrough` uses for the Web Client
- In each Consumer repository, `al-build.json` at the root, for the build gate

A claude.ai login is optional. It is used only for the Artifact fallback.

## Install

1. Run `claude plugin list`. If it shows `bcquality@bcquality`, run `claude plugin uninstall bcquality@bcquality` first. This plugin brings its own `bcquality`, and two copies shadow each other's skills.
2. Remove any personal user-level `ado` MCP entry, so skills see only the plugin's `ado` tools.
3. Add the marketplace, then install the plugin:

   ```
   /plugin marketplace add fbakkensen/al-agentic-dev
   /plugin install al-agentic-dev@al-agentic-dev
   ```

The marketplace also lists the `bcquality` and `al-language-server-go-windows` Base plugins, so adding it is the only setup. `mattpocock-skills` installs from `claude-plugins-official`, which Claude Code registers on the first interactive session.

The `ado` MCP server is fixed to the Azure DevOps organization `naveksaas` and connects with your Azure CLI sign-in. No prompt appears.

### Opt-ins

Both go in your own settings. No Consumer repository commits either.

- The `al-agentic-dev:AL` output style — Speak BC vocabulary in every word, and a diagram for questions that turn on structure. In `~/.claude/settings.json`:

  ```json
  { "outputStyle": "al-agentic-dev:AL" }
  ```

- Plain-text questions instead of `AskUserQuestion` prompts. In `~/.claude/settings.json` or `.claude/settings.local.json`:

  ```json
  { "permissions": { "deny": ["AskUserQuestion"] } }
  ```

## Verify

Run `/plugin` and confirm `al-agentic-dev` is installed at version `0.9.0`. Then run `/mcp` and confirm `microsoft-learn` and `ado` are connected.

## Update

Run

```
claude plugin update al-agentic-dev@al-agentic-dev
```

Fixes to `bcquality` and the AL language server arrive only when the Base plugin's maintainers bump `version`, never through commits alone.

## Known limits

- The `ado` MCP server is Windows-only.
- The AL language server installs inert on other systems.

## The flow

Type the entry skill; in an AL repository, the `SessionStart` hook has Claude Code load its AL addition beside it.

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

Skills you type directly:

| Skill | What it does |
|---|---|
| [`/al-build`](docs/al-build.md) | The scripted gate: compiles every app through the analyzer gate and runs the tests through AL Runner (`test.ps1`), runs container tests for `containerTestApps` (`container-test.ps1`), and handles provisioning, breaking-change validation against the Release, and the container lifecycle. |
| `/al-arc42` | Writes settled architecture in the official arc42 v9.0-EN format, with a local architecture review HTML. |
| `/al-walkthrough` | Walks an implemented work item's Gherkin scenarios in the Business Central Web Client of the branch's agent container. |
| `/al-next` | Reconciles landed code with the Original work item's design, its child slices, and their receipts, and names the next executable item. |
| `/al-pr-shepherd` | Drives one open Azure Repos pull request to merge: your comments worked, main merged in, policies read. Completing it is your go. |
| `/al-lookup` | Answers one platform question with a source pointer and grows the repository's precedent map. |
| `/al-webclient` | Loads the Web Client driving rules before any browser call that touches Business Central. |
| `/al-environment-data` | Reads data, GET only, from a SaaS sandbox's API or the branch's agent container. |

Other skills call these:

| Skill | What it does |
|---|---|
| `/al-commit` | Stages the full worktree and creates the maximum number of independently valid commits. |
| `/al-clone-bcapps` | Clones Microsoft's BCApps source at the matching BC version for reading platform code. |
| `/al-azure-devops-attachments` | Uploads local files and attaches them to an Azure DevOps work item. |

`/al-pull-request` runs when you ask for a pull request from the current branch: it creates or updates the ready pull request, with the landed change and available proof.

Third-party formats and runtime dependencies are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md).
