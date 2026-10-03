# Claude Code exclusive, github.com home

This plugin is a permanent fork for Naveksa of a Copilot-first plugin built for 9Altitudes, whose AL repositories lived on 9altitudes.ghe.com. It targets Claude Code only, and the Plugin repository lives and is distributed on github.com. Dual Copilot/Claude support is rejected because it is what made the hooks and gates heavy, and tracking the 9Altitudes predecessor is rejected because nearly every file diverges once the tool and the host both change.

## Consequences

- The plugin carries no Copilot manifest or hook formats, no `~/.copilot` paths, no Copilot tool names, and no non-Claude model tiers; the dev-time instructions and gates are written for Claude Code only.
- The MIT `LICENSE` names Flemming Bakkensen as the sole copyright holder; neither 9Altitudes nor Naveksa holds a line, and the marketplace `owner` is Flemming Bakkensen.
