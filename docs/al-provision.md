# al-provision

## What it is for

Runs the feature's provision task: refresh the AL compiler, the symbol packages, the analyzers, and — when breaking-change detection is on — the release baseline. Then it flips the task and opens the first slice.

Provision is a per-feature refresh, not machine setup. All four of those move between BC releases, so the feature's first task absorbs that drift before anything gets built on a stale toolchain.

## When you reach for it

- The feature's `kind: provision` task — the `T-001` that [`/al-scope`](al-scope.md) brackets every feature with — is open.
- The same task after a red run, once you have cleared what its `Last run:` line names.

[`/al-build`](al-build.md) is a prerequisite skill — it owns the run.

## What it produces

A refreshed build environment, and the task file flipped:

- **Green** → `/al-routing` settles the task and the provisioning gate lifts. That is the first slice opening.
- **Red** → the task stays open and its body's `Last run:` line names what failed in terms you can act on: the missing prerequisite, the package that did not resolve, the tool that is not on PATH. Clearing it is your move; re-run the skill afterwards.

Provision and breaking-change are the two ops kinds. Neither carries a phase, and neither passes through [`/al-refine`](al-refine.md).
