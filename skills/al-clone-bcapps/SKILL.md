---
name: al-clone-bcapps
description: Clone Microsoft's W1 application source (BCApps) at the app's resolved BC version into .bcapps/ for reading and searching platform code. The provision task's second step, and runnable anytime the clone is missing or suspect.
disable-model-invocation: true
---

# /al-clone-bcapps — the platform source clone

Symbols say whether a name exists; the clone shows how Microsoft implements it.
This skill keeps a searchable W1 checkout of the Base Application, the System
Application, Business Foundation, and the first-party apps under `.bcapps/`,
matched to the BC version the app targets.

## Precondition

The one dependency is the symbol cache: `symbols.lock.json` must exist for this
app, meaning a `/al-provision` run has landed at least once. Missing → stop and
name `/al-provision` as the step that produces it.

Beyond that, run it anytime — as the provision task's second step when routed
there, or ad hoc whenever `.bcapps/` is missing, broken, or suspect. Task-file
state is `/al-routing`'s.

## Target

- **Version** — the resolved `Microsoft.Application` version in
  `symbols.lock.json` under `~/.bc-symbol-cache/<publisher>/<name>/<app id>/`
  for the app `/al-provision` refreshed. Its major.minor names a branch of
  `https://github.com/microsoft/BCApps`: `releases/<major>.<minor>` when that
  branch exists, else `releases/<major>.x`, and `main` when the version is past
  the newest release branch.
- **Scope** — W1 only; apps here ship against the unlocalized release. The
  sparse set is `src/System Application`, `src/Business Foundation`,
  `src/Layers/W1/BaseApp`, `src/Layers/W1/Tests`, and `src/Apps/W1`.

## Run

When `.bcapps/` exists and its checked-out branch equals the target branch, the
step is green — leave it as it is; drift within a branch is deliberately left
alone. Otherwise delete `.bcapps/` and clone fresh:

```
git clone --depth 1 --single-branch --branch <target> --sparse \
    --filter=blob:none https://github.com/microsoft/BCApps .bcapps
git -C .bcapps sparse-checkout set "src/System Application" \
    "src/Business Foundation" "src/Layers/W1/BaseApp" \
    "src/Layers/W1/Tests" "src/Apps/W1"
```

Either way, the repo's `.gitignore` carries a `.bcapps/` line — add it when
missing. Green when the checked-out branch equals the target and every folder
in the sparse set is populated.

## Close

Name the outcome — `.bcapps/` on its branch, ready to search, or one line
naming what failed in the terms the developer acts on: the manifest that is
missing, the branch that did not resolve, the network. Clearing a red is the
developer's move; re-run this skill afterwards.

Ran as the provision task's step → then `/al-routing`. Ran ad hoc → close back
into the work that needed the clone; nothing to route.
