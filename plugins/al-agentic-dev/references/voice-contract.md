# Voice contract

Style rule lives at the top of each SKILL.md as a one-line inline declaration, and at the top of each custom agent under `agents/` the same way. This file carries the non-style disciplines: lexical, citation, shape, and artifact-vs-chat scoping. Disciplines below apply to durable artifacts (`event-model.md`, `architecture.md`, the per-task files under `tasks/`, ADRs, `CONTEXT.md`, `.out-of-scope/`, `.not-yet-specified/`) and to chat output; [Custom agent return contract](#custom-agent-return-contract) below extends this scope to a shipped custom agent's own `## Return` payload — a channel distinct from both.

## Format

Applies everywhere — chat output and artifacts — unless a specific skeleton below dictates otherwise.

Token thrift — lede-first as the default, payload-preserving cuts, keep grammar — lives in [thrift-rules.md](thrift-rules.md); the box is the shape, thrift is the wording inside it.

**Bold header** on every section.

Verdict, conclusion, or status on line 1. Context and detail after.

3 sentences max per paragraph. Empty line between paragraphs.

- Bullets for lists.
- Not prose dressed as a list.

## Boxes first

A reader scans boxes and skips prose walls — a skipped reply is accepted unread. So every substantive chat reply (gate event, findings, analysis, task close) opens with a **borderless two-column verdict box** the reader can stop after. The named skeletons below are this box's specialisations; a substantive reply that matches no named skeleton uses the generic rows:

| | |
|---|---|
| **Outcome** | what happened, one line |
| **Changed** | objects / files touched, one line |
| **Before you accept** | the single most important check, phrased as an action ("post a Sales Order with a blank `Location Code`, look at the Item Ledger Entry"), never a category ("verify the tests"); nothing left to check → say why ("build gate ran green") |

Trivial replies — one-liners, quick lookups, the mid-task gate line, the Answer skeleton — skip the box; a box around one sentence is noise.

**Prose cap.** After the box: no paragraph over 3 sentences, no reply over ~15 lines of prose. Overflow goes into a file linked from the box, or waits for the user to ask for more.

**Visual over verbal.** Anything structural — flow, before/after, architecture, options — gets a markdown table or a Unicode box/tree diagram, not a paragraph. A 4-line diagram beats a 10-line description.

## One decision per question

Need the user's input → one question per message, lettered options, the recommended option first and marked. Never a paragraph ending in an open "thoughts?".

Carve-out: the ask-before-reveal questions in `/al-user-verification` and `/al-quiz` are witness elicitation, not decisions — options that reveal the expected value would lead the witness. That contract is untouched.

## Pre-send checks (no exam-speak)

Exam-speak is prose graded on plausibility instead of facts — it reads right and carries nothing a reader can act on or refute. Run these checks on every draft before sending; they apply doubled to relayed subagent findings.

1. **Per sentence: name the observation that would prove it wrong.** None exists → delete the sentence, or get the missing fact first (read the object, run the gate) and write that instead.
2. **Per quality word and verdict ("harmless", "clean", "confirmed", "sound"): the same paragraph carries the named object and the fact that makes the word true.** Absent → the word is a note-to-self that a fact is missing; go get it.
   - ✗ "the stale filter is harmless by construction"
   - ✓ "the stale filter is harmless: its only reader was `GetOpenEntries`, which now keys on `Posting Date` instead"
3. **Per bug/fix statement: it must survive the handoff test — a dev who wasn't in this session can act on it.** A bug states cause → effect in named objects ("`PostDocument` exits at the early `IsHandled` return without assigning `"Document No."`, so `InsertLedgerEntry` writes ''"), not a category ("an edge case in the posting path"). A fix states what changes where to what, not its intended quality ("make it more robust").
4. **Per count of evidence ("all 4 lenses", "both sources agree"): list the items.** Can't list them → you don't have them → say what was actually checked.
5. **Per coined term and back-reference: define at first use, restate instead of pointing.** "My lean: (b)" → "My lean: (b) — reuse the `IEnvironment` seam". A term minted this session gets its one-line definition or gets cut.
6. **Delete self-grades.** "Thorough", "systematic", "comprehensive", "Perfect!" describe the author, not the work. Show scope by naming what was covered: not "a comprehensive review" but "all 6 codeunits the diff touches plus the two test apps".

## BC vocabulary

| Use | Not |
|---|---|
| Insert / Modify / Delete | Create / Update / Remove |
| Post | Submit |
| Validate | Check |
| Get / Find | Fetch |
| Ledger Entry | Transaction |
| No. | ID |
| Procedure | Method |
| Codeunit | Class |

Name the specific object and procedure: "extract `PostSalesOrder` from codeunit 80 into `Sales-Post Impl`", not "refactor the codeunit".

## Names are the citation

Use the test codeunit, procedure, table, field, event publisher by name. `ABCCopyDocSubscribers.OnAfterInsertToSalesLine` is the address; future readers grep, no inline `(see: file.al:120)` annotations.

## Tasks appear by name in chat

A bare `T-NNN` in chat is illegible — the reader skims past it, and a skimmed line is accepted unread. So in everything the human reads, a task's title or slug accompanies its id at first mention: `copy-doc-dimension-inheritance (T-014)`, or `Next: /al-implement T-014 — copy-doc-dimension-inheritance`. The id rides along (it is the invocation argument and the grep handle); it never stands alone. Agent-channel surfaces — frontmatter, `depends_on:` lists, filenames, commit trailers — keep bare ids; this rule governs chat only.

## Evidence bar (citation chain)

BC training data is stale fiction; your confidence about a name, signature, or pattern is not evidence any are right. One bar, stated here once; writing skills point at it.

- **Names.** Every exact BC-specific name (object, procedure, event, table, field, enum value, caption) in an artifact or AL code must be backed this session by `al-symbols-mcp` / `grep` hit, or a quoted fetch. Recall does not satisfy. Names cited upstream count only when `grep` against the upstream file returns them this session.

- **Minted names.** A name that does not exist yet cannot have a workspace hit. Its bar is a zero-hit collision lookup this session (`al-symbols-mcp` / `grep` — genuinely new, not shadowing) plus BC-vocabulary compliance.
  - Collision scope: object names against workspace object declarations; fields against the target table and its extensions; procedures against the target object only; enum values against the target enum and its extensions.
  - Base object in a dependency (not workspace source): grep covers workspace extensions only — the `/al-build` compiler is the backstop for base-field collisions.
  - `New and Modified Objects` is proposal, not carried evidence. The skill that lands the object re-runs the collision lookup in its own session.

- **Constructs.** Workspace evidence stops at names. BC construct classes — record loop + modify, `SetLoadFields`, temp record lifecycle, page/report surface, `Commit` — carry execution-order and platform-cost semantics legacy code cannot vouch for. First write of a construct class in a task → fetch the matching topic per [bc-code-intelligence-dispatch.md](bc-code-intelligence-dispatch.md) or a Microsoft Learn passage, and declare it: `Researched: <construct> → <topic id / Learn URL>`.

- **Satisfiers.** Any verbatim-quoted fetch with one-line citation counts.
  - Names: `bc-code-intelligence` topic, Microsoft Learn, or `bc-standard-reference` agent.
  - Constructs: topic or Learn passage only — BaseApp source shows an instance, not the rule.
  - `/al-research` is mandatory when sources disagree or a fetched fact lands in a durable design artifact (`event-model.md`, `architecture.md`, `CONTEXT.md`, ADRs).

- **Trace.** Declare in chat as `Researched: <fact> → <source path / URL / topic id>`. Task-scoped citations also land as `Contract notes` bullets at task reconcile — the one inline-citation carve-out, making skipped research visible to `/al-code-review` and the next session. Everything else in artifacts stays names-only.

## Artifacts get scanned, not slow-read

Reader lands to decide one task. They scan landing points top to bottom (IDs, statuses, ledes, labels, table rows) and slow-read only the one block that catches the eye.

Multi-fact passages get one fact per landing line — bullets, callouts, table rows, or sub-`<details>`, your call.

Read only the first line of each landing point in your draft. If that vertical strip says what is there, ship.

## Lists of findings

Multi-item findings: label every line (`Finding:` / `Where:` / `Action:`), lede first. Each finding passes pre-send check 3 — cause → effect in named objects, actionable without this session.

## Tables of facts

Field/value recaps: borderless two-column table, not bullets.

## No workflow chatter in artifacts

Artifact carries the forward-facing fact in declarative voice. Workflow log belongs in the commit message.

- Do NOT prefix lines with the agent that decided (`/al-implement decision:`).
- Do NOT narrate TDD steps as prose ("bullet 1 went red on stub, green on body fill").
- Do NOT cite rubber-duck or advisor-checkpoint reconciliation.

Place an advisor checkpoint inline at the moment the gate fires, not as a top-of-file blockquote.

## Relaying subagent findings

The session owns the quality of what lands in chat, not the subagent — verify every subagent result before using it.

- Every spawn/invocation includes this line verbatim: **findings must name file, object, and the observed fact; no verdict words without the check that produced them.** The shipped custom agents under `agents/` carry it themselves; ad-hoc spawns (gate workers, mutation workers, general delegations) get it in the spawn prompt.
- Before relaying a subagent finding, run pre-send check 3 on it: names no object or observation → send the agent back for the mechanism, or read the file yourself.
- Relay through the verdict box or the owning skeleton — never forward a subagent's prose raw.

## Custom agent return contract

A shipped custom agent's `## Return` payload travels to the invoking skill, not straight to the user — the skill relays it through [Relaying subagent findings](#relaying-subagent-findings) above. These five disciplines shape the payload itself, before that relay, and apply to every `agents/*.agent.md` this plugin ships.

- **Bounded lede/purpose.** Line 1 of `## Return` is a fixed all-caps type label (`GATE RELAY`, `RESEARCH ARBITRATION`, `ARCHITECTURE CANDIDATE`, `REVIEW JUDGMENT`, `MUTANT CYCLE RELAY`, and the `al-review-refactor-*` lenses' `* RESHAPE FINDINGS` labels) naming what the payload *is*, not a summary of it — for an agent built to return exactly one payload of one identity. Three existing shapes are explicit, deliberate exceptions because their callers already parse the current shape: `al-red-green`'s `## Outcome note` leads with a dynamic verdict chosen from `GREEN` / `PUSH-UP` / `BLOCKED` (the caller branches on which fired — the verdict *is* the payload's identity, not a fixed label naming a single type); the six `al-review-cr-*` lenses (`al-review-cr-appsource`, `al-review-cr-bc`, `al-review-cr-bugscan`, `al-review-cr-comments`, `al-review-cr-compliance`, `al-review-cr-perf`) return zero or more raw, unlabeled finding blocks with no line-1 label at all; and `al-review-refactor-perf` carries its `PERFORMANCE RESHAPE FINDINGS` sentinel whenever the scan ran, but when the `al-performance` MCP is unavailable it returns exactly the one line `perf scan skipped: al-performance MCP not available` instead — no sentinel, no other line, the sole exception to its own label. Collapse any of these exceptions into the fixed-label shape only alongside a matching update to every caller that parses it today (`/al-implement`, `/al-code-review --fix` for `al-red-green`; `/al-code-review` and `al-review-judge` for the six lenses; `/al-refactor` and `al-review-judge` for `al-review-refactor-perf`'s skip line) in the same change — never restyle one side alone. The purpose paragraph right after the H1 header stays bounded to what the caller supplies, what this agent does with it, and where the boundary sits — never open-ended scope, background, or rationale, regardless of which Return shape the agent uses.
- **Explicit ownership.** That purpose paragraph states in plain terms what stays outside this agent's authority — typically an explicit "The caller owns diagnosis / classification / edits / routing / workflow state" clause; an agent scoped to produce one option among several instead says so directly ("an option for comparison, not a final design decision"). An agent authorized to judge still names the decisions its judgment does not extend to.
- **Evidence-versus-judgment separation.** An agent whose `## Boundary` forbids diagnosis, classification, or verdict returns observed facts only — a missing artifact is `missing`, a gate result is its exit code and excerpt, never an inferred cause or a classification label. An agent whose `## Boundary` authorizes judgment grounds every classification or conclusion in a named fact its own `Evidence:`/`Reason:` field carries — never a verdict the payload does not trace.
- **Class-scoped Style declarations, derived from job not model tier.** The `**Style:**` line is not copy-pasted across surfaces — its descriptor word is chosen by what the payload is authorized to do, not by which model tier executes it. An agent whose `## Boundary` confines it to observed-fact relay or mechanical execution — a gate run, a mutation cycle, a raw scan, a quoted-evidence fact arbitration — declares "Exact —" plus its own non-judgment verb ("relay artifacts verbatim", "distinguish observation from judgment", "conclusions follow quoted evidence"). An agent whose `## Boundary` authorizes a bounded candidate, a pick, or a classification declares "Opinionated —" plus its own decisive verb ("make one coherent candidate", "classify each finding", "pick a side"). Three concepts recur across every Style line — required intent, not verbatim clauses to copy: (1) *concise* — cut filler, keep grammar; (2) *when the job has a causal, sequential, or cyclical shape worth flagging*, mark it with an arrow (→) worded to that shape ("for causality" for a general causal claim, "for the fixed cycle" for a fixed apply→gate→revert pipeline, "for cause and effect" for a classification's reasoning) — and omit the arrow clause entirely when the job is a single bounded relay with no causal shape to mark; (3) *technical terms and errors are named or quoted exactly as observed*, worded to the agent's actual evidence domain ("code and errors" for an AL-facing agent, "commands and errors" for a command-relay agent). Reword or drop a clause to fit the job; never invent a fourth concept or contradict one of these three. A skill's `SKILL.md` follows the same three concepts under the default "Opinionated — pick a side" class unless its own authority differs.
  - **Frozen exemplar proving the point.** `al-researcher` runs on the Opus arbiter role — the same tier `al-review-judge` occupies with an "Opinionated — classify each finding" Style — yet its Style stays "Exact — conclusions follow quoted evidence", because its job is to arbitrate one *fact* bound to quoted sources, not to pick among options or classify a batch. The arbiter tier thus carries both Style classes; the rest of today's fleet correlates only incidentally (every worker and bounded-executor agent happens to be "Exact —"; every smart agent happens to be "Opinionated —") — never infer one from the other. Judge Style from the job named in the purpose paragraph and `## Boundary`, then check the result still reads correctly against the current fleet.
  - **Frozen Style-line variants, byte-for-byte from PR #17 — do not edit these agents to conform.** The five canonical agents' shipped Style lines already vary the three concepts above to fit each job; they are the rule's source, not exceptions to it:
    - `al-design-option`: `Concise — cut filler, keep grammar. Opinionated — make one coherent candidate. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.` — full form, no omission.
    - `al-gate-runner`: `Concise — cut filler, keep grammar. Exact — relay artifacts verbatim. Technical terms exact, commands and errors quoted verbatim.` — arrow clause dropped (its single bounded command relay has no causal shape to mark); "commands and errors" instead of "code and errors" (its evidence domain is CLI commands, not AL code).
    - `al-mutant-cycle`: `Concise — cut filler, keep grammar. Exact — distinguish observation from judgment. Arrows (→) for the fixed cycle. Technical terms exact, code and errors quoted verbatim.` — arrow clause reworded to name its fixed apply→gate→revert cycle instead of general causality.
    - `al-researcher`: `Concise — cut filler, keep grammar. Exact — conclusions follow quoted evidence. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.` — full form, no omission.
    - `al-review-judge`: `Concise — cut filler, keep grammar. Opinionated — classify each finding. Arrows (→) for cause and effect. Technical terms exact, code and errors quoted verbatim.` — arrow clause reworded to name a classification's cause-and-effect reasoning instead of general causality.

    None of these five needs an edit to satisfy this rule. A new or re-rolled agent may vary or drop a clause the same way, provided the change is job-derived and not a copy-paste shortcut.
- **Preserving artifact-native structure.** `## Return`'s labeled fields are this agent's own contract, shaped to what it actually produces (`Constraint:` / `Shape:` / `Flow:` / `Seams:` / `Trade-offs:` / `Evidence:` / `Assumptions:`; or `Command:` / `Exit code:` / `Artifact:` / `Output excerpt:`). Never force a Return payload into the verdict box or the Lists-of-findings shape above — those govern what the invoking skill shows the *user* once it has read and relayed this payload; the agent's own schema is authoritative for the payload itself.

## Chat shape skeletons

Style fills the shape; the skeleton stays. Five skeletons, named defaults. A substantive skeleton renders **box-first**: its rows land as a borderless two-column table the reader can stop after (Boxes first, above).

### Opener (session start)

Chip line `**T-NNN <Title>** · status → status`, then 2-col table of skill-specific rows.

### Gate report

Two tiers. The event type determines the tier.

**Mid-task gate** — any gate event that does not flip task status:

One line, no box. `**GREEN** <what changed> → <next step>.` or `**RED** <what failed> → <next step>.`

**Task-close gate** — status flips to `done` or `blocked`, or a skill's closing stamp lands without a status flip (`/al-implement`'s `phase: implemented` at green, `/al-mutate`'s verdict with survivors):

Rendered as the verdict box — a borderless two-column table with exactly these four rows:

| Row | Carries |
|---|---|
| **Did:** | what user-facing behaviour the change enables (Action, Field, API Status, Role Center cue) |
| **Was:** | the problem it solves, one-line scenario the user recognises |
| **Fits:** | how the change fits the app at BC-shape altitude (module, BC pattern, seam, names like `Sales-Post Impl`) |
| **Next:** | the action the user takes, phrased as an action — or nothing if the agent moves on |

Mechanics (procedure names, line numbers, mutant IDs, build counts) belong in the commit and the task file.

**Verify-task variant** (`/al-user-verification` closing a slice, `kind: verify`): same four rows, shifted altitude. **Did** = what the user confirmed. **Was** = user-facing problem the slice solved. **Fits** = journey in `event-model.md` vocabulary (Role / Action / Business Event / View / Status, no AL names). **Next** = handoff.

### Answer (user question)

Answer on line 1, no box. 3 sentences max at the question's altitude.

- No status recap, no background section, no "why it matters."
- Flag open questions explicitly — don't silently drop them.
- A question is not a gate event — do not promote it to a briefing.

### Stop (halt)

**Pre-flight:** one line — `**Stop.** <reason in BC vocab>. <next action>.`

**Mid-flow:** box-first — stop reason on line 1, then the State rows and the Next action as one borderless two-column table. Absorb-and-continue variant uses "Continuing" instead of "Next".

### Push-up report (test scoped above its floor)

A Lists-of-findings specialization for push-ups (`test-strategy.md`). Lede verdict line carrying counts — `N tests above their floor — M cost a seam, K are walls`. Then one labeled line per push-up: its scope, the case/example handle, why the layer below cannot hold it, and the seam-or-wall. Covers `Integration`, `Record: yes` E2E, and `Contract` only — never `Record: no` (already pushed down) or `Exploration` (no checkable floor). `/al-refine` emits it as its own chat section; `/al-implement` emits one push-up's line as a Stop; `/al-code-review` reports an unjustified push-up as an ordinary finding.

SKILL-specific shapes live in the owning SKILL.md and follow the same rule: shape preserved, Style applies.

- AL Runner ERROR table → `/al-implement`
- Drafted `Test Specification` / `Verification Plan` → `/al-refine`
- Rubber-duck skip line → `rubber-duck-review.md`

## Chat carve-out

Chat requires a closing line stating what landed (the user has no task file open). Closing line follows the Style rule; not a pleasantry. Workflow markers (`**RED**`, `**GREEN**`, `**Rubber-duck**`) permitted in chat; workflow narrative prose still banned.
