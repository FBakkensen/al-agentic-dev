# Feature: Sales Document Posting, Item Charge Allocation Validation (kanban fixture)

Synthetic fixture for the al-kanban canvas extension. Derived from `plugins/al-agentic-dev/references/examples/tasks/`, enriched with `phase:` values covering every board column. Not a real feature.

## Goal

Catch item charge allocation mismatches at posting before invoice posts, surface cause inline on document, produce deterministic audit trail.

## Slices

- **post-validates-allocation** — main slice, exercises every technical column plus a blocked card.
- **audit-trail**, **charge-summary-fact-box**, **mismatch-notification**, **posting-preview** — one done technical + one verify task each, so every verify-strip column is populated.
