# Model selection

Which model a spawned subagent runs on. One home: the subagent prompt blocks under
`subagents/` and the skills that spawn them name a tier and point here; this file owns the
ordering and the escalation rule so they do not drift. Set the tier with the spawn's `model`
parameter on the task tool, using the harness's current model IDs.

## Tiers

Three tiers, ranked. Higher intelligence handles a harder problem unsupervised; higher taste
means better code shape, API design, and copy. Model IDs evolve fast — the tier is the
contract, the ID is looked up. As of this writing the tiers map to `claude-sonnet-5` (cheap),
`claude-opus-4.8` (mid), and `claude-fable-5` (smart); check the task tool's model list or
`/subagents` for the live set and substitute the nearest successor when an ID has rotated.

| tier | cost | intelligence | taste |
|--------|------|--------------|-------|
| cheap (`claude-sonnet-5`) | low | base | good |
| mid (`claude-opus-4.8`) | mid | higher | higher |
| smart (`claude-fable-5`) | high | highest | highest |

The cheap tier is the floor — never drop below it. When the choice is genuinely unclear,
inherit the spawning session's model (omit the `model` parameter).

## How to pick

- **Intelligence > taste > cost.** Cost breaks a tie; it never overrides a task that needs more
  intelligence. Escalating costs less than shipping wrong code.
- **Bulk / mechanical work → cheap tier.** Clear-spec implementation (a single AAA case with its
  `New and Modified Objects` block), the build/publish/test gate, the mutate-build-revert cycle.
  The spec carries the judgment; the worker executes it.
- **Review of a whole implementation → the smart tiers** (mid / smart) — *except the
  al-agentic-dev carve-out below.*
- **Escalate a cheap run that misses the bar.** Start at the mapped tier; if the output is wrong
  or the worker can't reach green, rerun the same work one tier up. Standing permission — judge
  the output, not the price tag.

## The al-agentic-dev carve-out — review runs cheap on purpose

A single smart reviewer is the usual way to review an implementation. This plugin doesn't use
one: `/al-code-review` and `/al-refactor` decompose the review into many **narrow single-goal
lenses**, each on the cheap tier, then adversarially judge the findings (skeptics prompted to
refute) and run an independent veto through the built-in **rubber-duck agent** — which the
harness runs on a different model family than the session, catching what same-family
self-review misses (see [`rubber-duck-review.md`](rubber-duck-review.md)). The decomposition
plus the veto substitutes for the one smart reviewer, so the lenses stay cheap deliberately.
This is not a downgrade of the review-→-smart-tier rule; it is a different shape that meets
its intent.

## Where each worker lands

| Worker | Tier |
|---|---|
| `al-red-green` (one AAA case RED→GREEN) | cheap; escalate → mid/smart only if a case can't reach green |
| `al-review-lens` / `al-review-lens-bc` (one focused review pass) | cheap (carve-out) |
| build gate worker (`/al-build`) | cheap |
| mutation worker (`/al-mutate`) | cheap |

The rubber-duck consult is orthogonal to this table: the harness owns its model and picks a
different family than the session by design. Do not try to re-tier it.

