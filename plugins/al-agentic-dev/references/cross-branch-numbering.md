# Cross-branch numbering

Spec folders and ADRs use monotonic numeric IDs (`<NNN>-<slug>/`, `<NNNN>-<slug>.md`). A number picked from only the current working tree silently collides with parallel features in flight elsewhere: a teammate runs `/al-design` on branch `006-foo` and adds `specs/006-foo/`; you run `/al-design` from `main`, scan only `main`, pick `006`, collide on push.

This file is the single source of truth for the picking algorithm. Read it before minting either kind of number.

## When this fires

| Caller | Artifact | Width |
|---|---|---|
| `/al-event-model` (user/API-facing) or `/al-design` (backend-only) — first-feature branch + folder setup | `specs/<NNN>-<slug>/` | three-digit `^\d{3}-` |
| `/al-grill-adr` ADR offer accept | `docs/adr/<NNNN>-<slug>.md` | four-digit `^\d{4}-` |

## Algorithm

1. **Refresh remote refs.** Unless the caller already refreshed, run `git fetch --prune origin` once before scanning. If it fails (non-zero exit), note `fetch failed, continuing with local refs only` in chat once and proceed. Do not abort, do not prompt. [worktree-feature-branching.md](worktree-feature-branching.md) is the exception: its entire flow stops on fetch failure and its successful refresh satisfies this step.
2. **Collect candidates** from three sources, deduped:
   - **Working tree.** Spec folders: directory names directly under `specs/` matching `^\d{3}-`. ADRs: file names directly under `docs/adr/` matching `^\d{4}-`.
   - **Local refs.** Spec folders: `git for-each-ref --format='%(refname:short)' refs/heads`, keep names matching `^\d{3}-`. ADRs: for each local ref, run `git ls-tree -r --name-only <ref> -- docs/adr/` and keep file names matching `^\d{4}-`.
   - **Remote-tracking refs.** Spec folders: scan `refs/remotes/origin`, stripping the `origin/` prefix before regex match. ADRs: scan `docs/adr/` in every `refs/remotes/origin` ref.
3. **Extract the leading digits** from each candidate, parse to int.
4. **Pick `max(candidates) + 1`**, zero-pad to the artifact width (three for spec folders, four for ADRs). Empty candidate set starts at `001` / `0001`.

## Scope of the ADR scan

ADR files are file-shaped, so collecting candidates from other branches needs one `git ls-tree -r <ref> -- docs/adr/` per ref. Scan all local and `origin` remote-tracking refs: `/al-grill-adr` can create an ADR before a linked worktree's disposable branch converts to `<NNN>-<slug>`. The working tree's `docs/adr/` covers everything merged to the default branch.

## Race risk

Residual collision window: after the scan and before the new branch ref is published (the picking step does not push). If a teammate picks the same number inside that window, both runs arrive at push time and one rebases. Accepted trade for a small-team flow; rename if it bites. Do not attempt remote locking, ref-claiming, or retry loops at picking time.

## Offline behaviour

`git fetch --prune origin` failure (no network, VPN down, GHE outage) → continue with local refs only, surface the failure once in chat, do not abort. A number picked offline may collide with a teammate's already-pushed branch; the same residual-risk stance applies.
