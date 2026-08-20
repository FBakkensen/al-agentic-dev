---
name: al-walkthrough
description: "Walks a landed slice in the running Business Central Web Client through the business-central-mcp tools — structured reads over the client's own protocol, observed vs expected reported verbatim per scenario, closing with a hand-reproduction recipe. Use when the user asks to walk the slice, run a walkthrough, try it in the web client, or show that it works."
---

# al-walkthrough — walk the slice in the Web Client

In: the slice's scenarios, drawn from its spec — the Azure DevOps work item or frontier bullet — or from the target the user names. Propose the scenario list and get the user's confirmation before walking. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

The walk drives the Web Client over its native WebSocket protocol through the business-central MCP server's tools: bc_search_pages (Tell Me), bc_open_page, bc_read_data, bc_write_data, bc_execute_action, bc_lookup (assist-edit), bc_respond_dialog, bc_navigate, bc_wizard_navigate, bc_run_report, bc_query, bc_close_page, bc_list_companies, bc_switch_company. When these tools are absent from the session, stop and point at the al-agentic-dev README's "Web Client walkthrough" section — the one-time user-level install lives there.

## Container first

The walk runs against the branch's agent container with the current code on it: run /al-build first for the container and a clean publish. `Error [AUTHENTICATION_ERROR]: Authentication failed: fetch failed` from a bc_* tool almost always means that container is not up, not that the credentials are wrong; bring it up through /al-build and retry.

## The walk

One scenario at a time, through the bc_* tools only. Read the real field values and report observed vs expected verbatim per scenario. A result that contradicts the scenario stops that scenario and lands as a finding — the user rules on it; the walk never repairs code and never moves work-item state. Every BC page, field, action, or dialog text shown or judged is confirmed by a lookup in the current session, never recalled, and BC vocabulary binds every line — Insert not create, Post not submit, Validate not check, Ledger Entry not transaction.

Use one sentence before the first tool call; update only on an important finding or a change of direction; put the outcome first when finishing.

## Close

Pass or fail per scenario, in chat. Then the hand-reproduction recipe: numbered human Web Client steps derived from the walked path — "Open <page> via Tell Me → set <field> → choose <action> → you should see <value>". The recipe lands in chat always, and as a comment on the work item when Azure DevOps tooling is wired — never in a file. The walk is done when every confirmed scenario carries a verdict or a stopping finding and the recipe covers the walked path.
