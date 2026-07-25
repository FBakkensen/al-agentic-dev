# Ground rules

Always-on rules for every reply and every line of AL. The `sessionStart` hook injects this file; it fires on new and resumed sessions only, never on compaction, so skills re-read it on invocation.

## Output shape

Output follows the `i-have-adhd` skill's rules — invoke `/i-have-adhd`; not installed → install it from https://github.com/ayghri/i-have-adhd. This binds every skill and every agent that writes files or reports to the user. A fixed Return block stays byte-identical regardless, per Schema outranks style below.

Schema outranks style: machine-read shapes (YAML frontmatter, task-file fields, template schemas, agent Return payloads) keep their consumer-required structure exactly — list caps and brevity never truncate them.

**One decision per question.** A reply that needs the user's input asks one question per message, with lettered options. Carve-out: the ask-before-reveal questions in `/al-user-verification` and `/al-quiz` are witness elicitation, not decisions — options that reveal the expected value would lead the witness.

## Chat thrift

Lead with the verdict on line 1, then the reason. The first line of each landing point carries its outcome. House shapes keep their schema; thrift governs the wording inside them.

Keep articles and connectives. Cut raw logs to the decisive line. Emit tool results, never tool-call narration. Drop decorative tables, emoji, the restated question, and "why it matters" preambles.

Compress framing, never code, AL object names, commands, or error strings.

## Grounding

BC training data is stale fiction. Every exact BC name — object, procedure, event, table, field, enum value, caption — written this session is grounded in a session-fresh lookup: an `al-symbols-mcp` / `grep` hit or a quoted fetch. Recall is not evidence.

- **Upstream names.** A name cited from an upstream artifact counts only when `grep` against that file returns it this session.
- **Minted names.** A name that does not exist yet needs a zero-hit collision lookup this session (`al-symbols-mcp` / `grep` — genuinely new, not shadowing) plus BC-vocabulary compliance. Collision scope: object names against workspace object declarations; fields against the target table and its extensions; procedures against the target object only; enum values against the target enum and its extensions. For a base object in a dependency, grep covers workspace extensions only — the `/al-build` compiler is the backstop for base-field collisions. `New and Modified Objects` is proposal, not carried evidence; the skill that lands the object re-runs the collision lookup in its own session.
- **Research gateway.** BC knowledge beyond direct workspace reading invokes `al-researcher` with `Question:` one framed fact, `Use:` `routine`, `durable artifact <path>`, or `resolve conflict`, and optional `Context:`. Skills and the main session spawn it directly. Custom agents need `agent` tool access and carry the same instruction in their own body. Relay its tagged result; `CONFLICT` or `UNRESOLVED` stops the lookup. Never continue through another agent, MCP, web, or shell source.
- **Constructs.** BC construct classes — record loop plus `Modify`, `SetLoadFields`, temp record lifecycle, page/report surface, `Commit` — carry execution-order and platform-cost semantics workspace names cannot vouch for. First write of a construct class in a task needs an `al-researcher` result.
- **Satisfiers.** `SINGLE-SOURCE` with a verbatim quote satisfies routine grounding. Facts landing in `event-model.md`, `architecture.md`, `CONTEXT.md`, or an ADR require `VERIFIED`. Source disagreement requires `Use: resolve conflict`; `CONFLICT` or `UNRESOLVED` blocks the fact from landing.
- **Trace.** Declare the citation in chat as `Researched: <fact> → <source path / URL / topic id>`. Task-scoped citations also land as `Contract notes` bullets at task reconcile — the one inline-citation carve-out. Everything else in artifacts stays names-only.

## BC vocabulary

A term naming a whole discipline with no BC equivalent — TDD, red/green, mutation testing, AAA — keeps its name and its density. Any word with a BC-domain rival takes the BC side: Insert not create, Modify not mutate or update, Delete not remove, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, No. not ID, procedure not method, codeunit not class, test data not fixture. The litmus — the term appears in BaseApp source or Microsoft Learn BC docs — governs only words with a BC-domain rival; exact platform and tool names (Git, Markdown, frontmatter, MCP, Copilot) stay exact.

## House shapes

- **Mid-task gate** — a gate event that does not flip task status: one line, no box. `**GREEN** <what changed> → <next step>.` or `**RED** <what failed> → <next step>.`
- **Task-close gate report** — a status flip to `done` or `blocked`, or a skill's closing stamp: four rows as a borderless two-column table. **Did** = the user-facing behaviour the change enables. **Was** = the problem it solves, one scenario the user recognises. **Fits** = how the change fits the app at module, BC pattern, and seam level, named. **Next** = one action, or nothing if the agent moves on. Mechanics — procedure names, line numbers, mutant IDs, build counts — go in the commit and the task file, never chat. Verify-task variant shifts altitude: **Did** = what the user confirmed, **Was** = the user-facing problem the slice solved, **Fits** = the journey in `event-model.md` vocabulary, **Next** = the handoff.
- **Stop** — one line: `**Stop.** <reason in BC vocabulary>. <next action>.`
- **Opener** — a chip line at skill start: `**T-NNN <Title>** · status → status`. Ongoing state restating is the `i-have-adhd` skill's job (its "restate state every turn" rule).
- **Names are the citation.** The object, procedure, table, field, or event publisher appears by name — the name is the address; no inline `(file.al:120)` annotations in durable artifacts. Name the specific target: "Extract `PostSalesOrder` from codeunit 80 into `Sales-Post Impl`", never "refactor the codeunit".
- **Tasks appear by name in chat.** A bare `T-NNN` never stands alone in human-read text — the title or slug rides along at first mention: `copy-doc-dimension-inheritance (T-014)`. Agent-channel surfaces — frontmatter, `depends_on:` lists, filenames, commit trailers — keep bare ids.
- **Workflow lives in the commit.** An artifact carries the forward-facing fact in declarative voice. The step-by-step story, the deciding-skill prefix (a `/al-implement decision:` line), and the rubber-duck reconciliation go in the commit message.

## Production-AL thrift

**Platform first.** Reach for the platform before writing code: a field plus a FlowField beats a setup table plus a management codeunit; a table relation or a permission-set entry beats validation code; an enum beats a hand-rolled status pattern.

**No abstraction for one caller.** An AL `interface` object arrives with its second implementing codeunit — the two-adapter rule, homed in [LANGUAGE.md](LANGUAGE.md). A value that never changes lives in code, never in setup. `/al-refactor` deepens a seam when a second caller earns it — not in anticipation of one.

**Lazy is not negligent.** Trust-boundary validation, posting and ledger correctness, permission checks, and everything the task asked for stay at full strength. This governs production code only, never test thoroughness — Unit-first TDD and the `/al-mutate` gate stand.

**Name the ceiling.** A shortcut with a known limit — a table scan fine under a row threshold, a naive heuristic — carries a one-line comment naming the ceiling and the upgrade path. No ceiling → no comment.
