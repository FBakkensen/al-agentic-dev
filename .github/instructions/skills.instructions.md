---
applyTo: "skills/**/*.md"
---

# Reviewing a skill

Every folder under `skills/` is an Agent Skill: a `SKILL.md` plus optional sibling files, read by Claude Code, GitHub Copilot, and Codex alike. Flag anything below.

## Portability — one skill, every harness

1. Frontmatter has at most three keys: `name`, `description`, `disable-model-invocation`. Flag `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`.
2. Model invocation is the exception. Every skill carries `disable-model-invocation: true` unless something must load it without a slash command — another skill invokes it mid-run (`al-build`; `al-grilling`, invoked mid-interview by `al-grill-adr`, `al-event-model`, `al-design`, `al-refine`; `al-routing`, invoked at close by every skill that moves task state and loaded by `al-next` and any skill needing its schema), it is the plain-language navigator (`al-next`), or it exists for discovery by someone who doesn't know the commands (`al-agentic-dev-overview`). Flag a skill missing the flag, and flag a new exception that doesn't name who invokes it.
3. The folder name equals `name`.
4. No relative link leaves the skill folder. Flag `](../`, `](/`, and any absolute path.
   - Correct: `See [TASK-FORMAT.md](TASK-FORMAT.md).`
   - Incorrect: `See [task-grammar.md](../../references/task-grammar.md).`
5. Another skill is named, never linked.
   - Correct: `Run the gate with /al-build.`
   - Incorrect: `Run [al-build](../al-build/SKILL.md).`
6. Scripts are run only by the skill that owns them. Outside `skills/al-build/`, flag any `.ps1` filename or `scripts/` path; the skill calls `/al-build` instead.
7. No harness-specific names. Flag environment variables such as `COPILOT_PLUGIN_ROOT`, custom agent names, model names such as `claude-opus-5` or `gpt-5`, MCP server ids, and `agent_type:`. The one exception is `al-agentic-dev-overview`'s snippet install, whose job is writing every harness's config home symmetrically.
8. Tools are described by what they do.
   - Correct: `search the workspace for the object declaration`
   - Incorrect: `use the Grep tool`

## The description: router on the model-invocable skills, menu line on the rest

9. On the model-invocable five (`al-build`, `al-grilling`, `al-next`, `al-routing`, `al-agentic-dev-overview`) the description says what the skill does and the state that should trigger it, in terms the model can match against the work in front of it: `Use when a pipeline skill finishes work on a task and the outcome needs recording`.
10. On those five, one trigger per distinct branch. Flag synonyms that rename a single branch.
11. On those five, flag identity restated from the body. The description spends its budget on triggers.
12. On a `disable-model-invocation: true` skill the description is one line for the human scanning the `/` menu — what it does and when to reach for it, in plain words. Flag state grammar and trigger syntax there; the model never reads it.

## Length and density

13. A `SKILL.md` body is at most 60 lines — 80 for `al-implement`, `al-code-review`, `al-user-verification`, `al-build`, `al-routing`. Flag anything longer and name what to cut.
14. Flag any sentence the model already obeys without it. "Be thorough", "think carefully", "read the file before editing" change nothing and cost tokens.
15. Flag one meaning stated in two places inside a skill. Each rule has one authoritative home.
16. Flag verification scaffolding: "verify your work", "double-check", "re-read before responding", "use a subagent to confirm". Models self-verify; the instruction produces over-verification and wasted tokens.
17. Flag a phase restated three ways where one familiar word carries it. Prefer a compact word the model already holds over a spelled-out triad.
18. Flag stale layers — a rule about a file, agent, or step that no longer exists.

## Say what to do, not what to avoid

19. Prefer the target behaviour to the prohibition; a ban names the thing it bans and makes it more available.
    - Correct: `Ask one question per message.`
    - Incorrect: `Don't ask several questions at once.`
    Keep a prohibition where it carries real bite — a mistake the model actually makes.

## Ceremony and contract

20. A status flip or routing rule earns its place only by surviving a session boundary. Work that completes inside one session carries no ceremony: no flip written to be immediately unwritten, no handoff for what the current skill can finish. Flag choreography whose only reader is documentation.
21. A skill's steps stay inside its own declared contract. Flag a step that requires an action the skill forbids itself, and flag an imperative whose actor is unnamed.

## Finishing

22. Each step ends on a condition that can be checked, and where it matters, an exhaustive one.
    - Correct: `every modified object appears in the change list`
    - Incorrect: `produce a change list`
23. A skill that moved or created task state closes by naming its outcome, then `/al-routing` — one line each; `/al-routing` records the state and presents the open moves. A skill that wrote no task state closes naming its outcome, then `/al-next`. Flag a table of conditional exits. The exceptions: the entry chain (`al-grill-adr`, `al-event-model`, `al-design`) runs in one sitting, so each closes naming its successor and that the session continues, and `al-scope` is where closes hand to `/al-routing`; `al-build` closes on its verdict, `al-grilling` on the shared understanding, `al-routing` on the state recorded and the moves named, and `al-next` on the moves named — the user takes the step; a run that stopped on an open question or a mid-episode helper run (the repair review scope, a walk paused on a defect) closes back into the flow it serves, routing nowhere.

## Reply shape a skill asks for

24. A skill that shapes the reply asks for: one sentence before the first tool call; a brief update only on an important finding or a change of direction; the outcome first when finishing, detail after.
25. Flag a skill that asks the model to announce each step before taking it.
26. Written artifacts match the length the task needs. Flag instructions to add summary sections, recaps, or boilerplate headings.

## Delegation

27. Delegation is for large, genuinely independent work. Flag a skill that spawns a subagent for work finishable in a few tool calls, or that spawns one to check its own output.
28. Where fan-out is optional, one sentence covers it: `If your harness supports subagents, these parallelize; otherwise apply them in one pass.`

## Task-file state has one home

29. `al-routing` declares the task-file frontmatter — fields, allowed values, the ladder, the gates, the derivations — and owns every lifecycle transition. Creation is the one shared write: `al-scope`, and any skill that finds new work mid-pipeline, creates a task file with the structural fields plus the opening state, per that schema. Every other state need is an outcome named in plain words and handed to `/al-routing`. Naming the `kind:` a skill accepts or declines is intake, not a restatement. Flag a lifecycle field, value list, or flip instruction restated outside `al-routing`, and flag a skill that moves the state of an existing task itself.

## AL correctness

30. A skill that writes AL carries the grounding rule: every BC object, table, field, procedure, event, or enum value name is confirmed by a lookup in the current session, never recalled. Flag its absence in `al-implement`, `al-refactor`, `al-code-review`, `al-design`, and `al-mutate` (whose survivor-kill tests are new AL).
31. The first four of those (`al-implement`, `al-refactor`, `al-code-review`, `al-design`) carry BC vocabulary — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction — and production-AL thrift: reach for the platform before writing code, no interface with a single implementation, and name the ceiling on a deliberate shortcut. `al-mutate` carries rule 30 alone.
32. The precedent chain keeps `.bcapps/` a pattern library rather than a name oracle: `al-design` fills a `Precedent` verdict per module-map row from reading the clone and stops when the clone is missing, `al-refine` re-checks a task whose behaviour no verdict covers and stops on a contradiction, and `al-implement` treats a `reused:` verdict as binding and stops on a mid-run find that Microsoft ships what the task builds. Flag a link of that chain missing from its skill.
