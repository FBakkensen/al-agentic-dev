---
name: al-research
description: Use whenever /mattpocock-skills:research runs in an AL repository, a folder that holds an `app.json` and `.al` source, in the main session or in a subagent. A folder without them gets no addition.
---

# al-research - the AL sources and the findings ledger

In: `/mattpocock-skills:research` running in an AL repository. The entry skill owns the process: primary sources, one cited Markdown file. This addition supplies the AL sources, the clone rule, and where the findings go.

## Sources, in order

1. **The precedent map** that /al-lookup keeps, read in its row format before any search. A hit is a verified claim and ends that question.
2. **Microsoft Learn**, through `mcp__plugin_al-agentic-dev_microsoft-learn__microsoft_docs_search`, then `mcp__plugin_al-agentic-dev_microsoft-learn__microsoft_docs_fetch` for the full page.
3. **The Base App source** in the BCApps clone: `Grep` pointed at `.bcapps/` explicitly, `.bcapps/release` first, and `.bcapps/main` only for the folders release lacks, since that code is next-major.
4. **/al-environment-data**, for what data is actually there. It reads GET only, so research changes no environment.

A question that no source answers stays an `unresolved:` line naming each source searched.

## The clone

A question that needs Base App source while `.bcapps/` is missing runs /al-clone-bcapps. When that skill stops because `symbols.lock.json` is missing, the blocker is a /al-build provisioning run: write that out as an `unresolved:` line, finish the findings below, and end the turn.

## The findings

The findings are one file of /al-lookup's ledger lines, each with its source pointer:

```
verified: <claim> — <source pointer>
assumed: <claim> — not verified
unresolved: <question> — searched: <source locations>
```

The file lives on a throwaway `research/<name>` branch, written from a second git worktree outside the repository folder, so the lead's checkout and branch never move. The agent adds that worktree on the new branch at the lead's `HEAD`, writes the file where the entry skill says, commits it, pushes the branch, and removes the worktree folder; the branch stays.

▶ haiku · /al-commit the complete worktree at <the second worktree's path> → commit hashes and subjects, remaining worktree

Each `verified:` claim also enters the precedent map: hand its question to /al-lookup, which appends the row and commits it on the lead's branch. /al-lookup owns every map change; this skill edits no map.

## Grounding

The agent confirms every BC object, table, field, procedure, event, enum value, and dialog text a finding names or judges by a lookup in this session, never from recall, and writes every finding in Business Central vocabulary.

## Close

Done when the pushed `research/<name>` branch holds the findings file, every `verified:` claim has its map row or a map hit, and the reply names the branch and the file for the caller's pointer.
