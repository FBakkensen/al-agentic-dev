---
name: al-commit
description: Use when repository changes need staging and splitting into the maximum number of independently valid commits, including when another skill must commit its writes.
---

# al-commit - commit the worktree

In: the current repository worktree and any applicable Azure DevOps work-item IDs already established in the conversation. Out: every committable change recorded in the maximum number of independently valid commits.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Inspect everything

Read the full tracked, staged, and untracked diff. Treat every file in the worktree as in scope, including changes that did not originate in this session.

Stage all files by default. When a file is temporary, secret-bearing, or generated output that belongs in `.gitignore`, stop before staging it and ask one question about its disposition. Never commit a secret.

## Maximize valid commits

Partition the worktree into the largest possible number of independently valid changes. One commit carries one complete change and leaves the repository internally consistent. Split files by hunk when independent changes share a file; keep dependent code, tests, manifests, generated lockfiles, and documentation together.

Stage one group explicitly, inspect the staged diff, commit it, then continue until every committable change is recorded. Do not exclude a change because its author or session is unclear.

## Write the message

Use:

```text
<Imperative subject>

<Short reason or constraint, only when it is not obvious from the diff.>

AB#<work-item-id>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

List only the work-item IDs served by that commit, one `AB#<id>` line each. Omit the body when the subject and diff are enough. Omit work-item lines when none applies; never guess an ID.

## Close

Show each commit hash and subject, then show the remaining worktree. The run is complete when every committable change is committed and every excluded path has the user's explicit disposition.
