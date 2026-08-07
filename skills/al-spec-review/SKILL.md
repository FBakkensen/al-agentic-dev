---
name: al-spec-review
description: "Blind agent review of a just-written spec artifact against its sources. Use when a pipeline skill has written architecture.md, event-model.md, a Test Specification, a Verification Plan, or the tasks/ folder whole, and its close needs fresh eyes on the artifact before anything commits."
---

# al-spec-review — the blind gate on spec artifacts

The session that wrote an artifact is its worst reader: its own rationale stands by to argue every finding down. This skill reads the artifact blind — the document and its sources, never the writing session's reasoning — and returns findings to the caller. Callers: `al-design` on `architecture.md`, `al-event-model` on `event-model.md`, `al-scope` on the `tasks/` folder, `al-refine` on a Test Specification or Verification Plan. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## The blind contract

If your harness supports subagents, run the review as one full-capability subagent on the same model as this conversation, carrying only the artifact, its sources — `architecture.md`, `event-model.md` when present, `CONTEXT.md`, the ADRs, the code the artifact lands on, `.bcquality/knowledge-index.json`, `.bcapps/` where cloned — and the locked constraints. Otherwise the caller runs this rubric itself in one pass, reading artifact and sources only, dimensions in order. `.bcapps/` and `.bcquality/` are intentionally gitignored: when either is a source, inspect it directly because default workspace search can omit it; use a search mode or file reading that includes the clone. A required clone that is missing is a blocking return to the caller, naming `/al-clone-bcapps` or `/al-clone-bcquality`.

**Locked constraints** are the decisions the user settled in the caller's interview, listed by the caller. They bound this read — the artifact is judged against its sources *within* them, and no pick is re-opened.

The review re-derives the rules rather than trusting citations: narrow `.bcquality/knowledge-index.json` to the domains the artifact touches and read those articles as your own evidence base — a `Researched:` bullet is a claim, not proof. A `Precedent` verdict is a claim too: a `reused:` or pattern verdict the `.bcapps/` source does not support is blocking. Every exact BC name the artifact writes is confirmed by a lookup run in this review, never recalled.

## Findings and disposition

Three classes, each finding a glyphed headline over three slots of one line each — `⚡ Breaks:` what goes wrong, `📍 Proof:` the source that convicts it, `🔧 Fix:` the change that clears it:

- **⛔ Blocking** — the artifact states something false or unproven: a coverage gap, a name that resolves to nothing, a verdict its source contradicts. The caller lands every blocking finding in the artifact, then one re-review; a finding still standing after that is named in the caller's close with the disagreement, one line each.
- **⚠️ Advisory** — worth knowing, not worth holding the close. Rides in the caller's close, one line each.
- **⚖️ Contradiction** — the evidence contradicts a decision the user settled. The caller cannot land it: it reopens the decision, not the artifact. The caller puts it to the user as one question before anything commits; this is the only class that reaches the user. The answer lands as the revised locked constraint: upheld, the close proceeds; overturned, the caller lands the rewrite and it joins the blocking fixes in the one re-review.

Two mechanical checks ride every artifact read: a `Contract notes:` bullet past one sentence, and run narration in a prose slot — each an advisory finding naming the bullet.

## Dimensions per artifact

**`architecture.md`** — Trace coverage both ways: every `event-model.md` Action, Business Event, and Status transition owns a named AL slot, and a module nothing on the claim side or the brownfield inventory asked for is an unclaimed obligation `/al-scope` turns into tasks nobody needed. Apply the delete test to each module — delete it in imagination: complexity that vanishes was a pass-through, complexity that reappears across callers earned its keep. A seam without both adapters named is indirection wearing a seam's name. Decision logic reachable only through posting or a TestPage is a finding now, while a seam still costs one edit. A module the platform already ships, per the `.bcapps/` read, is blocking.

**`event-model.md`** — Every step carries all five slots and an outcome an external observer can see; every branch has its own section and the failure path is visible. Every BaseApp name in a slot — persona, event, page — has a positive lookup; every Action, Business Event, and Status traces to a `CONTEXT.md` term or the BC baseline. AL realisation leaked into a slot — an `OnAfter*`, a codeunit name — belongs to `architecture.md` and is a finding here.

**Test Specification** — A decision branch, error path, or boundary value no `B#`/`R#` row carries is a gap. Read every `Covered By` case body against its row: a case exercising a different defect than the row names is not coverage, however near it reads. An `Assert` that would pass without the behaviour — observing only `Arrange` state, restating the `Act`, deriving its expected value the way production will — proves nothing. Judge `New and Modified Objects` against the workspace: a `New:` on an object already there, a `Modified:` on one absent that no earlier task lands, a signature the object contradicts, a listed object no case exercises. An `Integration` case whose `Contract notes:` names neither wall nor seam is an unearned push-up.

**Verification Plan** — Every user-visible outcome, exception path, and Status boundary the slice promises carries a journey or contract entry, and every `Observable Checks:` bullet reads the screen or the API body, never internal state. `Record: yes` claims a wall no AL test layer crosses; `Record: no` needs the named case or test procedure behind it. Every Role, Action, Business Event, View, and Status quotes `event-model.md` verbatim, and every page, action, and field named exists in the workspace — a name that is not there stops the walk.

**`tasks/` folder** — Every timeline step — or `architecture.md` slice, backend-only — appears as a `slice:` value; both ops brackets are on disk; each slice's verify task carries the edges `/al-scope`'s shape requires. Every `depends_on:` edge is sourced from the architecture: a false edge serialises independent work, a missing one opens a task before its ground exists. A description carrying two behaviours hides one from its own red; an object a description names that the architecture never carries is a guess.

## Close

Return the findings to the caller — class, what, where, source — or that the artifact is clean; a clean read is a result, say so. This gate runs mid-close in the caller's flow and routes nowhere: the caller owns the fixes, the one re-review, and its own close.
