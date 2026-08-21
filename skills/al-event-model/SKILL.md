---
name: al-event-model
description: The living event model — who publishes, who subscribes, which business events fire on the journey through posting. Open it when the eventing shape matters, and whenever understanding changes.
disable-model-invocation: true
---

# al-event-model — the eventing picture

A human conversation about who raises what and who listens: publishers and subscribers, integration events and business events, the journey a document takes through posting, and the moments other code may hook. BC vocabulary binds every line — Post not submit, Ledger Entry not transaction, codeunit not class. Every event, publisher, and object named is verified through lookup — the Base App's own events first; an invented event earns its place only where the Base App leaves no seam. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Connect the dots

Ask one substantive question per message. Before it, name the earlier answers and verified facts that cause or constrain it, translated from tactical names into business concepts and relationships. Use one compact text diagram or table when flow, grouping, sequence, boundaries, ownership, or competing consequences are easier seen than described. Explain why the decision comes next. Each option states what changes, what stays possible, and where responsibility lands, plus material risk or reversibility when relevant; mark the recommendation. Exact AL names are secondary coordinates when they help locate, distinguish, or verify something.

## Update immediately

The model changes the moment understanding changes, never batched: a discovery lands in the document before the conversation moves on. Drift between the model and the conversation is the failure this rule exists to kill.

## The living model

The artifact is `docs/event-model.md`, committed with a plain descriptive message: the journey — document to posting to entries — with the events that fire at each step, each publisher with its subscribers, and the seams left deliberately open. A mid-feature discovery legally rewrites it; re-entry from al-next's drill is a normal move.

## Pass end

Hand the pass's model delta to the rubber-duck agent — another voice in, the user decides. The GitHub Copilot app engine ships no duck: the pass says the checkpoint skipped. The session continues in the conversation that opened it.
