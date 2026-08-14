# al-provision

## What it is for

Runs the provision task's first step: refresh the AL compiler, the symbol packages, the analyzers, and — when breaking-change detection is on — the release baseline. The task's second and third steps are `/al-clone-bcapps` and `/al-clone-bcquality`; the first slice opens once the whole chain has run green.

Provision is a per-feature refresh, not machine setup. All four of those move between BC releases, so the feature's first task absorbs that drift before anything gets built on a stale toolchain.

## When you reach for it

- The feature's provision task — the first rung of the ops chain [`/al-scope`](al-scope.md) brackets every feature with — is open.
- The same task after a red run, once you have cleared what its `Last run:` line names.
- Ad hoc, whenever the toolchain is suspect — a stale compiler, missing symbols, an empty baseline cache. An ad-hoc run routes nowhere.

[`/al-build`](al-build.md) is a prerequisite skill — it owns the run.

## What it produces

A refreshed build environment, reported onward:

- **Green** → `/al-routing` settles the step; the next rung of the provision chain is the move, and after `/al-clone-bcquality` the first slice opens.
- **Red** → the task waits and its `Last run:` line names what failed in terms you can act on: the missing prerequisite, the package that did not resolve, the tool that is not on PATH. Clearing it is your move; re-run the skill afterwards.

The ops bracket — provision, clone-bcapps, clone-bcquality first, breaking-change last — never passes through [`/al-refine`](al-refine.md).
