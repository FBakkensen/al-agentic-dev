---
name: al-provision
description: Refresh the AL toolchain through /al-build — the provision task's first step, and runnable anytime the toolchain is suspect.
disable-model-invocation: true
---

# /al-provision — run the provision task

Provision is a per-feature refresh, not machine setup. The toolchain moves
between BC releases, so the feature's first task absorbs that drift before
anything is built on a stale toolchain. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Precondition

None beyond the workspace itself. Run it as the provision task's first step
when routed there — first time, or as a re-run once the developer has cleared
what the task body's `Last run:` line names — or ad hoc whenever the toolchain
is suspect: a stale compiler, missing symbols, a baseline cache a later gate
reported empty. Work-item state is `/al-routing`'s.

## Run

Invoke `/al-build` and ask it for the provision run — compiler, symbols,
analyzers, and the breaking-change baseline when detection is enabled. It is one
command, run once; `/al-build`'s reported outcome is the verdict.

## Close

Name the outcome — the environment refreshed, or one line naming what failed in
the terms the developer acts on: the prerequisite that is missing, the package
that did not resolve, the tool that is not on PATH. Clearing a red is the
developer's move; re-run this skill afterwards.

Ran as the provision task's step → then `/al-routing`. Ran ad hoc → close back
into the work that needed the refresh; nothing to route.
