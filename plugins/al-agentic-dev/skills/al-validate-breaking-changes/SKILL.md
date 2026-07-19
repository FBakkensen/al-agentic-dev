---
name: al-validate-breaking-changes
allowed-tools: ["execute", "read"]
description: "Execute the `kind: breaking-change` task in the `tasks/` folder for AL/Business Central — run al-build's `validate-breaking-changes.ps1` against the provisioned baseline, then flip the task `done` or `blocked`. Use as the feature's last task; a detected break stops for a human, never self-resolved."
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-validate-breaking-changes — run the breaking-change gate

Run one `kind: breaking-change` task against the cached baseline release, then flip its status. The AppSource-style, per-country `Run-AlValidation` answers whether the feature broke a released public API — broader than the compile-time AppSourceCop pass. `/al-build` is workflow-blind; this skill owns `validate-breaking-changes.ps1` and the task result.

`kind: breaking-change` is the feature's last task, `depends_on:` the final terminal task (last `verify`, or last technical for backend-only) → the per-feature `/al-code-review` opens it `ready` on a clean pass, so it validates the post-review bytes.

## Precondition

A `kind: breaking-change` task at `status: ready` is required. `blocked` means the feature is incomplete or per-feature `/al-code-review` has not passed → `/al-steer`. No `/al-refine`: this skill runs a script and flips status. Any other kind → **Stop**.

## Run

```powershell
pwsh "<this-skill-dir>/../al-build/scripts/validate-breaking-changes.ps1"
```

Substitute `<this-skill-dir>` with this skill's base directory (announced at skill activation) — `al-build` is a sibling skill in the same plugin.

Fresh runs delegate to the named `al-gate-runner` custom agent — the bounded executor (see [delegation.md](../../references/delegation.md)); keep verbose output out of the main session. The script reads, never downloads, the baseline cache `/al-provision` populated; `breakingChange.enabled=false` self-skips with exit `0`, `"disabled"`. The worker edits nothing and relays its exit code, supplied artifacts, and bounded verbatim stdout/stderr; this skill maps the exit code.

**Already inside an agent** mid-workflow → run `validate-breaking-changes.ps1` directly inline instead; nested custom-agent spawning does not happen, and this is not model substitution since no new spawn occurs. **`al-gate-runner` unavailable** for a fresh spawn → report `BLOCKED`, name `al-gate-runner` as the missing agent, and stop; no generic-subagent substitution (see [delegation.md](../../references/delegation.md)).

## Flip

Map the exit code, then surgical-Edit only the breaking-change task file's `status:` frontmatter line per [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md). Leave `slice:` and `kind:` intact.

| Exit | Meaning | Status |
|---|---|---|
| `0` | no break, or detection disabled | `done` |
| `3` (`Analysis`) | **breaking change detected** | `blocked` |
| `4` (`Contract`) | prerequisite failure (empty/missing baseline cache → re-run `/al-provision`; missing `AppSourceCop.json` affixes/countries; current app not built) | `blocked` |
| any other non-zero (`1`) | environment or unexpected failure (container creation, image pull, current-app compile error) — **no verdict on breaking changes**; fix, re-run | `blocked` |

## Breaking change detected → stop for a human

A confirmed break is a human merge-time intent decision: *intended* → major bump and accept; *accidental* → fix the schema change. Exit `3` → `blocked` and `/al-steer`; never auto-fix or auto-accept.

A `4` (`Contract`) or other non-zero prerequisite failure → `blocked`, fix the prereq (re-run `/al-provision` for an empty cache), re-run.

## Next step

- **`done` (exit `0`):** the feature's last gate is clear. `Next:` merge.
- **Break detected (exit `3`), task `blocked`:** `Next: /al-steer` for the human's intent call.
- **`4`/other prereq failure, task `blocked`:** fix the prereq (`/al-provision` for an empty cache), re-run `/al-validate-breaking-changes`.
