---
name: al-scope
description: Use when a Feature's accepted process and module design need cutting into one or more independently useful Vertical slices in Azure DevOps.
---

# al-scope - cut the vertical slices

In: the Azure DevOps Feature, its Trigger, Success guarantee, Minimal guarantee, BPMN outcomes, Runtime View when present, and arc42 Building Block Level 1. Synthesize from those artifacts and the conversation; do not reopen settled design.

Ask one substantive question per message. Show the candidate slices, what each user can complete, and what stays out. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Slice by outcome

Each Vertical slice delivers one useful business outcome through the full path it needs. It may cross several modules. AL objects, tests, diagrams, modules, verification, and operations are parts of a slice, never separate work items.

A slice ends at a named BPMN outcome and is small enough to implement and demonstrate in one focused run. Future or uncertain behavior stays in the Feature prose until evidence proves another executable slice.

## Keep the hierarchy shallow

- One user request creates one Feature.
- Exactly one Vertical slice creates no child; the Feature is executable.
- Two or more proven Vertical slices make the Feature their container; every slice gets one direct child User Story.
- The hierarchy stops at those User Stories.

Sequence alone does not create a dependency link. Add one only when an earlier business outcome is required before another can exist.

## Write the executable item

The Feature owns the request, process, and module design. A child Description names its one process path and points to the parent instead of copying design.

Write Gherkin Acceptance Criteria for caller-visible behavior. The scenarios start from the Trigger, cover the Success guarantee and every Minimal-guarantee path, and each reaches a named BPMN outcome. Keep AL object structure and test implementation out.

## Land the cut

Show the proposed hierarchy and Gherkin to the user. Send the complete cut to the rubber-duck agent before creation when that agent is available. The user decides the cut.

For two or more slices, create the approved User Stories and native parent links through Azure DevOps work-item tools. For exactly one, write its Gherkin on the executable Feature and create no child. If those tools are unavailable, show the exact work-item change and stop. Close with the Feature and executable item identifiers; the next executable item goes to /al-test-design.
