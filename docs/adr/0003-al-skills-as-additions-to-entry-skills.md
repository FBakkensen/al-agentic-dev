# AL skills as additions to mattpocock-skills entry skills

The user drives the flow with mattpocock-skills' own commands — `/grill-with-docs`, `/to-spec`, `/to-tickets`, `/implement` (→ `/tdd`, `mattpocock-skills:code-review`), `/improve-codebase-architecture`, `/setup-matt-pocock-skills` — plus Claude Code's `/simplify`. Our AL skills stop being a parallel chain and become AL additions: each named `al-<entry skill>` (one exception: the addition to `mattpocock-skills:code-review` stays `al-review`, since bcquality already ships `al-code-review`), loaded alongside its entry skill, carrying only what is AL- or Azure DevOps-specific. A developer who already knows Matt's skills works an AL repository without learning a second flow. This amends ADR 0002, where our skills owned the flow and called base-plugin skills by name.

An addition loads through two signals: its description names the entry skill ("Use whenever `tdd` runs against AL code"), and the plugin's `SessionStart` hook, which fires only in AL repositories, carries the entry → addition table. Most entry skills are `disable-model-invocation: true`, so no skill of ours can start them; the user types the entry, and the entry's own chaining replaces ours.

## Considered Options

- **Our skills as entries, calling Matt's by name** (ADR 0002 as written). Rejected: two flows compete for the same triggers, and `grill-with-docs`, `to-spec`, `to-tickets`, and `implement` cannot be called from a skill at all.
- **Invert only the overlapping pairs.** Rejected: a Matt user running `/to-tickets` in an AL repository would get GitHub-shaped tickets, which is where adoption breaks.

## Consequences

- `al-orchestrate` is deleted; `/implement` chains `/tdd` → `mattpocock-skills:code-review` → commit.
- `al-grill-adr`, `al-event-model`, `al-design`, `al-scope`, `al-test-design`, and `al-refactor` retire into additions, and `al-review` becomes the addition to `mattpocock-skills:code-review`; `al-build`, `al-arc42`, `al-walkthrough`, `al-next`, `al-pr-shepherd`, and `al-lookup` stay our own entries.
- The callee skills — `al-commit`, `al-pull-request`, `al-azure-devops-attachments`, `al-clone-bcapps` — and `al-miner` are unchanged.
- The review verdict follows `mattpocock-skills:code-review`'s two unmerged axes (Standards, Spec) instead of one merged verdict.
- Upstream can rename an entry skill or change its steps under an addition; the drift check must also resolve the entry names addition descriptions and the hook table use.
