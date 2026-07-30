---
name: al-refactor
description: Reshape AL production and test code while the tests stay green, behaviour identical. Run it after a task goes green.
disable-model-invocation: true
---

# Reshape while green

The build is green before the first change. Reshaping against red is debugging — that belongs in /al-implement. Task-file state is `/al-routing`'s; this skill reshapes code. The knowledge pass below reads `.bcquality/` — missing → name `/al-clone-bcquality` and stop. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## The knowledge pass

`.bcquality/microsoft/skills/review/al-code-review.md` names one review leaf per knowledge domain in its `sub-skills:` frontmatter. Run every leaf it lists against the task's diff, each per its own instructions, resolving the paths inside those files against `.bcquality/`. Every leaf runs — each decides its own applicability, and pre-judging which ones have something to say is the documented way to make them underreport. A leaf that ends partial or failed leaves its domain unjudged: name it and stop. Its findings are reshape candidates like any other, cited by the article behind them.

## Improvement dimensions

Read the whole diff — a task's full diff, once per task — through each of these:

- **Simplification** — duplication, dead code, pass-through procedures, generality nothing asked for.
- **BC platform** — code reinventing what BaseApp, the System Application, or the platform already does.
- **Structure** — decision logic separated from the reads and writes around it, so the decisions are testable without a database; depth over indirection; coupling weakened, or localised in one module where it cannot be.
- **Terminology** — object, procedure, and field names agreeing with `CONTEXT.md`, the ADRs, `architecture.md`, `event-model.md`, and the task's `New and Modified Objects`.
- **Performance shape** — a lookup hoisted out of a loop, a filtered read replacing a scan, fields loaded selectively. The structural kind, not one-line tweaks.

If your harness supports subagents, these parallelize on full-capability subagents running the same model as this conversation; otherwise apply them in one pass.

## Apply

One reshape at a time, committed under the owning task's `T-NNN` prefix, running the gate with /al-build after each. Red reverts that step, and recovery comes before the next one.

- Renames and seam introduction land first — they touch many call sites and conflict with anything queued behind them.
- Extract a helper on the third occurrence, not the second. Below that, leave the duplication and say so. Logic with a rightful home — a BaseApp or System Application helper, an existing module's internal helper — moves there and the canonical one is reused.
- Production and tests reshape together. A test added mid-reshape — a baseline on legacy code with no covering tests, a case on a branch the reshape uncovers — passes against current code first, so the regression signal stays honest. Unit tests on a module the reshape dissolves are deleted, not relayered.
- Rename freely what this branch introduced — `git log origin/main..HEAD` names it — and what is internal-only. A rename touching a public symbol that predates the branch is not a reshape; it follows the finding rule below.
- `[HandlerFunctions('...')]` names a test procedure inside a string literal that symbol tools do not see: search the workspace for that literal before renaming a test procedure, and update the AAA case header and `Covered By` in the same change.

## Findings

A defect needs no user decision: fix it in this run. A behavioural defect goes red first — write the missing case, watch it fail on a real assertion, then make it pass. A provably non-semantic defect lands directly.

A change request would override a decision the user already made, or establish missing business or architecture intent. Interview every change request before implementing any ruling, one per message, highest impact first. Explain the impact, choice, consequences, and recommendation. Name modules, boundaries, public objects, interfaces, events, or other AL concepts when they make the current or proposed architecture legible; keep paths, line numbers, private procedures, code snippets, lookup mechanics, and knowledge-article details out unless the user asks. One answer settles only the request in front of the user.

After every request is settled, apply its ruling: **Do it now** lands on the defect terms above; **Write a task** creates one per `/al-routing`'s schema; **Keep the current behaviour** records the ruling in the decision artifact. Create a task only when the user chose one. Technical evidence belongs in the resulting commit or task.

## Writing AL

Every BC object, table, field, procedure, event, and enum value name comes from a lookup in this session — search the workspace, or read the symbols. Recall is not evidence. `.bcapps/` is the pattern library: read how the nearest System Application or `src/Apps/W1` code shapes what you are reshaping toward, and lift that shape — default search skips gitignored folders.

Use BC vocabulary: Insert not create, Modify not update, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, procedure not method, codeunit not class.

Reach for the platform before writing code — a field plus a FlowField over a setup table and a management codeunit, a table relation over validation code, an enum over a hand-rolled status. An AL `interface` arrives with its second implementing codeunit, never in anticipation of one. A shortcut with a known limit carries a one-line comment naming the ceiling and the upgrade path.

## Close

Report the reshape and defects fixed at module, pattern, and seam altitude, naming the invariant that held and the dimensions and leaves that came back clean. Report each change request by impact, ruling, and outcome.

Then `/al-routing`.
