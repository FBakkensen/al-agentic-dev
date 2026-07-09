# gtm-bc-copilot-cli-playbook

Business Central agentic development tools — a GitHub Copilot CLI plugin marketplace for AI-assisted AL development.

## Install

```bash
copilot plugin marketplace add https://9altitudes.ghe.com/gtm-general/gtm-bc-copilot-cli-playbook.git
copilot plugin install <plugin-name>@gtm-bc-copilot-cli-playbook
```

Requires access to the 9altitudes GHE tenant.

## Plugins

- `al-agentic-dev` — full AL/BC dev stack. Agentic flow (`/al-steer`, `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-research`, `/al-implement`, `/al-page-script`, `/al-user-verification`, `/al-refactor`, `/al-mutate`, `/al-code-review`, `/al-quiz`) + build/test gate (`/al-build`, `/al-provision`, `/al-validate-breaking-changes`) + telemetry probes (`/al-debug-logging`) + the `bc-standard-reference` custom agent (canonical BaseApp / System Application / APIV2 lookup against `microsoft/BCApps`). Tour: `/al-agentic-dev-overview`
- `al-language-server` — AL language server for the Copilot CLI LSP tool (requires the AL dotnet tool ≥ 18.0 on PATH)
- `grill-me` — interview and stress-test plans
- `release-notes` — PR-driven release note generation

## Manifest

- Marketplace: `.github/plugin/marketplace.json`
- Plugin: `plugins/<plugin-name>/plugin.json`

## License

MIT
