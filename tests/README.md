# The smoke harness

Three tiers guard the plugin surface. The static tier is deterministic and runs in CI; the routing and hook tiers cost AI credits and run by hand.

## Static tier — deterministic, CI-run

CI runs these five on every push and pull request; run them locally before pushing:

```powershell
pwsh scripts/Validate-Json.ps1        # JSON syntax repo-wide; plugin.json, .mcp.json, marketplace.json structure; one version across all three
pwsh scripts/Validate-PowerShell.ps1  # PowerShell syntax repo-wide
pwsh scripts/Validate-Skills.ps1      # frontmatter keys, name = folder, description ≤ 1024, links stay in-folder, script ownership, retired-concept bans
pwsh scripts/Update-Review.ps1 -Check # REVIEW.md in sync with skills.instructions.md
Invoke-Pester tests                   # the validator suites and the al-build substrate tests
```

The 1024-character description cap is load-bearing, not style: on copilot CLI 1.0.80 a skill whose description exceeds it is **silently never loaded** — no warning, no log line, the skill just never fires (probed 2026-08-19 with sentinel descriptions: 900 characters loads, 1100 and 2100 vanish). `Validate-Skills.ps1` enforcing 1024 is what turns that silent drop into a red gate.

### Diff-vs-donor

Ports land as pinned forks — donor text except the al- namespace; the diff against the donor is the port note and the debug surface. Compare a skill against a git ref in this repo or a local donor checkout:

```powershell
pwsh scripts/Compare-SkillToDonor.ps1 -Skill al-grill-me -DonorRef 688915f -DonorPath skills/grill-me  # donor in this repo's history
pwsh scripts/Compare-SkillToDonor.ps1 -Skill al-grill-me -DonorDir C:\donors\pocock-skills\grill-me  # external donor checkout
```

Exit 0 identical, 2 diverged (diff printed), 1 unresolvable. On a pinned fork the expected report is exit 2 with exactly the namespace hunks — the frontmatter `name:` line and any renamed sibling reference — and nothing else; any other hunk is a finding. `-DonorPath` overrides the in-ref path when the donor lived elsewhere than `skills/<name>`.

## Routing tier — one paid run, by hand

```powershell
pwsh tests/routing/Invoke-RoutingSmoke.ps1
```

One batched `copilot -p` run: it loads this checkout's plugin, asks which skill the model would route each scenario in `scenarios.json` to, and prints a pass/miss table. A miss is a signal to inspect — LLM routing varies, so re-run before treating one as real; the script exits 0 on misses and 1 only on mechanical failure. Each run costs roughly 5 AI credits, which is why the file is not named `*.Tests.ps1`: Pester and CI never discover it.

Every package that adds skills appends its scenarios to `tests/routing/scenarios.json`. Every skill is model-invocable, so a matching scenario names the skill; `"expect": "none"` is reserved for a genuine non-match.

## Hook tier — two paid runs, by hand

```powershell
pwsh tests/hooks/Invoke-HookSmoke.ps1
```

Two `copilot -p` runs against this checkout's committed `hooks.json`: an AL fixture (an `app.json` at the scratch root) where the reply shape, `/al-unslop`, the Speak BC voice rule, and the ask_user deny must all show in the model's reply, and a plain directory where the reply shape and `/al-unslop` show while the voice rule stays absent. Assertions match short distinctive substrings ("Ledger Entry", "/al-unslop", "disabled by al-agentic-dev"). Hook injection is deterministic, so unlike routing misses any assertion failure exits 1 and prints both replies. Roughly 10 AI credits per invocation; run it after any hooks.json change.

## Loading this checkout's plugin in isolation

`--plugin-dir <directory>` loads a plugin from a local directory for that session only — the user's installed plugins, `~/.copilot/settings.json`, and `enabledPlugins` stay untouched. The bundled `.mcp.json` travels with it. Run from a scratch directory so repo instruction files stay out of the session:

```powershell
Set-Location (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "probe-$(New-Guid)"))
copilot -p "<question>" --plugin-dir <path-to-this-checkout> --log-level debug --log-dir .\logs -s
```

The debug log names what loaded: `Loaded MCP config from plugin-dir plugins: …` and `Plugin activation [skills]: …`; the `<available_skills>` block in the logged system prompt is the ground truth for which skills the model can see. A same-name collision with an installed copy of this plugin would shadow one of the two — none exists today (`~/.copilot/installed-plugins/` is empty); if that changes, isolate with `XDG_CONFIG_HOME` pointed at a scratch dir and authenticate through the `GH_TOKEN` environment variable — never by copying files out of the real `~/.copilot`.
