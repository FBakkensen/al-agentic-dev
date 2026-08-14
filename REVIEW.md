Report a violation of any directive below — they govern `skills/**/*.md` and `agents/*.agent.md` — as **Important**, not as a nit.

Skip findings under `skills/al-build/scripts/`; CI already covers that path.

# Reviewing a skill

Every folder under `skills/` is an Agent Skill — a `SKILL.md` plus optional sibling files — and every `agents/*.agent.md` is a packaged custom agent; together they ship as the GitHub Copilot plugin `al-agentic-dev`. Flag anything below.

## Copilot-first surface

1. Skill frontmatter has at most three keys: `name`, `description`, `disable-model-invocation`. Tool access and model pins live in `agents/*.agent.md`, never in skill frontmatter — flag `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable` on a skill.
2. Model invocation is the exception. Every skill carries `disable-model-invocation: true` unless something must load it without a slash command — another skill invokes it mid-run (`al-build`; `al-grilling`, invoked mid-interview by `al-grill-adr`, `al-event-model`, `al-design`, `al-refine`; `al-knowledge-pass`, invoked mid-run by `al-code-review` and `al-refactor` to run the BCQuality pass over a diff; `al-implement`, invoked mid-run by `al-code-review` and `al-refactor` for feedback implementation; `al-routing`, invoked at close by every skill that moves task state and loaded by `al-next` and any skill needing its schema; `al-visualize`, invoked mid-run by `al-design`, `al-event-model`, `al-refine`, `al-scope`, `al-code-review`, `al-quiz` and at close by every pipeline skill that presents its outcome drawn per rule 26; `al-spec-review`, invoked at close by `al-design`, `al-event-model`, `al-scope`, and `al-refine` to read a just-written spec artifact blind), it is the plain-language navigator (`al-next`), or it exists for discovery by someone who doesn't know the commands (`al-agentic-dev-overview`). Flag a skill missing the flag, and flag a new exception that doesn't name who invokes it.
3. The folder name equals `name`.
4. No relative link leaves the skill folder. Flag `](../`, `](/`, and any absolute path.
   - Correct: `See [TASK-FORMAT.md](TASK-FORMAT.md).`
   - Incorrect: `See [task-grammar.md](../../references/task-grammar.md).`
5. Another skill is named, never linked, and every slash reference resolves to a folder under `skills/`. Names are prefix-free — `al-` marks the AL pipeline family, and a generic name like `/babysit-pr` is as valid as `/al-build`; an `al-`prefixed reference that matches no folder is a defect the gate catches.
   - Correct: `Run the gate with /al-build.`
   - Incorrect: `Run [al-build](../al-build/SKILL.md).`
6. Scripts are run only by the skill that owns them. Outside `skills/al-build/`, flag any `.ps1` filename or `scripts/` path; the skill calls `/al-build` instead. One skill at a time may be exempted for one named script that upstream owns and it runs inside a checkout it clones — today `al-clone-bcquality` and the BCQuality knowledge-index generator, listed in the validator. Flag a new exemption that arrives without that approval, and flag an exempted skill naming any other script.
7. Copilot names are the working vocabulary. A skill body names the tool, the bundled MCP server, or the packaged agent it means; the word "harness" is a defect the gate fails. Flag harness-conditional phrasing and a capability paraphrase where a concrete name exists.
   - Correct: `search the workspace with grep; confirm the field through the nab-al-tools lookup`
   - Incorrect: `if your harness supports subagents…`, `use whatever search capability is available`
8. Model pins live in `agents/*.agent.md` only. Flag a model name in a skill body or skill frontmatter; a skill that needs a specific model for a delegation names the packaged agent that pins it.

## Packaged agents

9. Every `agents/*.agent.md` carries exactly four frontmatter keys — `name`, `description`, `tools`, `model`. `name` equals the filename stem and meets the skill name spec (1–64 characters of lowercase a-z0-9 and single hyphens). `description` is a non-empty single line, quoted when it carries a colon. `model` is a non-empty pin — silent model fallback is the defect the pin exists to stop. `tools` is a non-empty list scoped to what the agent needs.
10. A fixed delegation point names its agent. Flag a delegation left as "a subagent" where a packaged agent exists for that job.

## The description: router on the model-invocable skills, menu line on the rest

11. On the model-invocable nine (`al-build`, `al-grilling`, `al-knowledge-pass`, `al-implement`, `al-next`, `al-routing`, `al-agentic-dev-overview`, `al-visualize`, `al-spec-review`) the description says what the skill does and the state that should trigger it, in terms the model can match against the work in front of it: `Use when a pipeline skill finishes work on a task and the outcome needs recording`.
12. On those nine, one trigger per distinct branch. Flag synonyms that rename a single branch.
13. On those nine, flag identity restated from the body. The description spends its budget on triggers.
14. On a `disable-model-invocation: true` skill the description is one line for the human scanning the `/` menu — what it does and when to reach for it, in plain words. Flag state grammar and trigger syntax there; the model never reads it.

