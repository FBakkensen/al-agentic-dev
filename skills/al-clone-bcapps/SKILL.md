---
name: al-clone-bcapps
description: Clone Microsoft's BCApps source when the checkout is missing or suspect and platform implementation needs reading at the app's resolved BC version.
---

# /al-clone-bcapps — the platform source clone

Symbols say whether a name exists; the clone shows how Microsoft implements it
— a searchable W1 checkout of BCApps under `.bcapps/`, matched to the app's BC version — intentionally gitignored, so point grep at `.bcapps/` explicitly and view its files directly; a workspace-wide grep skips it. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Precondition

The one dependency is the symbol cache: `symbols.lock.json` must exist for this
app, meaning a `/al-build` provision run has landed at least once. Missing → stop
and name that run as the step that produces it.

## Target

- **Version** — the resolved `Microsoft.Application` version in
  `symbols.lock.json` under `~/.bc-symbol-cache/<publisher>/<name>/<app id>/`.
  Its major.minor names a branch of `https://github.com/microsoft/BCApps`:
  `releases/<major>.<minor>` when it exists, else `releases/<major>.x`, and
  `main` when the version is past the newest release branch.
- **Scope** — W1 only; apps here ship against the unlocalized release. The
  wanted set is `src/System Application`, `src/Business Foundation`,
  `src/Layers/W1/BaseApp`, `src/Layers/W1/Tests`, and `src/Apps/W1` — probed
  on the target branch with `git ls-tree`, never assumed: the Base
  Application lives on `main` only until the 29 branches, so release
  branches lack both `src/Layers` folders.

## Run

Two checkouts, one `.gitignore` line covering both: `.bcapps/release` on the
target branch, sparse-set to the wanted folders it carries; `.bcapps/main` on
`main`, sparse-set to only the folders the target branch lacks — absent when
the target branch carries everything, `main` itself included. Base App read
from `.bcapps/main` is next-major code, ahead of what the app runs against.

When the green bar below already holds, leave both checkouts alone; drift
within a branch is deliberately unhandled. Otherwise delete `.bcapps/` and
clone each checkout fresh — `core.longpaths` before the sparse set, since
BCApps paths overrun Windows' path limit; it is harmless elsewhere:

```
git clone --depth 1 --single-branch --branch <branch> --sparse \
    --filter=blob:none https://github.com/microsoft/BCApps .bcapps/<checkout>
git -C .bcapps/<checkout> config core.longpaths true
git -C .bcapps/<checkout> sparse-checkout set <its folders>
```

Either way, the repo's `.gitignore` carries a `.bcapps/` line — add it when missing,
then ask /al-commit to commit the complete worktree. Green when `.bcapps/release`
sits on the target branch and every wanted folder is populated in exactly one checkout.

## Close

Name the outcome — the checkouts on their branches, ready to search, or one
line naming what failed in the terms the developer acts on. Clearing a red is
the developer's move; re-run this skill afterwards. Close back into the work
that needed the clone.
