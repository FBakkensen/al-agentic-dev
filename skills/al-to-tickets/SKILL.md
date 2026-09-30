---
name: al-to-tickets
description: Use whenever /mattpocock-skills:to-tickets runs, or when an Azure DevOps Original work item's agreed process and design are ready to become executable work items, each slice ending at a named BPMN outcome.
---

# al-to-tickets - slices that end at BPMN outcomes

In: `/mattpocock-skills:to-tickets` running on an Original work item, with its Trigger, Success guarantee, Minimal guarantee, BPMN outcomes, Runtime View when present, and Building Block View Level 1. `Original` names a role in this workflow, not the top of the Azure DevOps hierarchy. The entry skill owns the quiz and the publishing, and the tracker text in `docs/agents/issue-tracker.md` turns its edges into native parent and blocking links. This addition adds where an AL slice ends and what each work item carries.

## Cut at BPMN outcomes

A slice ends at a named BPMN outcome. It delivers that business outcome through the full path it needs, across as many modules as that takes; AL objects, tests, diagrams, and verification are parts of a slice, never work items of their own. Behavior that is future or uncertain stays in the Original work item's prose until evidence proves another slice.

A blocking link is made only when a slice needs an earlier slice's business outcome to exist. Sequence alone makes none.

At the entry's quiz, each proposed ticket also shows the BPMN outcome it ends at and its `Behavior`.

## Place the slices

One slice creates no child. The Original work item stays the executable item, and its Acceptance Criteria carries the slice's `Behavior`. That write is the one change the publishing makes to the Original: `/mattpocock-skills:to-tickets` otherwise leaves the parent it slices untouched.

Several slices each get one direct child PBI under the Original work item, whether the Original is a Feature, a Bug, or a PBI.

Only those direct child PBIs are created. Every existing item stays where it is, including the Original's own structural parent.

The Original work item owns the shared design. A child's Description names its one process path, carries only what is specific to that slice, and points to the Original work item for the shared design instead of copying it.

## Write the Acceptance Criteria

Each slice carries its `Behavior` as valid fenced Gherkin in Acceptance Criteria: `Scenario`, `Given`, `When`, and `Then`, with `Background`, `And`, `But`, and `Scenario Outline` when useful. Gherkin speaks the business process; AL object structure and test implementation stay out of it.

`Behavior` precedes `Test specification` when both are present. Either section may be omitted, and its absence has no prescribed meaning. The two rules read together: every slice carries `Behavior`, while a container Original holds the shared design instead of one slice's `Behavior`, and `Test specification` arrives later through `/mattpocock-skills:tdd`.

The cut is done when every slice's BPMN outcome sits on exactly one executable work item, the Original for one slice or one child PBI each for several, and each of those items carries its `Behavior`.
