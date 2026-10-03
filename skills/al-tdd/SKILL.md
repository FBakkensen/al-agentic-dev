---
name: al-tdd
description: Use whenever /mattpocock-skills:tdd runs against AL code.
---

# al-tdd - AL proof for the red-green loop

In: `/mattpocock-skills:tdd` running against AL code. The entry skill owns the loop; this addition supplies its agreed seams, the AL proof set, and what red and green mean in AL. Read the executable work item, the Original work item or its child work item, for its `Behavior`, and the Original work item for its Trigger, Success guarantee, Minimal guarantee, and Building Block Level 1.

## The agreed seams

The seams `/mattpocock-skills:tdd` agrees are the AAA map and the current-to-final proof map, both tested through the caller-visible interface of a Level 1 module.

Before proposing cases, search the repository for existing proof by affected module interface, objects, business terms, fixtures, and assertions:

▶ haiku · inventory the existing proof for the affected interface, objects, and business terms → every test procedure and shared helper the changed Gherkin paths need, with paths

Widen the brief and dispatch again until every path's current proof is known; leave unrelated behavior out.

Design the proof set as if all current requirements had always existed. Keep, reshape, combine, split, or replace existing tests; add a test only for a distinct remaining case. The final set carries no layered or overlapping tests that preserve requirement history.

Standard BC test libraries and fixtures come before new helpers:

▶ haiku · standard test libraries and fixtures for the named objects → library and fixture names with paths

## Test specification

Write `## Test specification` into the executable work item's acceptance criteria, placed as the Tracker doc's "write the acceptance criteria" says, after `## Behavior` when both are present. Start with a `Current-to-final proof map`: for each existing or final test, the existing test procedure or `none`, the business behavior it proves, its final AAA case or cases, and `keep`, `reshape`, `combine`, `split`, `replace`, or `add`. Each case has:

- **Arrange:** business data, setup, permissions, and starting state.
- **Act:** one verified caller-visible action.
- **Assert:** exact records, field values, errors, notifications, and side effects, with independently derived expected values.
- **Proof:** unit, integration, or Web Client walkthrough.

Every Gherkin scenario maps to at least one case, and every Trigger-to-outcome path, business branch, boundary, guarantee, and meaningful failure path appears in the map. Production object layout and helper design stay out.

The user reviews both maps, including missing cases, expected values, and proof levels; the reviewed section is on the work item before the first red. Under `/mattpocock-skills:implement`, a reviewed `Test specification` already on the work item is the worker's agreed seam set, and a missing one is a decision only the user can take.

## Red and green in AL

`/al-build`'s gate on the affected test scope is the test run, with WARN_AS_ERROR as the repository states. A red stays red until the gate's output names its exact cause.

Apply the proof map's proof-preserving reshapes before new expectations or production changes. Account for every existing business assertion in the final cases unless the current requirement replaces it, rerun the gate green, and add no transitional test the accepted map does not retain. An unchanged test marked `keep` supplies evidence without a duplicate.

Every new or materially reshaped automated proof earns a red. Born red, it fails for the intended reason. Born green because the behavior exists, inject one compiling fault into the production site the proof targets, run its scope to red, revert the fault, and confirm green. A compile error or a failure before the assertion is not a red; if no fault forces red, strengthen the assertion until it does. A walkthrough-only case takes no automated red and goes to /al-walkthrough.

Every BC object, table, field, procedure, event, enum value, and dialog text in a case, a test, or production code is confirmed by a lookup in this session, never recalled. Green's production change keeps business writes on validated or posting paths, reuses Base App seams, and adds no AL interface with one implementation.

## Close

The pass ends when every automated case has its red evidence and the gate is green, or on the exact red cause still open. Run /al-commit at every exit when `/mattpocock-skills:tdd` ran alone. A worker under `/mattpocock-skills:implement` leaves the commit to its lead, because its lead commits each accepted scenario as a checkpoint.
