---
name: al-to-spec
description: Use whenever /mattpocock-skills:to-spec runs in an AL repository, or when an Original work item's settled request needs its process contract, BPMN process map, or Building Block View Level 1 written into its spec.
---

# al-to-spec - the spec in the Original work item

In: `/mattpocock-skills:to-spec` running on an Original work item whose request `/al-grill-with-docs` confirmed. The entry skill owns the spec's steps and headings; this addition adds where the spec lands and which AL sections it carries. Every work-item read and write follows the tracker text the `## Agent skills` block's issue tracker line points to. Model what the business observes; AL publishers, subscribers, and private procedures are design evidence, not the business process.

## Where the spec lands

Fill the existing Original work item, never a new one. The spec goes in the spec field the tracker text names, under the entry's headings unchanged: Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope, Further Notes. The confirmed request under Problem Statement stays untouched.

## Under Solution

`Process contract` (Trigger, Success guarantee, Minimal guarantee), then `Business process`, nest under Solution. When the Base App has a comparable flow:

▶ sonnet · process precedent: how the Base App's comparable flow posts, validates, and errors, read in .bcapps/release → step table with sources

Use BPMN 2.0 for roles, actions, gateways, records, exceptions, decisions, and named outcomes. Every gateway is exhaustive or carries a default. Every path reaches a stable named end event that `/mattpocock-skills:to-tickets` can map to Gherkin later. Follow [BPMN.md](BPMN.md) and write the editable BPMN source.

At the entry's user check:

▶ haiku · render SVG, PNG, and the local process review HTML from the BPMN source, with the BPMN.md render procedure passed in full → SVG, PNG, HTML paths

Show the HTML through `show_widget`, then an Artifact, then the local file. After the user's check:

▶ haiku · attach the BPMN source and PNG to the Original work item as the tracker text says → verified attachment URLs

Place the verified PNG with its explanatory text under `Business process`, as the tracker text says.

## Under Implementation Decisions

`Building Block View` Level 1 nests here, and a `Runtime View` after it when needed. At the entry's seam step, first consult `/mattpocock-skills:codebase-design` for each Level 1 module whose concept names a Base App table, document, or posting flow: its survey backs the boundary, and the module's black box records its shape and the survey's Base App precedent, an object plus file:line. Then settle Level 1 through /al-arc42:

▶ haiku · /al-arc42 the Building Block Level 1 view from the settled black boxes → HTML path, SVG and PNG paths, alt text, publishable fragments

Level 1 is settled when every important behavior has one module owner and each caller-visible interface is named. Add a Runtime View only when module call order, ownership, or a transaction boundary stays unclear after the BPMN map, and build it the same way:

▶ haiku · /al-arc42 the Runtime View from the settled sequence → HTML path, SVG and PNG paths, alt text, publishable fragments

Every local image published to the Original work item, Level 1 and Runtime View included, goes through:

▶ haiku · attach the Level 1 and Runtime View PNG and SVG to the Original work item as the tracker text says → verified attachment URLs

Place each verified PNG with its explanatory text under its section, as the tracker text says.

## Grounding

Every Business Central object, field, action, event, enum value, or dialog text shown is confirmed through lookup in this session. Speak BC on every line.

## Close

The pass ends when the Process contract, every BPMN path, and the Building Block View agree with the confirmed request, and, when the Base App has a comparable flow, its sourced step table is in hand. No `docs/` copy of the spec is created. At every exit:

▶ haiku · /al-commit the complete worktree → commit hashes and subjects, remaining worktree
