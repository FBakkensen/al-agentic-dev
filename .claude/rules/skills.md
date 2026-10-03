---
paths:
  - "skills/**"
---

# Reviewing a skill

Every folder under `skills/` is an Agent Skill — a `SKILL.md` plus optional sibling files — shipped in the Claude Code plugin `al-agentic-dev`. Flag anything below. Rule numbers are stable: a retired rule leaves a gap.

## Claude Code surface

1. Skill frontmatter has exactly two keys: `name` and `description` — flag `allowed-tools`, `model`, `tools`, `mcp-servers`, `user-invocable`, and `disable-model-invocation` on a skill.
2. Every skill is model-invocable. Omit `disable-model-invocation` from every SKILL.md, and write each description with the trigger branches that let the model reach it.
3. The folder name equals `name`.
4. No relative link leaves the skill folder. Flag `](../`, `](/`, and any absolute path.
   - Correct: `See [SURFACE.md](SURFACE.md).`
   - Incorrect: `See [recording-grammar.md](../../references/recording-grammar.md).`
5. Another skill is named, never linked, in one slash grammar across skill bodies, descriptions, and the `SessionStart` text. Our own skills are bare — `/al-build`; the `al-` prefix is the plugin's mark and can't collide, so a bare `/al-` reference must match a folder under `skills/`. Base plugin skills are always namespaced — `/mattpocock-skills:code-review`, `/bcquality:al-code-review` — because the Base plugins are unpinned and `code-review` already collides with a built-in. Built-ins are bare — `/code-review`, `/simplify`. The gate fails an `al-` reference with no folder, `al-agentic-dev:<x>` with or without `/`, and a `/<ns>:<skill>` whose namespace no plugin manifest dependency declares; whether `<skill>` exists upstream is the drift check's job.
   - Correct: `Run the gate with /al-build.`, `Deep questions go to /mattpocock-skills:research.`
   - Incorrect: `Run [al-build](../al-build/SKILL.md).`, `Run /al-agentic-dev:al-build.`
6. Scripts are run only by the skill that owns them. Outside `skills/al-build/`, flag any `.ps1` filename or `scripts/` path; the skill calls `/al-build` instead.
7. Claude Code names are the working vocabulary. A skill body names the Claude Code tool, the bundled MCP server, or the agent it means; the word "harness" is a defect the gate fails — name the Claude Code tool or agent instead. Flag harness-conditional phrasing and a capability paraphrase where a concrete name exists.
   - Correct: `search the workspace with grep; confirm the property through microsoft_docs_search`
   - Incorrect: `if your harness supports subagents…`, `use whatever search capability is available`

## The description: router on every skill

11. On every skill, the description says what it does and the state that should trigger it, in terms the model can match against the work in front of it: `Use when AL production or test code has changed and the change needs the gate`.
12. On every skill, one trigger per distinct branch. Flag synonyms that rename a single branch.
13. On every skill, flag identity restated from the body. The description spends its budget on triggers.
14. Every skill description is model-facing; it is never a menu-only summary.

## Length and density

15. A `SKILL.md` body is at most 60 lines — 80 for `al-build`. Flag anything longer and name what to cut.
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
23. Each step ends on a condition that can be checked, and where it matters, an exhaustive one. A multi-step skill names the task's finish line and any user-only decision that stops it; a progress report is not a finish line.
    - Correct: `every modified object appears in the change list`
    - Incorrect: `produce a change list`
24. A skill closes by naming its outcome back into the work that invoked it — `al-build` on its gate verdict, the clone skills on the clone ready or the red named, `al-arc42` on the formatted view and local HTML. Flag a table of conditional exits, and flag a close that hands off to a skill that no longer exists.

## Reply shape a skill asks for

26. Flag a skill that asks the model to announce each step before taking it, and flag a skill that ends a turn on a stated next step instead of running it. An update on an important finding accompanies the next action when no user decision blocks that action.
27. Written artifacts match the length the task needs. Flag an instruction to add a section that restates what the artifact already shows, and flag anti-formatting language — "no headings", "no lists" — where a rule naming when formatting helps belongs instead.

