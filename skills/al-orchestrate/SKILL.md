---
name: al-orchestrate
description: "Conduct a scoped feature from the feature session: spawn slice workspaces up to the parallel cap, run each pipeline skill as its own fresh conversation with its own model, relay child questions, merge slice PRs on Clean. Use when /al-scope closes on a scoped work-item tree and the session rolls into coordination, or when the user starts or resumes a feature by root work item id."
---

# al-orchestrate — the feature conductor

One session per feature is the user's cockpit. After `/al-scope` lands the tree, this session does no task work itself: it maintains the slice work, hands the user only what needs them, and forwards everything else. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Rebuild, never remember

`/al-orchestrate <root work item id>` starts or resumes coordination, and every run rebuilds the whole picture from durable stores — this conversation is disposable, archived any time, and a fresh run takes over mid-feature. The sources: the work-item tree under the root through the one-hop WIQL sweeps `/al-routing` owns, PR and CI state through `gh`, and the child conversations from the local session store — `session_store_sql`, matched on the slice branch — plus each child's session-state folder under the CLI home. Nothing lives only in this conversation's context.

## One workspace per slice

A ready slice — every Predecessor edge into its story satisfied — gets one workspace: one worktree on the slice branch its story names, cut from its stack base; one BC container through `/al-build`'s container-per-branch; one slice PR for the branch's life. Rework lands in the same workspace, and the workspace is removed when its PR has merged and feature-branch CI is green.

Inside the workspace, every skill run on a task is its own fresh conversation, started as a detached shell process:

```
copilot -C <worktree> -p "/<skill> <task id>" --model <pick> --allow-all-tools
```

A resume of a paused conversation repeats `-C <worktree>` and the permission flags — the file-path allowlist comes from the resuming process, not the session, and a bare resume gets its workspace writes denied.

The task's tier tag is the natural input for the model pick from the ladder in `config/al-orchestrate.json` (`parallelCap`, `modelLadder`; a copy at the consumer repo root overrides) — cheap where the conversation drives tools, premium where judgment lives; the packaged agents `al-review-lens`, `al-spec-reviewer`, and `al-knowledge-leaf` keep their own pins inside any conversation. Cross-skill episodes — a walk pausing on a defect, the repair, the resumed walk — are further conversations in the same workspace. Each child closes through `/al-routing` in its own context; the orchestrator never moves work-item state itself.

## The loop

Sweep the tree, spawn ready slices up to `parallelCap`, queue the rest; inside a slice, tasks run in Predecessor order.

- A skill run that plans before it acts starts with `--plan`: read `plan.md` from the child's session-state folder, resume the child with approval when the plan conforms to the task's contract, or send it back naming the mismatch.
- Advance on artifacts, never on a child's claim: the commit on the slice branch, the state `/al-routing` recorded, the green the gate reported.
- Merge a slice PR when `/babysit-pr` reports Clean and the slice's walk has passed — a merge commit into the feature branch, never a squash — then update dependent slice branches from it.
- Escalate to the user, never absorb: human reviewer feedback, verification walks, `/al-quiz`, any stop, and the root-PR ship moment after `/al-sync-main`.

## One cockpit

A child's question arrives in its final response or its event log. Relay it to the user here — plain text, lettered options, recommendation marked — and carry the answer back by resuming that conversation. The user leaves this session only to walk a verification: the container and the canvas live in the slice workspace.

## Sensing

Event-driven first: a finished conversation reports in its process output, a paused one leaves `plan.md` or a question. While any child runs, keep one session automation sweeping every ~5 minutes; clear it when none run. A child silent past a sweep: tail its `events.jsonl` in the session-state folder — a pending question or permission prompt is relayed or nudged, a dead process respawns as a new conversation in the same workspace (the commits survive), anything else escalates with the tail.

## Platform constraint

A conversation that needs the azure-devops MCP server runs as a direct-CLI process or in a user-created session — sessions spawned through the app's session tools get a clamped server set that drops it. The azure-devops server also needs its one-time interactive CLI auth per machine before headless children reach it.

## Close

The loop pauses on an escalation and resumes on the next event or sweep. It closes when `/al-sync-main` has run and the root PR is ready for the user's ship — the feature is out of coordination — or on a stop naming the blocker.
