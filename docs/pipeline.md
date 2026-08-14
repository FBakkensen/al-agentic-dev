# The pipeline

Twenty-four skills carry a Business Central feature from a rough idea to a merged branch. You drive; nothing auto-chains. A skill that moves a task hands its outcome to `/al-routing`, which records the state and presents the moves that are open.

Every skill starts cold. The artifacts live in git — `CONTEXT.md` and `docs/adr/` at the repo root, `specs/<NNN>-<slug>/` on the feature branch — and task state lives in Azure DevOps work items under the customer's root work item, bound per repo by `al-ado.json`.

## Order

```
/al-grill-adr → /al-event-model → /al-design → /al-scope → /al-provision
   → /al-refine → /al-implement → /al-refactor
   → /al-code-review → /al-user-verification → /al-validate-breaking-changes
```

| Stage | Skill | Runs |
|---|---|---|
| Settle the domain | [`/al-grill-adr`](al-grill-adr.md) | once, up front |
| Settle the journey | [`/al-event-model`](al-event-model.md) | once — user- or API-facing features only |
| Settle the architecture | [`/al-design`](al-design.md) | once |
| Cut the work-item tree | [`/al-scope`](al-scope.md) | once |
| Refresh the toolchain | [`/al-provision`](al-provision.md) | the feature's first task |
| Plan the proof | [`/al-refine`](al-refine.md) | once per task |
| TDD — red→green, or green proved by mutation | [`/al-implement`](al-implement.md) | once per technical task |
| Reshape while green | [`/al-refactor`](al-refactor.md) | once per technical task |
| Review the landed diff | [`/al-code-review`](al-code-review.md) | once per slice, then once across the feature |
| Walk it with the user | [`/al-user-verification`](al-user-verification.md) | once per slice with a user surface |
| Check the shipped surface | [`/al-validate-breaking-changes`](al-validate-breaking-changes.md) | the feature's last task |

## Always available

| Skill | Use |
|---|---|
| `/al-routing` | The state engine — records each skill's outcome on the Azure DevOps work items and derives the open moves. |
| [`/al-next`](al-next.md) | Names the open moves when you resume a session or ask what is next. |
| [`/al-build`](al-build.md) | The compile-publish-test gate, and the only skill that runs the PowerShell substrate. |
| [`/al-agentic-dev-overview`](al-agentic-dev-overview.md) | The tour, and the user-level reply-shape snippet install. |
| [`/al-quiz`](al-quiz.md) | Tests your model of what just landed, one question at a time. |
| [`/al-sync-main`](al-sync-main.md) | Rebases onto main and renumbers object and field collisions. |

## Branches in the route

- **Backend-only features** — no human, no API consumer — skip `/al-event-model`, and get no verify tasks from `/al-scope`. `/al-user-verification` never runs.
- `/al-refine` → `/al-implement` → `/al-refactor` is the per-task loop. It repeats for every technical task in a slice.
- A slice closes on `/al-code-review`; its clean verdict, recorded through `/al-routing`, stamps the review evidence `/al-user-verification` needs to start.
- An `/al-code-review` must-fix re-enters `/al-implement` under the task that owns it, red first.
- `/al-validate-breaking-changes` opens only after the feature-wide review comes back clean.
