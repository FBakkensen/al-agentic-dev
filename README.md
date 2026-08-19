# al-agentic-dev

A GitHub Copilot plugin for Microsoft Dynamics 365 Business Central development: a scripted compile-publish-test gate with containers, coverage, Page Scripting replay, and breaking-change validation underneath, plus the two platform-knowledge clones and a visual steering surface.

One install brings the whole surface: the Agent Skills, three packaged custom agents (`al-review-lens`, `al-spec-reviewer`, `al-knowledge-leaf`), and two bundled MCP servers — NAB AL Tools for XLF translation and Microsoft Learn for current Microsoft documentation.

The set is mid-rebuild: the earlier 26-skill pipeline is retired, and each new plugin version ports proven skills back in as real work needs them. Git history is the donor archive.

## Requirements

- Windows, PowerShell 7.2+
- GitHub Copilot CLI, authenticated to `9altitudes.ghe.com` (`gh auth status -h 9altitudes.ghe.com`)
- Docker Desktop, BcContainerHelper, and the .NET SDK — `/al-build`'s scripted toolchain
- Node.js 22+ with `npx` on PATH — runs the bundled NAB AL Tools MCP server
- In each consumer repo: `al-build.json` at the root for the build gate

The skills other than `/al-build` are prose and need nothing beyond Copilot itself.

## Install

Came here from an older install? Do [Migrating from `npx skills add`](#migrating-from-npx-skills-add) first — leftover copies silently mask everything below.

### As a marketplace (recommended)

This repository doubles as its own plugin marketplace through `.github/plugin/marketplace.json`, which is what keeps `copilot plugin update` working later:

```
copilot plugin marketplace add https://9altitudes.ghe.com/gtm-general/al-agentic-dev
copilot plugin install al-agentic-dev@al-agentic-dev
```

The full URL matters: the `owner/repo` shorthand always resolves against GitHub.com, and this repository lives on GitHub Enterprise.

### Directly from the repository

```
copilot plugin install https://9altitudes.ghe.com/gtm-general/al-agentic-dev
```

Same plugin, no marketplace registration — and no catalog for `copilot plugin update` to check against, which is why the marketplace form is recommended.

### Verify

```
copilot plugin list      # al-agentic-dev@al-agentic-dev (v1.3.0)
copilot skill list       # the 10 skills, under "Plugin skills"
copilot mcp list         # Plugin servers: nab-al-tools, microsoft-learn, bc-code-intelligence
```

The skills must appear under **Plugin skills**. Any of them listed under *Personal skills* is a leftover legacy copy shadowing the plugin — go to [Migrating from `npx skills add`](#migrating-from-npx-skills-add).

### Update

```
copilot plugin update al-agentic-dev
```

### Enable per repository — Copilot app, CLI, and cloud agent

A consumer repo can declare the plugin in `.github/copilot/settings.json`, committed to the repository. Copilot CLI (which the GitHub Copilot app runs on) and the Copilot cloud agent read the same two keys, auto-install the plugin for everyone who works in that repository, and scope it there:

```json
{
  "extraKnownMarketplaces": {
    "al-agentic-dev": {
      "source": {
        "source": "git",
        "url": "https://9altitudes.ghe.com/gtm-general/al-agentic-dev"
      }
    }
  },
  "enabledPlugins": {
    "al-agentic-dev@al-agentic-dev": true
  }
}
```

The auto-install runs when Copilot starts in a trusted checkout of that repository; a user-level install through the commands above works everywhere regardless.

## Migrating from `npx skills add`

Earlier versions of this set installed as loose per-user skill folders. Those copies load **before** plugin skills and silently mask every plugin update, forever — same name, stale text wins, no warning. Remove them once and the plugin takes over.

**1. Detect.** List what the legacy installer left behind (only folders whose names this set has ever shipped — your other personal skills are untouched):

```powershell
$plugin = 'al-agentic-dev-overview','al-build','al-clone-bcapps','al-clone-bcquality','al-code-review',
  'al-design','al-event-model','al-grill-adr','al-grilling','al-implement','al-knowledge-pass','al-next',
  'al-orchestrate','al-provision','al-quiz','al-refactor','al-refine','al-routing','al-scope','al-spec-review',
  'al-sync-main','al-user-verification','al-validate-breaking-changes','al-visualize','babysit-pr'
foreach ($dir in "$HOME\.agents\skills", "$HOME\.copilot\skills") {
  if (Test-Path $dir) { Get-ChildItem $dir -Directory | Where-Object Name -in $plugin }
}
```

`copilot skill list` shows the same problem from the other side: these names under *Personal skills* instead of *Plugin skills*.

**2. Remove.** Delete every folder the detection listed. Nothing else in those directories belongs to this plugin.

**3. Remove leftover direct installs.** If `copilot plugin list` shows an `al-agentic-dev` installed from a local path or an old source, uninstall it — after closing every Copilot session first. While any session holds the plugin's MCP processes, the uninstall fails with `os error 32` (files held open); it succeeds once the sessions are gone.

```
copilot plugin uninstall al-agentic-dev
```

**4. Install fresh** per [Install](#install), then verify: `copilot plugin list` shows the plugin, `copilot skill list` shows its skills under **Plugin skills** and none of them under *Personal skills*, and `copilot mcp list` shows `nab-al-tools`, `microsoft-learn`, and `bc-code-intelligence` as plugin servers.

## The skills

| Skill | What it does |
|---|---|
| [`/al-build`](docs/al-build.md) | Compiles, publishes, runs the tests — plus provisioning, breaking-change validation, Page Scripting replay, and the container lifecycle. |
| `/al-clone-bcapps` | Clones Microsoft's W1 source at the matching BC version into `.bcapps/` for reading and searching platform code. |
| `/al-clone-bcquality` | Clones Microsoft's BCQuality knowledge base into `.bcquality/` and builds its knowledge index. |
| `/al-visualize` | Draws what a run settled or landed as a steering surface on the Copilot app's side-panel canvas. |
| `/grilling` | Interviews you in numbered rounds over a plan's design tree until shared understanding — the engine `grill-me` starts. |
| `/grill-me` | Starts the grilling interview over a plan or design. |
| `/wait-what` | Stops the flow and re-pitches the last message in plain shared language. |
| `/unslop` | Cuts AI tells from any writing; applies to every reply and artifact. |
| `/miner` | Mines session history for repeated failures and steering corrections; proposes standing lessons with evidence, never landing them itself. |
| `/lookup` | Answers one platform question with a source pointer — Microsoft Learn, bc-code-intelligence, the BCApps clone, or the BCQuality index — and grows the repo's precedent map. |

Three read-only reviewer agents ride under `agents/` — `al-review-lens`, `al-spec-reviewer`, `al-knowledge-leaf` — ready for the review skills that return in later versions. `grilling`, `grill-me`, `wait-what` (mattpocock/skills, MIT) and `unslop` (pstack, MIT) are verbatim ports: their bodies stay byte-identical to their donors, and a fix belongs upstream.
