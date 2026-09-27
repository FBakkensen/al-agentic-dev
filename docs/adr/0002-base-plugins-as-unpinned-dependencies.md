# Base plugins as unpinned dependencies

This plugin is an add-on, not a standalone set: `plugin.json` declares three base plugins — `mattpocock-skills@claude-plugins-official`, `bcquality@bcquality`, and SShadowS's AL language server from `al-lsp-for-agents` — and the marketplace allowlists their marketplaces for cross-marketplace install. Skills call a base plugin's skill by name and never carry a copy; the AL-specific skills stay ours. Copies had drifted from their donors and cost a fork rulebook to keep honest, while the base plugins improve on their own.

The dependencies are unpinned by choice: each base plugin tracks whatever commit its marketplace lists, so improvements arrive without a release of ours. For mattpocock-skills a constraint is not even available — it needs `<name>--v<version>` git tags, and mattpocock/skills tags `v<version>`. The guard is detection, not pinning: a validator resolves every `<base-plugin>:<skill>` reference against that commit in the PR gate and in a daily scheduled run that opens an issue on failure.

## Considered Options

- **Soft add-on** — recommend the base plugins in the README, call nothing. Rejected: the AL skills would lose their interview engine whenever a base plugin is missing.
- **Standalone** — keep our own copies of grilling and wait-what. Rejected: two skills racing the same triggers, and a donor diff to keep reconciling.
- **Re-list a base plugin in our marketplace at a SHA we choose** — not taken: we chose to follow the base plugins and detect breakage rather than hold them back.

## Consequences

- `al-grill-me`, `al-grilling`, `al-wait-what`, and `al-unslop` retire, and with them the pinned-fork rule, `Compare-SkillToDonor.ps1`, and the fork exemptions in the gates.
- mattpocock-skills' `grilling` asks the whole frontier in rounds; one-question-at-a-time pacing goes with `al-grilling`. The connect-the-dots, visual, and business-language rules, and unslop's core cuts, move into the opt-in reply-shape output style.
- A base-plugin rename breaks our calls on users' next update until we ship a fix; the scheduled check shortens that window, it does not close it.
