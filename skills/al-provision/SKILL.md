---
name: al-provision
description: Run the feature's provision task — refresh the AL toolchain through /al-build. The first move of every feature.
disable-model-invocation: true
---

# /al-provision — run the provision task

Provision is a per-feature refresh, not machine setup. The toolchain moves
between BC releases, so the feature's first task absorbs that drift before
anything is built on a stale toolchain.

## Precondition

Run it on the feature's `kind: provision` task while that task is open — first
time, or as a re-run once the developer has cleared what the task body's
`Last run:` line names. Task-file state is `/al-routing`'s.

Any other `kind:` → stop and name the kind you found. A settled provision task →
stop; the environment is already refreshed for this feature — unless a later
gate reported the baseline cache empty or stale, in which case re-run on the
settled task and leave its state as it stands.

## Run

Invoke `/al-build` and ask it for the provision run — compiler, symbols,
analyzers, and the breaking-change baseline when detection is enabled. It is one
command, run once; `/al-build`'s reported outcome is the verdict.

## Close

Name the outcome — the environment refreshed, or one line naming what failed in
the terms the developer acts on: the prerequisite that is missing, the package
that did not resolve, the tool that is not on PATH. Clearing a red is the
developer's move; re-run this skill afterwards.

Then `/al-routing`.
