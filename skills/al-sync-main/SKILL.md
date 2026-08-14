---
name: al-sync-main
description: Sync the branch with main — merge main into a live feature branch, rebase a lone one — and mechanically renumber object or field numbers main has claimed. Run it while a feature's root PR lives, or on returning to a stale branch.
disable-model-invocation: true
---

# al-sync-main — sync with main, renumber the collisions

Two modes, picked by what lives. While a feature's root PR lives, the sync target is its `feature/ab<rootId>-<slug>` branch and main merges INTO it as a merge commit — a rebase under an open stack rewrites what every slice PR stands on — and once the sync lands, each open slice PR updates from the feature branch. A lone branch with no open stack **rebases onto main** — the replay makes every surfacing collision this branch's to move.
Start from a clean working tree on a branch that is not main. Uncommitted work →
ask the user to commit or stash. Already on main → stop; nothing to sync. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Sync

1. **Baseline gate.** Run `/al-build -AllTests` on the current tip. Red → report it as
   pre-existing and stop; the sync would otherwise take the blame for it.
2. **Replay.** Record the pre-sync tip — `git rev-parse HEAD` — then
   `git fetch origin main`, and `git rebase origin/main` — feature-live, `git merge origin/main` instead.
3. **Classify each conflict** as it surfaces. One shape is mechanical: the same
   object type and number, or the same field number in one object, claimed by both
   sides with no overlapping logic. Resolve it by keeping both declarations,
   continue the replay (`git rebase --continue`; a merge concludes on its merge
   commit), and fix the number in *Renumber*.

   Everything else is a decision — conflicting logic in one object, one object name
   carrying two different numbers (the concept was modelled twice), or anything
   else the replay flags. `git rebase --abort` or `git merge --abort` so the tree
   sits back at the branch tip, then report the object type, number, file, and reason, and ask.
4. **Closing gate.** After the renumber pass, run `/al-build -AllTests` on the synced
   tree. Green → push — `git push --force-with-lease` after a rebase, plain `git push` after a merge (`git push -u origin HEAD` where no remote counterpart exists). Red → name the object, field, or
   test that broke, then the user's call: repair it in this session and rerun
   this gate, or `git reset --hard` to the recorded tip and abandon the sync.

## Renumber

One pass once the replay completes, never per commit, landed as one commit
before the closing gate. `git log origin/main..HEAD` names the objects and
fields this branch introduced — the only ones eligible to move. Find the surviving collisions with an lsp workspace-symbol
search where an AL language server runs, or with grep over the workspace; that scan is what a number is
checked against, never recall.

Move the branch-new number within the same `idRanges` bucket in the owning app's
`app.json` that the colliding number already used. The project's object-ID
allocator picks the replacement where one is configured; otherwise take the lowest
number in that bucket the scan did not hit. Rewrite the declaration and every
reference in the same file that is unambiguous — the extension's own target, an
internal field reference. An ID allocated and then abandoned goes back to the
allocator rather than leaking from the pool.

Stop and ask where a literal number sits outside its own object — `Record 50100`, a
permission set entry, an `extends` target elsewhere — and cannot be rewritten
without guessing; or where the bucket has no free slot, the user's call to widen.

A spec folder `NNN` or ADR `NNNN` this branch minted that main has since taken
renames on the same terms: the next free number of that width, scanned across
the working tree, local branches, and remote-tracking refs.

## Close

Name the outcome — the sync landed (the merge into the feature branch, or the
branch replayed onto main), gates green, pushed, and each
renumber as old → new; or the rollback and what broke — then `/al-next`. A run
stopped on an open decision ends in chat awaiting the answer, routing nowhere.
