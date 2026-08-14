---
name: al-visualize
description: "Render what a run settled or landed as a read-only steering surface on the GitHub Copilot app's side-panel canvas. Use when a pipeline skill puts a decision to the user that turns on a picture, or when a pipeline skill closes and its settled artifact or landed change goes to the user drawn."
---

# al-visualize — the steering surface

The reader is the architect or PM steering agents: the surface gives them enough of the product to rule without reading every line. One self-contained markdown artifact per moment, composed by you directly — no renderer, no build step. [SURFACE.md](SURFACE.md) is the artifact contract: layers, furniture, pictures. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

## Show the product, never the work

Every layer answers one of four questions about the product — what changed, why, what it costs later, what needs the reader — and the moment picks which is loud. Agent effort — passes, commits, build counts, file lists — compresses into the final layer behind one drill. Dialog and error texts appear verbatim, in the product's own words. Cost-later rides reversibility: each call the run took or asks carries cheap, moderate, or hard to undo, and the hard ones are the loud ones.

## Two tiers

The caller names the moment and the tier; this skill alone picks the pictures.

- A **steering surface** — the full four-layer artifact of [SURFACE.md](SURFACE.md) — carries a settled artifact, a landed feature or slice, or a mid-run decision.
- A **receipt** — the glance plus the work drill, a mechanism section only when the change carries one worth drawing — carries a routine green: verdict line, the honest product delta, the work collapsed.

## Ground every fact

Every BC object, table, field, procedure, event, enum value, or dialog text the surface shows is confirmed by a lookup in the current session, never recalled. A fact nobody can trace to something real is decoration and gets cut.

## Present and settle

Open the surface beside the chat with open_canvas: the editor canvas on the side panel, scope `workspace`, the artifact created with the full surface as its content, the file navigator hidden, one stable canvas instance per topic. Then interview the open decisions in chat, one question per message, each naming its call's stable ID and its lettered options. As each answer lands, the open call becomes a settled one: re-open the same canvas instance with the full updated surface, which replaces the panel's content — the artifact is virtual to the app, so content travels in the open call, never through file edits — and the user answers every remaining question with the current truth in view. The surface closes as the approved picture.

In a terminal CLI session, where open_canvas is absent, state the finding as text in the reply and continue — no error raised, no file written.

## Export once

A surface is a session artifact and leaves nothing behind — no repo file, close surfaces, receipts, and quiz anchors included. Approval is export: the approved surface is written once, one self-contained file, into the session files area. The close hands the caller one line naming that file and the owning work item; the attachment of the file to the work item happens in /al-routing with the caller's outcome.

## Close

Report the settled decisions, the export line, and anything left open back into the flow that invoked the surface; the caller owns what happens next, and any task state it implies is the caller's outcome to hand to /al-routing. Invoked directly by the user, close naming what the surface settled, then /al-next.
