# Base plugins as unpinned dependencies

This plugin is an add-on, not a standalone set: `plugin.json` declares three base plugins by their own identity — `mattpocock-skills@claude-plugins-official`, `bcquality@bcquality` (Microsoft's), and `al-language-server-go-windows@al-lsp-for-agents` (SShadowS's). Our marketplace lists only this plugin; its `allowCrossMarketplaceDependenciesOn` names the three marketplaces. A dependency resolves only once its marketplace is registered on the machine, and Claude Code registers `claude-plugins-official` on the first interactive session, so the developer adds the other two by hand before installing — `/plugin marketplace add microsoft/BCQuality` and `/plugin marketplace add SShadowS/al-lsp-for-agents` — with nothing committed to a Consumer repository. Skipping that step is loud: the install warns that the dependency was not installed, and `claude plugin list` reports `al-agentic-dev` as failed to load with the dependency named. Skills call a base plugin's skill by name and never carry a copy; the AL-specific skills stay ours. Copies had drifted from their donors and cost a fork rulebook to keep honest, while the base plugins improve on their own.

The AL language server is SShadowS's `al-language-server-go-windows` variant, used unchanged; we ship no `.lsp.json` of our own. No Claude Code mechanism selects a plugin by OS, and upstream ships only a Windows and a Linux variant, each with its own binary. Its wrapper needs the VS Code AL extension (`ms-dynamics-smb.al`) installed — without it the server exits 1 and Claude Code reports a crash — so the extension is a stated developer prerequisite. On macOS, Linux, and CI the install is inert, the same failure shape accepted for the Windows-only `ado` MCP server.

The dependencies are unpinned by choice: mattpocock-skills tracks whatever commit the official marketplace lists, and bcquality and the language server track their upstream default branch, arriving on each upstream `version` bump, so improvements arrive without a release of ours. For mattpocock-skills a constraint is not even available — it needs `<name>--v<version>` git tags, and mattpocock/skills tags `v<version>`. The guard is detection, not pinning: a validator resolves every `<base-plugin>:<skill>` reference against upstream in the PR gate, and `Validate-Json.ps1` fails a dependency whose marketplace is neither ours nor on the allowlist.

## Considered Options

- **Soft add-on** — recommend the base plugins in the README, call nothing. Rejected: the AL skills would lose their interview engine whenever a base plugin is missing.
- **Standalone** — keep our own copies of grilling and wait-what. Rejected: two skills racing the same triggers, and a donor diff to keep reconciling.
- **Re-list bcquality and the language server in our marketplace, by bare-name dependency** — taken first, now rejected. It made adding our marketplace the only setup, but gave each plugin a second identity (`bcquality@al-agentic-dev`) beside the upstream one: a developer who already had `bcquality@bcquality` or the language server from its own marketplace ended up with two copies shadowing each other's skills, and the README needed an uninstall step that depended on what was already installed. Two `marketplace add` lines the same for every developer cost less than that.
- **Re-list a base plugin at a SHA we choose** — not taken: we chose to follow the base plugins and detect breakage rather than hold them back.
- **Re-list mattpocock-skills too** — rejected: a copy already installed from `claude-plugins-official`, its documented install, would sit beside ours, and the session silently keeps one skill per name.

## Consequences

- `al-grill-me`, `al-grilling`, `al-wait-what`, and `al-unslop` retire, and with them the pinned-fork rule, `Compare-SkillToDonor.ps1`, and the fork exemptions in the gates.
- mattpocock-skills' `grilling` asks the whole frontier in rounds; one-question-at-a-time pacing goes with `al-grilling`. The connect-the-dots, visual, and business-language rules, and unslop's core cuts, move into the opt-in reply-shape output style.
- A developer who already has `bcquality@bcquality` or the language server from its own marketplace keeps it; the install reuses that copy and there is nothing to uninstall.
- Installing before the two marketplaces are added fails visibly, not silently, but a developer still has to read the message.
- The drift check and `Update-EvalBasePlugins.ps1` resolve `<name>@<marketplace>` through a table of marketplace repositories in `Test-BasePluginDrift.ps1`; a new base plugin from another marketplace adds a row there.
- `.al` files get symbols and compiler diagnostics only on Windows with the VS Code AL extension installed; auto-downloading the extension would need our own `.lsp.json` and a copy of the binaries.
- A base-plugin rename breaks our calls on users' next update until we ship a fix; the PR gate shortens that window, it does not close it.
