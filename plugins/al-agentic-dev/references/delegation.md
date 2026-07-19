# Delegation

Whether to hand work to a spawned custom agent, and which model it runs on. One home: the
custom agents under `agents/` and the skills that invoke them name a role and
point here; this file owns the triggers, the role ordering, the effort rule, and the rerun
diagnostic so they do not drift. Each agent's frontmatter `model:` field fixes its role —
no per-invocation override — using the harness's current model IDs.

**Model control is closed.** A custom agent's `model:` frontmatter is the only place its
role is set. The 18 agents under `agents/` are all `user-invocable: false` — a session
never spawns one by typing a name, only a skill invokes it by role, in-flow. Invoking
skills never pass a `model` (or `reasoning_effort`) override at spawn time — doing so would
re-pin the role behind the frontmatter's back for that one call. Silent model substitution
is equally forbidden: if a pinned id is retired or unavailable, the spawn fails visibly (the
caller reports `BLOCKED`, names the missing id, and stops) rather than falling back to a
different model unannounced. A rotated id is corrected once, in the frontmatter, never
patched around at the call site.

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

Four roles, ranked. Higher intelligence handles a harder problem unsupervised; higher taste
means better code shape, API design, and copy; the arbiter role sits between worker and
smart — deep enough for one hard, consequential technical question, narrower than
whole-artifact authority over ambiguous, multi-part work. Model IDs evolve fast — the role
is the contract, the ID is looked up. As of this writing the roles map to `gpt-5.6-luna`
(bounded executor), `gpt-5.6-terra` (worker), `gpt-5.6-sol` (arbiter), and `claude-fable-5`
(smart); check the task tool's model list or `/subagents` for the live set. A rotated or
retired ID is corrected once, centrally, in the affected agent's `model:` frontmatter — never
substituted at the call site (closed model control, above). Until that frontmatter migration
lands, a spawn against the retired ID is `BLOCKED`, not silently redirected to a successor.

| role | model | use |
|------|-------|-----|
| bounded executor | `gpt-5.6-luna` | Read-only, bounded command execution that relays an authoritative artifact |
| worker | `gpt-5.6-terra` | Default delegated implementation, retrieval, classification, and focused review |
| arbiter | `gpt-5.6-sol` | One consequential technical question needing concentrated depth, cross-source arbitration, or an independent verdict on other agents' output — not multi-workstream authority |
| smart | `claude-fable-5` | Non-decomposable whole-artifact judgment or a proven worker knowledge limit |

The fleet under `agents/` currently pins 13 worker, 2 smart, 2 arbiter, and 1 bounded
executor — 18 agents total. The worker role is the generic floor. The bounded executor is
an exception, not a cheaper default. Those pins are fixed fleet assignments, not caller
choices: fleet invocations omit both `model` and `reasoning_effort`.

## How to pick

### Two dials for sanctioned non-fleet spawns only

This guidance applies only where a mechanism explicitly permits a non-fleet/ad-hoc spawn,
such as the cross-family rubber-duck fallback. It never applies to the 18 fleet agents:
their frontmatter fixes the model and their invocations omit both `model` and
`reasoning_effort`. For a sanctioned non-fleet spawn, the `model` parameter picks the role —
how hard or ambiguous the problem is, what the worker must *know*. The
`reasoning_effort` parameter picks the effort — how much ground the worker must cover and
verify before calling itself done, how hard it *tries*. The dials are independent: the worker
role at high effort suits a wide sweep of routine ground; the smart role at low effort suits
one hard judgment with little legwork. Omit `reasoning_effort` unless the workload names a
reason — the model's default is tuned for what most tasks need.

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
  context → fix the prompt; *didn't know* — confidently wrong despite complete context;
  *didn't try* — skipped a file, didn't run the gate, bailed early. For sanctioned non-fleet
  spawns, those diagnoses respectively mean touch no dial, one role up, or effort up at the
  same role. A fleet agent remains pinned; rerun once with the diagnosis named, without
  model or reasoning overrides.

## The al-agentic-dev carve-out — review runs on workers on purpose

A single smart reviewer is the usual way to review an implementation. This plugin doesn't use
one: `/al-code-review` and `/al-refactor` decompose the review into many **narrow single-goal
lenses**, mostly on the worker role. `al-review-cr-bugscan` is the named smart exception for
correctness judgment. The `al-review-judge` arbiter agent then dedups, substantiates, and
ranks the lens findings against the scoped diff, and an independent veto still runs through
the **rubber-duck agent** — which runs on a different model family than the session, catching
what same-family self-review misses (see [`rubber-duck-review.md`](rubber-duck-review.md)).
The decomposition plus the arbiter pass plus the veto retains worker roles for the focused
lenses that do not earn the smart exception. This is not a downgrade of the
review-→-smart-role rule; it is a different shape that meets its intent.

## Where each worker lands

| Worker | Role |
|---|---|
| `al-red-green` custom agent (one AAA case RED→GREEN) | worker, fixed — a case that can't reach green does not self-escalate (static `model:` frontmatter); the agent returns its own `BLOCKED` verdict and the caller routes it (never an inline or `general-purpose` fallback); an unavailable or retired pinned id is likewise `BLOCKED`, corrected only in the frontmatter |
| `al-review-cr-bugscan` custom agent | smart, fixed — correctness judgment earns the smart role |
| Remaining `al-review-cr-*` / `al-review-refactor-*` custom agents (one focused review pass each) | worker, fixed (carve-out) |
| `bc-standard-reference` custom agent | worker, fixed — version matching and hook selection require reasoning beyond retrieval |
| `al-gate-runner` custom agent (`/al-build`, `/al-provision`, `/al-validate-breaking-changes`, `/al-mutate` final closeout) | bounded executor, fixed — runs the one supplied gate command and relays its authoritative artifacts; the caller keeps diagnosis, reruns, and routing |
| `al-mutant-cycle` custom agent (`/al-mutate`) | worker, fixed — one supplied mutate→gate→revert cycle, returns observed evidence; the caller keeps mutant selection, equivalence judgment, and classification |
| `al-design-option` custom agent (`/al-design`) | smart, fixed — one self-contained architecture candidate under a supplied divergent constraint; `/al-design` fans out three in parallel, then chooses among them itself |
| `al-researcher` custom agent (`/al-research`) | arbiter, fixed — one framed consequential BC fact across source families, reconciling disagreement instead of concealing it |
| `al-review-judge` custom agent (`/al-code-review`, `/al-refactor`) | arbiter, fixed — dedups, substantiates, and ranks one supplied batch of review/refactor lens findings against its scoped diff; the caller keeps fixes, application order, and routing |

The rubber-duck consult is orthogonal to this table: spawned as `agent_type:
"rubber-duck"`, the harness pairs it to a different model family than the session by
design; the cross-family fallback in [`rubber-duck-review.md`](rubber-duck-review.md) owns
the model choice when that agent type is unavailable. Do not reassign its role.
