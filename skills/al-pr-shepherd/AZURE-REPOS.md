# Azure Repos procedure for al-pr-shepherd

Hosts: `dev.azure.com`, `ssh.dev.azure.com`, `*.visualstudio.com`.

## Ground rules

The organization is the one the `ado` server is started on in `plugin.json`.

## Read

- The pull request: `mcp__plugin_al-agentic-dev_ado__repo_pull_request`, `get` for status, mergeability, reviewers and their votes. A `mergeStatus` of `conflicts` is the conflict.
- The threads: `mcp__plugin_al-agentic-dev_ado__repo_pull_request_thread`, `list` with `fullResponse: true`. The trimmed output drops `commentType`, which tells a system thread — never feedback — from a human one.
- Branch policies: `az repos pr policy list --id <n>`.
- The driving user: the `az account show` login. A comment is theirs when its author's unique name matches.
- A blocking vote: a reviewer vote of `Waiting for author` or `Rejected`.
- A CI review's finding: a thread whose author is the project's build service identity, `<project> Build Service`, and a build policy on the pull request whose display name contains `review` carries the review. Its summary is that build service's top-level thread; its blocking items are acted on only when that policy's evaluation is rejected or failed.
- Anyone else's comment: a thread by any author other than the driving user and a review-check build service identity.

## Answer

`mcp__plugin_al-agentic-dev_ado__repo_pull_request_thread_write`: `reply` naming the fixing commit, then `update_status` to `Fixed`. A comment is answered when its thread is `Fixed`. A CI review's finding judged wrong gets the reason in the `reply`, then `update_status` to `WontFix`.

## Rerun

`az repos pr policy queue --id <n> --evaluation-id <id>`; the evaluation id comes from the build policy's entry in `az repos pr policy list --id <n>`. A finding the rerun posts again is a new thread, read fresh.

## Complete

On the user's go: `az repos pr update --id <n> --status completed --merge-strategy squash`.
