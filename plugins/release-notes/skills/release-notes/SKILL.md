---
name: release-notes
description: Generate release notes from per-PR analysis of merged work since the last release. Use after producing .output/releases/release-analysis.jsonl when drafting release notes, summarising changes between releases, or preparing version documentation for an AL/Business Central app.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /release-notes — PR JSONL to release notes

Turn `.output/releases/release-analysis.jsonl` into `.output/releases/RELEASE-NOTES-<VERSION>.md`. Classify one PR at a time into a single-line JSON todo description, then render the final markdown. Main context holds only the summary and final output.

One fact per analysis line. Name the page, codeunit, table, field, or action.

The section emoji in [references/output-format.md](references/output-format.md) are the explicit exception to the no-emoji prose rule.

## Resolve inputs

| Input | Contract |
|---|---|
| Analysis | `.output/releases/release-analysis.jsonl` must exist. Missing → `Stop.` Run `scripts\Get-ReleaseAnalysis.ps1` from this skill folder. |
| Output | `.output/releases/RELEASE-NOTES-<VERSION>.md`; version is `summary.appJsonDiff.version.new`, else `summary.toVersion`. Downstream tooling reads this exact path. |

## Flow

### 1. Generate analysis (if not done)

```powershell
scripts\Get-ReleaseAnalysis.ps1
```

Produces one `type == "summary"` record (boundaries, totals, files-by-category, `appJsonDiff`) and one `type == "pr"` record per merged PR (title, body, files, commits, key AL changes, breaking-change indicators).

### 2. Initialise

1. Verify: `Test-Path .output/releases/release-analysis.jsonl`.
2. Hold the `type == "summary"` version and BC compatibility in main context.
3. List `type == "pr"` records by number and title only.
4. Create Initialise, Analyse PRs, and Generate Notes todos plus one title-only todo per PR. Its description stores the JSON result.

### 3. Analyse each PR

Mark "Analyse PRs" in progress.

Apply [PR Classification Protocol](references/pr-classification.md). Store its single-line JSON in the PR todo description, then mark that todo done.

| Avoid | Required |
|---|---|
| `"desc":"Updated logic"` | Name the user-visible change. |
| `"area":"Configuration"` | Name the page, report, API, or workflow. |
| Empty `details` on a user-facing PR | Name the field, action, or page. |

Generic `"Updated logic"` means the AL surface was skipped → run the [Deep Dive Protocol](references/pr-classification.md).

### 4. Quality check (gate)

Sweep todo descriptions. PR fails gate when any of these hold:

| Symptom | Action |
|---|---|
| `desc` is generic ("Updated logic", "Fixed issue") | Deep Dive |
| `area` is vague ("Configuration", "the page") | Deep Dive |
| `details` empty on user-facing PR | Deep Dive |
| User-facing PR marked `exclude` with no justification | Deep Dive |

Deep Dive every failed PR and replace its todo description with the sharper line.

### 5. Generate the notes

Mark "Generate Notes" in progress.

Collect PR results from todo descriptions and group them:

| `type` | Section |
|---|---|
| `feature` | New Features |
| `improvement` | Improvements |
| `bugfix` | Bug Fixes |
| `breaking` | Breaking Changes & Migration Notes |
| `technical` | Technical Summary |
| `exclude` | Omitted from output |

Render with [output-format.md](references/output-format.md), apply [content-guidelines.md](references/content-guidelines.md), then write `.output/releases/RELEASE-NOTES-<VERSION>.md`.

## Edge cases

| Condition | Action |
|---|---|
| Zero PRs | Emit version header + `No changes in this release.` |
| All PRs `exclude` | Emit version header + `This release contains only internal changes.` |
| No user-facing PRs | Skip User-Facing Changes section; render Technical Summary only |
| No technical PRs | Skip Technical Summary section |

## Context management

PR diffs can be 500+ lines. Keep the summary, todo list, and final markdown in main context; load one `type == "pr"` record at a time; store every result in its todo description. Collapsing PRs into main context degrades descriptions into `Updated logic` and mixes sections.

## Per-PR cycle checklist

```
[ ] One PR record loaded; nothing else from the JSONL
[ ] Single-line JSON emitted, matches a template in references/pr-classification.md
[ ] User-facing PR cites a real page/codeunit/table/field/action
[ ] Technical PR has category + one-line summary
[ ] Breaking PR has change + exact migration steps
[ ] Result lives in the todo description, not in main context
```

## Inputs and references

| Item | Role |
|---|---|
| `scripts\Get-ReleaseAnalysis.ps1` | Produces the input JSONL. |
| [pr-classification.md](references/pr-classification.md) | Per-PR classification and Deep Dive. |
| [output-format.md](references/output-format.md) | Final markdown template. |
| [content-guidelines.md](references/content-guidelines.md) | Tone, phrasing, Good/Bad entries. |

## Out of scope

- No PR or issue links in output — release notes are self-contained.
- No re-running analysis script mid-flow — fix PR record by Deep Dive, not by regenerating JSONL.
- No alternate output paths — `.output/releases/RELEASE-NOTES-<VERSION>.md` is fixed.
- No multi-release synthesis — one version per run.
