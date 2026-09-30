# The test gates

The static tier is deterministic and runs in CI. The trigger evals arrive with the eval harness (#52), run by hand because every run is billed.

## Static tier — deterministic, CI-run

CI runs these five on every push to `main` and every pull request; run them locally before pushing:

```powershell
pwsh scripts/Validate-Json.ps1        # JSON syntax repo-wide; .claude-plugin/plugin.json, .claude-plugin/marketplace.json, and .mcp.json structure; no MCP tools allowlist
pwsh scripts/Validate-PowerShell.ps1  # PowerShell syntax repo-wide
pwsh scripts/Validate-Skills.ps1      # frontmatter keys, name = folder, description <= 1024, links stay in-folder, script ownership, retired-concept bans
pwsh scripts/Test-BasePluginDrift.ps1 # every <ns>:<skill> reference in skills/ and hooks/session-start.md resolves against the Base plugins' upstream heads
pwsh scripts/Invoke-Tests.ps1 -Mode Full  # the validator suites, the SessionStart hook, and the al-build substrate tests
```

The 1024-character description cap comes from the Agent Skills specification; Claude Code documents no limit, and the gate keeps the cap.

The drift check fetches over anonymous https: mattpocock-skills at the commit `claude-plugins-official` lists, bcquality and the AL language server at their default branches. `.github/workflows/base-plugin-drift.yml` reruns it daily and opens, updates, or closes the one `[Drift] Base plugin skill references` issue through `scripts/Update-BasePluginDriftIssue.ps1`. `tests/BasePluginDrift.Tests.ps1` drives it through `-PluginRoot`, which maps each namespace to a TestDrive fixture and fetches nothing.

`tests/SessionStartHook.Tests.ps1` runs exactly the command in `hooks/hooks.json` as a process, with `${CLAUDE_PLUGIN_ROOT}` pointed at the checkout, parses stdout as JSON, and asserts the `SessionStart` event name, the `▶ <model> · <brief> → <return>` line, and the delegation-cost text.

## Loading this checkout's plugin in isolation

`claude --plugin-dir <path-to-this-checkout>` loads the plugin from a local directory for that session only; installed plugins stay untouched. Pass each Base plugin's local copy with its own `--plugin-dir`, because a plugin whose `dependencies` are missing does not load.
