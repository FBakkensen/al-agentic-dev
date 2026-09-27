# Claude Code plugin and marketplace layout on github.com

Research for [#9](https://github.com/FBakkensen/al-agentic-dev/issues/9). Sources are the Claude Code docs at code.claude.com (fetched 2026-09-27, Claude Code v2.1.283 installed locally) and the `microsoft/azure-devops-mcp` README. Claims marked **validated** were confirmed by running `claude plugin validate --strict` (v2.1.283) against a scratch copy of the proposed layout.

## Answer in brief

- One repo serves as both the marketplace and the plugin: `.claude-plugin/marketplace.json` with one entry `"source": "./"`, plus `.claude-plugin/plugin.json`. Every other component stays at the repo root in its default location: `skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`.
- `plugin.json` needs only `name`. Set `version` in `plugin.json` and nowhere else. Drop the `skills`/`agents`/`hooks`/`mcpServers` keys, because the defaults already cover them.
- Hooks use the `settings.json` shape: PascalCase events (`SessionStart`, `PreToolUse`), then matcher groups, then handlers. Context is injected through `hookSpecificOutput.additionalContext`.
- Plugin agents take `model` as an alias (`opus`, `sonnet`, `haiku`, `fable`, `inherit`) or a full ID. `tools` takes Claude Code tool names (`Read, Grep, Glob, Bash`) and `mcp__plugin_<plugin>_<server>__*` for bundled MCP servers.
- Per-user MCP config comes from `userConfig` in `plugin.json`, referenced as `${user_config.KEY}` in `.mcp.json`. Plain `${ENV_VAR}` / `${VAR:-default}` expansion also works. Secrets stay out of the repo either way: `sensitive: true` values go to the OS keychain, and the ADO server can use `--authentication azcli`.
- **Validated breaking difference:** the Copilot per-server `tools` allowlist in `.mcp.json` is invalid in Claude Code. The loader **silently drops the whole server**.
- Install from github.com: `/plugin marketplace add FBakkensen/al-agentic-dev`, then `/plugin install al-agentic-dev@al-agentic-dev`.

## 1. Repository layout

Source: [Plugin manifest reference: Standard layout](https://code.claude.com/docs/en/plugins/manifest-reference.md#standard-layout), [Marketplace reference: Marketplace file](https://code.claude.com/docs/en/plugins/marketplace-reference.md#marketplace-file).

```text
al-agentic-dev/                      marketplace root = plugin root
├── .claude-plugin/
│   ├── marketplace.json             was .github/plugin/marketplace.json
│   └── plugin.json                  was ./plugin.json
├── skills/<name>/SKILL.md           unchanged (default location)
├── agents/<name>.md                 default location; scanned recursively
├── hooks/hooks.json                 was ./hooks.json
└── .mcp.json                        unchanged location, content changes (see 5)
```

- Only the manifest goes inside `.claude-plugin/`. Everything else sits at the plugin root.
- The marketplace file must be at `.claude-plugin/marketplace.json`. If it lives elsewhere, `claude plugin marketplace add` cannot find it, and users would have to declare it through `extraKnownMarketplaces` with a `path`.
- How manifest keys combine with the default locations ([source](https://code.claude.com/docs/en/plugins/manifest-reference.md#how-each-key-combines-with-its-default-location)):
  - `skills` **adds** to the `skills/` scan.
  - `agents` **replaces** the `agents/` scan and accepts only `.md` files, never directories.
  - `hooks` and `mcpServers` **merge** with `hooks/hooks.json` and `.mcp.json`.
  - All component paths must start with `./`.
- Consequence: the current `"agents": "agents/"` would be rejected twice over (no `./`, and it names a directory), and `"skills": "skills/"` lacks `./`. Omit all four keys.
- A `CLAUDE.md` at the plugin root is **not** loaded as context, and the validator warns about one ([source](https://code.claude.com/docs/en/plugins/components.md#skills)). The repo's own dev-time `CLAUDE.md` is fine for working on this repo, but it ships nothing to users. Put shipped instructions in skills or hooks.
- `bin/` goes on the Bash `PATH`. `settings.json` at the plugin root supports only `agent` and `subagentStatusLine`, so **a plugin cannot ship permission rules**.

## 2. `plugin.json`

Source: [Plugin manifest reference: Fields](https://code.claude.com/docs/en/plugins/manifest-reference.md#fields).

- **Required:** `name` (kebab-case). Every component is namespaced under it.
- **Useful:** `version`, `description`, `author{name,email,url}`, `homepage`, `repository`, `license`, `keywords`, `userConfig`, `dependencies`, `defaultEnabled`.
- **Unknown keys:** an unknown top-level key is stripped with a validator warning. Unknown keys inside `userConfig` options are errors.
- **Versioning:** setting `version` pins users to it until it changes, so bump it per release, which matches the per-package bump. Otherwise omit it everywhere and users track commits. Do not set it in both `plugin.json` and the marketplace entry: `plugin.json` wins silently and the validator reports the mismatch ([source](https://code.claude.com/docs/en/plugins/host-marketplace.md#release-a-new-version)).

The current `plugin.json` becomes:

```json
{
  "name": "al-agentic-dev",
  "displayName": "AL Agentic Dev",
  "version": "5.0.0",
  "description": "Agentic AL and Business Central development skills.",
  "author": { "name": "Naveksa" },
  "repository": "https://github.com/FBakkensen/al-agentic-dev",
  "license": "MIT",
  "userConfig": {
    "ado_org": {
      "type": "string",
      "title": "Azure DevOps organization",
      "description": "Organization name as in https://dev.azure.com/<org>",
      "required": true
    }
  }
}
```

`userConfig` is included only if the plugin bundles the ADO server (see 5). The version number is illustrative; the major bump is the migration decision.

**Naming consequence:** plugin skills are invoked as `/<plugin>:<skill>`, so `/al-build` becomes `/al-agentic-dev:al-build`, and agents become `al-agentic-dev:al-review-lens` ([source](https://code.claude.com/docs/en/plugins/components.md#skills)). The doubled `al-` prefix, and whether skill bodies keep writing `/al-build`, is an **open naming question** for the downstream ticket. It is not decided here.

## 3. `marketplace.json`

Source: [Marketplace reference: Top-level fields / Plugin entries](https://code.claude.com/docs/en/plugins/marketplace-reference.md#top-level-fields).

- **Required:** `name`, `owner{name}`, `plugins[]`.
- **Optional:** `description` (the validator warns when it is missing), `version`, `metadata.*`.
- **Plugin entries:** each needs `name` and `source`. `"./"` or `"."` means the marketplace root itself.
- **Relative sources:** they resolve only when the marketplace is added from a git/github/directory source, which is our case.
- **Marketplace name:** users type it after `@`. It must not be a reserved name; `al-agentic-dev` is not reserved.

The current `.github/plugin/marketplace.json` becomes `.claude-plugin/marketplace.json`:

```json
{
  "name": "al-agentic-dev",
  "owner": { "name": "Naveksa" },
  "description": "Agentic AL and Business Central development skills.",
  "plugins": [
    {
      "name": "al-agentic-dev",
      "source": "./",
      "description": "Agentic AL and Business Central development skills."
    }
  ]
}
```

The changes from the current file:
- Drop both `version` fields (the one under `metadata` and the one in the entry), because `plugin.json` owns the version.
- Change `owner` from 9Altitudes to Naveksa, per ADR 0001.

## 4. Hooks: file format and events

Sources:
- [Hooks reference: Configuration](https://code.claude.com/docs/en/hooks.md#configuration)
- [Command hook fields](https://code.claude.com/docs/en/hooks.md#command-hook-fields)
- [JSON output](https://code.claude.com/docs/en/hooks.md#json-output)
- [Add context for Claude](https://code.claude.com/docs/en/hooks.md#add-context-for-claude)
- [SessionStart](https://code.claude.com/docs/en/hooks.md#sessionstart)
- [PreToolUse decision control](https://code.claude.com/docs/en/hooks.md#pretooluse-decision-control)
- [Plugin components: Hooks](https://code.claude.com/docs/en/plugins/components.md#hooks)

`hooks/hooks.json` holds a top-level `"hooks"` object in the same shape as `settings.json`. The nesting is event, then matcher group, then handler:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "AskUserQuestion",
        "hooks": [ { "type": "command", "command": "…", "timeout": 15 } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "pwsh",
                     "args": ["-NoProfile", "-File", "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.ps1"] } ] }
    ]
  }
}
```

Mapping from the current Copilot `hooks.json`:

| Copilot | Claude Code |
|---|---|
| `preToolUse`, `sessionStart` (camelCase) | `PreToolUse`, `SessionStart`. **Validated:** camelCase gives `unknown hook event; entry ignored at runtime` |
| handler directly in the event array, with `matcher` on it | matcher group `{ "matcher": …, "hooks": [handler] }` |
| `bash` + `powershell` twin strings | one `command`. Shell form (no `args`) runs Git Bash on Windows, or PowerShell when Git Bash is absent. `"shell": "powershell"` forces it. Exec form (`command` + `args`) spawns the executable directly with no shell |
| `timeoutSec` | `timeout` (seconds, default 600 for command hooks) |
| `"version": 1` | not part of the schema. **Validated:** the validator neither warns nor fails on it, but drop it |
| matcher `ask_user` | `AskUserQuestion` (the Claude Code tool name) |
| `{"permissionDecision":"deny",…}` at top level | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`. The top-level form is deprecated for PreToolUse. The reason is shown to Claude on `deny` |
| `{"additionalContext": …}` at top level | `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"…"}}`. For SessionStart, plain stdout on exit 0 also reaches Claude's context |
| `cwd` parsed from stdin JSON | still on stdin (`cwd`, `session_id`, `hook_event_name`, `source`, `model`, …). `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA`, and `CLAUDE_PLUGIN_OPTION_<KEY>` are also exported to the hook process |

Event facts that matter for our two hooks:

- **Where `additionalContext` lands:** it is wrapped in a system reminder. For SessionStart and SubagentStart it goes at the start of the conversation. For PreToolUse and PostToolUse it goes next to the tool result.
- **The 10,000-character cap:** it applies to each `additionalContext` string. Longer text is spilled to a file, and only a 2,000-character preview is injected. Today's reply-shape, Speak BC, and tier table add up to roughly 3k characters, well within the cap.
- **Phrasing:** the docs advise writing injected text as factual statements. Text framed as out-of-band system commands can trigger prompt-injection defenses.
- **SessionStart matchers:** the event fires with matcher values `startup`, `resume`, `clear`, `compact`, and `fork`. **Recommend no matcher**, so the injected rules are re-added after `/clear` and compaction. Only `command` and `mcp_tool` handler types are supported.
- **SessionStart does not reach subagents.** A non-fork subagent's initial context is limited to four things: its own system prompt, the task message, the CLAUDE.md hierarchy, and git status ([Sub-agents: What loads at startup](https://code.claude.com/docs/en/sub-agents.md#what-loads-at-startup)). The main conversation's history, including SessionStart context, is not part of it. Forks are the exception. The carrier into subagents (`al-review-lens`, `al-knowledge-leaf`, `task`-style children) is a **`SubagentStart`** hook returning `additionalContext`, which lands at the start of the subagent's conversation. A plugin agent's own frontmatter `hooks` are ignored ([source](https://code.claude.com/docs/en/plugins/components.md#frontmatter-fields-in-plugin-agents)), so this must be a plugin-level hook.
- **Plugin hooks inside subagents:** plugin hooks also fire inside subagents for tool events, and the input carries `agent_id` and `agent_type`.
- **`AskUserQuestion` in subagents:** Claude Code removes `AskUserQuestion` from **every subagent**'s tool pool ([Sub-agents: Available tools](https://code.claude.com/docs/en/sub-agents.md#available-tools)). The original defect behind the ask_user deny hook, a child session hanging on a question, is therefore handled natively for subagents. A `PreToolUse` deny on `AskUserQuestion` now only affects the main session. Keeping or dropping it is for the downstream hooks ticket.
- **`${user_config.*}` in hooks:** shell-form hooks reject `${user_config.*}`. Use exec form, or read `$CLAUDE_PLUGIN_OPTION_<KEY>`.
- **Script paths:** use exec form with `${CLAUDE_PLUGIN_ROOT}` so a path with spaces is one argument. On Windows, exec form needs a real `.exe` such as `pwsh.exe` or `node.exe`, not a `.cmd` shim.
- **Where the hook logic can live:** the 7 KB inline bash and PowerShell one-liners can become one script under `hooks/`, run through exec form. That script is plugin content rather than a skill body, so the rule "no `.ps1` outside `skills/al-build`" would need its wording checked.

The model-tier state file `~/.copilot/al-agentic-dev/models.json` has two Claude-native replacements:
- `${CLAUDE_PLUGIN_DATA}` (`~/.claude/plugins/data/<id>/`), which is kept across plugin updates.
- `userConfig` options, whose non-sensitive values are stored under `pluginConfigs` in the user's settings.

## 5. Bundled MCP servers and per-user configuration

Sources:
- [MCP: Plugin-provided MCP servers](https://code.claude.com/docs/en/mcp.md#plugin-provided-mcp-servers)
- [Environment variable expansion in .mcp.json](https://code.claude.com/docs/en/mcp.md#environment-variable-expansion-in-mcp-json)
- [Manifest reference: User configuration](https://code.claude.com/docs/en/plugins/manifest-reference.md#user-configuration)
- [Plugin components: When the configuration dialog appears](https://code.claude.com/docs/en/plugins/components.md#when-the-configuration-dialog-appears)

- **Format:** `.mcp.json` at the plugin root uses the project `.mcp.json` shape, `{ "mcpServers": { name: config } }`. The config fields are:
  - stdio servers: `command`/`args`/`env`
  - remote servers: `type: "http"|"sse"|"ws"`, `url`, `headers`, `headersHelper`
  - any server: `alwaysLoad`
- **Names:** the server registers as `plugin:al-agentic-dev:<server>`. Its tools are `mcp__plugin_al-agentic-dev_<server>__<tool>`. Use that full form in agent `tools`, permission rules, and hook matchers; a matcher on the bare server name never fires.
- **No per-server tool allowlist.** **Validated:** the current `"tools": [...]` key on `microsoft-learn` gives `mcpServers.microsoft-learn.tools.0: Invalid input. The plugin loader silently drops this server at load.` It must be removed. Tool surface is narrowed in other ways:
  - the server's own flags, such as ADO `-d core work work-items`
  - agent `tools`/`disallowedTools`
  - user permission rules
  - MCP tool search, which defers tool schemas out of context by default

  Plugins can't ship permission rules (section 1).
- **Per-user values without secrets in the repo:**
  1. **`userConfig` + `${user_config.KEY}`** (preferred for org/project names):
     - **Prompting:** Claude Code prompts in `/plugin` when the plugin is installed or enabled, and `/plugin configure al-agentic-dev@al-agentic-dev` reopens the prompt. `claude plugin install` from a shell never prompts; pass `--config ado_org=naveksaas` instead.
     - **Storage:** values go under `pluginConfigs` in user settings. `sensitive: true` values go to the OS keychain, or `~/.claude/.credentials.json` as a fallback.
     - **Where it substitutes:** stdio `command`/`args`/`env`, and http `url`/`headers`.
     - **Validated:** `"${user_config.ado_org}"` in `args` passes the validator.
  2. **Environment expansion:** `${VAR}` and `${VAR:-default}` expand in `command`, `args`, `env`, `url`, and `headers`. An unset variable with no default leaves the literal text and a `/mcp` warning. Claude Code's own and cloud credential variables read as empty in remote `url`/`headers`.
  3. **Path variables:** `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, `${CLAUDE_PROJECT_DIR}`.
- **Azure DevOps authentication** ([azure-devops-mcp README](https://github.com/microsoft/azure-devops-mcp/blob/main/README.md), [GETTINGSTARTED](https://github.com/microsoft/azure-devops-mcp/blob/main/docs/GETTINGSTARTED.md#authentication)):
  - **Interactive:** the default is browser sign-in.
  - **Azure CLI:** `--authentication azcli` reuses `az login`, and nothing secret touches config.
  - **Avoid** `envvar` (`ADO_MCP_AUTH_TOKEN`) and `pat` (`PERSONAL_ACCESS_TOKEN`), which put secrets in the environment.
  - **Domains:** `-d` limits the tool domains, and `core` should always be included.
  - **Remote server:** Microsoft recommends its remote server at `https://mcp.dev.azure.com/{organization}`, which would take `"url": "https://mcp.dev.azure.com/${user_config.ado_org}"`.

Proposed `.mcp.json`:

```json
{
  "mcpServers": {
    "microsoft-learn": { "type": "http", "url": "https://learn.microsoft.com/api/mcp" },
    "ado": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@azure-devops/mcp", "${user_config.ado_org}",
               "-d", "core", "work", "work-items", "repositories", "search",
               "--authentication", "azcli"]
    }
  }
}
```

**Windows evidence:** the user's working, user-scoped ADO server is registered as `Command: cmd`, `Args: /c npx -y @azure-devops/mcp naveksaas -d core repositories work-items search work --authentication azcli` (`claude mcp get ado`, status Connected). The docs don't state the `cmd /c` wrapper requirement. The wrapper makes the file Windows-only, so bare `npx` versus `cmd /c npx` versus the remote http server is a decision for the MCP ticket.

**Bundling decision:** if the plugin bundles `ado` and a user also has a user-scoped `ado`, both load under different names (`plugin:al-agentic-dev:ado` vs `ado`), with different tool names. Skills that name `mcp__ado__*` tools would need to target one of them.

## 6. Plugin agents: frontmatter, models, tools

Sources:
- [Plugin components: Frontmatter fields in plugin agents](https://code.claude.com/docs/en/plugins/components.md#frontmatter-fields-in-plugin-agents)
- [Sub-agents: Supported frontmatter / Choose a model / Available tools](https://code.claude.com/docs/en/sub-agents.md#choose-a-model)
- [Model configuration: Model aliases](https://code.claude.com/docs/en/model-config.md#model-aliases)

- **Supported fields in plugin agents:** `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation` (`worktree`), `color`, `experimental.cacheTtl`.
- **Ignored fields:** `permissionMode`, `hooks`, `mcpServers`, `initialPrompt`.
- **Required:** only `name` and `description`. `name` must not contain `:`, and the loaded name is `al-agentic-dev:<name>`.
- **`model`:**
  - Values: an alias (`sonnet`, `opus`, `haiku`, `fable`; `best` exists as a session alias), a full ID such as `claude-opus-5-5`, or `inherit`.
  - Aliases track the provider's recommended version.
  - Resolution order: per-invocation `model` parameter, then frontmatter, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the main model.
  - A family alias resolves to the main conversation's exact model when the main model is in that family.
  - `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` overrides every definition.
- **`effort`:** `low|medium|high|xhigh|max`. It replaces the effort column of the Copilot tier table.
- **`tools`:** a comma-separated string or YAML list of Claude Code tool names. `mcp__<server>__*` patterns grant a whole server.
  - If no entry resolves, the agent refuses to launch with "Agent would be spawned with zero tools". The validator does **not** catch this (**validated:** the current `al-review-lens.agent.md` passes `claude plugin validate`).
  - Background subagents keep only `Read, Grep, Glob, LSP, Bash, PowerShell, Edit, Write, NotebookEdit, WebFetch, WebSearch, TodoWrite, Skill, ToolSearch, …`, plus all MCP tools.
- **Filename:** the `agents/` scan is recursive, and a subfolder becomes part of the name. `al-review-lens.agent.md` passes `claude plugin validate`, but its runtime load was not tested. The docs say the frontmatter `name` sets the agent name. Renaming the files to `<name>.md` is the documented convention. The repo gate rule "name equals filename stem" needs updating either way.

Current agents become:

```yaml
# agents/al-review-lens.md
---
name: al-review-lens
description: Reads one scoped AL/Business Central diff through exactly one review dimension named in the prompt and returns grounded findings. Invoked by al-review, one invocation per dimension.
tools: Read, Grep, Glob, Bash, mcp__plugin_al-agentic-dev_microsoft-learn__*
model: sonnet        # was gpt-5.6-sol (execution tier); alias choice belongs to the model-tier ticket
effort: medium
---
```

```yaml
# agents/al-knowledge-leaf.md
---
name: al-knowledge-leaf
description: …unchanged…
tools: Read, Grep, Glob, Bash
model: haiku         # was gpt-5.6-luna (mechanical tier)
effort: max
---
```

Copilot-to-Claude tool mapping: `view` → `Read`, `grep` → `Grep`, `glob` → `Glob`, `execute` → `Bash` (or `PowerShell`), `microsoft-learn/*` → `mcp__plugin_al-agentic-dev_microsoft-learn__*`.

## 7. Installing from the github.com marketplace

Sources: [Install and manage plugins](https://code.claude.com/docs/en/plugins/install.md#add-a-marketplace), [Host and maintain a marketplace](https://code.claude.com/docs/en/plugins/host-marketplace.md#turn-on-auto-update), [Settings reference: extraKnownMarketplaces](https://code.claude.com/docs/en/settings-reference.md#extraknownmarketplaces).

```text
/plugin marketplace add FBakkensen/al-agentic-dev          # owner/repo; append #ref to pin a branch or tag
/plugin install al-agentic-dev@al-agentic-dev              # opens details, pick scope, userConfig dialog

# or from a shell / setup script (never prompts for userConfig):
claude plugin marketplace add FBakkensen/al-agentic-dev
claude plugin install al-agentic-dev@al-agentic-dev --scope user --config ado_org=naveksaas

# or one step in a session (v2.1.275+):
/plugin install al-agentic-dev --marketplace FBakkensen/al-agentic-dev
```

- **Install scopes:**
  - `user` writes `~/.claude/settings.json` `enabledPlugins`.
  - `project` writes `.claude/settings.json` and is committed. Each collaborator still runs the install once.
  - `local` writes `.claude/settings.local.json`.
- **Consumer repositories in Azure Repos** can commit this `.claude/settings.json`. It registers the marketplace and enables the plugin for collaborators once they accept workspace trust:

  ```json
  {
    "extraKnownMarketplaces": {
      "al-agentic-dev": { "source": { "source": "github", "repo": "FBakkensen/al-agentic-dev" } }
    },
    "enabledPlugins": { "al-agentic-dev@al-agentic-dev": true }
  }
  ```

- **Private repositories:** clones use the user's existing git credentials and never prompt. `owner/repo` shorthand tries SSH first, then HTTPS, and `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` forces HTTPS.
- **Updates:** background auto-update is **off** by default for third-party marketplaces. A user enables it per marketplace in `/plugin` → Marketplaces. Otherwise updates come through `/plugin marketplace update al-agentic-dev` or `claude plugin update al-agentic-dev@al-agentic-dev`. Users receive a new copy only when `version` changes.

## 8. Verification recipe for the migration

Run these four commands in CI:

1. `claude plugin validate --strict .`, which validates `marketplace.json`
2. `claude plugin validate --strict .claude-plugin/plugin.json`, which validates the manifest paths, the `.mcp.json` server schema (v2.1.281+), and the `hooks/hooks.json` schema and event names
3. `claude plugin validate --strict agents`
4. `claude plugin validate --strict skills`

The last two check that frontmatter parses. Each command supports `--json` output and exits non-zero on failure. None of them checks that agent `tools` entries resolve.
