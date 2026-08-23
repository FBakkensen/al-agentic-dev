---
name: al-grill-adr
description: Use when a fresh AL/Business Central feature idea needs its original Azure DevOps Feature anchored, domain vocabulary settled, or hard-to-reverse business rules recorded.
---

# al-grill-adr - anchor the feature

In: a fresh user request, with an Azure DevOps Feature when one already exists. Establish that Feature before downstream design. If Azure DevOps work-item tools are unavailable, show the exact Feature fields needed and stop; no substitute design file becomes another source of truth.

Before publication, show the exact `Original request` block and ask the user to confirm it. Preserve every non-sensitive word verbatim; replace only credentials, tokens, private keys, secret paths, or third-party personal data with `[REDACTED: <reason>]`. The title may become a concise business outcome.

Ask one substantive question per message. Before it, name what the answer will lock in, then name the earlier answers and verified facts that cause or constrain it. Use one compact text diagram or table when relationships are easier seen than described. Each option states what changes, what stays possible, and where responsibility lands; put the recommendation first and mark it. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Settle the domain

- A fact is answered from the workspace or official BC documentation, not asked.
- A strategic decision is asked. Record project vocabulary in `CONTEXT.md` and hard-to-reverse business rules in accepted ADRs.
- A tactical decision is made and named in one line so the user can override it.
- Write each settled answer immediately. Open decisions stay in the Feature conversation; they do not become work items.

Ask which term means two things, which concrete BC scenario forces the boundary to be precise, which adjacent standard behavior matters, and where the requested behavior disagrees with the code. Every BC object, table, field, procedure, event, or enum name written into `CONTEXT.md` or an ADR comes from a lookup in this session.

## When a rule earns an ADR

Offer an ADR when the decision is hard to reverse, surprising without context, has a real alternative, and governs business behavior. Architecture and data shape belong to /al-design.

## Close

The pass ends when the original Feature exists, its publishable request is confirmed and preserved, and every surfaced domain question is answered, parked in the Feature conversation, or ruled out. Commit `CONTEXT.md` and accepted ADRs with a plain descriptive message at every exit. Continue with /al-event-model.
