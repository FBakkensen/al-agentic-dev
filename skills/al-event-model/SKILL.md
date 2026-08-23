---
name: al-event-model
description: Use when an Azure DevOps Feature needs its business process contract, BPMN process map, or arc42 Runtime View defined or revised.
---

# al-event-model - map the business process

In: the original Azure DevOps Feature and the settled domain vocabulary. Read the request verbatim. Model what the business observes; AL publishers, subscribers, codeunits, and private procedures are design or implementation evidence, not the business process. If Azure DevOps work-item tools are unavailable, show the exact Description update and attachment set, then stop without creating a substitute record.

Ask one substantive question per message. Connect it to earlier answers and verified facts, and show the affected path when a picture makes the choice clearer. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Process contract

Extend the Feature Description with:

- **Trigger:** the business event that starts the process.
- **Success guarantee:** what is observably true on the successful path.
- **Minimal guarantee:** what remains true on every stopped or failed path.

## BPMN process map

Use BPMN 2.0 for roles, actions, gateways, records, exceptions, decisions, and named outcomes. Every gateway is exhaustive or carries a default. Every path reaches a stable named end event that /al-scope can map to Gherkin later.

Follow [BPMN.md](BPMN.md). Create the editable BPMN source, render SVG and PNG from that source, and write the local process review HTML. The user reviews the HTML before publication.

Attach the BPMN source and PNG to the Feature and embed the PNG in its Description. Detect attachment upload separately from work-item editing; when upload is unavailable, show the two artifact paths and exact manual attach steps, then resume after the user supplies the attachment URLs.

## Runtime View

Add an arc42 Runtime View only when module call order, ownership, or a transaction boundary remains unclear after the BPMN map. Use verified module and interface names. Omit it when it would repeat the process map. Ask /al-arc42 to apply the official format and create the local architecture review HTML.

## Grounding

Every Business Central object, field, action, event, enum value, or dialog text shown is confirmed through lookup in this session. Speak BC on every line.

## Close

The pass ends when Trigger, both guarantees, every BPMN path, and any necessary Runtime View agree with the original request. The user confirms the local HTML before the Feature update. No `docs/event-model.md` copy is created.
