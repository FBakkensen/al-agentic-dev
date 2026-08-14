---
name: al-routing
description: "Use when a skill finishes work on a task and the outcome needs recording, or when a skill creating or reading pipeline work items needs the schema, the ladder, and the sweeps."
---

# al-routing — the state engine

Task state has one home: the Azure DevOps work item. Every other skill reports what happened in plain words and invokes `/al-routing`; the transitions, the derivations, and the open moves are decided here, and no skill writes task state to a repo file. Two preconditions, and a stop naming the missing one: the Azure DevOps work-item tools are available — see the README note — and the binding resolves: `al-ado.json` at the consumer repo root names `organization`, `project`, `rootWorkItemId`, and `areaPath` (shipped defaults in `config/al-ado.json`; `/al-scope` and `/al-next` read the same binding). Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## The schema

The tree hangs under the bound root — the customer's root work item, read-only for the pipeline, forever. Reads go through `azure-devops-wit_work_item` and `azure-devops-wit_query`; writes through `azure-devops-wit_work_item_write`, comments through `azure-devops-wit_work_item_comment_write`, links through `azure-devops-wit_work_item_link_write`, attachments through `azure-devops-wit_work_item_attachment_upload` and `azure-devops-wit_work_item_attachment_link`.

- `Design` User Story — the architecture and event model in its Description; the feature review verdict lands here as a comment.
- One User Story per vertical slice — Description carries the slice contract, `Microsoft.VSTS.Common.AcceptanceCriteria` the behaviour checks in `event-model.md` vocabulary.
- One Task per pipeline task, child of its slice story. The ops bracket sits under the Design story: provision → clone-bcapps → clone-bcquality chained by Predecessor links, breaking-change last, Successor of the feature's final task.

On every item: the Description is the contract only — behaviour, planned AAA cases, ceiling prose, precedent verdict — edited only on a scope change, a `✏️ Contract:` comment beside every edit. Comments are the append-only run log (grammar below). Attachments carry junit and coverage files and approved canvas snapshots. Every dependency edge is a Predecessor/Successor link. Never write the root item, `Custom.Release*`, or any estimate field.

Tags, all `al-`prefixed: `al-pipeline` on every pipeline item; kind — `al-technical` / `al-verify` / `al-provision` / `al-breaking-change`; tier — `al-mechanical` / `al-standard` / `al-frontier`, re-tiered by swapping the tag; slice — `al-slice-<slug>`; precedent — `al-reused` / `al-required`; `al-ceiling` on a task carrying a deliberate shortcut; `al-question`, transient, only while a question waits.

Identity is the work item ID. A commit landing task work opens with `AB#<id>`; the feature branch carries the root id (`feature/ab<rootId>-<slug>`), a slice branch its story id (`slice/ab<sliceId>-<slug>`).

## The ladder

The six Task states carry the rungs; nothing else encodes progress. New always means scoped, and the arrow names the skill that moves the work.

| Kind | New | Active | Testing | Resolved | Closed |
|---|---|---|---|---|---|
| `al-technical` | → `/al-refine` | refined → `/al-implement` | implemented → `/al-refactor` | refactored, or a deliberate early user close | slice review clean |
| `al-verify` | → `/al-refine` | planned → `/al-user-verification` | recording sealed or walk in flight → `/al-user-verification` resumes from the newest `🚶 Walk:` comment | walk clean, waived, or absorbed | slice review clean |
| ops | → its own skill: `/al-provision`, `/al-clone-bcapps`, `/al-clone-bcquality` in chain order; `/al-validate-breaking-changes` | — | — | its run came back green | feature close |

Blocked is written, never polled: creation opens an edge-held task Blocked and an open-edged one New; when a task resolves, every direct Successor whose Predecessors are now all Resolved or Closed flips Blocked → New. A cross-slice edge is satisfied when the predecessor slice's story is Closed. A run that stopped on an open question moves its task to Blocked, adds `al-question`, and writes one comment naming the question; the answering report removes the tag and restores the state the question interrupted. A red ops run moves its task to Blocked with one comment naming what failed; the repair report restores it.

## Clean-gate receipt

A completed full gate reports the `HEAD` committed immediately from its unchanged green tree; record it as a `✅ Gate: <40-character SHA> (full)` comment on the outcome task. A receiver accepts the newest receipt in its scope only on a clean tree, when the recorded commit is an ancestor of `HEAD` and `git diff <commit>..HEAD` is empty. A non-full profile, a missing or unreachable commit, or any other path requires a new full gate. No skill finishes red, so no invalid receipt is written.

## Gates

- **Scoping / re-scope** — no `al-pipeline` item under the bound root, or an `architecture.md` reshaped since the tree settled, → `/al-scope` before anything routes. While the provision chain is not fully Resolved, its next rung is the only move.
- **Slice review** — every Task in a slice story Resolved and the story not Closed → `/al-code-review` on the slice.
- **Feature review** — every slice story Closed and the breaking-change task still New → feature `/al-code-review` before it runs.
- **All shipped** — every story reviewed and every ops task Resolved → `/al-sync-main`, then the user opens the PR. Branch synced and PR open → close every remaining item; the feature is done.

