# al-refine

## What it is for

Opens one task and writes the proof it needs. A technical task gets a Test Specification — the thing [`/al-implement`](al-implement.md) drives red to green. A verify task gets a Verification Plan — the thing [`/al-user-verification`](al-user-verification.md) walks with the user.

One task per run, regenerated whole against the current app and tests. Everything decided at scope time stays: title, description, dependency edges, slice, constraints, acceptance intent.

## When you reach for it

- A task has no proof written yet and the router names it.

That is the whole trigger. Provision and breaking-change tasks are declined — they go to their own skills and never pass through here.

## What it produces

For a **technical** task: `New and Modified Objects` at signature level with bodies omitted, exactly one coverage table (`Expected Behaviors` or a `Decision Matrix`) where every row names the AL test procedure covering it, and one AAA case per test procedure — Unit cases first, then Integration. The proof is reported to `/al-routing`, which stamps the task refined.

For a **verify** task: Journey Examples, Contract Examples, and a Usability Review, each derived from the slice's observable user or API surface and quoting the Design happy path. The plan is reported to `/al-routing`, which stamps the task planned.

Every Integration case, recorded journey, and Contract example sits above the cheapest layer that could hold the behaviour, so each one owes a `Contract notes:` line saying why the layer below cannot hold it. Those are the lines worth your attention when the skill hands back.
