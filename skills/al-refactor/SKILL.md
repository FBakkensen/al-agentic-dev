---
name: al-refactor
description: Reshape AL production and test code while the tests stay green, behaviour identical. Run it after a task goes green.
disable-model-invocation: true
---

# Reshape while green

The tree is clean and the build is green before the first change. Evaluate the task's clean full-gate receipt: its commit is an ancestor of `HEAD` and the diff since it names only this task file. Match → `🔎✅ Green gate reused — T-123 @ abc123 (full).`; no match → `🔎🔧 Gate required — no compatible green receipt.`, then run `/al-build -AllTests` green. Reshaping against red is debugging — that belongs in /al-implement. Your first line names that this run wants a standard-class model or above — the user picked the model and weighs the mismatch. Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch. Task-file state is `/al-routing`'s; this skill reshapes code. The knowledge pass below reads the `.bcquality/` clone: missing → name `/al-clone-bcquality` and stop, before the gate rather than after it. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## The knowledge pass

`/al-knowledge-pass` on this task's diff returns the findings, or the one line naming the domain that stopped it; a stop there stops this run. Its findings are reshape candidates like any other, cited by the article behind them.

## Improvement dimensions

Read the whole diff — a task's full diff, once per task — through each of these:

- **Simplification** — duplication, dead code, pass-through procedures, generality nothing asked for.
- **BC platform** — code reinventing what BaseApp, the System Application, or the platform already does.
- **Structure** — decision logic separated from the reads and writes around it, so the decisions are testable without a database; depth over indirection; coupling weakened, or localised in one module where it cannot be.
- **Terminology** — every introduced name tracing to a `CONTEXT.md` term, the BC baseline, or an `event-model.md` Action, Business Event, or Status, its verb to BC's own set — an untraceable name is a finding — and names agreeing with the ADRs, `architecture.md`, and the task's `New and Modified Objects`; artifact prose the diff touched (task bodies, `architecture.md`) answers to the same vocabulary as the code.
- **Performance shape** — a lookup hoisted out of a loop, a filtered read replacing a scan, fields loaded selectively. The structural kind, not one-line tweaks.

If your harness supports subagents, these parallelize in full-capability subagents; otherwise apply them in one pass.

## Apply

One reshape at a time, committed under the owning task's `T-NNN` prefix, running the gate with `/al-build -AllTests` after each. Red reverts that step, and recovery comes before the next one.

- Renames and seam introduction land first — they touch many call sites and conflict with anything queued behind them.
- Extract a helper on the third occurrence, not the second. Below that, leave the duplication and say so. Logic with a rightful home — a BaseApp or System Application helper, an existing module's internal helper — moves there and the canonical one is reused.
- Production and tests reshape together. A test added mid-reshape — a baseline on legacy code with no covering tests, a case on a branch the reshape uncovers — passes against current code first, so the regression signal stays honest. Unit tests on a module the reshape dissolves are deleted, not relayered.
- Rename freely what this branch introduced — `git log origin/main..HEAD` names it — and what is internal-only. A rename touching a public symbol that predates the branch is not a reshape; it follows the finding rule below.
- `[HandlerFunctions('...')]` names a test procedure inside a string literal that symbol tools do not see: search the workspace for that literal before renaming a test procedure, and update the AAA case header and `Covered By` in the same change.

## Findings

A defect needs no user decision: fix it in this run. A behavioural defect routes to `/al-implement`, which writes the missing case, watches it fail on a real assertion, then makes it pass. A provably non-semantic defect lands directly.

A change request would override a decision the user already made, or establish missing business or architecture intent. Interview every change request before implementing any ruling, one per message, highest impact first. Explain the impact, choice, consequences, and recommendation. Name modules, boundaries, public objects, interfaces, events, or other AL concepts when they make the current or proposed architecture legible; keep paths, line numbers, private procedures, code snippets, lookup mechanics, and knowledge-article details out unless the user asks. One answer settles only the request in front of the user.

After every request is settled, apply its ruling: **Do it now** lands on the defect terms above; **Write a task** creates one per `/al-routing`'s schema; **Keep the current behaviour** records the ruling in the decision artifact. Create a task only when the user chose one. Each ruling commits as it lands: a created task under its own `T-NNN` prefix, an artifact ruling with a plain descriptive message. Technical evidence belongs in the resulting commit or task.

## Writing AL

Every BC object, table, field, procedure, event, and enum value name comes from a lookup in this session — search the workspace, or read the symbols. Recall is not evidence. `.bcapps/` is the intentionally gitignored pattern library: read how the nearest System Application or `src/Apps/W1` code shapes what you are reshaping toward, and lift that shape. Missing → stop, naming `/al-clone-bcapps`; otherwise default workspace search can omit the clone, so use a search mode or direct file reading that includes it.

Use BC vocabulary: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, procedure not method, codeunit not class — and a codeunit is named for the behaviour it owns, never a Manager or Handler.

Reach for the platform before writing code — a field plus a FlowField over a setup table and a management codeunit, a table relation over validation code, an enum over a hand-rolled status. An AL `interface` arrives with its second implementing codeunit, never in anticipation of one. A shortcut with a known limit carries a one-line comment naming the ceiling and the upgrade path.

## Close

Report the reshape and defects fixed at module, pattern, and seam altitude, naming the invariant that held and the dimensions and leaves that came back clean. Report the committed `HEAD` from the last durable full green when this run reshaped code; a no-change pass retains its incoming receipt. Report each change request by impact, ruling, and outcome. A run that reshaped code or landed a fix also goes up through `/al-visualize` as a receipt of the reshape; a run that changed nothing closes plain.

Then `/al-routing`.
