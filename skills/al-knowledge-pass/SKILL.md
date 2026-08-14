---
name: al-knowledge-pass
description: "Run BCQuality's knowledge pass over a scoped AL diff and return its findings. Use when a diff needs BCQuality's judgment before a verdict on it stands, and when the review leaves run as separate calls whose results have to be checked."
---

# al-knowledge-pass — BCQuality's pass over a diff

BCQuality is the intentionally gitignored rule set, one review leaf per knowledge domain. A leaf that never reached its articles reports clean, and that report reads exactly like a judged one — so this skill runs the pass and checks every leaf result before the findings stand. Callers: `al-code-review` on the reviewed diff, `al-refactor` on the task's diff. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## The knowledge pass

`.bcquality/skills/bcquality-al-review/SKILL.md` at the workspace root is the review entry. Follow it as written: it rebuilds the knowledge index, then names the parent review entry and its leaves. How each leaf is called, what travels with the call, how references are copied, and what happens with no knowledge index are its rules and the rules it names in turn. Run it and the parent entry in the active agent; delegate neither.

A workspace-wide grep skips the gitignored clone, so point grep at `.bcquality/` explicitly and view its files directly; missing → name `/al-clone-bcquality` and stop, since every domain would go unjudged. `.bcquality/knowledge-index.json` is one minified line — parse it as JSON rather than reading or searching it by line.

Run every isolated leaf call as one `al-knowledge-leaf` invocation through the task tool — the leaf's file path under `.bcquality/`, the diff scope, and the references the parent entry names all in the prompt — parallelized in one batch. Check every leaf on the parent review entry's `sub-skills` list:

- A leaf on the list with no result → name it and stop as an invocation failure.
- `no-knowledge` where that domain carries rows in the knowledge index → it never reached its articles: name the domain unjudged and stop.
- `completed` on an empty worklist → run that isolated call again; a second result that agrees is the leaf's verdict.
- Setup text or no valid result → run that isolated call again, then stop as an invocation failure.
- A valid `partial` or `failed` result leaves its domain unjudged: name it and stop.

## Close

Return the findings, the leaves that ran, and the leaves that came back clean — or the one line naming the domain that stopped the run. This pass runs inside the flow that called it and routes nowhere: its findings are ranked and settled there.
