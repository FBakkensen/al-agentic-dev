---
name: al-event-model
description: Settle the user-facing journey for AL/Business Central as `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). Use after `/al-grill-adr` for user/API-facing features before `/al-design`; backend-only features skip.
---

# /al-event-model, User-facing journey → event-model.md

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Settle the journey at the altitude of what an external observer sees. The user-side picks land here so `/al-design` commits architecture without re-litigating them.

## The interview

Run the interview contract in [user-involvement.md](../../references/user-involvement.md).

Strategic here — what `/al-design` and `/al-scope` consume and cannot reopen without a replan: the journey's boundary and its Roles, each step's observable outcome, which steps branch and the business rule deciding each branch, what an external observer sees when the journey fails, and the order of the timeline. Tactical: how a settled concept is worded, whether swimlanes are drawn, and the order of steps whose order carries no meaning.

## Artifact boundary

Writes only `event-model.md` — never `architecture.md` or the `tasks/` folder. Implementation structure and task proof belong to `/al-design` and the task skills.

## Preconditions

- `/al-grill-adr` ran for this idea. Without sharpened `CONTEXT.md` and domain ADRs, fuzzy terms compound into wrong Role names or fictitious Business Events. **Stop**, run it first.
- The feature has a user or API surface. Backend-only features (no human, no API consumer) skip this skill; `/al-design` asks whether the missing journey means backend-only.
- Branch and spec folder setup follows [worktree-feature-branching.md](../../references/worktree-feature-branching.md) — read it in full before touching the branch; it owns the checkout classification, the Stop conditions, and `specs/<NNN>-<slug>/` creation. On an in-flight feature branch, reshape `event-model.md` in place, with the user's awareness.

## The five slots

Every slot `/al-design` consumes settles here. Every BC-specific name is grounded per [GROUND-RULES.md](../../references/GROUND-RULES.md) before it lands in a slot. A slot whose meaning won't settle blocks the write. A BC name grounds through `al-researcher` with `Use: durable artifact event-model.md`. Domain intent still fuzzy after `CONTEXT.md` and the ADRs is a stop — `Next: /al-grill-adr`. A missing standard persona name never blocks — the Role slot settles on a plain business role name.

- **Role** — the acting persona in BC vocabulary: a human business role (a standard BC persona name — Order Processor, Accountant — anchors where one exists, never gates), an external API consumer or publisher, or a BC system actor such as the Posting Engine when the journey passes through one. Verify standard persona names the workspace cannot answer through `al-researcher`.
- **Action** — user-meaningful verb + object (*Release Sales Order*, *Approve Override*). Where it overlaps BaseApp, match BC's standard verb set: Insert / Modify / Delete / Post / Validate / Release / Reopen / Apply / Reverse.
- **Business Event** — past-tense fact in business language (*Sales Order Released*, *Credit Limit Breached*). Verify BaseApp event names through `al-researcher` before naming.
- **View** — surface plus its location (*Sales Order page → Status flips to Released*, *API response carries the Override decision*). The surface type settles here; the AL control name settles in `/al-design`.
- **Status** — when the Business Event flips a field on the aggregate's record, name field and new value (*Sales Header Status → Override Pending*).

## Question repertoire

- **Whose journey is this, and where does it start and end?** The Roles and the trigger. A second Role appearing mid-timeline is a handoff — name it rather than letting it pass silently. A feature that genuinely spans two disjoint journeys is two features.
- **What does an external observer see that says the step worked?** The View, in the surface's own words, plus the Status flip when the Business Event carries one. A step with no observable outcome cannot be verified, and `/al-refine` will owe a `Verification Plan` against it.
- **Which step branches, and which business rule decides the branch?** BaseApp's own branching is a fact — resolve it through `al-researcher` and name it. Ask only for the rule this feature adds. A branch left unnamed here is a slice `/al-scope` never emits.
- **What does the observer see when the journey fails?** BC's existing failure surfaces — a blocked posting, an error, a Status that never flips — are facts. The outcome the feature intends for its own failures is the user's call.
- **What is the user not asking?** The adjacent journey this one implies, or the Role who sees the result and was never named. Research the BC behaviour first, then ask whether it belongs in this feature.

Every leaf minted here is named in chat as it lands. A minted name that asserts a business fact — a Business Event claiming something the business does — is strategic and is asked. A label for a concept already settled is tactical.

## User-facing voice

A reader who cannot tell what the user experiences without consulting AL source means the artifact has failed. No AL pub/sub vocabulary (`OnAfter*`, `IntegrationEvent`, *Subscribes to*), no page-extension idioms, no codeunit references. AL realisation settles in `architecture.md` via `/al-design` — the *Slice* entry in [LANGUAGE.md](../../references/LANGUAGE.md) homes the two-artifact settlement.

## One timeline

The whole feature gets one timeline in temporal order. Role swimlanes appear when more than one Role participates. BaseApp steps join the chain under their canonical names, with no `(existing)` / `(new)` tags — a reader who knows BC tells *Sales Order Released* (BaseApp) from *Credit Limit Breached* (yours) by the names alone.

## Candidate timelines

Candidates follow the alternatives beat in [user-involvement.md](../../references/user-involvement.md). Building out at this altitude is a complete timeline per candidate: the same five slots end to end, diverging only on the fork the interview named.

## The write

Slots land in `event-model.md` as they settle, per [user-involvement.md](../../references/user-involvement.md). [task-lifecycle.md](../../references/task-lifecycle.md) is a mandatory read before the first write — it carries the markdown-only constraints and the examples table whose `event-model.example.md` owns the artifact shape.

## Document verification

Between the complete timeline and the close, run the document-integrity check yourself, inline (no subagent), against [doc-integrity.md](../../references/doc-integrity.md): the `event-model.md` profile and sibling consistency in the spec folder. A **fail** blocks the close and the `/al-design` handoff — fix it or route to `/al-steer`. A **warn** rides in the close. The check judges structure only, never whether the journey is the right product decision.

## Next step

Close with the task-close gate report ([GROUND-RULES.md](../../references/GROUND-RULES.md) House shapes). The picks were made in the room, so the report records what settled rather than asking for a greenlight. `event-model.md` landed with no integrity fail → `Next: /al-design`. `al-researcher` returned `CONFLICT` or `UNRESOLVED` → `Next: /al-steer`. A downstream fact invalidated the timeline → `Next: /al-steer`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-grill-adr` (CONTEXT + domain ADRs settled) |
| **Hands off to**   | `/al-design` (consumes `event-model.md`) |
| **Calls directly** | no skills |
| **Spawns**         | `al-researcher` for BC names and behaviour beyond direct workspace reading |
| **Replan venue**   | `/al-steer` (downstream fact invalidates timeline) |
| **Sidebands**      | `/grill-me` when an answer itself needs pressure ([user-involvement.md](../../references/user-involvement.md)) |
