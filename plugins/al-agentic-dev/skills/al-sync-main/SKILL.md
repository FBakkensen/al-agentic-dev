---
name: al-sync-main
description: Catch up the current AL/Business Central branch with main via rebase, mechanically renumbering any object/field number collisions introduced on this branch. Use when main has moved on and the branch needs to be brought current before continuing work or opening a PR.
allowed-tools: ["execute", "read", "edit", "search"]
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-sync-main — Rebase onto main, mechanically renumber collisions

Bring the current branch current with `main`. Always rebases — never merges. The one thing worth automating beyond the rebase itself: AL object and field numbers collide constantly across parallel branches, and resolving that collision is almost always mechanical (move the newer number to the next free slot in its own `idRanges` bucket), not a real conflict. This skill does that move so you don't have to by hand, and stops for you the moment anything stops being mechanical.

## Preconditions

- Working tree clean (`git status --porcelain` empty). Dirty tree → **Stop**, ask the user to commit or stash first; a sync must never mix with uncommitted work.
- On a feature branch, not `main`. On `main` → **Stop**, nothing to sync.
- `al-build.json` exists in repo root (this skill delegates gate runs to `/al-build`, which requires it).

## Procedure

1. **Full gate, pre-sync baseline.** Delegate to `/al-build` for the full gate on the current branch tip, before touching git. Red here is pre-existing — report it and stop; don't let a rebase's later red get blamed on the sync. Green → continue.

2. **Fetch and rebase.** `git fetch origin main`, then `git rebase origin/main`. Always rebase; this skill has no merge path.

3. **Resolve conflicts as they surface, one commit at a time:**
   - **Pure number collision** (same object type + number, or same field number in the same object, introduced on this branch vs. already used on `main`; no overlapping logic) → mechanical, handle per step 4.
   - **Real content conflict** (same object/field, actually conflicting logic) → **Stop**, ask the user. Do not guess intent.
   - **Same object name, different number** (a naming collision, not a numeric one) → **Stop**, ask the user — this usually means the same concept was modelled twice and needs a decision, not a renumber.
   - Anything else `git rebase` flags that isn't one of the above → **Stop**, ask the user.
   - On any stop condition: `git rebase --abort` first, so the tree is back at the pre-sync branch tip before you report. Never leave a rebase paused mid-conflict for the user to untangle by hand.

4. **Mechanical renumbering — one pass, after the rebase completes** (or after all conflicts are resolved), not per-commit:
   - Find every remaining object/field number collision via `al-symbols-mcp` (object/field listings across the workspace) or workspace `grep` when the MCP is unavailable — same evidence bar as the rest of this plugin (`voice-contract.md`: names backed by a symbol hit or grep this session, never recall).
   - Scope: renumber only objects/fields **introduced on this branch since it diverged from main** (`git log main..HEAD` on the pre-rebase tip tells you which). Never touch a number that already existed on `main` — the branch's new number moves, not main's.
   - Allocate the replacement number via the available object-ID allocator (e.g. `al-objid-mcp-server`'s `ninja_assignObjectId`/equivalent), scoped to the same `idRanges` bucket (from the owning app's `app.json`) the colliding number already used. Allocator absent → fall back to reading the app's `idRanges` from `app.json` and picking the lowest number in that bucket not already reported by `al-symbols-mcp`/grep.
   - If the bucket is exhausted (allocator returns none free, or manual scan finds no gap) → **Stop**, ask the user (widen the range, or pick a different bucket). This is not mechanical.
   - Apply the renumber: change the object/field declaration, and grep-and-replace every same-file reference that's safe to rewrite with confidence (e.g. the object's own extension target, an internal field reference within the same object). If a renumbered object was a scaffolded-then-abandoned allocation, unassign the old ID via the allocator so it doesn't leak from the pool (per `tdd.md`'s object-ID-allocation discipline).
   - **References by literal number outside the object itself** (e.g. `Record 50100`, a permission set entry, a page extension's `extends` target elsewhere in the tree) that this skill can't safely rewrite with confidence → **Stop**, ask the user rather than guess and silently break a reference.
   - Re-check via `al-symbols-mcp`/grep to confirm the collision is gone before moving on.

5. **Full gate, post-sync.** Delegate to `/al-build` for the full gate again, on the rebased + renumbered tree. Green → done, report the sync. Red → this is new: report exactly what broke (object, field, test) and stop; don't auto-retry.

## Abort semantics

Any stop condition — an unresolved real conflict, a naming collision, an unsafe reference rewrite, an exhausted `idRanges` bucket, a post-sync red the user hasn't triaged — ends with `git rebase --abort` (if a rebase is in progress) so the branch sits exactly where it did before the sync started. Report what stopped it and why, in named objects (object type, number, file), never a category. The user re-runs `/al-sync-main` after resolving the blocker by hand, or asks for help resolving it first.

## Next step

- **Clean sync (gate green both ends):** `Next:` continue whatever you were doing on the branch — `/al-implement`, `/al-refactor`, or opening a PR.
- **Stopped on a real conflict, naming collision, unsafe reference, or exhausted bucket:** resolve by hand (or ask for help), then re-run `/al-sync-main`.
- **Post-sync gate red:** fix the failing test or production code (`/al-build` again to confirm), then continue.

## Composition

- `/al-build` — the full gate, run before and after the sync. One of the two skills this skill is allowed to call directly.
- `/al-steer` — if the sync surfaces a genuine replan need (e.g. the collision reveals the same concept was built twice on both branches), that's a new decision, not a mechanical fix — hand off to `/al-steer` rather than absorb it here.

## Out of scope

- Merging `main` into the branch → not supported; this skill only rebases.
- Resolving real content conflicts → the user's call, this skill only flags them.
- Renumbering anything that existed on `main` before this branch diverged → never touched.
- Renumbering non-colliding branch-new numbers "for tidiness" → out of scope; only collisions get moved.
