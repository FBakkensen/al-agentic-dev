# Claude Code exclusive, github.com home, Azure Repos consumers

This plugin was built Copilot-first for 9Altitudes, whose AL repositories lived on 9altitudes.ghe.com. It is now a permanent fork for Naveksa: it targets Claude Code only, the plugin repository lives and is distributed on github.com, and consumer repositories are Naveksa AL repositories in Azure Repos alongside their Azure DevOps work items. Dual Copilot/Claude support was rejected because it is what made the hooks and gates heavy, and tracking the 9Altitudes predecessor was rejected because nearly every file diverges once the tool and the host both change.

## Consequences

- Copilot manifest and hook formats, `~/.copilot` paths, Copilot tool names, and non-Claude model tiers leave the plugin; the "Copilot-first" rules in the dev-time instructions and gates are rewritten, not extended.
- Pull-request skills move from `gh` to Azure Repos; GitHub stays only as this plugin repository's own host.
- The MIT `LICENSE` keeps the 9Altitudes copyright line and adds Naveksa's.
