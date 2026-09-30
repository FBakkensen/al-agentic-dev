---
name: al-scope
description: Use when an Original User Story's accepted process and module design need cutting into one or more independently useful Vertical slices in Azure DevOps.
---

# al-scope - cut the vertical slices

In: the Original Azure DevOps User Story, its Trigger, Success guarantee, Minimal guarantee, BPMN outcomes, Runtime View when present, and arc42 Building Block Level 1. `Original` names its role in this workflow, not the top of the Azure DevOps hierarchy; structural parents remain unchanged and out of scope. Synthesize from those artifacts and the conversation; do not reopen settled design.

Ask one substantive question per message. Show the candidate slices, what each user can complete, and what stays out.

## Slice by outcome

Each Vertical slice delivers one useful business outcome through the full path it needs. It may cross several modules. AL objects, tests, diagrams, modules, verification, and operations are parts of a slice, never separate work items.

A slice ends at a named BPMN outcome and is small enough to implement and demonstrate in one focused run. Future or uncertain behavior stays in the Original User Story prose until evidence proves another executable slice.

## Keep the hierarchy shallow

- One user request creates one Original User Story.
- Exactly one Vertical slice creates no child; the Original User Story is executable.
- Two or more proven Vertical slices make the Original User Story their container; every slice gets one direct child User Story.
- The hierarchy stops at those User Stories.

Sequence alone does not create a dependency link. Add one only when an earlier business outcome is required before another can exist.

## Write the work items

The Original User Story owns shared design. With one slice, its Description also carries the slice-specific detail. With several slices, each child Description names its one process path, carries only slice-specific design, and points to the Original User Story instead of copying shared design.

Use Description sections in this order when present: `Problem`, `Expected outcome`, `Scope`, `Process contract`, `Business process`, `Runtime View`, `Building Block View`. Keep each diagram with the text that explains it.

In Acceptance Criteria, `Behavior` precedes `Test specification` when both are present. Either section may be omitted when it does not fit the item; absence has no prescribed meaning. Write `Behavior` as valid fenced Gherkin using `Scenario`, `Given`, `When`, and `Then`, with `Background`, `And`, `But`, and `Scenario Outline` when useful. Keep AL object structure and test implementation out of Gherkin.

## Land the cut

Show the proposed hierarchy and Gherkin to the user. The user decides the cut.

For two or more slices, create the approved child User Stories and native parent links through Azure DevOps work-item tools. For exactly one, keep the Original User Story executable and create no child. If those tools are unavailable, show the exact work-item change and stop. Close with the Original and executable User Story identifiers; the next executable item goes to /mattpocock-skills:tdd.
