---
name: al-spec-review
description: "Blind agent review of a just-written spec artifact against its sources. Use when a pipeline skill has written the Design story Description, a Test Specification, a Verification Plan, or the work-item tree whole, and its close needs fresh eyes on the artifact before anything commits."
---

# al-spec-review — the blind gate on spec artifacts

The session that wrote an artifact is its worst reader: its own rationale stands by to argue every finding down. Callers: `al-design` and `al-event-model` on the Design story Description, `al-scope` on the work-item tree it created, read back and carried in the prompt, `al-refine` on a Test Specification or Verification Plan. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## The blind contract

Run the review as one `al-spec-reviewer` invocation through the task tool — the packaged agent pins its own model and carries the per-artifact dimensions, the re-derivation rules, and the two mechanical checks (a `Contract notes:` bullet past one sentence; run narration in a prose slot). The prompt carries the artifact, its sources — the Design story Description, `CONTEXT.md`, the ADRs, the code the artifact lands on, `.bcquality/knowledge-index.json`, `.bcapps/` where cloned — and the locked constraints.

**Locked constraints** are the decisions the user settled in the caller's interview, listed by the caller. They bound the read — the artifact is judged against its sources *within* them, and no pick is re-opened.

A required clone that is missing is a blocking return to the caller, naming `/al-clone-bcapps` or `/al-clone-bcquality` — checked before the invocation, because an agent judging without its evidence base returns findings not worth having.

## Findings and disposition

`al-spec-reviewer` returns three classes, each finding a glyphed headline over three slots of one line each — `⚡ Breaks:` what goes wrong, `📍 Proof:` the source that convicts it, `🔧 Fix:` the change that clears it:

- **⛔ Blocking** — the artifact states something false or unproven: a coverage gap, a name that resolves to nothing, a verdict its source contradicts. The caller lands every blocking finding in the artifact, then one re-review; a finding still standing after that is named in the caller's close with the disagreement, one line each.
- **⚠️ Advisory** — worth knowing, not worth holding the close. Rides in the caller's close, one line each.
- **⚖️ Contradiction** — the evidence contradicts a decision the user settled. The caller cannot land it: it reopens the decision, not the artifact. The caller puts it to the user as one question before anything commits; this is the only class that reaches the user. The answer lands as the revised locked constraint: upheld, the close proceeds; overturned, the caller lands the rewrite and it joins the blocking fixes in the one re-review.

## Close

Return the findings to the caller — class, what, where, source — or that the artifact is clean; a clean read is a result, say so. This gate runs mid-close in the caller's flow and routes nowhere: the caller owns the fixes, the one re-review, and its own close.
