# al-validate-breaking-changes

## What it is for

Answers one question: did this feature break a released public API? It is the AppSource-style validation — per country, install and upgrade, against the baseline release cached at provision time — and it catches breaks that the compile-time AppSourceCop pass inside the ordinary build gate never reaches.

## When you reach for it

- The feature's `kind: breaking-change` task is open — the feature's last task, opened by a clean feature-wide [`/al-code-review`](al-code-review.md).
- The same task after a red run, once you have cleared what its `Last run:` line names.

[`/al-build`](al-build.md) is a prerequisite skill — it owns the validation run. The baseline it validates against was cached by [`/al-provision`](al-provision.md), so an empty cache sends you back there.

## What it produces

The task flipped `done` or `blocked`, and on a break, a report for you.

| Result | Task |
|---|---|
| No break, or detection disabled | `done` |
| Breaking change detected | `blocked`, naming the count of broken members and the first object |
| Prerequisite failure — missing `AppSourceCop.json`, `mandatoryAffixes`, `supportedCountries`, or an empty baseline cache | `blocked`, naming the prerequisite and that no verdict was reached |
| Environment failure — container creation, image pull, compile | `blocked`, naming the failure and that no verdict was reached |

## Worth knowing

**A detected break is never self-resolved.** Whether a break is acceptable is a merge-time business call: intended means a major version bump and an accepted break; accidental means the schema change gets fixed. The skill reports the broken members and those two options, then stops. The decision, the AL, and the version are yours.
