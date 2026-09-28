# The test gates

The static tier is deterministic and runs in CI. The trigger evals arrive with the eval harness (#52), run by hand because every run is billed.

## Static tier — deterministic, CI-run

CI runs these four on every push to `main` and every pull request; run them locally before pushing:

```powershell
pwsh scripts/Validate-Json.ps1        # JSON syntax repo-wide; .claude-plugin/plugin.json, .claude-plugin/marketplace.json, and .mcp.json structure; no MCP tools allowlist
pwsh scripts/Validate-PowerShell.ps1  # PowerShell syntax repo-wide
pwsh scripts/Validate-Skills.ps1      # frontmatter keys, name = folder, description <= 1024, links stay in-folder, script ownership, retired-concept bans
pwsh scripts/Invoke-Tests.ps1 -Mode Full  # the validator suites, the SessionStart hook, and the al-build substrate tests
```

The 1024-character description cap comes from the Agent Skills specification; Claude Code documents no limit, and the gate keeps the cap.

`tests/SessionStartHook.Tests.ps1` runs exactly the command in `hooks/hooks.json` as a process, with `${CLAUDE_PLUGIN_ROOT}` pointed at the checkout, parses stdout as JSON, and asserts the `SessionStart` event name, the `▶ <model> · <brief> → <return>` line, and the delegation-cost text.

### Diff-vs-donor

Ports land as pinned forks — donor text except the al- namespace; the diff against the donor is the port note and the debug surface. Compare a skill against a git ref in this repo or a local donor checkout:

```powershell
pwsh scripts/Compare-SkillToDonor.ps1 -Skill al-grill-me -DonorRef 688915f -DonorPath skills/grill-me  # donor in this repo's history
pwsh scripts/Compare-SkillToDonor.ps1 -Skill al-grill-me -DonorDir C:\donors\pocock-skills\grill-me  # external donor checkout
```

Exit 0 identical, 2 diverged (diff printed), 1 unresolvable. On a pinned fork the expected report is exit 2 with exactly the namespace hunks — the frontmatter `name:` line and any renamed sibling reference — and nothing else; any other hunk is a finding. `-DonorPath` overrides the in-ref path when the donor lived elsewhere than `skills/<name>`.

## Loading this checkout's plugin in isolation

`claude --plugin-dir <path-to-this-checkout>` loads the plugin from a local directory for that session only; installed plugins stay untouched. Pass each Base plugin's local copy with its own `--plugin-dir`, because a plugin whose `dependencies` are missing does not load.
