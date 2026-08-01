---
name: al-design
description: Settle the feature's architecture through an interview and write architecture.md. Run it after the event model, or straight after al-grill-adr for backend-only features.
disable-model-invocation: true
---

# Idea → `architecture.md`

Settle the feature-level architecture through an interview and write it into `architecture.md` in the feature's spec folder, `specs/<NNN>-<slug>/` — created if absent with `<NNN>` one past the highest spec folder present, together with a matching `<NNN>-<slug>` branch off the default branch. `/al-scope` decomposes that file into every task of the feature, so a gap here resurfaces as a guess inside a task. [ARCHITECTURE-FORMAT.md](ARCHITECTURE-FORMAT.md) holds the shape and a worked example.

## Before the interview

- Sharpened intent comes first — `CONTEXT.md` vocabulary plus the domain ADRs. Without it, domain confusion is indistinguishable from architectural choice. **Stop.** Run `/al-grill-adr`.
- A user/API-facing feature needs `event-model.md` in the spec folder. Missing → ask whether the feature is backend-only (no human, no API consumer) or whether `/al-event-model` was skipped, and **stop** unless the user confirms backend-only.
- The module map's `Precedent` verdicts are read from `.bcapps/`. Clone missing → **stop.** Run `/al-clone-bcapps`.
- Architectural decisions are checked against BCQuality. `.bcquality/knowledge-index.json` missing → **stop.** Run `/al-clone-bcquality`.
- An existing `architecture.md` is reshaped whole by this run, never edited surgically. Say so before starting.

## Grounding and AL voice

Every BC object, table, field, procedure, event, and enum value name comes from a lookup run this session — a workspace symbol search, or official BC documentation read and quoted. Recall is stale fiction. `.bcapps/` is the pattern library: read how Microsoft implements the nearest analogous behaviour before shaping your own — default search skips gitignored folders. System Application, Business Foundation, and the apps under `src/Apps/W1` are the design authority; BaseApp binds for integration points — its events, its tables, its posting routines — but its internal shape is legacy, not a pattern to lift. A name carried in from `event-model.md` counts once a search of that file returns it this session; a name being minted needs a zero-hit collision search first.

BC vocabulary throughout: Insert not create, Modify not update, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, codeunit not class, procedure not method.

Production-AL thrift: reach for the platform before code — a field plus a FlowField beats a setup table plus a management codeunit, an enum beats a hand-rolled status pattern. An AL `interface` arrives with its second implementation, not in anticipation of one. A deliberate shortcut carries a one-line comment naming its ceiling and the upgrade path.

BCQuality is the rule set. `.bcquality/knowledge-index.json` carries one row per article with its `domain` and `keywords`. Narrow to the domains the decision in front of you touches — data modeling, events, interfaces, upgrade, whatever it is — and read those articles before settling it. Where an article moved a decision, `architecture.md` names it on that decision's line, so a later reviewer sees the rule and not just the choice. Elsewhere it stays silent; this is a citation, never a bibliography.

## The interview

Ask one question per message, with lettered options and the recommendation marked in its own option line. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. A decision that turns on a picture — the module map, a lifecycle, a data shape — may instead go to the user as a decision surface through `/al-visualize`; the decision still settles here in chat. Each answer lands in `architecture.md` as it settles — batching an hour of settled decisions into one write at the close loses the hour.

Strategic, and therefore asked: module ownership and dependency direction, where persisted data lives, seam placement, which existing behaviour the feature may change, the public surface it commits to, the boundary between pure decisions and BC runtime, the future change this architecture must keep cheap, and the binding constraint. The interview closes when each of those is settled or stopped on a named spike.

Module ownership takes the delete test: delete the module in imagination — complexity that vanishes was a pass-through, complexity that reappears across callers earned its keep. Name modules in the project's own vocabulary — "the Settlement intake module", never "the FooBarHandler". Each module row closes with its `Precedent` verdict from the `.bcapps/` read — the Microsoft object reused, the pattern lifted and where it differs, or `none in System App / apps`, a claim only the search can earn.

Tactical — object and file names, which of two equivalent patterns carries a module, the order sections land in — is decided and named in one line; naming it is what makes it overridable. A fact is never asked: search the workspace, or read the documentation. Escalate to `/al-grilling` when an answer itself needs pressure — a requirement that shifts each time it is restated, a preference with no reason under it.

## Candidates

Multi-module designs, brownfield refactors, and novel pattern selection earn candidates. Diverge only once the strategic inventory is settled apart from the fork they turn on; earlier, the user is choosing between guesses. Propose how many are worth building and which one you would pick, and let the user set the count. If your harness supports subagents, these parallelize on full-capability subagents running the same model as this conversation; otherwise build them in one pass.

Each candidate is self-contained under **Constraint**, **Shape**, **Flow**, **Seams**, **Trade-offs**, and carries the same settled decisions marked as settled so none reopens one. Present them in sequence, compare along depth, locality, and seam placement, recommend one or a hybrid opinionatedly, and put the pick to the user as one lettered question.

## BC patterns

A plain procedure on a focused codeunit is the default and most modules fit no pattern at all. Adopt one only where it fits the module as it already stands — Façade, Event Bridge, Generic Method, Template Method, Implementer Injection, `ErrorInfo` error collection, API Register Fieldset, Delegate API Operation, Command Queue, No. Series. A pattern that needs explaining means the module shape is wrong: reshape rather than rename. Any pattern implying a seam — Event Bridge, Template Method, Command Queue, an `interface` Façade — names both adapters now (production plus test, or two production variants), or gives way to one that needs no seam.

## AppSource and trade-offs

A BaseApp modification is replaced by interception: a published event, a table extension, or an `interface` implementation. A shipped field is never renamed or removed in place; it follows `ObsoleteState: Pending → Removed` across the deprecation window. Both bite here, as a reshape, rather than at implement time.

A contested decision carries its reason inline where the decision lands — one line naming what lost and why: `queue table, not job queue entries — replay needs ordering the platform doesn't guarantee`. Domain rules belong to `/al-grill-adr`.

## Close

`architecture.md` carries the module map, every slice's AL realisation named slot by slot with its `new` / `extends` marker, the brownfield touchpoint inventory, and where decision logic stays reachable by unit tests.

A settled architecture goes up drawn through `/al-visualize` — the module map, each slice's realisation on it.

Commit `architecture.md` with a plain descriptive message; a stop mid-interview commits what settled the same way.

Then continue in this session with `/al-scope`.
