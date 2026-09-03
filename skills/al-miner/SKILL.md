---
name: al-miner
description: Use when the user asks to mine session history for repeated failures or steering corrections and propose standing lessons.
---

# al-miner — lessons from real history

Turn session history into standing improvements. The history already holds the training data: every retry after a compile error, every mistake repeated across sessions, every moment the user grabbed the wheel. `/chronicle` owns the mechanics it already ships; this skill adds only what it lacks. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Three signals

- **Retry-after-error** — the agent misunderstood, failed, tried again.
- **The same mistake across sessions** — one session is an accident; three are a lesson.
- **User-steering moments** — "no, stop, do it this way". Each one is a labeled example of something the agent will do wrong again. These are the gold.

## Engines by surface

`/chronicle` ships in both the terminal Copilot CLI and the GitHub Copilot app composer. `/chronicle improve` proposes lines for the repo's `.github/copilot-instructions.md` and applies only what the user approves — that shelf is chronicle's end to end; leave its work alone. `/chronicle search <terms>` is the evidence probe. Both are the user's commands, typed in the composer — a skill turn cannot type them, and a headless `copilot -p "/chronicle …"` prompt lands as plain text, not the command. Inside a run, query the session store directly with the session_store_sql tool: turns for steering phrases, events for failure patterns, the local full-text index for error signatures. The extraction itself is one worker; the lead judges which candidates become lessons:

▶ mechanical · task · extract repeated failures and steering corrections from the session store for the named range with the session_store_sql tool → candidate table with counts, date spans, session ids, and the query used

## What the miner adds

- **The user-level AL shelf** — AL-language lessons that hold in every repo, proposed as lines for the `<!-- al-agentic-dev:al-lessons -->` block in `~/.copilot/copilot-instructions.md`. Hard cap 40 lines; one failure = one line; every line ends with its evidence tag: count, date span, session ids.
- **Idiom-capsule candidates** — a pattern too big for one line, tied to a work type: data access, error handling, eventing, posting hygiene. Proposed as a candidate with the sessions that earned it, never authored speculatively.
- **The retirement pass** — re-probe the evidence behind each existing shelf line: a failure that stopped appearing gets its line proposed for removal; a failure that persists despite its line escalates to a capsule candidate, or to a developer flag when a capsule already failed.
- **AL footgun focus** — trigger suppression, Validate order, Commit placement, locking patterns, and posting touchpoints get probed hardest.

## Propose, never land

Every run's own output is one proposals file — `.output/al-miner/proposals-<date>.md` — with no shelf or capsule write. Each proposal carries the shelf it targets, the proposed line or candidate, the evidence — count, date span, session ids — and the evidence method: the exact query or search terms, so a reviewer reruns it. A count in a proposal is the number its written method returns — a threshold or filter behind a number belongs in the query itself. Verify each proposal against the platform through /al-lookup before proposing; until that verification runs, mark every proposal "history-evidenced, Learn-unverified". Applying a line is the user's act, after the run.

## Close

Name the proposals file and the proposal count per shelf, then stop. The run is done when every proposal in the file carries both its evidence and its method.
