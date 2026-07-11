# Worktree feature branching

First-feature skills read this before branching. It keeps the flow's `<NNN>-<slug>` invariant when a host created a disposable linked-worktree branch.

## Classify the checkout

1. Read the current branch. A branch matching `^\d{3}-` is an in-flight feature only when `specs/<branch>/` belongs to the requested feature; reshape in place and end branch setup. A new feature or missing folder → **Stop**.
2. Run `git rev-parse --path-format=absolute --git-dir` and `git rev-parse --path-format=absolute --git-common-dir`. Different paths identify a linked worktree.
3. Resolve the default branch below. A named current branch equal to the resolved default takes *Ordinary create*. A non-default branch named `main`, `master`, or `develop` → **Stop**. Any other named branch in the primary checkout → **Stop**; it may be user-owned.
4. A detached HEAD in the primary checkout → **Stop**. A detached HEAD in a linked worktree follows *Detached HEAD*. A named non-flow branch in a linked worktree follows *Convert the placeholder branch*.

## Resolve the default branch

Run `git fetch --prune origin`. Failure → **Stop**; the entire worktree branching flow requires fresh remote refs. This overrides the offline fallback in [cross-branch-numbering.md](cross-branch-numbering.md).

Resolve the base in order:

1. `git symbolic-ref --short refs/remotes/origin/HEAD`.
2. `git remote set-head origin -a`, then repeat step 1.
3. Existing local `main`.
4. Existing local `master`.

No base → **Stop**; the user must attach or name the repository default branch.

Use the base branch's short name when comparing it to the current branch.

## Allocate the feature name

Resolve `<NNN>` per [cross-branch-numbering.md](cross-branch-numbering.md). The successful refresh above satisfies its refresh step; do not fetch again. Derive the 2-4-word kebab-case slug, then form `<NNN>-<slug>`.

Before any mutation, reject a target that exists in `refs/heads/` or `refs/remotes/origin/`. Other remotes are outside this flow's ownership.

## Ordinary create

On the default branch, create `<NNN>-<slug>`, then create `specs/<NNN>-<slug>/`.

## Convert the placeholder branch

Keep uncommitted files; renaming preserves them. Require the current branch to add no commits beyond the resolved base:

```text
git merge-base --is-ancestor HEAD <base>
```

False → **Stop**; retain the branch or start a new worktree.

Read the configured upstream with `git for-each-ref --format='%(upstream:remotename) %(upstream:remoteref)' refs/heads/<placeholder>`. No upstream → rename the local branch, skip upstream cleanup, then create the spec folder. It must be exactly `origin refs/heads/<placeholder>`; any other upstream → **Stop**, because this flow never deletes another remote or branch.

For an `origin` upstream:

1. If `refs/remotes/origin/<placeholder>` is absent after the successful fetch, treat it as already deleted.
2. Otherwise require `git merge-base --is-ancestor refs/remotes/origin/<placeholder> <base>`. False → **Stop**; the remote branch has commits outside default.
3. Announce the exact `origin/<placeholder>` deletion, then run `git push origin --delete <placeholder>`. A `remote ref does not exist` result from a deletion race counts as success; any other failure → **Stop**, without renaming.

After origin cleanup, rename with `git branch -m <placeholder> <NNN>-<slug>`, then run `git branch --unset-upstream <NNN>-<slug>`. If rename fails after deletion, **Stop**: the local placeholder branch remains and can be renamed manually; its removed remote carried no commits outside default.

Create `specs/<NNN>-<slug>/` only after the branch operation succeeds.

## Detached HEAD

Require `git merge-base --is-ancestor HEAD <base>`. False → **Stop**; detached history is not a disposable placeholder. True → `git switch -c <NNN>-<slug>`, then create `specs/<NNN>-<slug>/`. There is no upstream to delete.

## Reused feature worktree

A matching `specs/<NNN>-<slug>/` identifies the existing feature and permits reshape in place. A request for another feature on that branch → **Stop**; use a new worktree or manually clean the existing branch.