## Outcome → transition

One state write per reported outcome, plus one `➡️ Routing:` comment on the item naming old → new and the next move:

| The reported outcome | Transition |
|---|---|
| `/al-refine` wrote the proof into the Description | Task → Active; swap the tier tag to the class its report names |
| `/al-implement` reached green outside a repair episode | Task → Testing; record its `✅ Gate:` receipt |
| `/al-refactor` closed its pass — reshape landed, or every dimension clean | Task → Resolved; replace the receipt after a reshaped green, otherwise retain the incoming one |
| `/al-user-verification` sealed the slice's last recording | one `🚶 Walk:` comment; the task stays Testing |
| `/al-user-verification` finished the walk clean | Task → Resolved |
| `/al-code-review` cleared the slice | `⚖️ Review:` comment on the story; the story and its Tasks → Closed; record its latest durable full gate when it changed the tree |
| `/al-code-review` cleared the feature | `⚖️ Review:` comment on the Design story |
| an ops skill ran green | its Task → Resolved |
| the user closes a task early — a waived or absorbed verify walk included | Task → Resolved; the closing comment names the cover — the pinning cases and prior walk, or the carrying task. A waiver closes the walk, never the slice's review gate |
| the user retired a task at `/al-scope`'s reconcile | the item → Removed |
| `/al-sync-main` synced and the user's PR is open | every remaining item → Closed |

Four outcomes transition nothing: `/al-scope` landed the tree → present the opening move. A run whose outcome is a work item it created — a change request at the review gate, a quiz follow-up — → the new item is the move, and any gate it re-holds re-fires once it settles. A repair episode — the fix green, its repair-scope review, a verification run paused on a fail — stays inside its episode: a durable full green records or replaces its receipt, and the run resumes at the failed scenario. A declined task's stop line in chat is the whole record. Any other unmatched outcome goes back to the reporter as one question rather than being guessed into a transition.

## The comment log

One comment per event, the lede greppable: `🔎 Researched:` a grounding citation · `🏛️ Precedent:` a `.bcapps/` verdict · `⬆️ Push-up:` a layer justification · `✅ Accepted:` a survivor ruling · `🔴→🟢 <CaseName>:` a red→green receipt · `✅ Gate:` the full-gate receipt · `🧬 Mutation:` a mutation proof · `⚖️ Review:` a review verdict · `🛠️ Repair:` a repair episode opened or closed · `🚶 Walk:` a walk result or the walk's partial-run record · `✏️ Contract:` a scope change · `➡️ Routing:` a transition. One sentence per fact, the thing shown — the page, the field, the command, the number; a table in a comment stands after a blank line below its lede, or the lede renders as the table's header; an emoji outside these ledes stays out of the log.

## Leave the tree clean

After recording — transition or none — a dirty git tree is put to the user: summarize what the leftover changes do, intent rather than a file list — the user reads the chat, not the diff — deduce the work item they belong to and suggest its `AB#<id>`, listing each candidate with its reason when several fit, and ask whether to commit them too. Yes → one separate commit opening with the chosen `AB#<id>`, or a plain descriptive message when no task owns them, never folded into another commit. No → they stay uncommitted, named as the record.

## Present the moves

After recording a report — or when `/al-next` asks — sweep the tree level by level with one-hop queries, no repo file: `SELECT [System.Id] FROM WorkItemLinks WHERE (Source.[System.Id] IN (<ids>)) AND ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') MODE (MayContain)` — the root first, then each returned level, until a level returns no new ids; the schema's tree settles in two hops, and the azure-devops MCP server rejects `MODE (Recursive)`, so the level walk is the sweep. Then the dependency edges, the same one-hop shape on `'System.LinkTypes.Dependency-Forward'` over the swept task ids, then one `azure-devops-wit_work_item` batch read of State, Tags, and Title. Derive each gate above first, naming the result in one line — `Gates: <slice> review firing` or `Gates: none` — a firing gate outranks every ladder move and is presented first; a move whose gate condition the sweep does not confirm is never named. Then one line per runnable task: its id, the skill the ladder names, the model class the move wants, and what opened it, in the feature's own object and field vocabulary. A move's class is the task's tier tag, raised to frontier for `/al-refine` and `/al-user-verification`, raised to standard for `/al-refactor` and `/al-code-review`; untagged, any other move at standard. Several open → id order, naming which unblocks the most; runnable verify tasks sharing a surface and fixtures are one walk opportunity — merged at refine or walked back-to-back in one warm session, never serial refine→walk cycles. None → the one edge or gate that must settle, and who settles it. A repair-episode report skips the move list — its own path continues.

Close on the state recorded and the moves named; the session continues in the caller's flow.
