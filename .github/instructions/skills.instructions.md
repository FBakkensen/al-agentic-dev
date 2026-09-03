---
applyTo: "skills/**/*.md,agents/*.agent.md"
---

# Reviewing a skill

Every folder under `skills/` is an Agent Skill — a `SKILL.md` plus optional sibling files — and every `agents/*.agent.md` is a packaged custom agent; together they ship as the GitHub Copilot plugin `al-agentic-dev`. Flag anything below.

## Copilot-first surface

1. Skill frontmatter has exactly two keys: `name` and `description`. Tool access and model pins live in `agents/*.agent.md`, never in skill frontmatter — flag `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`, and `disable-model-invocation` on a skill.
2. Every skill is model-invocable. Omit `disable-model-invocation` from every SKILL.md, and write each description with the trigger branches that let the model reach it.
3. The folder name equals `name`.
4. No relative link leaves the skill folder. Flag `](../`, `](/`, and any absolute path.
   - Correct: `See [SURFACE.md](SURFACE.md).`
   - Incorrect: `See [recording-grammar.md](../../references/recording-grammar.md).`
5. Another skill is named, never linked, and every slash reference resolves to a folder under `skills/`. Every skill this plugin ships is `al-`prefixed — the namespace is the plugin's mark; an `al-`prefixed reference that matches no folder is a defect the gate catches.
   - Correct: `Run the gate with /al-build.`
   - Incorrect: `Run [al-build](../al-build/SKILL.md).`
6. Scripts are run only by the skill that owns them. Outside `skills/al-build/`, flag any `.ps1` filename or `scripts/` path; the skill calls `/al-build` instead. One skill at a time may be exempted for one named script that upstream owns and it runs inside a checkout it clones — today `al-clone-bcquality` and the BCQuality knowledge-index generator, listed in the validator. Flag a new exemption that arrives without that approval, and flag an exempted skill naming any other script.
7. Copilot names are the working vocabulary. A skill body names the tool, the bundled MCP server, or the packaged agent it means; the word "harness" is a defect the gate fails. Flag harness-conditional phrasing and a capability paraphrase where a concrete name exists.
   - Correct: `search the workspace with grep; confirm the field through the nab-al-tools lookup`
   - Incorrect: `if your harness supports subagents…`, `use whatever search capability is available`
8. Model names live in `skills/al-setup-models/models.default.json` and in `agents/*.agent.md` pins only. Flag a model name in a skill body or skill frontmatter — the gate fails it; a skill names a tier on a `▶` line (rule 38), never a model.

## Packaged agents

9. Every `agents/*.agent.md` carries exactly four frontmatter keys — `name`, `description`, `tools`, `model`. `name` equals the filename stem and meets the skill name spec (1–64 characters of lowercase a-z0-9 and single hyphens). `description` is a non-empty single line, quoted when it carries a colon. `model` is a non-empty pin — silent model fallback is the defect the pin exists to stop. `tools` is a non-empty list scoped to what the agent needs.
10. A fixed delegation point names its agent. Flag a delegation left as "a subagent" where a packaged agent exists for that job.

## The description: router on every skill

11. On every skill, the description says what it does and the state that should trigger it, in terms the model can match against the work in front of it: `Use when AL production or test code has changed and the change needs the gate`.
12. On every skill, one trigger per distinct branch. Flag synonyms that rename a single branch.
13. On every skill, flag identity restated from the body. The description spends its budget on triggers.
14. Every skill description is model-facing; it is never a menu-only summary.

## Length and density

15. A `SKILL.md` body is at most 60 lines — 80 for `al-build`, and donor length wins on a pinned fork. Flag anything longer and name what to cut.
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
24. A skill closes by naming its outcome back into the work that invoked it — `al-build` on its gate verdict, the clone skills on the clone ready or the red named, `al-arc42` on the formatted view and local HTML. Flag a table of conditional exits, and flag a close that hands off to a skill that no longer exists.

## Reply shape a skill asks for

25. Every authored `SKILL.md` carries this exact rule: `Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.` The pinned forks `al-grill-me` and `al-unslop` are exempt — `hooks.json` enforces the ask_user ban at runtime. A skill that shapes the reply also asks for: one sentence before the first tool call; a brief update on an important finding or a change of direction; a close that stands on its own, outcome first and detail after. Flag a line that suppresses updates — "work quietly", "hold findings for the final response" — the model already under-reports during long tool chains.
26. Flag a skill that asks the model to announce each step before taking it, and flag a skill that ends a turn on a stated next step instead of running it.
27. Written artifacts match the length the task needs. Flag an instruction to add a section that restates what the artifact already shows, and flag anti-formatting language — "no headings", "no lists" — where a rule naming when formatting helps belongs instead.

## Delegation

28. Delegation is for work that returns a compact result — a survey table, one scenario's red→green evidence, a gate verdict — or that owns its own branch. A single lookup stays in-line: flag a `▶` line for work finishable in a few tool calls, and flag one that checks the skill's own output. A delegated review judgment runs at `execution` or above; a leaf following a written contract runs `mechanical`.
29. Fan-out is several `▶ task` lines at one step, launched together in the background; the lead keeps working on independent steps and waits with `read_agent wait:true` only where the next step needs a result. Every Copilot surface has the `task` tool, so no skill carries an unavailable-subagents fallback.

## Retired concepts

