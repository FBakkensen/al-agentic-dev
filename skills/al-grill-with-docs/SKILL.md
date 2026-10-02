---
name: al-grill-with-docs
description: Use whenever /mattpocock-skills:grill-with-docs runs on an AL/Business Central request, when such a request needs its Azure DevOps Original work item anchored with the request confirmed verbatim, or when its Trigger, Success and Minimal guarantees, and BPMN outcomes are still unsettled.
---

# al-grill-with-docs - anchor the request in its Original work item

In: `/mattpocock-skills:grill-with-docs` running on an AL request. `/mattpocock-skills:grilling` owns the interview; `/mattpocock-skills:domain-modeling` owns `CONTEXT.md`, ADRs, and when to offer one. This addition adds the Azure DevOps anchor, the process questions, and the BC deltas to the glossary. Every work-item read and write follows the tracker text that the `## Agent skills` block's issue tracker line points to.

## The anchor

Before the first round, anchor the Original work item. A request that arrives on a Feature, Bug, or PBI names its id; read that item. A request that arrives on none gets a new Original work item in the backlog project the `## Agent skills` block's issue tracker line names; tell the user so, and create it with the request block's write.

## The request block

Before the first write to the Original work item, show the exact request block and ask the user to confirm it. Keep every non-sensitive word verbatim; replace credentials, tokens, private keys, secret paths, and third-party personal data with `[REDACTED: <reason>]`. The title may become a concise business outcome.

Write the confirmed block first, under `Problem Statement`, in the spec field the tracker text names. Every later write, `/mattpocock-skills:to-spec`'s included, goes around that block and leaves it untouched.

## The process questions

Once the anchor stands, these join the frontier. Model what the business observes; publishers, subscribers, and codeunits are implementation, not process.

- **Trigger:** the business event that starts the process.
- **Success guarantee:** what is observably true on the successful path.
- **Minimal guarantee:** what remains true on every stopped or failed path.
- **BPMN paths:** every path from the Trigger through each gateway to a named outcome the business observes. Every gateway is exhaustive or carries a default.
- **Adjacent standard behavior:** which standard BC behavior next to the request must keep working.

## The glossary in AL

`CONTEXT.md` follows `/mattpocock-skills:domain-modeling`'s format with the BC deltas in [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md).

Every BC object, table, field, procedure, event, or enum name written into `CONTEXT.md` or an ADR comes from a lookup in this session.

## Close

The pass ends when the Original work item holds the confirmed request first under `Problem Statement`, and the Trigger, both guarantees, and every BPMN path to its named outcome are settled with the user. At every exit:

▶ haiku · /al-commit the complete worktree — CONTEXT.md, ADRs, and the rest → commit hashes and subjects, remaining worktree
