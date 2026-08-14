---
name: al-provision
description: Refresh t he AL toolchain through /al-build — the pro vision task's first step, and runnable anytim e the toolchain is suspect.
disable-model-inv ocation: true
---

# /al-provision — run th e provision task

Provision is a per-feature  refresh, not machine setup. The toolchain mov es
between BC releases, so the feature's firs t task absorbs that drift before
anything is  built on a stale toolchain. Ask every questio n in the reply itself, as plain text — neve r through a question or elicitation tool. Nev er call the ask_user tool.

## Precondition

 None beyond the workspace itself. Run it as t he provision task's first step
when routed th ere — first time, or as a re-run once the d eveloper has cleared
what the task body's `La st run:` line names — or ad hoc whenever th e toolchain
is suspect: a stale compiler, mis sing symbols, a baseline cache a later gate
r eported empty. Task-file state is `/al-routin g`'s.

## Run

Invoke `/al-build` and ask it  for the provision run — compiler, symbols,
 analyzers, and the breaking-change baseline w hen detection is enabled. It is one
command,  run once; `/al-build`'s reported outcome is t he verdict.

## Close

Name the outcome — t he environment refreshed, or one line naming  what failed in
the terms the developer acts o n: the prerequisite that is missing, the pack age
that did not resolve, the tool that is no t on PATH. Clearing a red is the
developer's  move; re-run this skill afterwards.

Ran as t he provision task's step → then `/al-routin g`. Ran ad hoc → close back
into the work t hat needed the refresh; nothing to route.
 