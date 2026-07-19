# Output Format

Render this template. Drop empty sections; User-Facing Changes precedes Technical Summary. Release notes are self-contained: no PR or issue links.

Version → `summary.appJsonDiff.version.new`, else `summary.toVersion`. BC compatibility → `summary.appJsonDiff.application`.

## Canonical template

```markdown
# Release Notes - Version <X.Y.Z>

**Release Date**: <YYYY-MM-DD>
**Business Central Compatibility**: <BC version range from summary.appJsonDiff.application>

## User-Facing Changes

### 🚀 New Features

- **<Feature name based on `area`>**
  - <`desc` — what the user can now do>
  - <`details` — how to reach it: page, action, field>
  - <Why it matters — business value>

### ✨ Improvements

- **<`area`>**: <`desc` — user benefit, not implementation>

### 🐛 Bug Fixes

- **<`area`>**: <What was wrong, how it affected users, now resolved>

### ⚠️ Breaking Changes & Migration Notes

- **<`change`>**: <`migration` — exact, imperative, ordered steps>

---

## Technical Summary

### Architecture Changes

- <`technical` items with category `refactor` that affect architecture — one line each>

### API Changes

- <New, modified, or deprecated procedures, events, or interfaces — one line each>

### Database Changes

- <Table additions, field additions, obsolete markers — one line each>

### Performance Optimizations

- <`technical` items with category `perf` — one line each>

### Dependency Updates

- <Version bumps, runtime updates, drawn from `summary.appJsonDiff` — one line each>
```

## Slot mapping

| Section | Source | Type filter |
|---|---|---|
| New Features | PR records | `type == "feature"` |
| Improvements | PR records | `type == "improvement"` |
| Bug Fixes | PR records | `type == "bugfix"` |
| Breaking Changes | PR records | `type == "breaking"` |
| Architecture Changes | PR records + judgement | `type == "technical"` AND `category == "refactor"` AND architecture-affecting |
| API Changes | PR records + judgement | Public surface change (procedure/event/interface) |
| Database Changes | PR records + judgement | Table or field change |
| Performance Optimizations | PR records | `type == "technical"` AND `category == "perf"` |
| Dependency Updates | `summary.appJsonDiff` | Runtime, platform, or dependency version delta |

## Section rules

| Rule | Contract |
|---|---|
| Empty section | Omit its header. |
| Order | User-Facing Changes stays above Technical Summary. |
| Citations | No PR numbers, issue numbers, or URLs; names are the citation. |
| Version | Use the summary source above; do not infer. |
| Emoji | Keep `🚀`, `✨`, `🐛`, `⚠️` exactly on section headers only. |
| Migration | Imperative and ordered: `Replace X with Y. Re-run upgrade codeunit. Recompile dependent extensions.` |
