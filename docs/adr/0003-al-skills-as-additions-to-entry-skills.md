# AL skills as additions to mattpocock-skills entry skills

The user drives the flow with mattpocock-skills' own commands — `/grill-with-docs`, `/to-spec`, `/to-tickets`, `/implement` (→ `/tdd`, `mattpocock-skills:code-review`), `/improve-codebase-architecture`, `/setup-matt-pocock-skills` — plus Claude Code's `/simplify`. Our AL skills are AL additions, not a parallel chain: each named `al-<entry skill>` (one exception: the addition to `mattpocock-skills:code-review` is `al-review`, since bcquality already ships `al-code-review`), loaded alongside its entry skill, carrying only what is AL-specific; how the Tracker is worked comes from the Tracker doc. A developer who already knows Matt's skills works an AL repository without learning a second flow. mattpocock-skills owns the flow; our skills add to it.

An addition loads through two signals: its description names the entry skill ("Use whenever `tdd` runs against AL code"), and the plugin's `SessionStart` hook carries the entry → addition table. The hook injects in every session, because the plugin is installed only for AL work and a repository gate would miss an AL app whose `app.json` is nested. Most entry skills are `disable-model-invocation: true`, so no skill of ours can start them; the user types the entry, and the entry's own chaining runs the flow.

## Considered Options

- **Our skills as entries, calling Matt's by name.** Rejected: two flows compete for the same triggers, and `grill-with-docs`, `to-spec`, `to-tickets`, and `implement` cannot be called from a skill at all.
- **Invert only the overlapping pairs.** Rejected: a Matt user running `/to-tickets` in an AL repository would get GitHub-shaped tickets, which is where adoption breaks.

## Consequences

- No skill of ours orchestrates the flow; `/implement` chains `/tdd` → review → commit. `/implement` names only a bare `/code-review`, which resolves to Claude Code's built-in (plugin skills are namespaced), so the `al-implement` addition names both reviews: `mattpocock-skills:code-review` with `al-review`, and the built-in `/code-review` at effort `high` as the correctness pass.
- The additions are the ones in the hook's entry → addition table, among them `al-review`, the addition to `mattpocock-skills:code-review`, and `al-wayfinder`, the addition to `mattpocock-skills:wayfinder`. `al-build`, `al-arc42`, `al-walkthrough`, `al-next`, `al-pr-shepherd`, `al-lookup`, `al-environment-data`, and `al-webclient` are our own entries.
- The callee skills are `al-commit`, `al-pull-request`, `al-azure-devops-attachments`, and `al-clone-bcapps`. The plugin ships no model-tier setup and no session-history miner: Claude Code auto memory's feedback memories carry the steering-correction signal, so auto memory is the one place a steering correction becomes a standing lesson.
- The review verdict follows `mattpocock-skills:code-review`'s unmerged axes (Standards, Spec) plus a third, Correctness, from the built-in `/code-review`, instead of one merged verdict. The built-in ships with Claude Code, so it is neither a declared dependency nor drift-checked.
- Upstream can rename an entry skill or change its steps under an addition; the drift check must also resolve the entry names addition descriptions and the hook table use.
- `al-setup-matt-pocock-skills` names the AL verbs the entry's draft answers in the Tracker doc and proposes the Consumer repository's work item types and fields for the user to confirm; it chooses no tracker, organization, or project: the entry owns the Tracker doc and the `## Agent skills` line, and the skills name verbs and never types or fields.