## Length and density

15. A `SKILL.md` body is at most 60 lines — 80 for `al-implement`, `al-code-review`, `al-user-verification`, `al-build`, `al-routing`, `al-spec-review`. Flag anything longer and name what to cut.
16. Flag any sentence the model already obeys without it. "Be thorough", "think carefully", "read the file before editing" change nothing and cost tokens.
17. Flag one meaning stated in two places inside a skill. Each rule has one authoritative home.
18. Flag verification scaffolding: "verify your work", "double-check", "re-read before responding", "use a subagent to confirm". Models self-verify; the instruction produces over-verification and wasted tokens. The one sanctioned gate is `/al-spec-review`: a blind read of a just-written spec artifact against its sources in fresh context is not scaffolding.
19. Flag a phase restated three ways where one familiar word carries it. Prefer a compact word the model already holds over a spelled-out triad.
20. Flag stale layers — a rule about a file, agent, or step that no longer exists.

## Say what to do, not what to avoid

21. Prefer the target behaviour to the prohibition; a ban names the thing it bans and makes it more available.
    - Correct: `Ask one question per message.`
    - Incorrect: `Don't ask several questions at once.`
    Keep a prohibition where it carries real bite — a mistake the model actually makes.

## Ceremony and contract

22. A status flip or routing rule earns its place only by surviving a session boundary. Work that completes inside one session carries no ceremony: no flip written to be immediately unwritten, no handoff for what the current skill can finish. The reader is a model in a live conversation, not an automaton — an interview branch settles in the conversation that raised it and needs no routing rule for an answer the interviewer absorbs; an unclaimed state is a defect only when it survives a session boundary unclaimed. Flag choreography whose only reader is documentation.
23. A skill's steps stay inside its own declared contract. Flag a step that requires an action the skill forbids itself, and flag an imperative whose actor is unnamed.

## Finishing

24. Each step ends on a condition that can be checked, and where it matters, an exhaustive one.
    - Correct: `every modified object appears in the change list`
    - Incorrect: `produce a change list`
25. A skill that moved or created task state closes by naming its outcome, then `/al-routing` — one line each; `/al-routing` records the state and presents the open moves. A skill that wrote no task state closes naming its outcome, then `/al-next`. Flag a table of conditional exits. The exceptions: the entry chain (`al-grill-adr`, `al-event-model`, `al-design`) runs in one sitting, so each closes naming its successor and that the session continues, and `al-scope` is where closes hand to `/al-routing`; `al-build` closes on its verdict, `al-grilling` on the shared understanding, `al-knowledge-pass` on the findings returned to its caller, `al-routing` on the state recorded and the moves named, `al-spec-review` on the findings returned to its caller, and `al-next` on the moves named — the user takes the step; a run that stopped on an open question or a mid-episode helper run (the repair review scope, a walk paused on a defect) closes back into the flow it serves, routing nowhere.
26. Before its route, a pipeline close puts its outcome in view through `/al-visualize` — the settled artifact or landed change drawn: `al-grill-adr`, `al-event-model`, `al-design`, `al-scope`, `al-refine`, `al-implement`, `al-user-verification`, and `al-quiz` on every completed run; `al-refactor`, `al-code-review`, and `al-validate-breaking-changes` only when the run changed or found something — a clean one closes plain. `al-implement`'s repair green also draws its fix diff before rejoining its episode. Flag a close surface missing where one is due, and flag one added to a stop, a decline, or a mid-episode exit other than that repair green.

## Reply shape a skill asks for

27. Every `SKILL.md` carries this exact rule: `Ask every question in the reply itself, as plain text — never through a question or elicitation tool.` A skill that shapes the reply also asks for: one sentence before the first tool call; a brief update only on an important finding or a change of direction; the outcome first when finishing, detail after.
28. Flag a skill that asks the model to announce each step before taking it.
29. Written artifacts match the length the task needs. Flag instructions to add summary sections, recaps, or boilerplate headings.

## Delegation

30. Delegation is for large, genuinely independent work. Flag a skill that spawns a subagent for work finishable in a few tool calls, or that spawns one to check its own output — `/al-spec-review`'s blind spec gate is the sanctioned exception; a writing skill invoking it at close is not a finding. Every delegated review judgment runs in a full-capability subagent; flag a skill that assigns one below that capability.
31. Where fan-out is optional, one sentence covers it: `These parallelize in full-capability subagents; when subagents are unavailable, apply them in one pass.`

