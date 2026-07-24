# Cross-branch numbering

Spec folders and ADRs use monotonic numbers (`<NNN>-<slug>/`, `<NNNN>-<slug>.md`). This file owns the picking algorithm. Use it before minting either kind of number. Parallel worktrees mint numbers concurrently, so a scan of only the current working tree collides. `/al-grill-adr` can create an ADR before a linked worktree's disposable branch converts to `<NNN>-<slug>`, so the ADR scan covers refs of any name.

| Caller | Artifact | Width |
|---|---|---|
| `/al-event-model` (user/API-facing) or `/al-design` (backend-only) — feature branch and spec folder setup | `specs/<NNN>-<slug>/` | three-digit `^\d{3}-` |
| `/al-grill-adr` — accepted ADR offer | `docs/adr/<NNNN>-<slug>.md` | four-digit `^\d{4}-` |

## Algorithm

1. **Refresh remote refs.** Unless the caller already refreshed, run `git fetch --prune origin` once before scanning. If it fails (non-zero exit), note `fetch failed, continuing with local refs only` in chat once and proceed on local refs.
2. **Collect candidates** from three sources, deduped:
   - **Working tree.** Spec folders: directory names directly under `specs/` matching `^\d{3}-`. ADRs: file names directly under `docs/adr/` matching `^\d{4}-`.
   - **Local refs.** Spec folders: `git for-each-ref --format='%(refname:short)' refs/heads`, keep names matching `^\d{3}-`. ADRs: for each local ref, run `git ls-tree -r --name-only <ref> -- docs/adr/` and keep file names matching `^\d{4}-`.
   - **Remote-tracking refs.** Spec folders: scan `refs/remotes/origin`, stripping the `origin/` prefix before regex match. ADRs: scan `docs/adr/` in every `refs/remotes/origin` ref.
3. **Extract the leading digits** from each candidate and parse each as an integer.
4. **Pick `max(candidates) + 1`**, zero-pad to the artifact width (three for spec folders, four for ADRs). Empty candidate set starts at `001` / `0001`.

## Race risk

Picking does not push, leaving a TOCTOU race between the scan and the new branch ref's publication. That race is accepted for a small-team flow. On collision, one side renames its branch, spec folder, or ADR at rebase time. Do not attempt remote locking, ref-claiming, or retry loops at picking time. A scan left on local refs only by a failed fetch is accepted on the same terms.
