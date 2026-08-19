# The smoke harness

Two tiers guard the plugin surface. The static tier is deterministic and runs in CI; the routing tier costs AI credits and runs by hand.

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

Ports land with the smallest possible diff against their donor; the diff is the port note and the debug surface. Compare a skill against a git ref in this repo or a local donor checkout:

```powershell
pwsh scripts/Compare-SkillToDonor.ps1 -Skill grilling -DonorRef 3b1ed60 -DonorPath skills/al-grilling  # donor in this repo's history
pwsh scripts/Compare-SkillToDonor.ps1 -Skill grilling -DonorDir C:\donors\grilling  # external donor checkout
```

Exit 0 identical, 2 diverged (diff printed), 1 unresolvable. `-DonorPath` overrides the in-ref path when the donor lived elsewhere than `skills/<name>`.

## Routing tier — one paid run, by hand

```powershell
pwsh tests/routing/Invoke-RoutingSmoke.ps1
```

One batched `copilot -p` run: it loads this checkout's plugin, asks which skill the model would route each scenario in `scenarios.json` to, and prints a pass/miss table. A miss is a signal to inspect — LLM routing varies, so re-run before treating one as real; the script exits 0 on misses and 1 only on mechanical failure. Each run costs roughly 5 AI credits, which is why the file is not named `*.Tests.ps1`: Pester and CI never discover it.

Every package that adds skills appends its scenarios to `tests/routing/scenarios.json`. Slash-only skills (`disable-model-invocation: true`) are invisible to the model by design — write their scenarios with `"expect": "none"`; they then double as canaries that fail loudly if a disable flag ever breaks.

## Loading this checkout's plugin in isolation

`--plugin-dir <directory>` loads a plugin from a local directory for that session only — the user's installed plugins, `~/.copilot/settings.json`, and `enabledPlugins` stay untouched. The bundled `.mcp.json` travels with it. Run from a scratch directory so repo instruction files stay out of the session:

```powershell
Set-Location (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "probe-$(New-Guid)"))
copilot -p "<question>" --plugin-dir <path-to-this-checkout> --log-level debug --log-dir .\logs -s
```

The debug log names what loaded: `Loaded MCP config from plugin-dir plugins: …` and `Plugin activation [skills]: …`; the `<available_skills>` block in the logged system prompt is the ground truth for which skills the model can see. A same-name collision with an installed copy of this plugin would shadow one of the two — none exists today (`~/.copilot/installed-plugins/` is empty); if that changes, isolate with `XDG_CONFIG_HOME` pointed at a scratch dir and authenticate through the `GH_TOKEN` environment variable — never by copying files out of the real `~/.copilot`.
