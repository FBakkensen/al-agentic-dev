---
name: al-orchestrate
description: Use when a sharpened frontier bullet should run through implement, refactor, and review as one loop.
---

# al-orchestrate — one bullet, the whole loop

In: one sharpened bullet — named in the invocation, or the next ready one from the frontier store (Azure DevOps work items, or `docs/frontier.md`). The orchestrator adds sequencing and nothing else: a human and this skill call each block with the same words, the blocks stay unchanged, and a decision point is never answered here — it passes through to the user verbatim. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## The sequence

/al-implement the bullet → /al-refactor → /al-review the diff against the bullet. The refactor beat is skipped only when the al-implement receipt says `Tidy: none` and names no deepening goal — an empty child run buys nothing; a receipt-named goal upgrades the refactor run to the deepening reshape. The loop ends at the review verdict — acting on findings is the user's next move: a repair pass, a re-run, or the merge path through /al-pr-shepherd.

## The mechanism, by surface

In the terminal Copilot CLI each block runs as its own headless child run — `copilot -p "/al-implement <bullet>" --plugin-dir <plugin folder>`, and likewise for /al-refactor and /al-review — the literal invocation a human types. Fresh context per block; the receipts in `.output/receipts/` and the diff carry the hand-over. In the GitHub Copilot app, follow each block's SKILL.md from the plugin folder in this session instead, one block at a time, its contract obeyed as written.

## Pauses and resume

A block that stops on a declared decision point ends the loop turn: surface the block's question verbatim, wait for the user's answer, resume. Resume is idempotent — position re-derived from the receipts, the frontier store, and git, never from a remembered step; the same wake resumes an interrupted loop days later.

## Close

The loop receipt: the bullet, each block run with its receipt's core — gate verdict, ledger count, findings — the decision points passed through, and the review verdict. Done when every block in the sequence has its receipt and the verdict sits in front of the user.
