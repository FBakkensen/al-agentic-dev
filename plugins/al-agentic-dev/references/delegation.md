# Delegation

Whether to hand work to a spawned custom agent, and which model it runs on. One home: the
custom agents under `agents/` and the skills that invoke them name a role and
point here; this file owns the triggers, the role ordering, the effort rule, and the rerun
diagnostic so they do not drift. Each agent's frontmatter `model:` field fixes its role —
no per-invocation override — using the harness's current model IDs.

## When to delegate

Each trigger names a cue and the reflex it fires:

- **The task sentence contains "across all / every / each"** — a distributive phrase means
  the sentence is already a delegation prompt. Hand it to a subagent verbatim.
- **Third repetition** — the same-shaped edit is being made for the third time. Stop: the
  remaining instances are a sweep; delegate the rest.
- **The spec is already written down** — a task file, a todo description, or a decisions
  table contains what-changes-where. "The context is in my head" is disproven by that
  artifact; the artifact *is* the prompt.
- **The checking command is nameable** — a grep count, a validator, or the build/test gate
  proves the work done. Then quality is bounded by the gate, not the worker; the least capable
  eligible role does it and the caller runs the check.
- **Disjoint file sets** — two work items touch no common file. They run as parallel
  background subagents, not sequentially by the caller.

Stay inline when: the edit needs a judgment call per site; the files overlap work already
in flight; or the whole job is smaller than writing the handoff.

## Model roles

Three roles, ranked. Higher intelligence handles a harder problem unsupervised; higher taste
means better code shape, API design, and copy. Model IDs evolve fast — the role is the
contract, the ID is looked up. As of this writing the roles map to `gpt-5.6-luna` (bounded
executor), `gpt-5.6-terra` (worker), and `claude-fable-5` (smart); check the task tool's
model list or `/subagents` for the live set and substitute the nearest successor when an ID
has rotated.

| role | model | use |
|------|-------|-----|
| bounded executor | `gpt-5.6-luna` | Read-only, bounded command execution that relays an authoritative artifact |
| worker | `gpt-5.6-terra` | Default delegated implementation, retrieval, classification, and focused review |
| smart | `claude-fable-5` | Non-decomposable whole-artifact judgment or a proven worker knowledge limit |

The worker role is the generic floor. The bounded executor is an exception, not a cheaper
default. When the choice is genuinely unclear, inherit the spawning session's model (omit
the `model` parameter).

## How to pick

Two dials, set both at spawn. The `model` parameter picks the role — how hard or ambiguous
the problem is, what the worker must *know*. The `reasoning_effort` parameter picks the
effort — how much ground the worker must cover and verify before calling itself done, how
hard it *tries*. The dials are independent: the worker role at high effort suits a wide sweep
of routine ground; the smart role at low effort suits one hard judgment with little legwork.
Omit `reasoning_effort` unless the workload names a reason — the model's default is tuned
for what most tasks need.

- **Intelligence > taste > cost.** Cost breaks a tie; it never overrides a task that needs more
  intelligence. Escalating costs less than shipping wrong code.
- **Effort never buys capability.** Genuinely hard work on the worker role at high effort just
  grinds: more iterations, sometimes a higher total cost, and some tasks it never finishes.
  Judge by expected total task cost — per-token price × tokens consumed — never per-token
  price alone; a stronger model that reaches green in fewer steps can be both better and
  cheaper.
- **A sharp spec lowers the role.** Precise instructions suit the worker role; ambiguity
  demands the smart role. Sharpening the spawn prompt is the first lever.
- **Bounded execution → bounded executor only when its result is host-visible.** The worker
  must stay read-only, relay an authoritative artifact, and leave cause diagnosis and routing
  to the caller. Otherwise use the worker role.
- **Review of a whole implementation → smart** — *except the al-agentic-dev carve-out below.*
- **When a run misses the bar, never rerun blind.** A rerun without a named cause is a coin
  flip at full price. Diagnose first: *wasn't told* — the spawn prompt was vague or missing
  context → fix the prompt, touch no dial; *didn't know* — confidently wrong despite complete
  context → one role up; *didn't try* — skipped a file, didn't run the gate, bailed early →
  effort up, same role. Rerun once, naming the diagnosis.

## The al-agentic-dev carve-out — review runs on workers on purpose

A single smart reviewer is the usual way to review an implementation. This plugin doesn't use
one: `/al-code-review` and `/al-refactor` decompose the review into many **narrow single-goal
lenses**, mostly on the worker role. `al-review-cr-bugscan` is the named smart exception for
correctness judgment. The host then adversarially judges the findings (skeptics prompted to
refute) and runs an independent veto through the **rubber-duck agent** — which runs on a
different model family than the session, catching what same-family
self-review misses (see [`rubber-duck-review.md`](rubber-duck-review.md)). The decomposition
plus the veto retains worker roles for the focused lenses that do not earn the smart exception.
This is not a downgrade of the review-→-smart-role rule; it is a different shape that meets
its intent.

## Where each worker lands

| Worker | Role |
|---|---|
| `al-red-green` custom agent (one AAA case RED→GREEN) | worker, fixed — a case that can't reach green does not self-escalate (static `model:` frontmatter); the caller falls back to doing the case inline or a `general-purpose` smart spawn on *didn't know* |
| `al-review-cr-bugscan` custom agent | smart, fixed — correctness judgment earns the smart role |
| Remaining `al-review-cr-*` / `al-review-refactor-*` custom agents (one focused review pass each) | worker, fixed (carve-out) |
| `bc-standard-reference` custom agent | worker, fixed — version matching and hook selection require reasoning beyond retrieval |
| build gate worker (`/al-build`) | bounded executor — read-only gate execution and authoritative result relay |
| mutation worker (`/al-mutate`) | worker — transient source edits and kill/stillborn classification |

The rubber-duck consult is orthogonal to this table: spawned as `agent_type:
"rubber-duck"`, the harness pairs it to a different model family than the session by
design; the cross-family fallback in [`rubber-duck-review.md`](rubber-duck-review.md) owns
the model choice when that agent type is unavailable. Do not reassign its role.
