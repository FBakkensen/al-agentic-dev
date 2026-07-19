# release-notes

Generate release notes from per-PR analysis of merged work since the last release.

*Dev-time only — this file never ships. The shipped surface is `SKILL.md`, `scripts/`, and `references/`; see the root `AGENTS.md` "Shipped artefacts vs dev-time files".*

## Layout

```
skills/release-notes/
├── SKILL.md
├── scripts/
│   └── Get-ReleaseAnalysis.ps1    # produces .output/releases/release-analysis.jsonl
└── references/
    ├── pr-classification.md       # per-PR classification + Deep Dive Protocol
    ├── output-format.md           # final markdown template
    └── content-guidelines.md      # tone, phrasing, Good/Bad entries
```

## Editing rules

- **JSONL contract is load-bearing.** `Get-ReleaseAnalysis.ps1` emits one `type == "summary"` record and one `type == "pr"` record per PR; `SKILL.md`'s load steps depend on these names. Change the script's output schema and `SKILL.md` + `pr-classification.md` in lockstep, never one alone.
- **Per-PR todo descriptions are the buffer.** The skill writes each PR's single-line JSON result into that PR's todo description, so main context never holds the diff — *the* reason this skill scales to releases with many PRs. Preserve it when refactoring; the named risk lives in `SKILL.md`'s "## Context management" paragraph: collapsing PRs into main context degrades descriptions into `Updated logic` and mixes sections.
- **Output path is fixed.** `.output/releases/RELEASE-NOTES-<VERSION>.md`. Downstream tooling reads this exact path.
- **Reference-doc split, one concern each.** `pr-classification.md` (per-PR protocol), `output-format.md` (markdown template), `content-guidelines.md` (tone). Do not merge them.
- **Six classifications.** `feature`, `improvement`, `bugfix`, `breaking`, `technical`, `exclude`. A seventh changes both the output template and the classification table.
- **Canonical emoji exception is a coupling, not decoration.** `SKILL.md`'s body prose — not its `**Style:**` line — calls the section emoji "the explicit exception to the no-emoji prose rule"; `output-format.md`'s section-emoji set (`🚀`/`✨`/`🐛`/`⚠️`) is the other half of that one contract. Change both in the same edit or neither.
- **Style line borrows the rubric, owns no `voice-contract.md`.** This plugin has no shared voice file — `SKILL.md`'s `**Style:**` line is a standalone copy of the marketplace's default class (see `plugins/al-agentic-dev/references/voice-contract.md`'s class-scoped Style rule). A rewrite touching those shared clauses there must scan this file's Style line too; it will not update automatically.
