---
name: al-sync-main
description: Catch up the current AL/Business Central branch with main via rebase, mechanically renumbering any object/field number collisions introduced on this branch. Use when main has moved on and the branch needs to be brought current before continuing work or opening a PR.
allowed-tools: ["execute", "read", "edit", "search"]
---

# /al-sync-main — rebase onto main, renumber collisions

Read [GROUND-RULES.md](../../references/GROUND-RULES.md) before any chat or file output. This is the compaction recovery path; point there rather than restating its rules.

Bring the current branch current with `main`: always rebase, never merge. A branch-new object or field number colliding with `main` moves mechanically to the next free slot in its `idRanges` bucket. Everything requiring a decision stops and asks.

## Preconditions

| Check | Failure |
|---|---|
| Working tree clean (`git status --porcelain` empty) | Ask the user to commit or stash first |
| On a feature branch, not `main` | Stop; nothing to sync |

## Procedure

**Gate before, gate after — the rebase never gets blamed for a pre-existing red.**

1. **Full gate, pre-sync baseline.** Delegate the full `/al-build` gate on the current tip before touching git. Red is pre-existing → report and stop. Green → continue.

2. **Fetch and rebase.** `git fetch origin main`, then `git rebase origin/main`.

3. **Classify each conflict as it surfaces:**

   | Conflict | Route |
   |---|---|
   | Pure number collision — same object type + number, or same field number in the same object, branch-new vs. already used on `main`, no overlapping logic | Mechanical → step 4 |
   | Real content conflict — same object/field, actually conflicting logic | **Stop**, ask the user; never guess intent |
   | Same object name, different number — a naming collision, not a numeric one | **Stop**, ask the user; the same concept was likely modelled twice and needs a decision, not a renumber |
   | Anything else `git rebase` flags | **Stop**, ask the user |

   On any stop while a rebase is active: `git rebase --abort` first, so the tree is back at the pre-sync branch tip before you report. Never leave a rebase paused mid-conflict for the user to untangle by hand. Every stop reports the named object type, number, file, and reason, never a category.

4. **Mechanical renumbering — one pass after the rebase completes**, never per commit:
   - Find every remaining object/field number collision via `al-symbols-mcp` (object/field listings across the workspace). When the MCP is unavailable, use workspace `grep` instead. Every name is backed by a symbol hit or grep this session, never recall, per the grounding rules in GROUND-RULES.md.
   - Scope: renumber only objects/fields **introduced on this branch since it diverged from main** (`git log main..HEAD` on the pre-rebase tip tells you which). Never touch a number that already existed on `main` — the branch's new number moves, not main's.
   - Allocate the replacement via the available object-ID allocator (e.g. `al-objid-mcp-server`'s `ninja_assignObjectId`/equivalent), scoped to the same `idRanges` bucket (from the owning app's `app.json`) the colliding number already used. Allocator absent → read the app's `idRanges` from `app.json` and pick the lowest number in that bucket not already reported by `al-symbols-mcp`/grep.
   - Bucket exhausted (allocator returns none free, or manual scan finds no gap) → **Stop**, ask the user to widen the range or pick a different bucket. This is not mechanical.
   - Apply the renumber: change the object/field declaration, and grep-and-replace every same-file reference that is safe to rewrite with confidence (e.g. the object's own extension target, an internal field reference within the same object). A renumbered object that was a scaffolded-then-abandoned allocation gets its old ID unassigned via the allocator so it doesn't leak from the pool, per **Object ID allocation** in [tdd.md](../../references/testing/tdd.md).
   - **References by literal number outside the object itself** (e.g. `Record 50100`, a permission set entry, a page extension's `extends` target elsewhere in the tree) that this skill can't safely rewrite with confidence → **Stop**, ask the user rather than guess and silently break a reference.
   - Re-check via `al-symbols-mcp`/grep to confirm the collision is gone before moving on.

5. **Full gate, post-sync.** Delegate the full `/al-build` gate on the rebased and renumbered tree. Green → report done. Red is new → name the broken object, field, or test and stop; never auto-retry. The rebase has completed, so there is nothing to abort: the rebased, renumbered tree stays in place and the red is reported for the user to fix.

## Next step

| Outcome | Next |
|---|---|
| Clean sync — gate green both ends | Continue the branch's work: `/al-implement`, `/al-refactor`, or opening a PR |
| Stopped — real conflict, naming collision, unsafe reference, or exhausted bucket | Resolve by hand (or ask for help), then re-run `/al-sync-main` |
| Post-sync gate red | Fix the failing test or production code (`/al-build` again to confirm), then continue |

## Composition

| | |
|---|---|
| `/al-build` | The full gate, run before and after the sync |
| `/al-steer` | A sync surfacing a genuine replan need (e.g. the collision reveals the same concept was built twice on both branches) is a new decision, not a mechanical fix. Hand off, never absorb it here |

Close with the task-close gate report per [GROUND-RULES.md](../../references/GROUND-RULES.md); a precondition failure or a stop closes with the one-line **Stop**.