30. Task-state ceremony is retired with the old pipeline. Flag a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: Resolved`), or an abstract stage gate — the gate bans the fields mechanically; the concept ban is wider. A concrete artifact may require user agreement before the next skill consumes it, and a skill may name that next consumer. Flag routing whose only purpose is advancing a named stage, choreography whose only reader is documentation, and a skill that requires ceremonial state rather than a concrete input.

## AL grounding

31. Every BC object, table, field, procedure, event, enum value, or dialog text a skill or agent shows, writes, or judges is confirmed by a lookup in the current session, never recalled. BC vocabulary rides with it on every line written into code or a receipt — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method — and so does production-AL thrift: reach for the platform before writing code, and an interface with a single implementation is a finding. Today `al-arc42`, the two reviewer agents, `al-implement`, `al-refactor`, `al-review`, `al-test-design`, `al-design`, `al-event-model`, and `al-walkthrough` carry the grounding rule; flag its absence in any new skill that writes, shows, or judges AL.

## Commit discipline

32. A skill that writes repo files calls `/al-commit` at every exit — clean close, fail pause, or open-question stop. Flag a direct commit command or a writing skill with no `/al-commit` handoff. `/al-commit` owns the full worktree, questions only temporary paths, secret-bearing paths, or generated output that belongs in `.gitignore`, and creates the maximum number of independently valid commits.

## Show the thing

33. Artifact prose shows the thing — the page, the field, the command, the number — one sentence per fact; run narration in an artifact is a defect, its home the commit message. Chat surfaces glyph their fixed slots, shape-distinct rather than color-coded: findings as `⛔` Blocking / `⚖️` Non-Blocking headlines over one-line `⚡ Breaks:` / `📍 Proof:` / `🔧 Fix:` slots in the reviewer agents — the set-wide verdict grammar, "no blocking issues found" a legal verdict, one optional `Refactor food:` line the only home for aesthetics — and the run-narration ledes — `▸` finding / `➜` move mid-run, `✅` / `⛔` at the close — carried by the reply-shape snippet. These carried lines are deliberate, not rule-16/17 findings — live sessions ignored the shape while it was unwritten. Flag a carrier missing its line, and flag an emoji outside a defined slot — that one is decoration.  The delegation line `▶ <tier> · <vehicle> · <brief> → <return>` of rule 38 is a defined slot; `al-walkthrough`'s `▶ <business action>` report line stays — it sits in a code span and names no tier.

## Pinned forks

34. A ported skill is a pinned fork: today `al-grill-me` (mattpocock/skills @ 885e2ca, MIT) and `al-unslop` (cursor/plugins pstack @ 60c641e, MIT). The body stays donor text except the al- namespace — the frontmatter `name:` line and any port-internal reference to a renamed sibling; `scripts/Compare-SkillToDonor.ps1` against the donor SHA is expected to show exactly those namespace hunks and nothing else. Flag any other diff — a content fix belongs upstream or in the port note of a deliberate re-port. Rules 15, 16, 17, 19, 21, and 25 read the donor as authoritative on these files; the structural gate (frontmatter, links, scripts, retired concepts) applies unchanged.

## Azure DevOps attachments

35. A skill that publishes local files to an Azure DevOps work item calls `/al-azure-devops-attachments`. Flag manual-upload fallback and any claim that missing MCP attachment support blocks publication. Azure CLI authentication failure pauses for the exact user-run login command; after authentication, the skill resumes upload and verifies every `AttachedFile` relation.

## Azure DevOps work items

36. One request starts as one Original User Story. `Original` names its role in this workflow, not the top of the Azure DevOps hierarchy; structural parents remain unchanged and out of scope. With one Vertical slice, the Original User Story is executable and has no child from this workflow. With several slices, it becomes the container and every slice is one direct child User Story. Flag Azure DevOps Features introduced by this workflow and grandchildren below the Original User Story.
37. Description sections keep this order when present: `Problem`, `Expected outcome`, `Scope`, `Process contract`, `Business process`, `Runtime View`, `Building Block View`. Diagrams stay with their explanatory text. In Acceptance Criteria, `Behavior` is valid fenced Gherkin and precedes `Test specification` when both exist; either section may be absent without prescribed meaning.

## Delegation contract

38. A skill delegates a step with one line — `▶ <tier> · <vehicle> · <brief> → <return>` — placed at the step it serves. `tier` is `frontier`, `execution`, or `mechanical`; `vehicle` is `task` for work that writes into the current branch or reads only, `session` for work that owns its own branch. The `brief` names what the child receives — it inherits nothing — and the `return` names what comes back, checkable. Task workers do not delegate; session children run their skill's `▶` lines as written. Callee skills — `/al-build`, `/al-commit`, `/al-arc42`, `/al-azure-devops-attachments`, `/al-pull-request`, `/al-clone-bcapps`, `/al-clone-bcquality` — carry no `▶` line; the caller writes it. Every dispatch prompt carries the brief, the return contract, the unattended line (`You run unattended; the user cannot answer mid-task. Proceed on every reversible step the User Story already covers, and end your turn only when the slice is complete or a decision only the user can take is written out with its options.`), and the plain-text question rule; a child that writes or judges AL also carries the Speak BC paragraph and the grounding rule of rule 31. A child's stop is a decision: the skill's own contract answers it to the same child, or the lead quotes it to the user with options and the recommendation marked and relays the answer unchanged. A return that misses its contract, or a red twice on the same cause, is re-dispatched once, one tier up, with the child's output added to the brief; a second miss goes to the user with the evidence. Flag a `▶` line outside this grammar, a callee skill carrying one, a dispatch prompt missing a fixed part, and a model name where a tier belongs.
