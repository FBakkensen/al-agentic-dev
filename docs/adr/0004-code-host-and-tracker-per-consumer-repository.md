# Code host and Tracker per Consumer repository, GitHub through `gh`

Naveksa is moving its AL repositories from Azure DevOps to GitHub, under the `naveksadk` organization, one repository at a time and in no known order; a repository's code and its work items can move separately. So each Consumer repository has its own Code host, which its remote names, and its own Tracker, which its setup records, in any combination, and no skill depends on which.

## Considered Options

- **One host for the whole plugin, switched on a date.** Rejected: nobody knows the order, and repositories sit on both hosts for an open-ended time.
- **The Tracker follows the Code host.** Rejected: a repository can move its code before its work items, or the other way round.
- **A GitHub MCP server bundled beside `ado`.** Rejected for the `gh` CLI: mattpocock-skills' own GitHub tracker template already speaks `gh`, there is no server to bundle or token to configure per developer, it runs on every OS, and since `gh` 2.99.0 it sets issue types, sub-issues, and blocking edges and attaches images natively.
- **The GitHub organization fixed in `plugin.json`, as `ado` fixes `naveksaas`.** Rejected: the remote already names the owner.

## Consequences

- Tracker specifics live only in the Tracker doc `al-setup-matt-pocock-skills` writes into the Consumer repository, from a seed template or the user's description, with the types and fields the user confirms; skill bodies and descriptions name no Tracker, type, or field.
- Code-host specifics live in one sibling file per Code host inside `al-pull-request` and `al-pr-shepherd`, chosen from the remote.
- A GitHub pull request names an Azure DevOps work item as `AB#<id>`, which links only once the Azure Boards app is connected to `naveksadk`.
- On a GitHub Tracker, images attach through `gh --attach`, so `gh` 2.99.0 or later is a developer requirement; `--attach` takes media only.
- On GitHub, a pull request is ready to merge when the repository's own rules say so; the skills add none of their own.
- The `ado` server is bundled, and Azure DevOps support has no end date.
