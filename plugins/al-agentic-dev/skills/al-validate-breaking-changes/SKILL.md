---
name: al-validate-breaking-changes
allowed-tools: ["execute", "read"]
description: "Execute the `kind: breaking-change` task in the `tasks/` folder for AL/Business Central — run al-build's `validate-breaking-changes.ps1` against the provisioned baseline, then flip the task `done` or `blocked`. Use on the feature's last task, or as a re-run after the developer clears the blocker from a failed run; a detected break stops for a human."
---

# /al-validate-breaking-changes — run the breaking-change gate

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

The gate answers whether the feature broke a released public API — the AppSource-style, per-country validation against the baseline release `/al-provision` cached, broader than the compile-time AppSourceCop pass.

## Precondition

Any kind other than `breaking-change` → Stop. The task runs at `status: ready`, or at `status: blocked` as a re-run once the developer has cleared the blocker a previous run named in `blocked-on:`. A `blocked` task that never ran — `depends_on:` unsatisfied, or the per-feature `/al-code-review` has not yet opened it `ready` on a clean pass — waits on its flip owner → Stop, `/al-steer`. `done` → Stop: nothing to do.

## Run

```powershell
pwsh "<this-skill-dir>/../al-build/scripts/validate-breaking-changes.ps1"
```

Replace `<this-skill-dir>` with this skill's base directory announced at activation; `al-build` is its sibling skill in the plugin.

- A fresh run delegates this one command to the named `al-gate-runner` custom agent. Its own body carries the worker rules; this skill maps the relayed exit code.
- Already inside an agent mid-workflow → run the command inline. No nested spawn.
- `al-gate-runner` unavailable for a fresh spawn → report `BLOCKED`, name it as missing, and stop. No generic-subagent substitute.

## Write state

Map the exit code, then surgical-Edit the task's `status:` frontmatter line per [task-lifecycle.md](../../references/task-lifecycle.md), which also owns the `blocked-on:` write and delete rules.

| Exit | Meaning | Status |
|---|---|---|
| `0` | no break, or detection disabled (self-skip) | `done` |
| `3` (`Analysis`) | breaking change detected | `blocked` |
| `4` (`Contract`) | prerequisite failure — `AppSourceCop.json` missing, `mandatoryAffixes` missing, `supportedCountries` missing, current app not found, baseline cache empty, or no baseline for this app in the cache | `blocked` |
| `1` (`GeneralError`) | environment failure — container creation, image pull, current-app compile error. No verdict on breaking changes | `blocked` |
| any other exit | unexpected failure. No verdict on breaking changes | `blocked` |

## Stop and handoff

A detected break is a human merge-time intent decision: intended → major version bump and accept; accidental → fix the schema change. Never auto-fix or auto-accept.

| Result | Next |
|---|---|
| `done` | the feature's last gate is clear → merge |
| `blocked`, exit `3` | `/al-steer` for the human's intent call |
| `blocked`, exit `4` | fix the prerequisite (empty cache → re-run `/al-provision`), then re-run `/al-validate-breaking-changes` |
| `blocked`, exit `1` or any other | fix the environment, then re-run `/al-validate-breaking-changes` |

Close with the task-close gate report per [GROUND-RULES.md](../../references/GROUND-RULES.md); a precondition failure closes with the one-line **Stop**.