## Task-file state has one home

32. `al-routing` declares the task-file frontmatter — fields, allowed values, the ladder, the gates, the derivations — and owns every lifecycle transition. Creation is the one shared write: `al-scope`, and any skill that finds new work mid-pipeline, creates a task file with the structural fields plus the opening state, per that schema. Every other state need is an outcome named in plain words and handed to `/al-routing`. Naming the `kind:` a skill accepts or declines is intake, not a restatement. Pipeline state is moving to Azure DevOps work items — the work item becomes the single store, its states New → Active → Blocked → Testing → Resolved → Closed — and the single home holds in both vocabularies: outside `al-routing`, flag a legacy lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`) and equally a work-item transition (`State: Resolved`). Flag a lifecycle field, value list, or flip instruction restated outside `al-routing`, and flag a skill that moves the state of an existing task itself.

## AL correctness

33. A skill that writes AL carries the grounding rule: every BC object, table, field, procedure, event, or enum value name is confirmed by a lookup in the current session, never recalled. Flag its absence in `al-implement`, `al-refactor`, `al-code-review`, and `al-design`.
34. BC vocabulary — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method — binds every line written into a spec artifact or task file as much as code: `al-grill-adr`, `al-design`, `al-scope`, `al-refine`, `al-implement`, `al-refactor`, and `al-code-review` carry it. Flag its absence there, and flag it imposed on a skill that quotes the user's own words or `event-model.md` verbatim. Name derivation rides with it: the minting skills (`al-design`, `al-refine`, `al-implement`) derive every minted name — noun from a `CONTEXT.md` term, the BC baseline, or an `event-model.md` Action, Business Event, or Status; verb from BC's own set — and settle a term no source names as one question landing in `CONTEXT.md`; `al-event-model` carries the same stop on its Action, Business Event, and Status slots; `al-refactor` and `al-code-review` treat an untraceable name as a finding. Flag a link of that chain missing. The four that write production AL (`al-implement`, `al-refactor`, `al-code-review`, `al-design`) also carry production-AL thrift: reach for the platform before writing code, no interface with a single implementation, and name the ceiling on a deliberate shortcut.
35. The precedent chain keeps `.bcapps/` a pattern library rather than a name oracle: `al-design` fills a `Precedent` verdict per module-map row from reading the clone and stops when the clone is missing, `al-refine` re-checks a task whose behaviour no verdict covers and stops on a contradiction, and `al-implement` treats a `reused:` verdict as binding and stops on a mid-run find that Microsoft ships what the task builds. Flag a link of that chain missing from its skill.

## Commit discipline

36. A skill that writes repo files commits its own writes at every exit — clean close, fail pause, or open-question stop. Writes on a task carry the owning `T-NNN` commit prefix; writes outside any task (`CONTEXT.md`, ADRs, `event-model.md`, `architecture.md`, the `tasks/` folder, approved visuals) carry a plain descriptive message and no prefix. The foreign-dirt interview — leftovers summarized by intent, the owning task deduced and suggested, one question, a separate commit — has one home: `al-routing`. Flag a writing skill with no commit line, a non-task write carrying a `T-NNN` prefix, and the interview restated outside `al-routing`.

## Show the thing

37. Artifact prose shows the thing — the page, the field, the command, the number — one sentence per fact; run narration in an artifact is a defect, its home the commit message. The carriers: `TASK-FORMAT.md` bounds `Contract notes:` to one-sentence bullets with glyphed ledes (🔎 Researched, 🏛️ Precedent, ⬆️ Push-up, ✅ Accepted), `ARCHITECTURE-FORMAT.md` carries the no-narration line, `al-implement`'s reconcile carries the one-sentence shape, and `al-spec-review` checks both mechanically. Chat surfaces glyph their fixed slots, shape-distinct rather than color-coded: findings as ⛔ / ⚠️ / ⚖️ headlines over one-line `⚡ Breaks:` / `📍 Proof:` / `🔧 Fix:` slots in `al-spec-review` and `al-code-review`, moves as ▶ / ⛔ / ✅ in `al-next`, the run-narration ledes — `▸` finding / `➜` move mid-run, `✅` / `⛔` at the close — carried by the reply-shape snippet, and the gate-receipt ledes — `🔎✅` reused / `🔎🔧` required in `al-refactor` and `al-code-review`, `✅` recorded in `al-routing`. These carried lines are deliberate, not rule-16/17 findings — live sessions ignored the shape while it was unwritten. Flag a carrier missing its line, and flag an emoji outside a defined slot — that one is decoration.
