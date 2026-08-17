---
name: al-design
description: Settle the feature's architecture through an interview and rewrite it onto the same Design User Story. Run it after the event model, or straight after al-grill-adr for backend-only features.
disable-model-invocation: true
---

# Idea → the Design story

Settle the feature-level architecture through an interview and rewrite it onto the same Design User Story `/al-event-model` opened — or create that story here when the feature is backend-only. Your first line names that this run wants a frontier-class model — the user picked the model and weighs the mismatch — then proceed. `/al-scope` decomposes that page into every task of the feature, so a gap here resurfaces as a guess inside a task. [ARCHITECTURE-FORMAT.md](ARCHITECTURE-FORMAT.md) holds the page. The run continues on `feature/ab<rootId>-<slug>` — the root id from the `al-ado.json` binding, the slug kebab-case of the journey or, backend-only, the feature outcome:

- No branch for this feature yet → create `feature/ab<rootId>-<slug>` off the default branch.
- The session sits on its own working branch with another name → rename it to `feature/ab<rootId>-<slug>`, through the rename_branch tool where the session provides it, with plain `git branch -m` otherwise.
- Never rename the default branch.
- Never rename a branch already `feature/ab<rootId>-<slug>`-shaped — its slug binds it to this Design story; a mismatch with this run is a stop put to the user.
- A rename that fails is a stop put to the user, never a quiet note.

## Before the interview

- Sharpened intent comes first — `CONTEXT.md` vocabulary plus the domain ADRs. Without it, domain confusion is indistinguishable from architectural choice. **Stop.** Run `/al-grill-adr`.
- The Azure DevOps work-item tools are available — see the README note — and the `al-ado.json` binding resolves. Missing → **stop.**
- A user/API-facing feature needs a happy path on the Design story. Missing → ask whether the feature is backend-only (no human, no API consumer) or whether `/al-event-model` was skipped, and **stop** unless the user confirms backend-only.
- Backend-only with no Design story: create it on the first settled answer, same write as `/al-event-model`, titled `Design: <feature outcome>`.
- The module map's `Precedent` verdicts are read from `.bcapps/`. Clone missing → **stop.** Run `/al-clone-bcapps`.
- Architectural decisions are checked against BCQuality. `.bcquality/knowledge-index.json` missing → **stop.** Run `/al-clone-bcquality`.
- An existing Design Description is reshaped whole by this run, never edited surgically. Say so before starting.

## Grounding and AL voice

Every BC object, table, field, procedure, event, and enum value name comes from a lookup run this session — a grep or lsp workspace-symbol search, or official BC documentation read and quoted through the microsoft-learn tools (microsoft_docs_search, microsoft_docs_fetch). Recall is stale fiction. `.bcapps/` is the intentionally gitignored pattern library: read how Microsoft implements the nearest analogous behaviour before shaping your own. Point grep at `.bcapps/` explicitly and view its files directly. System Application, Business Foundation, and the apps under `src/Apps/W1` are the design authority; BaseApp binds for integration points — its events, its tables, its posting routines — but its internal shape is legacy, not a pattern to lift. A name carried in from the Design happy path counts once a search of that Description returns it this session; a name being minted needs a zero-hit collision search first.

BC vocabulary throughout: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, codeunit not class, procedure not method — and a codeunit is named for the behaviour it owns, never a Manager or Handler.

Naming is derivation, not invention — in BC the ubiquitous language is the object model. A minted name takes its noun from a `CONTEXT.md` term, the BC baseline, or a Design-story Action, Business Event, or Status, and its verb from BC's own set, confirmed in `.bcapps/` where the clone is present. A term no source names is a vocabulary gap: settle it as one question, land it in `CONTEXT.md` per its format, then derive. Where a term plus the app's object-name prefix outgrows AL's 30-character object names, settle the short form once and record it on the term's `CONTEXT.md` entry as `_As name_`.

Production-AL thrift: reach for the platform before code — a field plus a FlowField beats a setup table plus a management codeunit, an enum beats a hand-rolled status pattern. An AL `interface` arrives with its second implementation, not in anticipation of one. A deliberate shortcut carries a one-line comment naming its ceiling and the upgrade path.

BCQuality is the intentionally gitignored rule set. `.bcquality/knowledge-index.json` is one minified line — parse it as JSON. Point grep at `.bcquality/` explicitly. Narrow to the domains the decision touches and read those articles before settling it. Where an article moved a decision, name it on that decision's line; elsewhere stay silent.

## The interview

Ask one question per message, with lettered options and the recommendation marked in its own option line. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Each answer rewrites the same Design Description as it settles. Overview stays visible: Goal, happy path by Role, two stop paragraphs. Modules and brownfield sit in a `<details>` fold-out whose summary is `Modules and brownfield`. Keep the happy path `/al-event-model` wrote; do not re-decide its slots. No canvas, no session markdown copy, no `/al-visualize`.

Strategic, and therefore asked: module ownership and dependency direction, where persisted data lives, seam placement, which existing behaviour the feature may change, the public surface it commits to, the boundary between pure decisions and BC runtime, the future change this architecture must keep cheap, and the binding constraint. The interview closes when each of those is settled or stopped on a named spike.

Module ownership takes the delete test: delete the module in imagination — complexity that vanishes was a pass-through, complexity that reappears across callers earned its keep. Name modules in the project's own vocabulary. Modules are short paragraphs, not a table; the `Precedent` verdict from the `.bcapps/` read is a short suffix on the module name.

Tactical — object and file names, which of two equivalent patterns carries a module — is decided and named in one line. A fact is never asked: grep the workspace, or read the docs through the microsoft-learn tools. Escalate to `/al-grilling` when an answer itself needs pressure.

## Candidates

Multi-module designs, brownfield refactors, and novel pattern selection earn candidates. Diverge only once the strategic inventory is settled apart from the fork they turn on. Propose how many are worth building and which one you would pick, and let the user set the count. These parallelize in full-capability subagents; when subagents are unavailable, build them in one pass. Each candidate is self-contained under **Constraint**, **Shape**, **Flow**, **Seams**, **Trade-offs**, and carries the same settled decisions marked as settled. Present them in sequence, compare along depth, locality, and seam placement, recommend one or a hybrid, and put the pick to the user as one lettered question.

## BC patterns

A plain procedure on a focused codeunit is the default and most modules fit no pattern at all. Adopt one only where it fits the module as it already stands — Façade, Event Bridge, Generic Method, Template Method, Implementer Injection, `ErrorInfo` error collection, API Register Fieldset, Delegate API Operation, Command Queue, No. Series. A pattern that needs explaining means the module shape is wrong: reshape rather than rename. Any pattern implying a seam names both adapters now, or gives way to one that needs no seam.

## AppSource and trade-offs

A BaseApp modification is replaced by interception: a published event, a table extension, or an `interface` implementation. A shipped field is never renamed or removed in place; it follows `ObsoleteState: Pending → Removed` across the deprecation window. A contested decision carries its reason inline where the decision lands. Domain rules belong to `/al-grill-adr`.

## Close

The Design story is one page: a visible overview (Goal, happy path by Role, two stop paragraphs) and fold-outs `Journey slots` plus `Modules and brownfield`. Every module paragraph carries its `Precedent` suffix. Decision logic that unit tests must reach lives in what the module Owns.
A settled page first goes blind through `/al-spec-review` — the Description, its sources, and the interview's settled answers as locked constraints; its findings land per that skill's disposition before the page stands. Commit any `CONTEXT.md` term this run settled with a plain descriptive message; a stop mid-interview commits what settled the same way. Then continue in this session with `/al-scope`.
