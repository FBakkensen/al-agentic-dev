# User involvement

The planning skills are working sessions. `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, and `/al-refine` interview the user while the artifact takes shape, instead of surfacing at the close with a finished file and a greenlight question. Each skill names its own question repertoire; this file carries what they share. `/al-steer` reads it too — it grills inline and is the replan venue.

## What reaches the user

Three kinds of open question, one route each. Questions go out one at a time ([GROUND-RULES.md](GROUND-RULES.md) One decision per question).

**A fact is never asked.** The workspace, `al-symbols-mcp`, `grep`, and `al-researcher` answer it on the grounding terms in [GROUND-RULES.md](GROUND-RULES.md).

**A strategic decision is asked.** Strategic means this artifact locks it in for downstream: the next skill consumes it and can only reopen it through a replan trigger ([task-lifecycle.md](task-lifecycle.md)).

**A tactical decision is made and named.** Decide it, then say so in chat in one line. Naming it is what makes it overridable without a question; an unnamed tactical decision is indistinguishable from an oversight.

In `/al-design`: which module owns a decision is strategic, whether BaseApp publishes the event the design leans on is a fact, and the name of a private helper procedure is tactical.

Each skill names the strategic categories its artifact must settle. The interview closes when every one of them is settled or stopped on a named spike. Relabelling an open decision tactical does not close its category.

## Fidelity

Every open decision has a cheapest rung that settles it. Route each one as it surfaces.

- **Conversation.** The judgment fits in one proposition. Most decisions.
- **Chat sketch.** The judgment needs several items seen together — the timeline so far, the module list, the candidate edges.
- **`al-researcher` lookup.** Not a decision medium: the question is waiting on a BC fact. Resolve the fact and put the question again; it often stops being a question.
- **Canvas.** The judgment needs branches or dependencies traced rather than read.
- **Stop and spike.** Runtime observation could change the answer. Name what the spike would prove and stop, naming the strategic category still open. No close gate runs and no handoff is named. This pipeline has no spike step, so the experiment is the user's.

Keep comparison tables in chat — candidates side by side read the same in a panel. Reach for a panel when the judgment traverses structure: a journey with its branches, a module map with its pure core and seams, a task graph and what actually stands in the way of one task.

## Alternatives come after the grilling

Diverge only when the strategic inventory is settled apart from the fork the alternatives turn on. Diverging earlier asks the user to choose between guesses, because nothing has found the fork yet.

Propose which alternatives are worth building, how many, and which one you would pick and why. A fork with one credible answer earns no alternatives — say so rather than manufacturing a second. The user sets the count. Build them out, present them, and the user picks. Each skill names what building out means at its altitude.

## The artifact is memory, not a reading surface

Write each decision into the artifact as it settles, the way `/al-grill-adr` lands a `CONTEXT.md` term the moment it resolves. A session that batches an hour of settled answers into one write at the close loses the hour to compaction.

Mid-session the file is working state — rewrite it, reorder it, leave it half-built. Close gates run against what landed, never against working state; which gates a skill runs, and how a finding against one is repaired, stay in [doc-integrity.md](doc-integrity.md) and [review-lenses.md](review-lenses.md). A re-run reshapes `event-model.md` and `architecture.md` whole ([task-lifecycle.md](task-lifecycle.md)) — that governs the next run, not the session still writing the file.

Planning artifacts are agent-facing on the terms task files already hold ([task-lifecycle.md](task-lifecycle.md), The audience split). Everything reaching the user goes through chat or a canvas. Never write "see `architecture.md`", and never assume a line of it was read.

## Escalating to `/grill-me`

The repertoire is the ordinary interview. Escalate to `/grill-me` when the answer itself needs pressure — a requirement that shifts each time it is restated, a preference with no reason under it, a scope claim that would commit the feature. It is an external skill; install it per [GROUND-RULES.md](GROUND-RULES.md). Carry what it surfaces back into the repertoire.

## Canvases

Nothing here ships a canvas. There is no component library and no shared shell. A panel is scaffolded on demand, for one decision that earned the rung, and torn down at the close.

Scaffold at **session** scope, author, reload, open. Project scope writes `.github/extensions/<name>/` into the AL repo, so a throwaway interview aid reaches `git status`, a commit, and a pull request. User scope loads in every later session and forks a process at each start. Neither is worth a panel that lives an hour.

The panel that carried the interview shows the final result at the close, and its folder is deleted after that — session teardown ends the process, not the folder on disk. A live panel holds a Node process, so keep one open at a time.

A canvas changes how a decision is presented, never which decisions must settle. A user on the CLI, or one who wants no panel, is interviewed on the same repertoire.

## Findings against what the user settled

A review lens reads the artifact blind, so it cannot tell a decision the agent made from one the user settled. Blocking authority splits on the same line the interview does: a finding the agent may simply fix never reaches the user; only a finding that needs the user's authority — one whose resolution would contradict what a baselined artifact settled, or establish what no baseline yet contains — does. [review-lenses.md](review-lenses.md) owns the terms: **A blocking finding on a plan** for the plan gates, **A finding on code** for the code gates.
