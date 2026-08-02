---
name: review-skills
description: Review the shipped skills under skills/ against the rubric in .github/instructions/skills.instructions.md. Use when the user asks for a skills review, after a batch of skill edits before a PR, or when a generic code review keeps landing on scripts instead of the skills. Dev-time only; never ships.
---

# Review the shipped skills

**A finding is a numbered rule plus the line that breaks it.** The rubric is `.github/instructions/skills.instructions.md`; every finding cites its rule number and the offending `file:line`. What has no rule number is not a finding here: scripts belong to the PowerShell gate, mechanical frontmatter/link/name checks belong to `scripts/Validate-Skills.ps1`, and a real defect the rubric cannot name is a **rubric gap** — report it in its own section as a proposed rule, not as a violation.

Two passes.

**Per-skill.** One reviewer per folder under `skills/`, the full rubric text plus that folder's SKILL.md and siblings as the whole input. If your harness supports subagents these parallelize; otherwise walk the folders in one pass. Each reviewer returns only violations: rule number, `file:line`, the quoted line, one sentence on why. The judgement rules carry the weight — router quality, density, positive phrasing, checkable endings, AL grounding. Raise a rule the CI validator also covers only when the validator provably passes the violating text.

**Cross-skill.** One reviewer with all descriptions, every `/al-*` handoff, and every task-frontmatter value list side by side. It checks closure:

- Every state a skill emits — a `phase:`/`status:` value it writes, a `/al-x` it hands to, a condition it leaves the feature in — is claimed by a model-invocable skill's trigger or an `/al-next` routing branch. An emitted state nothing claims is the stall class; rank it top. A branch that settles inside a live interview is not an emitted state — only what crosses a session boundary unclaimed counts.
- The task-frontmatter value lists are complete and identical in every skill that reads or writes a task file (rule 30 names the lists).
- No two descriptions claim the same state (rule 10, applied across the model-invocable four).

**Merge.** Dedupe overlapping findings, drop any whose quoted line does not exist in the file, rank by blast radius: pipeline stalls, then misrouting, then density and phrasing.

**Report.** The `rule N — file:line — quoted line` form is for the reviewers and the merge pass, never for the reader. The report is the 10 most critical findings and one closing line — nothing else: no density grab-bag, no checked-and-cleared section, no rubric-gap section. Each finding:

```
**N. 🟥 STALL — <defect in plain words, few words>**
⚡ **Breaks:** <the failure scenario, one sentence>
📍 **Proof:** "<short recognizable quote from the skill, no line numbers>"
🔧 **Fix:** <the target behaviour, one line>
```

Severity tags rank the 10: 🟥 stall (pipeline stops), 🟧 misroute/drift (wrong move possible), 🟨 waste (density, phrasing). The closing line is a single sentence: how many lower-ranked findings and rubric-gap proposals were withheld, available on request. Report only; edits are a separate instruction.
