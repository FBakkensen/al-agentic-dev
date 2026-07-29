---
name: al-validate-breaking-changes
description: Run the feature's final breaking-change gate against the provisioned baseline. The last move before merge; a detected break goes to a human.
disable-model-invocation: true
---

# Breaking-change gate

The gate answers one question: did this feature break a released public API? It is the AppSource-style validation — per country, install and upgrade — run against the baseline release cached at provision time, and it catches breaks that the compile-time AppSourceCop pass inside the ordinary build gate never reaches.

## Precondition

Run it on the feature's `kind: breaking-change` task while it is open — the feature's last task, opened by the feature-done review. Any other kind, or a task already settled, closes on one Stop line with no run. Task-file state is `/al-routing`'s.

## Run

Ask `/al-build` to run the breaking-change validation against the provisioned baseline. Take its verdict as the result, read by exit code:

| Result | The outcome to report |
|---|---|
| no break, or detection disabled — exit `0` | clean; the gate is clear |
| breaking change detected — exit `3` | red: the count of broken members and the first object named |
| prerequisite failure — exit `4`: `AppSourceCop.json`, `mandatoryAffixes`, or `supportedCountries` missing; current app not found; baseline cache empty or holding no baseline for this app | red: the missing prerequisite, that no verdict was reached, and `/al-provision` when the cache is empty or stale |
| environment failure — exit `1` or any other code: container creation, image pull, current-app compile | red: the failure, and that no verdict was reached |

## A detected break belongs to the developer

Whether a break is acceptable is a merge-time business call: intended means a major version bump and an accepted break; accidental means the schema change gets fixed. Report the broken members and those two options, and leave the decision, the AL, and the version to the developer. An accepted intended break is the user's early close of the task; the version bump is separate work.

## Close

Name the outcome in one line — the feature's last gate is clear, or the run is red on the named cause.
Then `/al-routing`.
