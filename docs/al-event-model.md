# al-event-model

## What it is for

Settles the user-facing journey before anyone designs code for it. The interview works at the altitude of what an external observer sees, in five slots: Role, Action, Business Event, View, and Status.

Getting this down first means the architecture interview does not have to re-litigate user-side picks halfway through.

## When you reach for it

- The feature has a human or API surface.
- `CONTEXT.md` terms and any domain ADRs are settled — run [`/al-grill-adr`](al-grill-adr.md) first.
- No Design User Story exists for the feature yet.

Skip it for backend-only work. A Job Queue entry, an install or upgrade codeunit, a scheduled task — nobody watches it happen, so there is no journey to settle. Those go straight to [`/al-design`](al-design.md).

## What it produces

One Design User Story under the bound Azure DevOps root. Git keeps `CONTEXT.md` and `docs/adr/` only.

The Description is one page. This skill owns Goal, Happy path, and When it stops. Happy path groups steps under an `<h3>` per Role. When it stops is two bold lead-ins, not a table. Every step still names its Role, Action, Business Event, View, and Status flip — folded under that Role. Module and brownfield sections arrive in [`/al-design`](al-design.md).

It reads in business language, not AL. `OnAfter*` subscribers, codeunit names, and page-extension names settle later, on the same page.
