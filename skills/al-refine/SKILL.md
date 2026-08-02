---
name: al-refine
description: Turn one task into its proof — a Test Specification on a technical task, a Verification Plan on a verify task. Run it on the next unrefined task the router names.
disable-model-invocation: true
---

# Refine a task into its proof

One named task per run. Task files live in `specs/<branch>/tasks/` — the current git branch names the spec folder; a branch with no matching folder stops the run, naming the mismatch. Regenerate its Test Specification or Verification Plan whole against the current app and tests; keep everything scope-time — title, description, `depends_on:`, `slice:`, constraints, risks, acceptance intent — except a user-approved split, which narrows title and description as part of writing it. [TASK-FORMAT.md](TASK-FORMAT.md) is the body's exact shape — section order, heading levels, labels, and column names.

The body is your write; the frontmatter is `/al-routing`'s. An open question this run cannot settle — one only running code can answer, a slot `architecture.md` never allotted, an unsettled domain rule — stops the run instead: name it in chat and leave the body as the interview left it; the next run regenerates it whole once the question settles.

## Branch by kind

- `technical` → Test Specification, the red→green driver.
- `verify` → Verification Plan, the walk run with the user. Without `event-model.md` the slice has no user-facing source; the run stops.
- `provision` → decline, naming `/al-provision`. `breaking-change` → decline, naming `/al-validate-breaking-changes`.

## The interview

Read `architecture.md`, `event-model.md` when present, `CONTEXT.md`, and the code the task lands on before the first question.

BCQuality is the rule set for what the proof pins. `.bcquality/knowledge-index.json` carries one row per article with its `domain` and `keywords`; missing → **stop**, naming `/al-clone-bcquality`, which builds it. Narrow to the domains the task's surface touches, plus `testing` always — the cases and their layers are this run's whole output — and read those articles before minting names or cases. The corpus is written for the container runtime and does not document AL Runner, so a `Unit` case follows the runner's semantics where they collide. An article that moved a decision lands as a `Researched:` bullet in `Contract notes:`; elsewhere it stays silent.

A fact is looked up. A tactical call — AL test procedure names, case ordering, assertion phrasing — is decided and named in one chat line, which is what makes it overridable without asking. A strategic call is asked one question per message with lettered options, because downstream consumes it as settled: which behaviours this proof has to pin, which layer holds a behaviour when the cheapest one cannot reach it, any name landing on public surface — a shipped object, an API, a published event — that AppSource then holds for the life of the app, and what the user signs off by hand. A strategic call that turns on a user flow or a screen sequence may go to the user drawn, through `/al-visualize`. Ask every question in the reply itself, as plain text — never through a question or elicitation tool.

Write each answer into the task file as it settles. Where an answer itself needs pressure — a requirement that shifts each time it is restated, a bound nobody wrote down — run `/al-grilling`.

## Technical task: Test Specification

The sections and their shapes are [TASK-FORMAT.md](TASK-FORMAT.md)'s; this run decides what fills them — which behaviours become coverage rows, which layer proves each, and the production surface the task lands at signature level. A behaviour needing both layers gets two cases, one per scope.

Two unrelated behaviour groups mean a low-cohesion task: put the split to the user, and on their yes narrow this task to one group and write each other group yourself as a new open technical task per `/al-routing`'s schema — the original keeps its id and its inbound edges, and each new task carries the `depends_on:` edges its group needs.

## Verify task: Verification Plan

Every check derives from the slice's observable user or API surface, never internal state, and title, description, and every Role / Action / Business Event / View / Status name quote `event-model.md`. Write only the sections the slice earns, per [TASK-FORMAT.md](TASK-FORMAT.md).

## Push-ups and exact names

Every `Integration` case, `Record: yes` journey, and `Contract` example sits above the cheapest layer that could hold the behaviour. Each owes a `Contract notes:` bullet naming why the layer below cannot hold it and what reaching it would cost — a named seam, or the wall that makes it impossible.

Every exact BC name written into the task — object, table, field, procedure, event, enum value — comes from a workspace or documentation lookup made this session; recall is not evidence. A minted name earns a zero-hit collision lookup first — objects against workspace declarations, fields against the target table and its extensions, procedures against the target object — and is derived, never invented: its noun from a `CONTEXT.md` term, the BC baseline, or an `event-model.md` Action, Business Event, or Status, its verb from BC's own set, confirmed in `.bcapps/` where the clone is present. A term no source names is a vocabulary gap: settle it as one question and land it in `CONTEXT.md` per its format — committed on its own with a plain descriptive message, apart from the task's `T-NNN` commits — then derive; the entry is the record, and the task file carries nothing extra.

BC vocabulary in every line the body takes: Insert not create, Modify not update or mutate, Post not submit, Validate not check, Get and Find not fetch, Ledger Entry not transaction, Status not state, the record or the API body not the payload, codeunit not class, procedure not method — TDD, red/green, and AAA keep their own names.

A technical task's behaviour answers to a `Precedent` verdict in `architecture.md`'s module map. A behaviour no verdict covers gets its own `.bcapps/` read — clone missing → stop, naming `/al-clone-bcapps` — and the verdict lands as a `Precedent:` line in `Contract notes:`; a verdict that already covers the behaviour is consumed, never copied down. A read contradicting the map — Microsoft ships what a module builds — is a strategic finding: stop the run and name it in chat, because it reopens the architecture, not the task.

## Close

A written proof first goes blind through `/al-spec-review` — the body, its sources, and the interview's settled answers as locked constraints; its findings land per that skill's disposition before anything commits.

Name the task and what this run left on it — the proof written, the open question that stopped it, or the decline and the skill it names. A written proof goes up drawn through `/al-visualize` — its behaviours mapped to the cases and layers that pin them. Every exit commits the task file under its `T-NNN` prefix — the written proof, or on a stop whatever settled before the question.

Then `/al-routing` on a written proof. A stop ends in chat and the user re-runs once the question settles; a decline ends naming the owning skill.
