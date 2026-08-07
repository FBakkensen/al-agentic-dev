---
name: al-event-model
description: Settle the feature's user-facing journey as event-model.md in the five BC slots — Role, Action, Business Event, View, Status. Run it after al-grill-adr on user- or API-facing features; backend-only skips it.
disable-model-invocation: true
---

# Journey → event-model.md

Settle the journey at the altitude of what an external observer sees, so the architecture can be designed without re-litigating the user-side picks. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch — then proceed.

Preconditions: the `CONTEXT.md` terms and the domain ADRs are settled — run `/al-grill-adr` first, since a fuzzy domain term becomes a wrong Role name or an invented Business Event. And the feature has a human or API surface; a Job Queue, install/upgrade, or scheduled-task feature has no journey and goes straight to `/al-design`. The journey is checked against BCQuality — `.bcquality/knowledge-index.json` missing → **stop.** Run `/al-clone-bcquality`.

`event-model.md` lands in the feature's spec folder, `specs/<NNN>-<slug>/`, created if absent with `<NNN>` one past the highest spec folder present. Where the file already exists for this feature, reshape it in place. The run continues on a branch named `<NNN>-<slug>`:

- No branch for this feature yet → create `<NNN>-<slug>` off the default branch.
- The session sits on its own working branch with another name → rename it to `<NNN>-<slug>`, with plain `git branch -m` where the environment's branch tooling cannot produce the exact name.
- Never rename the default branch.
- Never rename a branch already `<NNN>-<slug>`-shaped — that name binds it to its own spec folder; a mismatch with this run's spec is a stop put to the user.
- A rename that fails is a stop put to the user, never a quiet note.

Every BC name that lands in a slot — a persona, a BaseApp event, a table, a field, a page — comes from a lookup made this session: search the workspace, or read Microsoft's BC documentation. Recall is fiction. Where `.bcapps/` is present, it is intentionally gitignored: inspect it directly for BaseApp's own events and code. Default workspace search can omit it, so use a search mode or direct file reading that includes the clone.

BCQuality is the intentionally gitignored rule set for the slots that carry BC mechanics. `.bcquality/knowledge-index.json` carries one row per article with its `domain` and `keywords`. Default workspace search can omit the clone, so use a search mode or direct file reading that includes it. Narrow to the domains a step touches — events above all, plus ui and web services where the View sits there — and read those articles before settling the step. Where an article moved a decision, `event-model.md` names it on that step's line; elsewhere it stays silent.

The timeline is a naming authority: downstream skills derive procedure, event publisher, and enum value names from its Actions, Business Events, and Statuses. A concept entering one of those three slots with no `CONTEXT.md` term and no BC baseline term behind it is a vocabulary gap: settle it as one question, land the term in `CONTEXT.md` per its format, and name the slot from it — Roles and Views stay in the user's own words.

## The five slots

- **Role** — the acting persona: a human business role (a standard BC persona such as Order Processor or Accountant where one fits), an external API consumer or publisher, or a BC system actor such as the Posting Engine. A plain business role name carries the slot when no standard persona matches.
- **Action** — user-meaningful verb plus object: *Release Sales Order*, *Approve Override*. Where it overlaps BaseApp, take BC's own verbs — Insert, Modify, Delete, Post, Validate, Release, Reopen, Apply, Reverse.
- **Business Event** — the past-tense business fact the Action produced: *Sales Order Released*, *Credit Limit Breached*.
- **View** — the surface the observer reads and where it sits: *Sales Order page*, *Allocation Ledger Entries, drill-down from the Posted Sales Invoice*, *API response carries the Override decision*. The AL control name settles later, in design.
- **Status** — where the Business Event flips a field on the aggregate record, name the field and its new value: *Sales Header Status → Override Pending*. Otherwise `—`.

## The interview

Ask one question per message, with lettered options and your recommendation marked. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Put to the user what the design and the task breakdown will lock in; decide the rest and name it in one line — wording, the order of steps whose order carries no meaning. Look up a BC fact rather than asking it.

- **Whose journey is this, and where does it start and end?** A second Role appearing mid-timeline is a handoff — name it. Two disjoint journeys are two features.
- **What does an external observer see that says the step worked?** The View in the surface's own words, plus the Status flip where there is one. A step with no observable outcome is a step nobody can verify later.
- **Which step branches, and which business rule decides it?** Look BaseApp's own branching up; ask only about the rule this feature adds. An unnamed branch is a slice nobody builds.
- **What does the observer see when the journey fails?** BaseApp's existing failure surfaces are facts — a blocked posting, an error, a Status that never flips. What this feature does with its own failures is the user's call.
- **What is the user not asking?** The adjacent journey this one implies, or the Role who sees the result and was never named.

An answer that shifts each time it is restated, or a preference with no reason under it, goes through `/al-grilling`; carry back what surfaces.

Once everything is settled except one genuine fork, offer competing timelines on that fork — each complete, the same five slots end to end — and say which you would pick. A fork with one credible answer earns no alternatives. Competing timelines may go to the user drawn as a decision surface through `/al-visualize`.

## The write

Write each slot into `event-model.md` as it settles. Mid-session the file is working state: reorder it, leave it half-built. An hour of settled answers batched into a single write at the close is an hour lost to compaction.

The feature gets one timeline in temporal order, with Role swimlanes once more than one Role participates, and BaseApp steps joining the chain under their canonical names — a reader who knows BC tells *Sales Order Released* from *Credit Limit Breached* by the names alone, so no *(existing)* / *(new)* tags.

Word every View and Business Event the way the user would describe what they see, so the journey reads without opening AL source. AL realisation — `OnAfter*`, `IntegrationEvent`, *Subscribes to*, codeunit and page-extension names — settles in `architecture.md` instead.

Document shape and a worked example: [EVENT-MODEL-FORMAT.md](EVENT-MODEL-FORMAT.md). The document this skill writes is `event-model.md` — `architecture.md` and `tasks/` belong to later skills.

## Close

`event-model.md` holds one timeline in which every step names its Role, its Action, its Business Event, its View, and the Status it flips or `—`, and every branch the interview surfaced has its own section.

A settled timeline first goes blind through `/al-spec-review` — the file, its sources, and the interview's settled answers as locked constraints; its findings land per that skill's disposition before anything commits. Then it goes up drawn through `/al-visualize` — the five slots end to end, swimlanes where Roles hand off.

Commit `event-model.md` and any `CONTEXT.md` term this run settled with a plain descriptive message; a stop mid-interview commits what settled the same way. Then continue in this session with `/al-design`.
