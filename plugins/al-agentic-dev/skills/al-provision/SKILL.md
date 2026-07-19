---
name: al-provision
allowed-tools: ["execute", "read"]
description: "Execute the `kind: provision` task in the `tasks/` folder for AL/Business Central — refresh the build environment (compiler, symbols, and — when enabled — the breaking-change baseline) by running al-build's `provision.ps1`, then flip the task `done` or `blocked`. Use on the first task of a feature, or whenever a `kind: provision` task sits at `status: ready`."
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-provision — run the provision task

Run one `kind: provision` task → refresh the build environment and flip its status. `/al-build` stays workflow-blind; this skill runs its `provision.ps1` and records the result.

Provision is the feature's first task, `T-001`. It is a per-feature freshness refresh, not machine setup: compiler, symbols, and the breaking-change baseline can advance between releases, so provision precedes `/al-refine` or `/al-implement`.

## Precondition

The selected task is `kind: provision` at `status: ready`. It carries no `Test Specification` or `Verification Plan`, so `/al-refine` does not apply. Any other kind → **Stop**.

## Run

```powershell
pwsh "<this-skill-dir>/../al-build/scripts/provision.ps1"
```

Replace `<this-skill-dir>` with this skill's base directory announced at activation; `al-build` is its sibling skill in the plugin.

Delegate the command to the named `al-gate-runner` custom agent — the bounded executor in [delegation.md](../../references/delegation.md). The worker runs this command once, edits nothing, and relays its exit code, a bounded verbatim stdout/stderr excerpt, and any supplied authoritative artifacts; this skill maps the exit code.

Already inside an agent mid-workflow → run `provision.ps1` inline. No nested custom-agent spawn occurs, so this is not model substitution.

`al-gate-runner` unavailable for a fresh spawn → report `BLOCKED`, name `al-gate-runner` as missing, and stop. Do not substitute a generic subagent.

## Write state

Read the provision task, map its exit code, then surgical-Edit only its `status:` frontmatter line under [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). Keep `slice: provision` and `kind: provision`.

| Exit | Status |
|---|---|
| `0` | `done` |
| non-zero | `blocked` |

On `done`, open the first slice: surgical-Edit every first-slice technical task with `depends_on: [T-001]` from `blocked` to `ready`. Provision owns this open; without it, the first slice remains stranded.

## Stop and handoff

Non-zero → `blocked`: the environment is not ready. Never write `done` without a clean exit; a stale environment poisons downstream compilation. `Next: /al-steer`.

| Result | Next |
|---|---|
| `done`, first slice opened | `/al-refine T-NNN` on the first slice's first technical task |
| `done`, no slices yet | `/al-event-model` for user/API-facing work, or `/al-design` for backend-only work |
| `blocked` | `/al-steer` |

## Chat close

For a status flip, use the [Gate report](../../references/voice-contract.md#gate-report) skeleton: name what provision refreshed, the failed or cleared readiness condition, the feature-pipeline fit, and the handoff. A precondition failure uses the one-line **Stop** skeleton.

## Composition

| | |
|---|---|
| **Runs after** | `/al-scope` emits `T-001 kind: provision`; this is the feature's first executed task |
| **Routes to** | first-slice technical tasks with `depends_on: [T-001]` open on `done` |
| **Failure venue** | `/al-steer` |
