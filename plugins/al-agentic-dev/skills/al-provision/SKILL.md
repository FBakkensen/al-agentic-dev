---
name: al-provision
allowed-tools: ["execute", "read"]
description: "Execute the `kind: provision` task in the `tasks/` folder for AL/Business Central — refresh the build environment (compiler, symbols, analyzers, and — when enabled — the breaking-change baseline) by running al-build's `provision.ps1`, then flip the task `done` or `blocked`. Use on a `kind: provision` task at `status: ready`, or as a re-run after the developer clears the named blocker."
---

# /al-provision — run the provision task

Provision is the feature's first task, `T-001` — a per-feature refresh, not machine setup. It absorbs toolchain drift: compiler, symbols, analyzers, and the breaking-change baseline can advance between releases, so provision precedes `/al-refine` and `/al-implement`.

## Precondition

Any kind other than `provision` → Stop. The task runs at `status: ready`, or at `status: blocked` as a re-run once the developer has cleared the blocker named in `blocked-on:`. `done` → Stop: nothing to do.

## Run

```powershell
pwsh "<this-skill-dir>/../al-build/scripts/provision.ps1"
```

Replace `<this-skill-dir>` with this skill's base directory announced at activation; `al-build` is its sibling skill in the plugin.

- A fresh run delegates this one command to the named `al-gate-runner` custom agent. Its own body carries the worker rules; this skill maps the relayed exit code.
- Already inside an agent mid-workflow → run the command inline. No nested spawn.
- `al-gate-runner` unavailable for a fresh spawn → report `BLOCKED`, name it as missing, and stop. No generic-subagent substitute.

## Write state

Map the exit code, then surgical-Edit the task's `status:` frontmatter line per [task-lifecycle.md](../../references/task-lifecycle.md), which also owns the `blocked-on:` write and delete rules. Keep `slice: provision` and `kind: provision` untouched.

| Exit | Status |
|---|---|
| `0` | `done` |
| non-zero | `blocked` |

On `done`, open the first slice: surgical-Edit every first-slice technical task with `depends_on: [T-001]` from `blocked` to `ready`.

## Stop and handoff

| Result | Next |
|---|---|
| `done`, first slice opened | `/al-refine T-NNN` on the first slice's first technical task |
| `blocked` | fix the named blocker, then re-run `/al-provision` |

Close with the task-close gate report per [GROUND-RULES.md](../../references/GROUND-RULES.md); a precondition failure closes with the one-line **Stop**.
