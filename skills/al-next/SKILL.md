---
name: al-next
description: Use when a frontier bullet has landed and the next move needs choosing.
---

# al-next — the gate between loops

One conversation, five moves, always with you: agents draft the material; the conversation is never skipped. The frontier lives in Azure DevOps work items with native blocking links, worked through the azure-devops MCP work-item tools; a repo without that wiring degrades to `docs/frontier.md` — one bullet per line with its state and `after:` edges — named second-class, because edges drift in files and ADO is the home when wired. The tracker tax lands here: every create, resolve, split, and re-link is this skill's work, never the developer's. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Connect the dots

Ask one substantive question per message. Before it, name the earlier answers and verified facts that cause or constrain it, translated from tactical names into business concepts and relationships. Use one compact text diagram or table when flow, grouping, sequence, boundaries, ownership, or competing consequences are easier seen than described. Explain why the decision comes next. Each option states what changes, what stays possible, and where responsibility lands, plus material risk or reversibility when relevant; mark the recommendation. Exact AL names are secondary coordinates when they help locate, distinguish, or verify something.

## 1 · The capsule

Open with where we are: the store in use, the bullet that landed, the receipts since the last transition — the bullet's work-item comments where ADO is wired, `.output/receipts/` always — and one concrete next move. Branches and PRs are verified live with git and gh, never recalled.

## 2 · Show what now exists

The BC-anatomy delta since the last transition — objects touched, events published and subscribed, schema changes, the flow in pattern terms — every claim quoting the diff it comes from. When the shape changed, al-visualize draws it as boxes and connections.

## 3 · Reconcile the living design

The design document — `docs/design.md` — is the user's window into the code, kept truthful every loop. Where the design says X and the code does Y: update the design, or fix the code — one question per drift, answered before moving on. Design diffs, never code walls.

## 4 · Drill the consequential

The /al-grilling engine asks one consequential decision at a time, fed by the receipts' assumptions ledgers, the loop's surprises, and every answer already settled.

## 5 · Reshape and sharpen

Resolve the landed bullet; graduate new bullets from the fog; prune what fell out of scope; re-link the blocking edges. Then sharpen the next bullet, effort scaled to it — a trivial bullet gets one line: the test spec naming the behavior that proves it done and the cheapest decisive seam; bullet-scoped Base App precedent through al-lookup; a mini design when the bullet warrants one. The spec lives on the bullet — the work item's description in ADO, an indented block under the bullet's line in `docs/frontier.md`. A non-trivial spec goes to the rubber-duck agent before the /al-implement exit — another voice in, the user decides; the GitHub Copilot app engine ships no duck, and the close says so when the checkpoint skips.

## The exits

- ready → /al-implement, the spec riding the bullet
- a decision-class item → /al-grill-adr; a decision resolves by conversation, never by /al-implement
- too unknown → prototype first, then back through this transition
- hides a decision → /al-grill-me
- wrongly cut → /al-scope reshapes the frontier's bones
- already in the Base App → close the bullet with zero code, the cheapest implementation

## Close

Name the exit taken, the store updated, and where the spec now lives. The transition is done when the landed bullet is resolved in the store, every graduated and pruned bullet is written there, and the next bullet carries its spec.
