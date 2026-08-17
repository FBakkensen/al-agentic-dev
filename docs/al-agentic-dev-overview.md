# al-agentic-dev-overview

## What it is for

The tour. It shows the pipeline in order, catalogues the skills in one line each, and tells you where to start when nothing about the feature is written down yet. It reads no repository state — it is the same tour on any repo, on any day.

It also carries the reply-shape snippet these skills assume, and installs it for you at user level on request.

## When you reach for it

- You are new to the toolkit and want the map.
- Someone asks "what skills are in here?" or "where do I start?".
- A feature is still an idea: no Design User Story yet.
- You want the reply-shape snippet installed.

Mid-feature, reach for [`/al-next`](al-next.md) instead — it reads the bound Azure DevOps work items and names the next move from actual state, which this skill deliberately does not do.

## What it produces

A tour in chat, and the entry point for the work in front of you. Nothing is written to the repository.

On request it also writes the snippet to `~/.copilot/copilot-instructions.md`, wrapped in `<!-- al-agentic-dev:start -->` / `<!-- al-agentic-dev:end -->` markers. Re-running rewrites only what sits between the markers, and a copy left by an earlier install in another home is named and offered for removal. This is user level only — it never touches the repository you are working in.
