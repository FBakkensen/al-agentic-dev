# The tour, verbatim

Everything below the rule is emitted as written, with the `<...>` slots filled. SKILL.md names how each is picked.

- `<start here line>` — one of these, paths filled:
  - You're in `<cwd>` — not an AL repository. `cd` into your AL repo, then run `/al-agentic-dev-overview` again.
  - You're in `<repo root>` — an AL app with no provisioned environment. Run `/al-provision` → `/al-clone-bcapps` → `/al-clone-bcquality`, then begin at `/al-grill-adr`.
  - You're in `<repo root>` — provisioned, nothing written down yet. Begin at `/al-grill-adr`.
  - You're in `<repo root>`, mid-feature on `specs/<NNN>-<slug>/` — its tasks live in the bound Azure DevOps work items. Run `/al-next` for the open moves.
- `<snippet state>` — `not installed` when no home carries the snippet, `out of date` when some do.
- `<stale homes>` — the homes missing or stale. All four current → the whole Snippet section is omitted.

---

# AL agentic dev

Skills that carry a Business Central feature from idea to merged branch. You drive each step; nothing runs on its own.

## Pipeline

```
1. Provision  /al-provision → /al-clone-bcapps → /al-clone-bcquality
2. Shape      /al-grill-adr → /al-event-model → /al-design → /al-scope
3. Build      per task:  /al-refine → /al-implement → /al-refactor
4. Ship       per slice: /al-code-review → /al-user-verification
              before merge: /al-validate-breaking-changes
```

`/al-event-model` only for user- or API-facing features; backend-only goes straight to `/al-design`.

## Support skills

- `/al-next` — names your next move when you resume or ask what's next
- `/al-routing` — records each skill's outcome, derives the open moves
- `/al-build` — the compile-publish-test gate every skill reaches through
- `/al-quiz` — quizzes you on what just landed
- `/al-grilling` — stress-tests one answer at a time
- `/al-sync-main` — rebases onto main, renumbers object collisions

## Start here

<start here line>

## ⚠️ Reply-shape snippet — <snippet state>

- **What it is** — the reply rules these skills assume: one question at a time, plain text, lettered options, recommendation marked; brief replies, outcome first; exact object and field names.
- **Where it goes** — your personal agent config, user level, never the repo.
- **Status** — `<stale homes>`.

**→ Say "install the snippet" and I'll set it up.**
