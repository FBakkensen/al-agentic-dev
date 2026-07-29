# al-sync-main

## What it is for

Brings a feature branch current with main by rebasing onto it, then mechanically renumbers any object or field number the branch introduced that main has since claimed.

Rebase, never merge: a rebase replays this branch's commits on top of main, so every collision that surfaces belongs to this branch and is the one that moves.

## When you reach for it

- Main has moved ahead of the branch and you are about to open a PR.
- You are returning to a branch after time away.
- A build breaks on an object or field number main already uses.

Start from a clean tree on a branch that is not main. [`/al-build`](al-build.md) is a prerequisite skill — the gate runs at both ends of the sync.

## What it produces

The branch replayed on top of main with both gates green, and each renumbered object reported as old → new. Or one clear question, where the collision is a decision rather than arithmetic.

- **Baseline gate first.** A red before the rebase is reported as pre-existing and stops the run, so the rebase never takes the blame for it.
- **Mechanical conflicts** — the same object type and number, or the same field number, claimed by both sides with no overlapping logic — are resolved by keeping both declarations and renumbering afterwards.
- **Everything else stops and asks.** Conflicting logic in one object, or one object name carrying two different numbers because the concept was modelled twice, aborts the rebase and comes back to you with the object type, number, file, and reason.
- **The renumber pass runs once**, after the rebase completes, never per commit. Only objects and fields this branch introduced are eligible to move, and the replacement number comes from the project's ID allocator or from a workspace scan — never from recall.

Spec folder numbers and ADR numbers this branch minted that main has since taken are renamed on the same terms.
