# al-event-model

## What it is for

Settles the user-facing journey before anyone designs code for it. The interview works at the altitude of what an external observer sees, in five slots: Role, Action, Business Event, View, and Status.

Getting this down first means the architecture interview does not have to re-litigate user-side picks halfway through.

## When you reach for it

- The feature has a human or API surface.
- `CONTEXT.md` terms and any domain ADRs are settled — run [`/al-grill-adr`](al-grill-adr.md) first.
- No `event-model.md` exists for the feature yet.

Skip it for backend-only work. A Job Queue entry, an install or upgrade codeunit, a scheduled task — nobody watches it happen, so there is no journey to settle. Those go straight to [`/al-design`](al-design.md).

## What it produces

`event-model.md` in the feature's spec folder, `specs/<NNN>-<slug>/`, created if it is not there.

It holds one timeline in temporal order. Every step names its Role, its Action, its Business Event, its View, and the Status field it flips — or `—` where it flips none. Every branch the interview surfaced gets its own section. More than one Role means swimlanes.

It reads in business language, not AL. `OnAfter*` subscribers, codeunit names, and page-extension names settle later, in `architecture.md`.
