---
name: al-test-design
description: Use when an executable User Story has agreed behavior and needs a reviewable AAA test specification before AL implementation.
---

# al-test-design - specify the proof

In: the executable Original User Story, or a child User Story and its Original User Story. Read the executable item's `Behavior` when present and the Original User Story's Trigger, Success guarantee, Minimal guarantee, and module contracts. This pass chooses how tests prove the behavior. It writes no AL code.

## Connect the dots

Treat the interview as a decision tree. Resolve facts from the work items, workspace, and lookup before asking. Ask only a decision whose prerequisite facts and earlier choices are settled.

Before each substantive question, rebuild the situation from the affected Gherkin scenario, Original User Story guarantees, module contract, verified platform behavior, and earlier answers. Show the current scenario-to-case map and the gap that causes the question; use one compact text diagram or table when the relationship is easier seen than described. Explain why this decision comes next.

Each option states which Arrange, Act, Assert, or Proof changes, what remains provable, and where proof responsibility lands, plus material risk or reversibility when relevant. Put the recommendation first, mark it, and give the reason. Use the answer to revise the map before choosing the next question.

Ask one substantive question per message. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Choose the seam

Test through the smallest caller-visible module interface that proves the Gherkin behavior. Do not split tests by private procedure or internal object. A deep module's internals may change while its contract stays green.

Before proposing cases, search the repository for existing proof by affected module interface, objects, business terms, fixtures, and assertions:

▶ mechanical · task · inventory the existing proof for the affected interface, objects, and business terms → every test procedure and shared helper the changed Gherkin paths need, with paths

Widen the brief and dispatch again until every path's current proof is known; leave unrelated behavior out.

Design that proof set as if all current requirements had existed when its tests were first written. Keep, reshape, combine, split, or replace existing tests; add a test only for a distinct remaining case. The final set must not preserve requirement history through layered or overlapping tests.

Confirm every Business Central object, table, field, action, procedure, event, enum value, and dialog text through lookup in this session. Reach for standard test libraries and fixtures before inventing helpers:

▶ mechanical · task · standard test libraries and fixtures for the named objects → library and fixture names with paths

## Write AAA cases

Add `## Test specification` to the executable User Story's Acceptance Criteria, after `## Behavior` when both are present. Start with a `Current-to-final proof map`: for each existing or final test, name the existing test procedure or `none`, the business behavior already proved, its final AAA case or cases, and `keep`, `reshape`, `combine`, `split`, `replace`, or `add`. Every existing proof stays mapped unless the current requirement explicitly replaces it. Each case has:

- **Arrange:** required business data, setup, permissions, and starting state.
- **Act:** one verified caller-visible action.
- **Assert:** observable outcomes with independently derived expected values.
- **Proof:** unit, integration, or Web Client walkthrough.

One Gherkin scenario may require several AAA cases. Every Gherkin scenario maps to at least one case, and every applicable Trigger-to-outcome path, business branch, boundary, guarantee, and meaningful failure path appears in the map.

Keep production object layout, private seams, helper design, and production implementation out. Name exact expected records, field values, errors, notifications, and side effects where the platform contract supports them.

## Review with the user

Show the scenario-to-case map before saving it. The user reviews the seam, missing cases, expected values, and proof level. Revise the work-item section until every case is accepted.

## Close

The pass ends with a reviewed `Test specification` after any `Behavior` section in the executable User Story's Acceptance Criteria and no separate test work item. If Azure DevOps work-item tools are unavailable, show the exact section and stop without creating a substitute record. Otherwise name the reviewed item and hand it to /al-implement.
