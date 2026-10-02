---
name: al-diagnosing-bugs
description: Use whenever /mattpocock-skills:diagnosing-bugs runs against AL code.
---

# al-diagnosing-bugs - the AL order of the feedback loops

In: `/mattpocock-skills:diagnosing-bugs` running against AL code. The entry skill owns the process. This addition supplies the order of its Phase 1 feedback loops: the agent builds the tightest loop first and moves to the next only when the loop before it cannot reproduce the bug, because its run shows no symptom or it cannot arrange the data or page state the bug needs.

## The loops

1. **A failing AL test through /al-build.** The agent runs the failing test through /al-build, which owns how the test runs. Done when the gate's output names that test failing on the user's exact symptom.
2. **A data read through /al-environment-data.** It reads what an environment holds, which a test cannot arrange: a record, a setup value, a Ledger Entry. The agent reads the rows the symptom concerns. Done when the rows show the wrong value or the missing record the user describes.
3. **The Web Client through /al-webclient.** It shows what a page shows or does: an action, a validation on a field, a dialog. The agent drives the page to the symptom. Done when the page's re-read shows the symptom in the page's own words.

## Grounding

The agent confirms every BC object, table, field, procedure, event, enum value, and dialog text the diagnosis names or judges, in a test, a data read, or a finding, by a lookup in this session, never from recall, and writes every line in Business Central vocabulary.

## Close

Done when one loop has gone red on the symptom and the reply names it and, for each faster loop, why it could not reproduce the bug. The agent hands that loop back to the `/mattpocock-skills:diagnosing-bugs` run as its Phase 1 loop. When none of the three reproduces the bug, the agent hands the three reasons back to that run, whose remaining ways to build a loop follow.
