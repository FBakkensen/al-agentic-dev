# Feature: Sales Document Posting, Item Charge Allocation Validation

| | |
|---|---|
| **Slug**         | sales-charge-validation |
| **ADR**          | ADR-0007 |
| **Event model**  | [../event-model.example.md](../event-model.example.md) |
| **Architecture** | [../architecture.example.md](../architecture.example.md) |
| **Tasks**        | 6 technical + 2 verify |
| **Slices**       | post-validates-allocation, audit-trail |

## Goal

Catch item charge allocation mismatches at posting before the invoice posts, surface the cause inline on the document, and record one `Allocation Ledger Entry` per resolved allocation, tied to its source line.

> A fresh `/al-scope` run also brackets the feature with two ops tasks: `kind: provision` as `T-001` first, `kind: breaking-change` last. This example omits them to keep the focus on slice, `Test Specification`, and `Verification Plan` shapes. With them present, the feature tasks would start at `T-002`. See Ops kinds under [Status lifecycle](../../task-lifecycle.md#status-lifecycle).

## Slices

- **post-validates-allocation** — the Order Processor releases and posts a `Sales Header` with `Item Charge Assignment (Sales)` rows. A balanced allocation posts to a Posted Sales Invoice; a mismatched allocation halts posting with an inline breakdown on the `Sales Order Card`.
- **audit-trail** — after a successful `Post` on a balanced allocation, the audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from the `Posted Sales Invoice`.

## Execution order

The `NNN-` prefix carries the run order. The `T-MMM` id stays a stable locator. Here they diverge: `050-T-006` (slice-one verify) runs before `060-T-005` (slice-two first technical).
