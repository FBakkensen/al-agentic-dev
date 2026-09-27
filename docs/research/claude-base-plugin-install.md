# Installing al-agentic-dev's base plugin dependencies on a fresh machine

Resolves FBakkensen/al-agentic-dev#24.

## Question

ADR 0002 (`docs/adr/0002-base-plugins-as-unpinned-dependencies.md`, on branch `claude/mattpocock-skills-wayfinder-e27f98`, not yet on `main`) has al-agentic-dev declare three unpinned `plugin.json` dependencies —
`mattpocock-skills@claude-plugins-official`, `bcquality@bcquality`, `al-language-server-go-windows@al-lsp-for-agents` — and allowlist those three marketplace names in its own `marketplace.json` via `allowCrossMarketplaceDependenciesOn`.

When a Naveksa developer who has added only the `al-agentic-dev` marketplace runs `claude plugin install al-agentic-dev@<al-agentic-dev-marketplace>`, do the three dependencies resolve automatically, or does each dependency's marketplace need to be added first — and what exactly does the developer see?

## Answer

**No — none of the three resolve until its own marketplace is added (known) on the developer's machine; the allowlist alone does not fetch or register it.** `allowCrossMarketplaceDependenciesOn` only lifts the trust block on a dependency whose marketplace is already known; it does not cause Claude Code to discover it. Confirmed both by direct doc statements and by four empirical probes (below).

- **Dependency declared in `plugin.json` (the shape ADR 0002 actually uses):** the *parent* plugin still installs ("Successfully installed"), but it then **fails to load**, and `claude plugin list` reports one error — for the *first* unresolved dependency only, not all three at once — `Dependency "<dep>@<marketplace>" is not installed — run \`claude plugin install <dep>@<marketplace>\`, or check that its marketplace is added`.
- **Dependency declared instead in the marketplace entry:** the install of the parent plugin is **refused outright** (exit code 1, nothing installed) with `Dependency "<dep>" (required by <plugin>) not found. Is the "<marketplace>" marketplace added?`
- **Order does not matter, and the marketplaces don't need to precede the install** for the `plugin.json` shape: running `claude plugin marketplace add <dep-marketplace>` *after* a failed/partial install self-heals whatever dependency that marketplace can now resolve, with no explicit `/reload-plugins` or reinstall — each add prints `(+ 1 dependency: <name>)` and the error on the parent plugin moves to the next unresolved dependency, until all three are added and the parent shows no errors at all. This matches `dependencies.md`'s list of operations that "also install any missing declared dependency," which includes `claude plugin marketplace add`.
- For the marketplace-entry-declared shape, there is nothing to self-heal — the install never created a record — so the developer must re-run `claude plugin install <plugin>@<marketplace>` once the marketplaces are added.
- Once all three dependency marketplaces are known, `claude plugin install` on the parent plugin auto-installs and enables all three dependencies in one step, reporting `(+ 3 dependencies: ...)`.

## Docs findings (primary source: code.claude.com)

