---
name: al-event-model
description: Settle the feature's user-facing journey on the Design User Story — Role, Action, Business Event, View, Status. Run it after al-grill-adr on user- or API-facing features; backend-only skips it.
disable-model-invocation: true
---

# Journey → the Design story

Settle the journey at what an external observer sees, so architecture does not re-litigate user-side picks. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch — then proceed.

Preconditions, a stop naming the missing one: `CONTEXT.md` and the domain ADRs are settled — `/al-grill-adr` first; the feature has a human or API surface — Job Queue, install/upgrade, or scheduled-task work goes to `/al-design`; the Azure DevOps work-item tools are available — see the README note; the `al-ado.json` binding resolves; `.bcquality/knowledge-index.json` is present — missing → `/al-clone-bcquality`.

The journey lives on one Design User Story under the bound root. Git keeps `CONTEXT.md` and `docs/adr/` only. On the first settled answer, create that story through `azure-devops-wit_work_item_write` under the binding's `areaPath`, child of the root, tagged `al-pipeline`, titled `Design: <journey>`, opening state per `/al-routing`'s schema. Every later answer rewrites the same Description. Overview stays visible: Goal, happy path grouped by Role, two stop paragraphs — never a five-column table. Journey slots sit in a `<details>` fold-out whose summary is `Journey slots`. Ugly HTML mid-interview is allowed; a second copy is not. No canvas, no session markdown copy, no `/al-visualize`.

The run continues on `feature/ab<rootId>-<slug>` — root id from the binding, slug kebab-case of the journey:

- No branch for this feature yet → create `feature/ab<rootId>-<slug>` off the default branch.
- The session sits on its own working branch with another name → rename it to `feature/ab<rootId>-<slug>`, through the rename_branch tool where the session provides it, with plain `git branch -m` otherwise.
- Never rename the default branch.
- Never rename a branch already `feature/ab<rootId>-<slug>`-shaped — its slug binds it to this Design story; a mismatch with this run's journey is a stop put to the user.
- A rename that fails is a stop put to the user, never a quiet note.

Every BC name that lands in a slot comes from a lookup this session: grep the workspace, or Microsoft's BC docs through the microsoft-learn tools (microsoft_docs_search, microsoft_docs_fetch). Recall is fiction. Where `.bcapps/` is present it is gitignored: point grep at `.bcapps/` explicitly and view its files for BaseApp events.

BCQuality is the gitignored rule set for slots that carry BC mechanics. `.bcquality/knowledge-index.json` is one minified line — parse it as JSON. Point grep at `.bcquality/` explicitly. Narrow to the domains a step touches — events above all, plus ui and web services where the View sits there — and read those articles before settling the step. Where an article moved a decision, name it on that step's line; elsewhere stay silent.

The timeline is a naming authority: downstream skills derive procedure, event publisher, and enum value names from its Actions, Business Events, and Statuses. A concept entering one of those three slots with no `CONTEXT.md` term and no BC baseline term is a vocabulary gap: settle it as one question, land the term in `CONTEXT.md` per its format, and name the slot from it — Roles and Views stay in the user's own words.

## The five slots

- **Role** — the acting persona: a human business role (a standard BC persona such as Order Processor or Accountant where one fits), an external API consumer or publisher, or a BC system actor such as the Posting Engine. A plain business role name carries the slot when no standard persona matches.
- **Action** — user-meaningful verb plus object: *Release Sales Order*, *Approve Override*. Where it overlaps BaseApp, take BC's own verbs — Insert, Modify, Delete, Post, Validate, Release, Reopen, Apply, Reverse.
- **Business Event** — the past-tense business fact the Action produced: *Sales Order Released*, *Credit Limit Breached*.
- **View** — the surface the observer reads and where it sits: *Sales Order page*, *Allocation Ledger Entries, drill-down from the Posted Sales Invoice*, *API response carries the Override decision*. The AL control name settles later, in design.
- **Status** — where the Business Event flips a field on the aggregate record, name the field and its new value: *Sales Header Status → Override Pending*. Fold it into You see; never a dash column.

## The interview

Ask one question per message, with lettered options and your recommendation marked. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Put to the user what the design and the task breakdown will lock in; decide the rest and name it in one line. Look up a BC fact rather than asking it.

- **Whose journey is this, and where does it start and end?** A second Role appearing mid-timeline is a handoff — name it. Two disjoint journeys are two features.
- **What does an external observer see that says the step worked?** The View in the surface's own words, plus the Status flip where there is one. A step with no observable outcome is a step nobody can verify later.
- **Which step branches, and which business rule decides it?** Look BaseApp's own branching up; ask only about the rule this feature adds. An unnamed branch is a slice nobody builds.
- **What does the observer see when the journey fails?** BaseApp's existing failure surfaces are facts. What this feature does with its own failures is the user's call.
- **What is the user not asking?** The adjacent journey this one implies, or the Role who sees the result and was never named.

An answer that shifts each time it is restated, or a preference with no reason under it, goes through `/al-grilling`; carry back what surfaces. Once everything is settled except one genuine fork, offer competing timelines in chat — each complete, the same five slots — and say which you would pick. Write only the picked timeline onto the Design story.

## The write

Rewrite the Design Description as each slot settles, per [EVENT-MODEL-FORMAT.md](EVENT-MODEL-FORMAT.md). Mid-session the page is working state. Batching an hour of settled answers into one write at the close loses the hour. Break sameness by shape: Goal is two short paragraphs; happy path is an `<h3>` per Role with its steps in one paragraph — do not repeat the Role on every step; when it stops is two bold lead-ins (Before X / After X), not blockquotes. Separate major sections with `<hr>`. No table unless the section is a comparison. No Role/Action/Business Event/View/Status matrix. AL realisation settles under Modules later.

## Close

The Design story holds a visible overview — Goal, happy path by Role, two stop paragraphs — and a `Journey slots` fold-out where every step names Role, Action, Business Event, View, and Status flip.

A settled journey first goes blind through `/al-spec-review` — the Description, its sources, and the interview's settled answers as locked constraints; its findings land per that skill's disposition before the page stands.
Commit any `CONTEXT.md` term this run settled with a plain descriptive message; a stop mid-interview commits what settled the same way. Then continue in this session with `/al-design`.
