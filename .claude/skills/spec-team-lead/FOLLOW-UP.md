# Follow-up issue shape

File a follow-up for a finding outside a PR's scope, or one found after its merge. It comes out decided, so the teammate builds it without asking.

Title: an imperative summary of the outcome. Label: `ready-for-agent`. Then attach it as a sub-issue of the spec; the recipe is in [GITHUB.md](GITHUB.md).

```markdown
## Parent

#<spec> (<spec title>)

## What to build

<What is wrong, with its source: the PR, the review, and the file:line.>

**Decisions:**
1. **<short name>.** <the exact behaviour or wording to build>
2. …

## Acceptance criteria

- [ ] <one checkable line per decision, naming the file it lands in>
- [ ] <contract-test pins for the new statements, as short phrases that tolerate line endings>
- [ ] <the eval rule from CLAUDE.md: which case reruns, or "no description changes, so no eval runs">
- [ ] The gates and the Full suite pass, and the version is unchanged.

## Blocked by

<issues, or "None.">

## Notes

**Source:** <the review and PR>.
**Why this choice:** <the reasoning behind any decision that had options>.
**Overlap:** <other open work touching the same files; resolve by merging `origin/main`>.
**Out of scope:** <anything deliberately left, and who owns it>.
```

When a decision corrects an earlier decision, name the issue and decision number it supersedes.
