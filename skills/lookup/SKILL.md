---
name: lookup
description: "One platform question in, a sourced answer out in seconds. Use when about to write AL that depends on platform behavior not verified in this session — trigger and validation semantics, posting touchpoints, locking — or when a Base App precedent, a BC idiom, or a review rule needs a citation."
---

# lookup — the sourced answer

One question in, one sourced answer out, in seconds. When looking up costs one call, looking it up is less work than faking a citation. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Consult the map first

`docs/precedent-map.md` in the consumer repo holds every answered question — a table `| date | question | answer | source |`, newest first. A hit there ends the run before any search. No file means no map yet; the first append creates it with the table header.

## Four sources, picked by question class

| Question class | Source | Copilot name |
|---|---|---|
| Platform and language semantics — what a property, trigger, or method does | Microsoft Learn MCP | microsoft_docs_search, then microsoft_docs_fetch for the full page |
| BC idioms, patterns, best practices | bc-code-intelligence MCP | find_bc_knowledge and get_bc_topic; ask_bc_expert for judgment; analyze_al_code over a snippet |
| Precedent by example — how the Base App does it | the version-matched BCApps clone | grep pointed at `.bcapps/` explicitly (it is gitignored, so a workspace-wide grep skips it), then view the file |
| Review rules and quality precedent | the BCQuality index | `.bcquality/knowledge-index.json` — one minified line, parse it as JSON — then the article it names |

A miss falls through to the next source that fits the question; no source answering is an honest result, reported as such. A missing clone names its producer — /al-clone-bcapps or /al-clone-bcquality — and the run answers from the remaining sources. The clone is version-matched through `symbols.lock.json`: read `.bcapps/release` first, and `.bcapps/main` only for the folders release lacks — that code is next-major, ahead of what the app runs against.

## The ledger entry

The answer's durable form is one line:

```
verified: <claim> — <source pointer>
assumed: <claim> — not verified
```

A valid pointer is a Learn URL, a BCApps file and line, a bc-code-intelligence topic id, or a BCQuality article path. Writing skills carry these entries in their receipts; review reads the ledger first.

## Append to the map

A fresh answer appends its row to `docs/precedent-map.md` — append only; the developer's next commit carries the row.

## Deep questions go to /research

A whole-feature shape question — which BC pattern, which tables and extensions, which Base App seams — belongs to the native /research command, with the `.bcapps/` and `.bcquality/` paths named in its prompt. lookup stays the in-flight fast path.

## Close

State the answer with its pointer, name the map row appended or the map hit reused, and hand the ledger line to the caller. Invoked by the user directly, that one answer is the whole run.
