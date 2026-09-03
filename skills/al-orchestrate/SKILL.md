---
name: al-orchestrate
description: Use when one executable AL User Story has reviewed AAA and needs implementation, bounded refactoring, and read-only review coordinated across child sessions.
---

# al-orchestrate - run the execution loop

In: the executable Original User Story, or a child User Story and its Original User Story, with reviewed Gherkin and `Test specification`, plus any explicit deepening goal. If AAA is not reviewed, return `/al-test-design` as the next move and stop.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update on an important finding, a decision point, or a changed direction.

## Run one owner at a time

1. ▶ execution · session · /al-implement with the work-item ID, repository, Original User Story contract, and exact receipt path → its result, branch, commit, and full receipt content
2. ▶ execution · session · Launch a fresh /al-refactor child stacked on the implementation branch with the receipt content, reviewed AAA, Original User Story, and any named deepening goal → its branch, commit, and updated receipt content
3. ▶ frontier · session · /al-review stacked on the latest writing branch with the executable work item, Original User Story, diff base, and receipt content → the verdict and its findings
4. After each blocking repair, a fresh /al-review line on the repaired branch; repeat until the verdict has no blocking findings.
5. When the `Test specification` names walkthrough proof and the review has no blocking findings, dispatch the walk.

   ▶ execution · session · /al-walkthrough on the latest writing branch with the executable item and Original User Story → evidence for every walkthrough case

In the GitHub Copilot app, each line is `create_session` with kickoff mode `autopilot`, the tier's model and effort, `coordinate_with_creator`, and `notify_on_idle`, stacked on the branch named; read results with `get_session`. `.output/` is ignored, so later app children receive receipt content explicitly rather than by path.

In the terminal Copilot CLI, give each block a UUID and run it sequentially in the current worktree as a fresh headless process: `copilot -p "/al-implement <work-item>" --model <tier model> --session-id <uuid> --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`, then the same shape for /al-refactor, /al-review, and /al-walkthrough when required. The shared worktree, commits, and receipt path carry state; one process runs at a time.

Each writing child calls /al-commit before returning; review remains read-only. Every kickoff carries this line: `You run unattended; the user cannot answer mid-task. Proceed on every reversible step the User Story already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.` The pass-through below is that decision's only route.

## Pass through decisions

When a child raises a real decision, quote it to the user with its options and recommendation. After the answer, send it back to the same child session and continue. Do not reinterpret the choice.

In the app, send it with `send_session_message`. In the CLI, resume that child with `copilot --resume=<uuid> -p "<answer>" --model <tier model> --allow-all-tools --no-ask-user --plugin-dir <plugin-folder>`.

## React to evidence

- A red implementation or gate result returns to the owning child.
- A blocking review finding returns to a fresh implementation or refactor child with the exact proof and fix requirement, then to step 6.
- A walkthrough mismatch returns to a writing child, then a fresh review and walkthrough.
- `non-blocking only` or `no blocking issues found` ends the review-repair loop; step 7 still runs when walkthrough proof is required.
- A module-contract dispute returns to the user rather than being decided by orchestration.

## Close

Finish with the executable item, commits, receipt, connected-object change map, gate result, review verdict, walkthrough evidence when required, and whether Original User Story Level 2 changed. Outcome first; the close stands on its own for a reader who sees only the last message.
