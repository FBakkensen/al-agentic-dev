---
name: al-lookup
description: "One platform question in, a sourced answer out in seconds. Use when about to write AL that depends on platform behavior not verified in this session — trigger and validation semantics, posting touchpoints, locking — or when a Base App precedent, a BC idiom, or a review rule needs a citation."
---

# al-lookup — the sourced answer

One question in, one sourced answer out, in seconds. When looking up costs one call, looking it up is less work than faking a citation.

## Consult the map first

`docs/precedent-map.md` in the consumer repo holds every answered question — a table `| date | question | answer | source |`, newest first. A hit there ends the run before any search. No file means no map yet; the first append creates it with the table header.

## Two sources, picked by question class

| Question class | Source | Claude Code name |
|---|---|---|
| Platform and language semantics — what a property, trigger, or method does; what an analyzer rule means | Microsoft Learn MCP | `mcp__plugin_al-agentic-dev_microsoft-learn__microsoft_docs_search`, then `mcp__plugin_al-agentic-dev_microsoft-learn__microsoft_docs_fetch` for the full page |
| Precedent by example — how the Base App does it | the version-matched BCApps clone | `Grep` pointed at `.bcapps/` explicitly (it is gitignored, so a workspace-wide `Grep` skips it), then `Read` the file |

A miss falls through to the next source that fits the question; if none answers, name the unresolved question and each source searched instead of claiming a verified answer. A missing clone names its producer, /al-clone-bcapps, and the run answers from the remaining sources. The clone is version-matched through `symbols.lock.json`: read `.bcapps/release` first, and `.bcapps/main` only for the folders release lacks — that code is next-major, ahead of what the app runs against.

## The ledger entry

The result's durable form is one line:

```
verified: <claim> — <source pointer>
assumed: <claim> — not verified
unresolved: <question> — searched: <source locations>
```

A valid pointer is a Learn URL or a BCApps file and line. Use `unresolved:` when no claim can be stated; name the locations actually searched, not missing clones. Writing skills carry these entries in their receipts; al-review reads the ledger first.

## Own the map change

Whether /al-lookup runs standalone or inside another skill, it owns every change it makes to `docs/precedent-map.md`. A map hit writes nothing. A search with no sourced answer writes nothing.

For a fresh answer, require a clean map path before writing; a dirty path stops the run before the map changes. Append the row, then ask /al-commit to commit the complete worktree. Return only after one resulting commit contains the map change and the map path is clean.

If /al-commit cannot record the map change, remove only this run's row from the index and working tree, then report the exact error. The caller receives the ledger line, never ownership of a dirty map change.

## Deep questions go to /mattpocock-skills:research

A whole-feature shape question — which BC pattern, which tables and extensions, which Base App seams — belongs to /mattpocock-skills:research, with the `.bcapps/` path named in its prompt. al-lookup stays the in-flight fast path.

## Close

State a sourced answer with its pointer and map commit or hit, a tentative claim, or the unanswered question with locations searched. Hand the corresponding `verified:`, `assumed:`, or `unresolved:` ledger line to the caller. Invoked by the user directly, that result is the whole run.