1. **Cross-marketplace dependencies are off by default; the allowlist only lifts that block, it doesn't discover the marketplace.**
   > "By default, Claude Code doesn't install a dependency from a different marketplace than the declaring plugin's own, unless the user already has that dependency installed and enabled at the same scope. This default prevents one marketplace from silently installing plugins from a source the user hasn't reviewed. To allow the install, add the target marketplace's name to `allowCrossMarketplaceDependenciesOn` in the root marketplace's `marketplace.json`."
   — [Plugin dependencies § Depend on a plugin from another marketplace](https://code.claude.com/docs/en/plugins/dependencies.md)

   The doc never says the allowlist causes the target marketplace to be added — it only describes what happens when the allowlist is *missing*:
   > "If `allowCrossMarketplaceDependenciesOn` is missing or doesn't include the target marketplace, Claude Code doesn't install the dependency. When the dependency is declared in the marketplace entry, the install itself is refused with a message that starts `Dependency "audit-logger@your-shared-marketplace" (required by deploy-kit@your-marketplace) is in marketplace "your-shared-marketplace", which is not in the allowlist" ... When it's declared in `plugin.json`, the install completes without the dependency and your plugin then fails to load."
   — same page. This is the *not-allowlisted* message; our probe below shows the *allowlisted-but-marketplace-unknown* message is worded differently (`not found... Is the marketplace added?`), which is new information this doc page doesn't state.

2. **The `Dependency errors` troubleshooting table gives the fix for both shapes:**

   | Message | Meaning | Fix |
   |---|---|---|
   | `Dependency "<dep>" is not installed` | A declared dependency isn't installed. | "Install it in your shell with `claude plugin install <dep>@<marketplace>`, or uninstall the plugin. **If the dependency's marketplace isn't registered yet, add it** and run `/reload-plugins` in your session, which installs the missing dependencies it can resolve." |
   | `Dependency "<dep>" (required by <plugin>) is in <marketplace>, which is not in the allowlist` | The dependency is in a different marketplace, and cross-marketplace resolution is off by default. | "Install the dependency yourself at the same scope, in your shell with `claude plugin install <dep>@<marketplace>` plus the `--scope` you're installing the plugin at, then retry." |

   — [Troubleshoot plugins § Dependency errors](https://code.claude.com/docs/en/plugins/troubleshooting.md#dependency-errors)

   Both fixes assume the marketplace either needs to be added or the dependency installed directly — neither describes automatic registration. This is the strongest textual signal, short of running it, that the marketplace must be known ahead of time.

3. **`extraKnownMarketplaces` is the mechanism that pre-registers a marketplace without the user running `plugin marketplace add`.** It is a settings-file field (user, project `.claude/settings.json`, or managed settings), a map from marketplace name to a `source` object:
   ```json
   {
     "extraKnownMarketplaces": {
       "your-marketplace": {
         "source": { "source": "git", "url": "https://git.example.com/your-org/your-marketplace.git", "ref": "main" }
       }
     }
   }
   ```
   — [Marketplace reference § Source objects in settings](https://code.claude.com/docs/en/plugins/marketplace-reference.md). This is the one documented way to make a dependency's marketplace known ahead of an install without the developer typing `claude plugin marketplace add` themselves — an admin (or a repo's committed `.claude/settings.json`) can pre-list it. Nothing in `plugin.json` or `marketplace.json` can populate `extraKnownMarketplaces`; it is settings-only.

   Confirmed empirically: after `claude plugin marketplace add <path>` in probe 1, the fresh config dir's `settings.json` contained exactly
   ```json
   { "extraKnownMarketplaces": { "test-marketplace": { "source": { "source": "directory", "path": "<local path>" } } } }
   ```
   i.e. `claude plugin marketplace add` is implemented as "write an `extraKnownMarketplaces` entry (at user scope by default) + clone/validate it" — the same key an admin would populate directly. "Known" and "present in `extraKnownMarketplaces`" are the same fact.

4. **Install a plugin from your shell — the marketplace must be added first, docs say so explicitly for the official marketplace and generalize it:**
   > "The marketplace must be added first: on a machine where no one has opened an interactive Claude Code session yet, the official marketplace isn't registered, so a script that installs from it runs `claude plugin marketplace add anthropics/claude-plugins-official` before the install."
   — [Install and manage plugins § Install from your shell](https://code.claude.com/docs/en/plugins/install.md)

5. **`claude-plugins-official` is not known "for free" on a fresh `CLAUDE_CONFIG_DIR`.** Claude Code auto-adds it only "the first time you start an interactive terminal session" — a plain `claude plugin install` in a shell that has never run an interactive session does not trigger that auto-add:
   > "Marketplace "claude-plugins-official" not found ... The official marketplace isn't registered on this machine yet. Claude Code normally registers it on its own the first time you start an interactive terminal session. ... The `claude plugin` shell commands never register it for you."
   — [Troubleshoot plugins § `Marketplace "claude-plugins-official" not found`](https://code.claude.com/docs/en/plugins/troubleshooting.md). Confirmed empirically too: our fresh-`CLAUDE_CONFIG_DIR` probes never ran an interactive session and `claude-plugins-official` was absent from `claude plugin marketplace list` until added explicitly.

   `unverified:` a real Naveksa developer's machine is not pure-fresh in this one respect — if they have ever opened `claude` interactively before (even for unrelated work), `claude-plugins-official` is likely already auto-registered per this same doc passage, so `mattpocock-skills` may already resolve for them without an explicit `marketplace add`. `bcquality` and `al-lsp-for-agents` get no such auto-registration (only the official marketplace does), so those two always need an explicit add regardless of prior interactive use. This distinction was not probed — all probes below used a `CLAUDE_CONFIG_DIR` that never ran an interactive session, to isolate the mechanism from this auto-registration behavior.

## Empirical probe

All commands ran with `claude` 2.1.283 on Windows, with `CLAUDE_CONFIG_DIR` pointed at fresh, isolated folders — never the real `~/.claude`. Two environment issues came up and are noted so the recipe below anticipates them for other Windows machines:

- **Windows `MAX_PATH`**: the assigned scratch folder is deep enough that `git clone` of the three real dependency marketplaces failed with `Filename too long`, unfixed by `git config --global core.longpaths true` (reverted after) or a `subst` drive alias (git canonicalized back to the long path either way). Probes 2–4, which clone real marketplaces, therefore ran `CLAUDE_CONFIG_DIR` from short paths directly under the user's own Windows temp folder (`...\Temp\al-probe\p2`, `...\Temp\alp3`, `...\Temp\alp4`, deleted after the session) instead of the assigned deep scratchpad path — still fully isolated from `~/.claude`, just not nested under the session scratchpad. Probe 1, and the local-marketplace fixture itself, stayed in the assigned scratchpad throughout, since only the git-clone step hit the limit.
- **SSH host key**: cloning `anthropics/claude-plugins-official` by `owner/repo` shorthand first tried SSH and failed with `SSH host key is not in your known_hosts file` (this sandbox has no accepted GitHub SSH host key). Setting `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` (documented in [Host and maintain a marketplace](https://code.claude.com/docs/en/plugins/host-marketplace.md)) made all three adds clone over HTTPS with no credentials needed, since all three repos are public.

### Fixture

A local marketplace at `install-probe/local-marketplace/`, with `allowCrossMarketplaceDependenciesOn` allowlisting exactly the three real marketplace names, and two consumer plugins so both dependency-declaration shapes could be probed side by side:

`.claude-plugin/marketplace.json`:
```json
{
  "name": "test-marketplace",
  "owner": { "name": "Probe" },
  "allowCrossMarketplaceDependenciesOn": ["claude-plugins-official", "bcquality", "al-lsp-for-agents"],
  "plugins": [
    { "name": "test-consumer-a", "source": "./plugins/test-consumer-a" },
    {
      "name": "test-consumer-b",
      "source": "./plugins/test-consumer-b",
      "dependencies": [
        { "name": "mattpocock-skills", "marketplace": "claude-plugins-official" },
        { "name": "bcquality", "marketplace": "bcquality" },
        { "name": "al-language-server-go-windows", "marketplace": "al-lsp-for-agents" }
      ]
    }
  ]
}
```

`plugins/test-consumer-a/.claude-plugin/plugin.json` — dependencies declared here, mirroring ADR 0002's shape:
```json
{
  "name": "test-consumer-a",
  "version": "0.0.1",
  "dependencies": [
    { "name": "mattpocock-skills", "marketplace": "claude-plugins-official" },
    { "name": "bcquality", "marketplace": "bcquality" },
    { "name": "al-language-server-go-windows", "marketplace": "al-lsp-for-agents" }
  ]
}
```

`plugins/test-consumer-b/.claude-plugin/plugin.json` — no dependencies (they live in the marketplace entry above):
```json
{ "name": "test-consumer-b", "version": "0.0.1" }
```

`claude plugin validate <marketplace-dir>` passed with only cosmetic warnings (missing `description`/`author`).

### Probe 1 — fresh config, dependency marketplaces never added

```
$env:CLAUDE_CONFIG_DIR = "<fresh dir>\cfg-probe1-notadded"
claude plugin marketplace add <path to local-marketplace>
claude plugin install test-consumer-a@test-marketplace
```
Output:
```
=== claude plugin marketplace add (local) ===
Adding marketplace…√ Successfully added marketplace: test-marketplace (declared in user settings)

=== claude plugin install test-consumer-a@test-marketplace (deps in plugin.json) ===
Installing plugin "test-consumer-a@test-marketplace"...√ Successfully installed plugin: test-consumer-a@test-marketplace (scope: user)
```
The install itself reports success — but `claude plugin list` immediately after shows the plugin disabled by a load error:
```
Installed plugins:
  > test-consumer-a@test-marketplace
    Version: 0.0.1
    Scope: user
    Status: × failed to load
    Error: Dependency "mattpocock-skills@claude-plugins-official" is not installed — run `claude plugin install mattpocock-skills@claude-plugins-official`, or check that its marketplace is added
```
`claude plugin marketplace list` at this point shows **only** `test-marketplace` — the allowlisted `claude-plugins-official`, `bcquality`, and `al-lsp-for-agents` marketplaces were never fetched or registered on their own.

Then, same config dir, installing the other consumer plugin (dependency declared in the marketplace entry instead of `plugin.json`):
```
=== claude plugin install test-consumer-b@test-marketplace (deps in marketplace entry) ===
Installing plugin "test-consumer-b@test-marketplace"...× Failed to install plugin "test-consumer-b@test-marketplace": Dependency "mattpocock-skills@claude-plugins-official" (required by test-consumer-b@test-marketplace) not found. Is the "claude-plugins-official" marketplace added?
EXIT: 1
```
Nothing installed for `test-consumer-b`; `claude plugin list` afterward is unchanged (still only the failed-to-load `test-consumer-a`).

Note the message differs from the *not-in-the-allowlist* wording the dependencies.md page documents for a missing allowlist entry — this is the *allowlisted-but-marketplace-unknown* case, and Claude Code phrases it as "not found... Is the marketplace added?" rather than repeating the allowlist language. This exact phrasing is not on any of the fetched docs pages; it comes only from the probe.

### Probe 2 — dependency marketplaces added first, then the same installs

```
$env:CLAUDE_CONFIG_DIR = "<fresh short dir>\p2"
$env:CLAUDE_CODE_PLUGIN_PREFER_HTTPS = "1"
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add microsoft/BCQuality
claude plugin marketplace add SShadowS/al-lsp-for-agents
```
Output (all three, HTTPS, no credentials needed — public repos):
```
√ Successfully added marketplace: claude-plugins-official (declared in user settings)
√ Successfully added marketplace: bcquality (declared in user settings)
√ Successfully added marketplace: al-lsp-for-agents (declared in user settings)
```
`claude plugin marketplace list` confirms the registered names match ADR 0002's expectations exactly: `claude-plugins-official` (GitHub `anthropics/claude-plugins-official`), `bcquality` (GitHub `microsoft/BCQuality`), `al-lsp-for-agents` (GitHub `SShadowS/al-lsp-for-agents`).

Then:
```
claude plugin marketplace add <path to local-marketplace>
claude plugin install test-consumer-a@test-marketplace
claude plugin install test-consumer-b@test-marketplace
```
Output:
```
√ Successfully added marketplace: test-marketplace (declared in user settings)
√ Successfully installed plugin: test-consumer-a@test-marketplace (scope: user) (+ 3 dependencies: mattpocock-skills, bcquality, al-language-server-go-windows)
√ Successfully installed plugin: test-consumer-b@test-marketplace (scope: user)
```
`claude plugin list` afterward: all five plugins `√ enabled` — `al-language-server-go-windows@al-lsp-for-agents` (1.17.0), `bcquality@bcquality` (0.2.0), `mattpocock-skills@claude-plugins-official` (1.2.3), `test-consumer-a@test-marketplace` (0.0.1), `test-consumer-b@test-marketplace` (0.0.1). No errors on any entry. `test-consumer-b`'s install didn't need to re-name its dependencies because they were already installed and enabled at the same (user) scope — matching the documented allowlist exception: "The allowlist check doesn't apply to a dependency that is already enabled" ([Plugin dependencies](https://code.claude.com/docs/en/plugins/dependencies.md)).

### Probe 3 — does adding a dependency's marketplace *after* a failed install self-heal it? (plugin.json shape)

Fresh short config dir `p3`. Step 1 repeats probe 1 (add local marketplace, install `test-consumer-a`, confirm the single `mattpocock-skills` error). Then, **without any reinstall or `/reload-plugins`**, the three dependency marketplaces were added one at a time and `claude plugin list --json` was checked after each:

| Step | Command | Result |
|---|---|---|
| 2 | `claude plugin marketplace add anthropics/claude-plugins-official` | `√ Successfully added marketplace: claude-plugins-official (declared in user settings) (+ 1 dependency: mattpocock-skills)` — `mattpocock-skills` now installed+enabled; `test-consumer-a`'s error changed to `Dependency "bcquality@bcquality" is not installed...` |
| 3 | `claude plugin marketplace add microsoft/BCQuality` | `√ Successfully added marketplace: bcquality (declared in user settings) (+ 1 dependency: bcquality)` — error changed to `Dependency "al-language-server-go-windows@al-lsp-for-agents" is not installed...` |
| 4 | `claude plugin marketplace add SShadowS/al-lsp-for-agents` | `√ Successfully added marketplace: al-lsp-for-agents (declared in user settings) (+ 1 dependency: al-language-server-go-windows)` — `claude plugin list --json` now shows `test-consumer-a` with **no `errors` field at all** |

Each `marketplace add` healed exactly the one dependency it could now resolve and re-enabled the parent plugin, with no explicit reinstall or reload. Order was immaterial — this ran official → bcquality → al-lsp-for-agents, but nothing in the mechanism depends on that order (each add only checks whether *its own* marketplace unblocks a pending dependency).

### Probe 4 — same question for the marketplace-entry-declared shape (`test-consumer-b`)

Fresh short config dir `p4`. Added the local marketplace, then `claude plugin install test-consumer-b@test-marketplace` with none of the three dependency marketplaces present — same refusal as probe 1 (`Dependency "mattpocock-skills@claude-plugins-official" ... not found. Is the "claude-plugins-official" marketplace added?`, exit 1, nothing installed). Then added all three dependency marketplaces (none of the three `marketplace add` outputs mentioned `test-consumer-b` or printed a `(+ N dependency...)` note this time), and `claude plugin list --json` afterward was `[]` — empty. `test-consumer-b` never got an install record to heal, so it silently stays not-installed until the developer re-runs `claude plugin install test-consumer-b@test-marketplace` by hand.

## What the Naveksa developer actually sees

Because ADR 0002 declares al-agentic-dev's base-plugin dependencies in `plugin.json` (`test-consumer-a`'s shape, not `test-consumer-b`'s), the realistic sequence is probe 1 → probe 3, not probe 4:

**If they just run `claude plugin install al-agentic-dev@<marketplace>` with none of the three base-plugin marketplaces added:** the command reports success (`Successfully installed plugin: al-agentic-dev@<marketplace>`, no dependency count, because none resolved), but al-agentic-dev's skills then fail to load. `claude plugin list` / the `/plugin` Errors tab shows exactly **one** dependency error — the first of the three, in the order `plugin.json` declares them — not all three at once; resolving it only reveals the next one.

**If they then add just one of the three missing marketplaces** (in any order, at any later time, no reload needed), that `marketplace add` call itself prints `(+ 1 dependency: <name>)`, installs and enables that one dependency, and the visible error moves to the next missing one. Add all three and al-agentic-dev shows no errors and every skill is available — no `/reload-plugins` or reinstall required at any point in this sequence.

**If they add all three marketplaces before ever installing al-agentic-dev**, the one install line prints `(+ 3 dependencies: mattpocock-skills, bcquality, al-language-server-go-windows)` and everything is enabled immediately, with no intermediate error ever shown.

## Minimal install recipe for a Naveksa developer

Cleanest experience — no visible errors at any point — add the three dependency marketplaces before installing al-agentic-dev, in any order:

```shell
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add microsoft/BCQuality
claude plugin marketplace add SShadowS/al-lsp-for-agents
claude plugin marketplace add <al-agentic-dev marketplace source>
claude plugin install al-agentic-dev@<al-agentic-dev marketplace name>
```

On a machine where an interactive `claude` session has already run at least once, `claude-plugins-official` may already be registered (`unverified:`, see doc finding #5 above), so that first line may be a no-op; `microsoft/BCQuality` and `SShadowS/al-lsp-for-agents` are never auto-registered and always need an explicit add.

If a developer skips straight to `claude plugin install al-agentic-dev@<marketplace>` (the scenario the issue actually asks about), nothing is lost — because the dependency is declared in `plugin.json`, per probe 3 they can recover with **no reinstall of al-agentic-dev at all**: just `claude plugin marketplace add` each missing marketplace named in the error (`claude plugin list` names the next one each time), which self-heals as it goes. This is also exactly the fix the docs table gives: "If the dependency's marketplace isn't registered yet, add it and run `/reload-plugins` in your session, which installs the missing dependencies it can resolve" ([Troubleshoot plugins](https://code.claude.com/docs/en/plugins/troubleshooting.md#dependency-errors)) — our probe shows the `marketplace add` step alone is enough; `/reload-plugins` is only needed to make an *already-running* session pick up the change, not to trigger the install itself.

Equivalently, an administrator can pre-register the three marketplaces for everyone through `extraKnownMarketplaces` in managed settings or a committed `.claude/settings.json`, so a developer's one `claude plugin install al-agentic-dev@...` "just works" with zero manual marketplace-add steps — this variant is `unverified:` (not probed; it follows directly from the `extraKnownMarketplaces` schema in the marketplace reference, doc source #3 above, and from what a plain `claude plugin marketplace add` was empirically shown to write into that same settings key, but the probes above only exercised the CLI command, not settings-file pre-registration or the project-scope trust-dialog gate `host-marketplace.md` describes for a `.claude/settings.json` marketplace entry).

## Source manifests used for the probe

- `install-probe/local-marketplace/.claude-plugin/marketplace.json`, `install-probe/local-marketplace/plugins/test-consumer-a/.claude-plugin/plugin.json`, `install-probe/local-marketplace/plugins/test-consumer-b/.claude-plugin/plugin.json` — reproduced verbatim above; built in the session scratchpad, not committed to this repo.
- Real marketplaces cloned during the probes (public, no credentials, HTTPS via `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`): `github.com/anthropics/claude-plugins-official`, `github.com/microsoft/BCQuality`, `github.com/SShadowS/al-lsp-for-agents`.
- The three short-path temp roots (`al-probe`, `alp3`, `alp4`) were deleted at the end of the session; nothing from this research was left on disk outside this document and the deliberately-unremoved local marketplace fixture and probe-1 config dir in the assigned scratchpad.
