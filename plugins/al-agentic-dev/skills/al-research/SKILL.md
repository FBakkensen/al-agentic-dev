---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources, quote them, return. Invoke when two sources disagree, when a fact lands in a durable design artifact (event-model.md, architecture.md, CONTEXT.md, ADRs), or when a fuzzy question needs framing plus cross-family verification. Callable from a session and by another skill. Single-fact lookups go direct; this skill arbitrates.
---

# /al-research, Verify BC specifics

The skill is read-only advisory — it never picks designs.

## Escalation bar

[GROUND-RULES.md](../../references/GROUND-RULES.md) homes the grounding bar and its two mandatory triggers. This skill adds a third: a fuzzy question that needs framing plus cross-family verification. Frame the question before delegation.

## Preconditions

- Workspace search did not resolve the question.
- Claim is BC-specific.
- Question is framed.

## Delegation

Invoke the `al-researcher` custom agent with the framed question, why the escalation bar was earned, and any candidate sources or conflicting claims in hand. If `al-researcher` is unavailable: report `BLOCKED`, name `al-researcher` as the missing agent, and stop — no inline substitution.

**bc-standard-reference carve-out.** A spawned agent does not spawn another agent, so when the question is "what does Microsoft's shipped BaseApp / System Application / APIV2 code do", invoke the `bc-standard-reference` custom agent directly. A question needing cross-family verification *and* a shipped-code quote invokes each agent directly; this skill reconciles.

## Relay and routing

The agent's `RESEARCH ARBITRATION` return is the deliverable — relay it to whoever needed the fact. Citations land per the Trace rule in [GROUND-RULES.md](../../references/GROUND-RULES.md).

A returned `Conflict:` routes here: the caller or user has the architectural context to choose or route. An architectural choice → `Next: /al-steer`.

## Next step

- Invoked by another skill → return the finding to the caller.
- Run standalone → `Next:` the skill owning the artifact the fact feeds: `/al-design` or `/al-event-model` for a design fact, `/al-refine` or `/al-implement` for an implementation fact, `/al-grill-adr` for a CONTEXT/ADR fact, `/al-steer` for an architectural conflict.
