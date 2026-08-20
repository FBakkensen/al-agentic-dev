---
name: al-visualize
description: "Draw the BC-anatomy delta — objects, events, and flows as boxes and connections — on the GitHub Copilot app's side-panel canvas. Invoked by al-next when the shape changed, or directly for a drawn view of any landed change or settled picture."
---

# al-visualize — boxes and connections

The reader is the architect steering agents: show the product's shape, never the work. The content is BC anatomy — objects in BC shapes (master data, documents, journals, posting, entries), the calls, events, and flows between them — drawn when the shape changed, skipped when it did not. A procedure or codeunit name alone is not information; it means something with its context and connections visible. [SURFACE.md](SURFACE.md) is the artifact contract: layers, furniture, pictures. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Ground every fact

Every BC object, table, field, procedure, event, enum value, or dialog text shown is confirmed by a lookup in the current session, never recalled. A fact nobody can trace to something real is decoration and gets cut.

## Render and present

Open the surface beside the chat with open_canvas: the editor canvas, scope `workspace`, one stable instance per topic, the full artifact traveling in the open call — the artifact is virtual to the app, never a repo file, and an update re-opens the same instance with the new content. Open at the essence and disclose detail on demand — the reader scrolls into depth, per the contract. The visual craft belongs to the impeccable skill the GitHub Copilot app bundles — no design rules live here. The bare terminal CLI ships neither the canvas nor impeccable: state the delta as text in the reply and continue — no error raised, no file written.

## Close

A surface is a session artifact and leaves nothing behind. Report what the surface showed back into the flow that invoked it — al-next's delta move, or the user's direct ask — and the caller owns what happens next.
