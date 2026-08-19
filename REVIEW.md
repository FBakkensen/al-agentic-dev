Report a violation of any directive below — they govern `skills/**/*.md` and `agents/*.agent.md` — as **Important**, not as a nit.

Skip findings under `skills/al-build/scripts/`; CI already covers that path.

# Reviewing a skill

Every folder under `skills/` is an Agent Skill — a `SKILL.md` plus optional sibling files — and every `agents/*.agent.md` is a packaged custom agent; together they ship as the GitHub Copilot plugin `al-agentic-dev`. Flag anything below.

## Copilot-first surface

1. Skill frontmatter has at most three keys: `name`, `description`, `disable-model-invocation`. Tool access and model pins live in `agents/*.agent.md`, never in skill frontmatter — flag `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable` on a skill.
2. Model invocation is the exception. Every skill carries `disable-model-invocation: true` unless something must load it without a slash command — today `al-build` (changed AL code or another skill's script need invokes it mid-run), `al-visualize` (next invokes it when the shape changed; the user calls it directly for a drawn view), `grilling` (the interview engine `grill-me` starts and grill trigger phrases reach), `unslop` (the donor says it must always apply), and `lookup` (verify-or-declare is a mid-write reflex; the writing and review skills invoke it in-flight). Flag a skill missing the flag, and flag a new exception that doesn't name who invokes it.
3. The folder name equals `name`.
4. No relative link leaves the skill folder. Flag `](../`, `](/`, and any absolute path.
   - Correct: `See [RECORDING-FORMAT.md](RECORDING-FORMAT.md).`
   - Incorrect: `See [recording-grammar.md](../../references/recording-grammar.md).`
5. Another skill is named, never linked, and every slash reference resolves to a folder under `skills/`. Names are prefix-free — `al-` marks the AL family and a bare name is as valid; an `al-`prefixed reference that matches no folder is a defect the gate catches.
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

11. On the model-invocable skills (`al-build`, `al-visualize`, `grilling`, `unslop`, `lookup`) the description says what the skill does and the state that should trigger it, in terms the model can match against the work in front of it: `Use when AL production or test code has changed and the change needs the gate`.
12. On those skills, one trigger per distinct branch. Flag synonyms that rename a single branch.
13. On those skills, flag identity restated from the body. The description spends its budget on triggers.
14. On a `disable-model-invocation: true` skill the description is one line for the human scanning the `/` menu — what it does and when to reach for it, in plain words. Flag state grammar and trigger syntax there; the model never reads it.

## Length and density

15. A `SKILL.md` body is at most 60 lines — 80 for `al-build`, and donor length wins on a verbatim port. Flag anything longer and name what to cut.
16. Flag any sentence the model already obeys without it. "Be thorough", "think carefully", "read the file before editing" change nothing and cost tokens.
17. Flag one meaning stated in two places inside a skill. Each rule has one authoritative home.
18. Flag verification scaffolding: "verify your work", "double-check", "re-read before responding", "use a subagent to confirm". Models self-verify; the instruction produces over-verification and wasted tokens.
19. Flag a phase restated three ways where one familiar word carries it. Prefer a compact word the model already holds over a spelled-out triad.
20. Flag stale layers — a rule about a file, agent, or step that no longer exists.

## Say what to do, not what to avoid

21. Prefer the target behaviour to the prohibition; a ban names the thing it bans and makes it more available.
    - Correct: `Ask one question per message.`
    - Incorrect: `Don't ask several questions at once.`
    Keep a prohibition where it carries real bite — a mistake the model actually makes.

## Contract and finishing

22. A skill's steps stay inside its own declared contract. Flag a step that requires an action the skill forbids itself, and flag an imperative whose actor is unnamed.
23. Each step ends on a condition that can be checked, and where it matters, an exhaustive one.
    - Correct: `every modified object appears in the change list`
    - Incorrect: `produce a change list`
24. A skill closes by naming its outcome back into the work that invoked it — `al-build` on its gate verdict, the clone skills on the clone ready or the red named, `al-visualize` on what the surface settled. Flag a table of conditional exits, and flag a close that hands off to a skill that no longer exists.

## Reply shape a skill asks for

25. Every authored `SKILL.md` carries this exact rule: `Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.` Verbatim ports are exempt — `hooks.json` enforces the ask_user ban at runtime. A skill that shapes the reply also asks for: one sentence before the first tool call; a brief update only on an important finding or a change of direction; the outcome first when finishing, detail after.
26. Flag a skill that asks the model to announce each step before taking it.
27. Written artifacts match the length the task needs. Flag instructions to add summary sections, recaps, or boilerplate headings.

## Delegation

28. Delegation is for large, genuinely independent work. Flag a skill that spawns a subagent for work finishable in a few tool calls, or that spawns one to check its own output. Every delegated review judgment runs in a full-capability subagent; flag a skill that assigns one below that capability.
29. Where fan-out is optional, one sentence covers it: `These parallelize in full-capability subagents; when subagents are unavailable, apply them in one pass.`

## Retired concepts

30. Task-state ceremony is retired with the old pipeline. Flag a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: Resolved`), a stage-gate prerequisite, or a routing hand-off in any skill or agent — the gate bans the fields mechanically; the concept ban is wider. Flag choreography whose only reader is documentation, and flag a skill that needs the world prepared before it can act.

## AL grounding

31. Every BC object, table, field, procedure, event, enum value, or dialog text a skill or agent shows, writes, or judges is confirmed by a lookup in the current session, never recalled. BC vocabulary rides with it on every line written into code or a receipt — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method — and so does production-AL thrift: reach for the platform before writing code, and an interface with a single implementation is a finding. Today `al-visualize`, the two reviewer agents, `implement`, `refactor`, `review`, `al-design`, and `al-event-model` carry the grounding rule; flag its absence in any new skill that writes, shows, or judges AL.

## Commit discipline

32. A skill that writes repo files commits its own writes at every exit — clean close, fail pause, or open-question stop — with a plain descriptive message. Flag a writing skill with no commit line.

## Show the thing

33. Artifact prose shows the thing — the page, the field, the command, the number — one sentence per fact; run narration in an artifact is a defect, its home the commit message. Chat surfaces glyph their fixed slots, shape-distinct rather than color-coded: findings as `⛔` Blocking / `⚖️` Non-Blocking / `⚠️` Suggestion headlines over one-line `⚡ Breaks:` / `📍 Proof:` / `🔧 Fix:` slots in the reviewer agents — the set-wide verdict grammar, "no blocking issues found" a legal verdict — and the run-narration ledes — `▸` finding / `➜` move mid-run, `✅` / `⛔` at the close — carried by the reply-shape snippet. These carried lines are deliberate, not rule-16/17 findings — live sessions ignored the shape while it was unwritten. Flag a carrier missing its line, and flag an emoji outside a defined slot — that one is decoration.

## Verbatim ports

34. A verbatim port's `SKILL.md` is donor-owned: today `grilling`, `grill-me`, `wait-what` (mattpocock/skills @ 885e2ca, MIT) and `unslop` (cursor/plugins pstack @ 60c641e, MIT), each byte-identical to its donor. Flag any edit to a ported file — a fix belongs upstream or in the port note of a deliberate re-port; `scripts/Compare-SkillToDonor.ps1` proves the identity. Rules 15, 16, 17, 19, 21, and 25 read the donor as authoritative on these files; the structural gate (frontmatter, links, scripts, retired concepts) applies unchanged.
