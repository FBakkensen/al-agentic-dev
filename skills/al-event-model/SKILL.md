---
name: al-event-model
description: Use when an Azure DevOps Original User Story needs its business process contract, BPMN process map, or arc42 Runtime View defined or revised.
---

# al-event-model - map the business process

In: the Original Azure DevOps User Story and the settled domain vocabulary. Read the request verbatim. Model what the business observes; AL publishers, subscribers, codeunits, and private procedures are design or implementation evidence, not the business process. If Azure DevOps work-item tools are unavailable, show the exact Description update and attachment set, then stop without creating a substitute record.

Ask one substantive question per message. Connect it to earlier answers and verified facts, and show the affected path when a picture makes the choice clearer.

## Process contract

When the Base App has a comparable flow:

▶ sonnet · process precedent: how the Base App's comparable flow posts, validates, and errors, read in .bcapps/release → step table with sources

Extend the Original User Story Description with `Process contract`, followed by `Business process`. Keep existing sections in this order when present: `Problem`, `Expected outcome`, `Scope`, `Process contract`, `Business process`, `Runtime View`, `Building Block View`.

- **Trigger:** the business event that starts the process.
- **Success guarantee:** what is observably true on the successful path.
- **Minimal guarantee:** what remains true on every stopped or failed path.

## BPMN process map

Use BPMN 2.0 for roles, actions, gateways, records, exceptions, decisions, and named outcomes. Every gateway is exhaustive or carries a default. Every path reaches a stable named end event that /mattpocock-skills:to-tickets can map to Gherkin later.

Follow [BPMN.md](BPMN.md). Create the editable BPMN source, then:

▶ haiku · render SVG, PNG, and the local process review HTML from the BPMN source, with the BPMN.md render procedure passed in full → SVG, PNG, HTML paths

Show the HTML through `show_widget`, falling back to an Artifact, then to the local file; the user reviews it before publication.

▶ haiku · /al-azure-devops-attachments the BPMN source and PNG to the Original User Story → verified attachment URLs

Embed the verified PNG URL with its explanatory text under `Business process`. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works.

## Runtime View

Add an arc42 Runtime View only when module call order, ownership, or a transaction boundary remains unclear after the BPMN map. Use verified module and interface names. Omit it when it would repeat the process map. Then:

▶ haiku · /al-arc42 the Runtime View from the settled sequence → HTML path, SVG and PNG paths, alt text, publishable fragments

## Grounding

Every Business Central object, field, action, event, enum value, or dialog text shown is confirmed through lookup in this session. Speak BC on every line.

## Close

The pass ends when Trigger, both guarantees, every BPMN path, and any necessary Runtime View agree with the original request. The user confirms the local HTML before the Original User Story update. No `docs/event-model.md` copy is created. At every exit:

▶ haiku · /al-commit the complete worktree, work items <ids> → commit hashes and subjects, remaining worktree