## Delegation

28. Delegation is for work that returns a compact result — a survey table, one scenario's red→green evidence, a gate verdict. A single lookup stays in-line: flag a `▶` line for work finishable in a few tool calls, and flag one that checks the skill's own output. A delegated review judgment runs on `sonnet` or above; a leaf following a written contract runs on `haiku`.
29. Fan-out is several `▶` lines at one step, dispatched as background `Agent` calls in one message; the lead keeps working on independent steps and picks up each result from its completion notification, never by polling. A child's decision reaches the user through `AskUserQuestion`, and the answer goes back to the same child with `SendMessage`. Claude Code always has the `Agent` tool, so no skill carries an unavailable-subagents fallback.

## Retired concepts

30. Task-state ceremony is retired with the old pipeline. Flag a lifecycle field (`status:`, `phase:`, `blocked-on:`, `review:`, `tier:`, `green-gate:`), an Azure DevOps work-item transition (`State: Resolved`), or an abstract stage gate — the gate bans the fields mechanically; the concept ban is wider. A concrete artifact may require user agreement before the next skill consumes it, and a skill may name that next consumer. Flag routing whose only purpose is advancing a named stage, choreography whose only reader is documentation, and a skill that requires ceremonial state rather than a concrete input.

## AL grounding

31. Every BC object, table, field, procedure, event, enum value, or dialog text a skill or agent shows, writes, or judges is confirmed by a lookup in the current session, never recalled. BC vocabulary rides with it on every line written into code or a receipt — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction, codeunit not class, procedure not method — and so does production-AL thrift: reach for the platform before writing code, and an interface with a single implementation is a finding. Today `al-arc42`, `al-implement`, `al-improve-codebase-architecture`, `al-simplify`, `al-review`, `al-tdd`, `al-codebase-design`, `al-to-spec`, `al-grill-with-docs`, `al-walkthrough`, `al-environment-data`, `al-diagnosing-bugs`, and `al-research` carry the grounding rule; flag its absence in any new skill that writes, shows, or judges AL.

## Commit discipline

32. A skill that writes repo files calls `/al-commit` at every exit — clean close, fail pause, or open-question stop. Flag a direct commit command or a writing skill with no `/al-commit` handoff. `/al-commit` owns the full worktree, questions only temporary paths, secret-bearing paths, or generated output that belongs in `.gitignore`, and creates the maximum number of independently valid commits.

## Show the thing

33. Artifact prose shows the thing — the page, the field, the command, the number — one sentence per fact; run narration in an artifact is a defect, its home the commit message. Chat surfaces glyph their fixed slots, shape-distinct rather than color-coded: findings as `⛔` Blocking / `⚖️` Non-Blocking headlines over one-line `⚡ Breaks:` / `📍 Proof:` / `🔧 Fix:` slots in `al-review`'s three axes — Spec, Standards, Correctness — reported unmerged, the set-wide findings grammar, with no closing verdict that merges the axes — and the run-narration ledes — `▸` finding / `➜` move mid-run, `✅` / `⛔` at the close. These carried lines are deliberate, not rule-16/17 findings — live sessions ignored the shape while it was unwritten. Flag a carrier missing its line, and flag an emoji outside a defined slot — that one is decoration. The delegation line `▶ <model> · <brief> → <return>` of rule 38 is a defined slot; `al-walkthrough`'s `▶ <business action>` report line stays — it sits in a code span and names no model.

## Work-item attachments

