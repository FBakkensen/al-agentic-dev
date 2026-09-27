# Re-listing the base plugins in our own marketplace

Resolves part of FBakkensen/al-agentic-dev#27. Probed with Claude Code 2.1.283 on Windows, fresh `CLAUDE_CONFIG_DIR`s, 2026-09-27.

## Question

A dependency resolves only once its marketplace is known on the machine (#24), and nothing may be committed to a Consumer repository to make it known. If our own `marketplace.json` lists the three base plugins as entries pointing at their upstream repositories, does one `claude plugin install al-agentic-dev@al-agentic-dev` pull everything in — and what breaks?

## Answer

Yes. With only our marketplace added, the install reports `(+ 3 dependencies: mattpocock-skills, bcquality, al-language-server-go-windows)` and `claude plugin list` shows all four enabled with no errors. Three constraints come with it:

- **Sources must be `url` over https, not `github`.** A `github` source clones over SSH and fails on a machine with no GitHub SSH host key: `No ED25519 host key is known for github.com … Host key verification failed.` `claude-plugins-official` lists mattpocock-skills as a `url` source for the same reason.
- **A copy installed from the upstream marketplace is not replaced.** With `mattpocock-skills@claude-plugins-official` already installed, our install adds `mattpocock-skills@al-agentic-dev` beside it; both show enabled, both load (`Total plugin skills loaded: 52`), and the session sends the model one copy per name (`Sending 27 skills` = 25 + bcquality's 1 + ours 1). The log does not say which copy wins; nothing errors.
- **Updates follow the upstream `version`, not its commits.** A new upstream commit without a version bump never reaches an installed copy (`probe-base is already at the latest version (1.0.0)`). After a bump, `claude plugin marketplace update al-agentic-dev` then `claude plugin update <name>@al-agentic-dev` installs it (`updated from 1.0.0 to 1.0.1`). Auto-update is off for a third-party marketplace unless the user turns it on.

## The manifest that passed

```json
{
  "name": "al-agentic-dev",
  "owner": { "name": "Naveksa" },
  "plugins": [
    { "name": "al-agentic-dev", "source": "./" },
    { "name": "mattpocock-skills",
      "source": { "source": "url", "url": "https://github.com/mattpocock/skills.git" } },
    { "name": "bcquality",
      "source": { "source": "url", "url": "https://github.com/microsoft/BCQuality.git" },
      "skills": ["./skills/"] },
    { "name": "al-language-server-go-windows",
      "source": { "source": "git-subdir", "url": "https://github.com/SShadowS/al-lsp-for-agents.git",
                  "path": "al-language-server-go-windows" } }
  ]
}
```

`plugin.json`: `"dependencies": ["mattpocock-skills", "bcquality", "al-language-server-go-windows"]` — bare names, same marketplace, no `allowCrossMarketplaceDependenciesOn`.

## Probes

1. **Fresh install** — `claude plugin validate` passes; install succeeds with `(+ 3 dependencies …)`.
2. **bcquality loads through our entry** — `claude plugin details bcquality@al-agentic-dev`: `Skills (1) al-code-review`. BCQuality has no `plugin.json`; the entry's `"skills": ["./skills/"]` is copied from BCQuality's own marketplace entry.
3. **LSP survives the sparse clone** — cache holds `.lsp.json`, `plugin.json`, `bin/al-lsp-wrapper.exe`, `bin/al-call-hierarchy.exe`, `bin/alsem.exe`; session log: `Loaded 1 LSP server(s) from plugin: al-language-server-go-windows`.
4. **Clash** — official `mattpocock-skills` installed first, then ours: five plugins enabled, two named `mattpocock-skills`; see Answer.
5. **Update** — a local git repo as the `url` source: commit without bump ignored; bump installed after `marketplace update` + `plugin update`.

## Side findings

- An entry's `description` replaces the upstream plugin's description in `claude plugin details`; copy the upstream text.
- mattpocock-skills' `version` (1.2.3) comes from its own `plugin.json`; bcquality's 0.2.0 was picked up without a `version` in our entry.
- Git on Windows fails the clone with `'$GIT_DIR' too big` when `CLAUDE_CONFIG_DIR` is very long (a probe artifact; a normal `~/.claude` is short).
- Skill namespaces are plugin names, not marketplace names: `mattpocock-skills:grilling` and `bcquality:al-code-review` are unchanged by re-listing.

## Hybrid: mattpocock-skills from the official marketplace

No plugin source type points at another marketplace's entry; the dependency itself does. `plugin.json` declares `"mattpocock-skills@claude-plugins-official"` beside the bare `"bcquality"` and `"al-language-server-go-windows"`, our marketplace lists only bcquality and the LSP, and `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]` lifts the trust block.

"Claude Code adds Anthropic's official marketplace for you the first time you start an interactive terminal session" ([Install plugins](https://code.claude.com/docs/en/plugins/install.md)), so any developer who has opened Claude Code once already knows it.

6. **Official known, mattpocock-skills not installed** — `(+ 3 dependencies: mattpocock-skills, bcquality, al-language-server-go-windows)`; list shows `mattpocock-skills@claude-plugins-official` enabled.
7. **Official copy already installed** — `(+ 2 dependencies: bcquality, al-language-server-go-windows)`; the existing `mattpocock-skills@claude-plugins-official` is reused, one copy, no clash.

On a config that never ran an interactive session, the official dependency errors until `claude plugin marketplace add anthropics/claude-plugins-official`, then self-heals (#24). mattpocock-skills then moves only when Anthropic bumps the SHA the official marketplace pins, as ADR 0002 already assumed.
