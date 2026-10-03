# Azure Repos procedure for al-pr-shepherd

Hosts: `dev.azure.com`, `ssh.dev.azure.com`, `*.visualstudio.com`.

## Ground rules

The organization is the one the `ado` server is started on in `plugin.json`.

## Read

- The pull request: `mcp__plugin_al-agentic-dev_ado__repo_pull_request`, `get` for status, mergeability, reviewers and their votes.
- The threads: `mcp__plugin_al-agentic-dev_ado__repo_pull_request_thread`, `list` with `fullResponse: true`. The trimmed output drops `commentType`, which tells a system thread — never feedback — from a human one.
- Branch policies: `az repos pr policy list --id <n>`.
- The driving user: the `az account show` login. A comment is theirs when its author's unique name matches.

## Answer

`mcp__plugin_al-agentic-dev_ado__repo_pull_request_thread_write`: `reply` naming the fixing commit, then `update_status` to `Fixed`. The reply, posted under the user's identity, is how the next read tells instruction from answer.

## Complete

On the user's go: `az repos pr update --id <n> --status completed --merge-strategy squash`.
