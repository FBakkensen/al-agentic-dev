---
name: spec-team-lead
description: Use when asked to work through, implement, or coordinate every child issue of a spec issue (for example "work through all child issues of #70"). Leads an agent team, one teammate per child issue, through merged PRs to the spec's close.
---

# spec-team-lead

You are the team lead. Each child issue of the spec gets its own teammate, a separate Claude Code session in its own worktree. Teammates report only to you, and you report only to the user. You make every decision the work needs: order, concurrency, ticket ambiguities, review findings, even a change to the spec's own wording. Record each decision where it belongs (the issue, a PR comment, or a spec comment) and tell the user what you decided. The user acts only on what you physically can't do: restarting the session, and the `autoMode` rule in Preflight.

## 1. Preflight

1. **Agent teams.** Probe that this session has a team:
   - Spawn `Agent` named `probe`, model `haiku`, prompt "Reply OK".
   - `ListAgents` lists it under **Teammates** when the team exists, and under **Subagents** when it doesn't.
   - Stop the probe.

   With no team, add `"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }` to `~/.claude/settings.json`, ask the user to restart this session, and stop. A team only forms when a session starts. While the flag is on, any subagent given a name in any session launches as a teammate. That trade buys the team, and the user knows it.
2. **Teammate merges.** `claude auto-mode config | grep -c "PR merges in <owner>/<repo>"` must be at least 1. If not, give the user this rule to add under `/permissions`, Auto mode tab, allow, then wait:
   `PR merges in <owner>/<repo>: merging a pull request in <owner>/<repo> with gh pr merge <number> --repo <owner>/<repo> --merge is allowed without a human approval once its required checks pass and every review thread is resolved. The repository owner delegated these merges to Claude Code agent teammates. Enabling auto-merge (--auto) is not covered.`
   Without it, auto mode denies every teammate merge as "Merge Without Review", and you can't edit `autoMode` yourself.
3. **The implement procedure.** `jq -r '.["plugins"]["mattpocock-skills@claude-plugins-official"][0].installPath' ~/.claude/plugins/installed_plugins.json` gives the plugin path; the procedure is `<path>/skills/engineering/implement/SKILL.md`. `/mattpocock-skills:implement` can't be started by a model, so teammates read that file and follow it.
4. **Roots.** The *main checkout* is the repository the session started in. The *worktree root* is `<parent of main checkout>/worktrees/<repo name>/`.

## 2. Orient

- Read the spec issue, and list its sub-issues with the GitHub recipe in [GITHUB.md](GITHUB.md).
- For each open child, read its `## Blocked by` section and place it in a wave: *ready* when every blocker is closed, otherwise *blocked*, naming the blocker.
- Check for work already in flight, and adopt it instead of duplicating it: open PRs whose closing references name a child, and peer sessions in `ListAgents` working on a child.

This step is done when every open child is in a wave with its reason, and no child has two owners.

## 3. Start a teammate per ready child

- Run at most three or four teammates at once. Use `sonnet` unless the user named another model.
- For each ready child:
  1. Create its worktree from the main checkout: `git -C <main checkout> worktree add <worktree root>/team-<n>-<slug> -b claude/team-<n>-<slug> origin/main`. A follow-up issue always gets a new worktree; never switch branches in a working teammate's worktree.
  2. Spawn the teammate with `Agent`: name `issue-<n>`, the chosen model, and the prompt from [TEAMMATE.md](TEAMMATE.md) with every placeholder filled.
- Arm the coordinator watcher with `Monitor`, `timeout_ms` 1800000: `bash <this skill folder>/watch-team.sh <spec number>`. Re-arm it every time it expires while any child is open. It exits by itself once every child is closed.

## 4. Run the event loop

Each event gets its action at once: a `SendMessage` to the teammate that must act, or your own work. A status line to the user isn't an action.

