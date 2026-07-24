# Worktree feature branching

Use this branch setup for `/al-event-model` and `/al-design` when the host may have created a disposable linked-worktree branch. Each route keeps the `<NNN>-<slug>` invariant. Every other checkout stops.

## Classify the checkout

Run `git rev-parse --path-format=absolute --git-dir` and `git rev-parse --path-format=absolute --git-common-dir`. Different paths identify a linked worktree. Route by the first matching row. The two `^\d{3}-` rows apply before the default branch is resolved. Every later row compares against the resolved default (*Resolve the default branch*) by its short name.

| Checkout | Route |
|---|---|
| Branch matching `^\d{3}-` whose `specs/<branch>/` belongs to the requested feature | In-flight feature — reshape in place and end branch setup |
| Branch matching `^\d{3}-` with another feature requested or the folder missing | **Stop** — use a new worktree or manually clean the existing branch |
| Named branch equal to the resolved default | *Ordinary create* |
| Non-default branch named `main`, `master`, or `develop` | **Stop** |
| Any other named branch in the main worktree | **Stop** — it may be user-owned |
| Any other named branch in a linked worktree | *Convert the placeholder branch* |
| Detached HEAD in the main worktree | **Stop** |
| Detached HEAD in a linked worktree | *Detached HEAD* |

## Resolve the default branch

Run `git fetch --prune origin` first. Failure → tell the user and ask how to proceed. This ask replaces the continue-on-local-refs fallback in [cross-branch-numbering.md](cross-branch-numbering.md).

Resolve the base in order:

1. `git symbolic-ref --short refs/remotes/origin/HEAD`.
2. `git remote set-head origin -a`, then repeat step 1.
3. Existing local `main`.
4. Existing local `master`.

No base → **Stop**. The user must attach or name the repository default branch.

## Allocate the feature name

Resolve `<NNN>` per [cross-branch-numbering.md](cross-branch-numbering.md). The successful fetch in *Resolve the default branch* satisfies its refresh step, so do not fetch again. Derive the 2-4-word kebab-case slug and form `<NNN>-<slug>`. Before changing repository state, reject a target that exists in `refs/heads/` or `refs/remotes/origin/`. Other remotes are outside this flow's ownership.

## Ordinary create

On the default branch, create `<NNN>-<slug>`, then create `specs/<NNN>-<slug>/`.

## Convert the placeholder branch

Delete nothing except the exact `origin/<placeholder>` upstream.

1. The current branch must add no commits beyond the resolved base. Check with `git merge-base --is-ancestor HEAD <base>`. False → **Stop**. Retain the branch or start a new worktree.
2. Read the configured upstream with `git for-each-ref --format='%(upstream:remotename) %(upstream:remoteref)' refs/heads/<placeholder>`. No upstream → rename with `git branch -m <placeholder> <NNN>-<slug>`, skip upstream cleanup, then create the spec folder. Any upstream other than exactly `origin refs/heads/<placeholder>` → **Stop**.
3. For the `origin refs/heads/<placeholder>` upstream: if `refs/remotes/origin/<placeholder>` is absent after the successful fetch, treat it as already deleted and continue at step 6.
4. Otherwise require `git merge-base --is-ancestor refs/remotes/origin/<placeholder> <base>`. False → **Stop**. The remote branch has commits outside default.
5. Announce the exact `origin/<placeholder>` deletion, then run `git push origin --delete <placeholder>`. A `remote ref does not exist` result from a deletion race counts as success. Any other failure → **Stop** without renaming.
6. Rename with `git branch -m <placeholder> <NNN>-<slug>`, then run `git branch --unset-upstream <NNN>-<slug>`. If the rename fails after the deletion, **Stop**. The local placeholder branch remains and can be renamed manually. Its removed remote carried no commits outside default.
7. Create `specs/<NNN>-<slug>/` only after the branch operation succeeds.

## Detached HEAD

Require `git merge-base --is-ancestor HEAD <base>`. False → **Stop**. Detached history is not a disposable placeholder. True → `git switch -c <NNN>-<slug>`, then create `specs/<NNN>-<slug>/`. There is no upstream to delete.
