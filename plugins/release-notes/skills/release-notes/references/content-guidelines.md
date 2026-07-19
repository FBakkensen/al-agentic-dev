# Content Guidelines

Rendered-entry rules. Apply with [output-format.md](output-format.md).

## User-Facing entries — primary focus

| Rule | Required |
|---|---|
| Plain language | Prefer `the Posting Date validation` to `subscriber on OnAfterValidateEvent`. |
| Specific surface | Name the `Configuration Card page`, `the "Apply Template" action`, or field; never `the page` or `a setting`. |
| Value-led | Lead with what users can do or no longer hit. Put implementation in Technical Summary. |
| Self-contained | No PR numbers, issue numbers, or URLs. |
| One fact | One line; no semicolon chains or nested clauses. |

## Technical Summary entries

- One line per item.
- State what changed, not how: `Replaced NoSeriesManagement with codeunit "No. Series" across posting.`
- Group refactors that move the same boundary.

## Drop list

| Drop | Why |
|---|---|
| Hedging — `should`, `may`, `tends to`, `it is now possible to` | Release notes ship facts, not maybes |
| Process noise — `as part of this release`, `we have introduced` | Reader knows it's a release note |
| Passive voice on user actions | Active voice names the actor — `Copy a configuration to multiple target items in one action.` |
| Implementation verbs in user-facing prose — `refactored`, `extracted`, `wired up` | Belongs in Technical Summary, not User-Facing |
| PR/issue references in body text | Self-contained rule — names are the citation |

## Phrasing — Yes/No

| | |
|---|---|
| _Avoid_: | `It is now possible to copy configurations to multiple items.` |
| Use: | `Copy a configuration to multiple target items in one action.` |
| _Avoid_: | `Various improvements to configuration logic.` |
| Use: | `The Item Configurator List page applies template overrides correctly when items share a template group.` |
| _Avoid_: | `Fixed a bug where things didn't work right.` |
| Use: | `Posting a sales invoice with a blocked customer no longer leaves a stray Cust. Ledger Entry.` |

## Good user-facing entry

```markdown
### 🚀 New Features

- **Bulk Configuration Copy**
  - Copy configuration settings from one item to multiple target items in a single operation
  - Access via the "Copy Configuration" action on the Item Configurator List page
  - Reduces setup time when configuring similar products
```

## Good technical entry

```markdown
### Database Changes

- Added `NALICF Bulk Copy Log` table for tracking copy operations
- New field `Last Bulk Copy Date` on Configuration Header
```

## Bad entries

```markdown
- Fixed bug in PR #142
- Updated code per user request
- Various improvements to configuration logic
```

They fail: PR numbers break self-containment; `code` and `logic` name no surface; readers cannot see their impact.

`Updated logic` means the JSONL line is vague. [Deep Dive](pr-classification.md), fix the line, then re-render; never paper over it while rendering.
