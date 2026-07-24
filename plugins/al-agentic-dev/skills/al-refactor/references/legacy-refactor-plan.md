# Legacy AL refactor plan

**No green baseline means no regression signal — write the baseline tests before changing behaviour.** This plan phases refactoring of legacy AL code that ships without sufficient tests; use it when there is no calling task and no `architecture.md`. Companion to `/al-refactor`, whose lens-and-apply discipline assumes tests already exist.

## Dependency categories

**The dependency's category decides whether a port is justified at the seam.** Classify each dependency the candidate module reaches for:

| # | Category | Examples | Test approach | Port? |
|---|---|---|---|---|
| 1 | In-process | Pure computation, no I/O: rounding, discount math, validation predicates | Test through the deepened interface directly | No |
| 2 | Local-substitutable | Stand-ins inside the BC test runtime: tables (test isolation gives transactional rollback), `Library*` helpers, `LibraryRandom` | Seam stays internal | No port at the external interface |
| 3 | Remote but owned | Your own services across a network/async boundary: API pages you publish, integration codeunits, queues you own | Port at the seam | Yes |
| 4 | True external | Third-party services you do not control: Stripe, Twilio, external rate APIs | Injected port; tests provide a mock asserting the contract observed in production. Schema drift on the external side is a replan, not a refactor | Yes |

Categories 3 and 4 justify a port (AL `interface`) at the seam: the production adapter implements transport, the test adapter is an in-memory codeunit on the same interface. **The two-adapter rule** and **Internal seams stay private** (Principles, [LANGUAGE.md](../../../references/LANGUAGE.md)) govern the seam's shape.

## Phasing

**Three passes, build green and tests re-run after each.** The five lenses' detection disciplines apply throughout; this file adds only the legacy-specific ordering.

1. **Rename and tighten locality.** No behaviour change. BC vocabulary, internal helpers behind `Access = Internal`.
2. **Reshape the decision/IO split.** Split decision logic from the reads and writes around it (**Functional core, imperative shell**, [LANGUAGE.md](../../../references/LANGUAGE.md)); merge or delete pass-throughs per **The deletion test** (Principles, [LANGUAGE.md](../../../references/LANGUAGE.md)).
3. **Modernise APIs and define seams.** BC-specific upgrades carrying real platform cost: `Find('-')` → `FindSet()`, `SetLoadFields` for performance, BC v24+ `NoSeriesManagement` → `codeunit "No. Series"`. Define ports for category-3/4 dependencies. `Message()` → `Error()` flips a previously-silent branch into an error case — a behaviour change; update its assertions in the same change.

Replace, do not layer: delete unit tests on modules the refactor merged away; new tests assert observable outcomes at the deepened module's interface.

## Scope

**No silent scope expansion.** A hidden requirement or design flaw surfacing mid-phase halts to `/al-design` or `/al-refine` via `/al-steer`.
