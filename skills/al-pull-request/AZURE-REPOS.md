# Azure Repos procedure for al-pull-request

Hosts: `dev.azure.com`, `ssh.dev.azure.com`, `*.visualstudio.com`.

## Read the existing pull request

Call `mcp__plugin_al-agentic-dev_ado__repo_pull_request`: `list` filtered by `sourceRefName`, then `get` with `includeWorkItemRefs` for its linked work items.

## Description cap

Azure Repos caps the description at 4000 characters.

## Create or update

With no pull request, create a ready one with `mcp__plugin_al-agentic-dev_ado__repo_pull_request_write`, action `create`, with `isDraft` false. With one, call `update` with the title, description, and `isDraft` false, passed explicitly on every `update` because the tool's default would otherwise publish a draft silently.
