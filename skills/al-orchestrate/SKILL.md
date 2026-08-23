---
name: al-orchestrate
description: Use when one executable AL Feature or Vertical slice has reviewed AAA and needs implementation, bounded refactoring, and read-only review coordinated across child sessions.
---

# al-orchestrate - run the execution loop

In: the executable Feature itself, or a child User Story and its parent Feature, with reviewed Gherkin and `Test specification`, plus any explicit deepening goal. If AAA is not reviewed, return `/al-test-design` as the next move and stop.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update only on an important finding, a decision point, or a changed direction.

## Run one owner at a time

1. Launch a child session for /al-implement with the work-item ID, repository, Feature contract, and exact receipt path.
2. Read its result, branch, commit, and full receipt content.
3. Unless the receipt says `Tidy: none` and the invocation names no deepening goal, launch a fresh /al-refactor child stacked on the implementation branch; pass the receipt content, reviewed AAA, Feature, and deepening goal in its kickoff.
4. When refactor ran, read its branch, commit, and updated receipt content; otherwise keep the implementation branch and receipt.
5. Launch a fresh /al-review child stacked on the latest writing branch; pass the executable work item, parent Feature, diff base, and receipt content in its kickoff.
6. After each blocking repair, launch another fresh /al-review child on the repaired branch; repeat until the verdict has no blocking findings.
7. When the `Test specification` names walkthrough proof, launch /al-walkthrough on the latest writing branch after the blocking-free review and require evidence for every such case.

In the GitHub Copilot app, use `create_session` with kickoff mode `autopilot`, then `get_session` and `send_session_message`, with the stacked branches above. `.output/` is ignored, so later app children receive receipt content explicitly rather than by path.

In the terminal Copilot CLI, give each block a UUID and run it sequentially in the current worktree as a fresh headless process: `copilot -p "/al-implement <work-item>" --session-id <uuid> --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`, then the same shape for /al-refactor when required, /al-review, and /al-walkthrough when required. The shared worktree, commits, and receipt path carry state; one process runs at a time.

Each writing child commits before returning; review remains read-only.

## Pass through decisions

When a child raises a real decision, quote it to the user with its options and recommendation. After the answer, send it back to the same child session and continue. Do not reinterpret the choice.

In the CLI, resume that child with `copilot --resume=<uuid> -p "<answer>" --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`.

## React to evidence

- A red implementation or gate result returns to the owning child.
- A blocking review finding returns to a fresh implementation or refactor child with the exact proof and fix requirement, then to step 6.
- A walkthrough mismatch returns to a writing child, then a fresh review and walkthrough.
- `non-blocking only` or `no blocking issues found` ends the review-repair loop; step 7 still runs when walkthrough proof is required.
- A module-contract dispute returns to the user rather than being decided by orchestration.

## Close

Finish with the executable item, commits, receipt, connected-object change map, gate result, review verdict, walkthrough evidence when required, and whether Feature Level 2 changed. Outcome first; no extra summary.