| Event | Action |
|---|---|
| `pr-opened: #<n>` | Check `closingIssuesReferences` names the child; if it doesn't, fix the body yourself (GITHUB.md). |
| Watcher: CLEAN, `hold=0` | Every required check passed, `claude-review` included, and no thread is open: tell the teammate to merge now. |
| Watcher: DIRTY | Tell the teammate to merge `origin/main`, keep both sides of shared lists, rerun the gates, and push. |
| Watcher: FAILED-CHECKS | Read the failed log (GITHUB.md) and send the teammate the exact failing assertion and its cause. |
| Watcher: new open threads | Tell the teammate to handle each thread: fix it, or reply with reasoning, then resolve it. |
| Watcher: STILL ACTIONABLE | The teammate missed the last event; send it again, naming what to do. |
| Subagent hand-back (`agent-message`) | A teammate's helper sends its report to you. Relay it to that teammate in full. If its owner is unclear, send it to each candidate, tagged with the agent ID. |
| Teammate asks for a missing report | Resume the agent by ID with `SendMessage`, asking it to resend without redoing the work. Arm a 5-minute fallback alarm with `Monitor`; when it fires, have the teammate rerun that one step in the foreground. |
| Teammate reports a blocker or question | Check it against the ticket and spec yourself, decide, and answer. |
| `merged: #<n>` / watcher MERGED | Verify on `origin/main` that every decided fix is present, and that the child is closed. If something is missing, file a follow-up (step 5). Stop the teammate, then start the next ready child. |
| Watcher: WATCH ERROR or an empty result | Treat it as a failure: check the query by hand and fix the watcher. |

**Holds.** To keep a PR from merging until fixes land, post a `HOLD (team-lead)` review thread on it (GITHUB.md). `main` requires every conversation resolved, so GitHub blocks the merge whatever the teammate does. Before you resolve it, verify each decided fix on the PR head. Post the hold *before* you start any extra review of an open PR; a review that lands while the PR is unheld races its merge.

## 5. Reviews and follow-ups

- **The automatic review** is the required `claude-review` check, plus its inline threads. CLAUDE.md's "Working here" says how a red run is handled; teammates follow it.
- **Substitute review**, only when the automatic review can't produce a verdict on a PR:
  - Post a hold first.
  - The built-in review checks the PR branch out in this session's working directory, which is the main checkout. Run it only when the checkout is on `main` with no changes (`git -C <main checkout> status --short --branch`) and `ListAgents` shows no other session of this repository. Otherwise defer: a clean checkout can still belong to another session.
  - Run the built-in `code-review` skill with `high <pr>`, one PR at a time, then put the main checkout back on `main` if the review moved it.
  - Teammates never run the built-in review themselves; they send `review-request: #<n>`.
- **Findings.** Decide each one: a real defect, a decided change, or declined with a reason. Send the teammate a numbered list of decided fixes. When a finding shows an earlier decision was wrong, say so and supersede it explicitly, naming the issue and decision number.
- **Follow-up issues**, for findings out of a PR's scope or found after its merge: file a decided, `ready-for-agent` sub-issue of the spec in the shape of [FOLLOW-UP.md](FOLLOW-UP.md). Then give it a new worktree and a teammate. A teammate that just finished keeps its context, so resume it with the new assignment.

## 6. Finish

This step is done when all of these hold:
- The watcher reports every child closed.
- `origin/main` shows the end state the spec's Solution describes.
- CI on `main` is green for the last merge commit.
- A summary comment is on the spec: a table of each child with its PR, any spec changes with their reasons, and any decided non-changes. The spec is closed as completed.
- Every teammate is stopped.
- The team worktrees are removed with `git worktree remove`, and the team branches are deleted only once `git merge-base --is-ancestor <branch> origin/main` passes.

Leave the agent-teams flag on for the next spec, unless the user asks to turn it off (see Preflight step 1 for its side effect).

## Standing rules

- **The main checkout is shared.** Another session may be working in it, so use it read-only, plus `worktree add`, `remove`, and `prune`. The one write is the substitute-review step in section 5.
- **No silent wait.** Every watch emits each terminal state and each error, treats an empty result as an error, re-alerts a lingering actionable state, and is re-armed when it expires. Check that a watcher's query returns data before you trust its silence.
- **A rule arrives late.** A message reaches a teammate between its tool calls, and it may already have merged by then. Anything that must stop a merge is a hold thread, never a message.