35. A skill that publishes local files to a work item delegates the line `▶ haiku · attach <the files> to <the item> as the Tracker doc in docs/agents/issue-tracker.md says → verified attachment URLs`; the Azure DevOps seed template sends it to `/al-azure-devops-attachments`, and the GitHub seed template attaches through `gh --attach`. A skill whose lead attaches in-line, as `al-walkthrough` does, says so in prose and defers to the Tracker doc. Flag manual-upload fallback and any claim that missing MCP attachment support blocks publication. Azure CLI authentication failure pauses for the exact user-run login command; after authentication, `/al-azure-devops-attachments` resumes upload and verifies every `AttachedFile` relation.

## Work items

36. One request has one Original work item, the item it arrives on. `Original` names its role in this workflow, not the top of the hierarchy; structural parents remain unchanged and out of scope. One Vertical slice creates no child; the Original work item is executable. Several slices make it the container, and each slice gets one direct child work item. Flag a work item above the Original introduced by this workflow, a grandchild below the Original work item, and a child created any way but the Tracker doc's "create a slice" section.
37. The spec keeps `/mattpocock-skills:to-spec`'s headings in order: `Problem Statement`, `Solution`, `User Stories`, `Implementation Decisions`, `Testing Decisions`, `Out of Scope`, `Further Notes`. `Process contract` and `Business process` nest under `Solution`; `Building Block View` and `Runtime View` nest under `Implementation Decisions`. The spec lives in the spec field the Tracker doc names. Diagrams stay with their explanatory text. In the acceptance criteria, `Behavior` is valid fenced Gherkin and precedes `Test specification` when both exist; either section may be absent without prescribed meaning.

## Delegation contract

38. A skill delegates a step with one line — `▶ <model> · <brief> → <return>` — placed at the step it serves. The line is one `Agent` call with that `model`: `opus`, `sonnet`, or `haiku`, never `fable`. The `brief` names what the child receives — it inherits nothing — and the `return` names what comes back, checkable. Callee skills — `/al-build`, `/al-commit`, `/al-arc42`, `/al-azure-devops-attachments`, `/al-pull-request`, `/al-clone-bcapps` — carry no `▶` line; the caller writes it. The `SessionStart` hook text owns the rest of the contract, and a skill restates none of it: every child runs in the lead's worktree and branch; the fixed dispatch parts are the brief, the return contract, the unattended line, "write the decision out and end your turn", and the delegation-cost paragraph, plus the grounding rule of rule 31 for a child that writes or judges AL; a child's stop reaches the user through `AskUserQuestion` and returns with `SendMessage`; a missed return is re-dispatched once, one step up `haiku` → `sonnet` → `opus`. Flag a `▶` line outside this grammar, a callee skill carrying one, and a brief that lists a dispatch part the hook does not.

## Base plugin references

39. Call a Base plugin skill by its namespaced name — `/mattpocock-skills:<skill>`, `/bcquality:<skill>` — only once upstream has shipped it in a version bump. The drift check resolves references against upstream heads, which run ahead of what developers have installed, so a skill it accepts may not exist on a developer's machine yet.

## Tracker neutrality

40. A skill reads, writes, comments on, links, and attaches to a work item only as the Tracker doc says. Flag an `ado` MCP tool, `az boards`, `az repos`, `gh issue`, `sub-issue`, `gh pr`, GraphQL, Azure DevOps, Azure Repos, or `AB#` in a skill outside the two seed templates, `al-setup-matt-pocock-skills/SKILL.md` (which picks between them), `al-azure-devops-attachments`, and the Code-host procedures — `al-pull-request/AZURE-REPOS.md`, `al-pr-shepherd/AZURE-REPOS.md`, and their `GITHUB.md` siblings; `tests/SkillWorkflowContracts.Tests.ps1` fails the same tokens, and `AB#` outside the two seed templates too: a Code-host procedure never parses a tracker's link syntax. Flag a work item type or field name anywhere in a skill, the seed templates included: skills name verbs, and the seed templates carry placeholders that the setup fills with the Consumer repository's types and fields; the test fails those tokens everywhere. `al-pull-request` and `al-pr-shepherd` read `git remote get-url origin`, take the sibling procedure whose `Hosts` line lists the host, and stop naming an unlisted host.
