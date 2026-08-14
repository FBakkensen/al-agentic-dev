# Stacked-slice delivery

How a feature built with these skills ships, and the two one-time repository settings a consumer repo needs before the first stack.

## The delivery model

- One **root PR** per feature, from `feature/ab<rootId>-<slug>` into the default branch. It mirrors the customer's root work item and carries the feature-level look: the full diff, the user-verification evidence, and the release notes for the consultant. It merges **last**, shipping the feature in one release moment.
- One **slice PR** per vertical slice, from `slice/ab<sliceId>-<slug>`, based on and targeting its stack base — the feature branch, or the branch of the slice it consumes. `/al-scope` records each slice's branch and stack base on the slice story when it cuts the tree.
- Slices merge into the feature branch with **merge commits** — a squash inside the stack rewrites the `AB#<id>` commit identity the slice reviews select by, and is a defect.
- After a lower layer merges and its branch is deleted, GitHub retargets dependent PRs to the merged-into branch; every dependent slice then updates from the feature branch and verifies no false conflicts.
- Slice PRs get the per-slice review: the repository ruleset fires the automatic Copilot code review on the PR (drafts and on-push re-reviews included), and `/babysit-pr` loops it to Clean — fixes actionable findings and PR-caused CI failures, replies, resolves, never merges. Only a Clean slice PR merges.
- While the feature lives, `/al-sync-main` merges main into the feature branch (never a rebase under an open stack) so the stack stays current.

## One-time consumer-repo setup

### 1. CI triggers must cover non-default PR bases

Workflows that gate PRs must trigger on `pull_request` **without a `branches:` filter**:

```yaml
on:
  push:
    branches: [main]
  pull_request:
```

A `pull_request` trigger filtered to `branches: [main]` runs no checks on mid-stack PRs — their base is a `feature/*` or `slice/*` branch — so every slice PR would merge unchecked. Keep the `push` trigger filtered; the PR trigger carries the stack.

### 2. Extend the Copilot code review ruleset to feature branches

The automatic Copilot code review is driven by a repository ruleset (rule type `copilot_code_review`) whose default include is only `~DEFAULT_BRANCH` — slice PRs targeting a feature branch get no review, silently. Extend the ruleset's target branches to include `refs/heads/feature/*`:

Repository **Settings → Rules → Rulesets →** the Copilot review ruleset → **Target branches** → add `feature/*`. Enable *review draft pull requests* and *re-review on push* so the loop sees every iteration.

Requesting the `copilot-pull-request-reviewer` bot per PR through the REST `requested_reviewers` endpoint is not a substitute: on GitHub Enterprise tenants the write returns 2xx and silently no-ops. The ruleset is the mechanism.
