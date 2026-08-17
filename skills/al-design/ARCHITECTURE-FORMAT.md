# The Design story page

One Azure DevOps Description per feature — the same work item `/al-event-model` opened. Same item, two depths: overview always visible; agent tails in `<details>` fold-outs on that Description. Never a comment fallback, never a second work item, never a git file. Agent and consultant read this page the same way. HTML only. AzDO owns the font; dark theme makes heading+list+table look identical, so break sameness by changing each section's shape. A section that is not a comparison does not use a table. No images, no mermaid, no markdown file, no session copy, no five-column journey matrix. Declarative, present tense — one sentence per fact, showing the object, the field, the event; no workflow narration, no history; the story of how the design got here belongs in the commit message. Separate major sections with `<hr>`.

Rewrite the whole Description each time, in this order: **Goal**, **Happy path**, **When it stops** (overview), then fold-outs **Journey slots** and **Modules and brownfield**. Omit Happy path and When it stops on a backend-only feature. Mid-interview ugliness is allowed; drift from this order is not.

## Section order

1. **Goal** — `<h2>Goal</h2>` then two short paragraphs max, in BC vocabulary. Put the open gap in one bold line. No table.
2. **Happy path** — one `<h3>` per Role, several steps in one paragraph under that heading. Status only when it flips. Not a list that repeats the Role, not a table.
3. **When it stops** — two paragraphs with bold lead-ins, Before X vs After X. Not blockquotes (AzDO quotes have no visual bar) and not a table.
4. **Journey slots** — keep the fold-out `/al-event-model` wrote.
5. **Modules and brownfield** — one `<details><summary>Modules and brownfield</summary>` fold-out. Inside it: one short paragraph per module, not a table — name, folder (`new` or the existing folder), `Precedent` suffix (`reused: <Microsoft object>`, `pattern: <source>`, or `none`), what it Owns, what it Does not. Owns includes which decision is reproducible from its inputs alone. Then labelled brownfield paragraphs **Read** / **Insert** / **Profile** / **Reshape** / **Remove**. Omit an empty group. Merge sibling objects onto one line. Not a table.

Object level throughout. Fields, signatures, and parameter lists shift during TDD and rot here.

If a comparison table is ever earned, its chrome is `style="border-collapse:collapse;width:100%;"` on `table` and `style="border:1px solid #8a8a8a;padding:8px 10px;text-align:left;"` on every `th` and `td`. No background colour. No font colour.

## Slices

A slice is one initiated behaviour: trigger → command → event → state → view. The happy path already settled Who, Does, and You see. What settles here is which module owns the trigger and which brownfield object it extends. Backend-only slices carry the trigger source in what the module Owns.

| Pattern | Trigger source |
|---|---|
| **Command** | page action, report request — user-initiated |
| **Automation** | event subscriber, Job Queue, install/upgrade — system-initiated; the most common AL pattern |
| **Translation** | API page, web service, webhook — external-system-initiated |
| **View** | page render, FlowField, report layout — read-only |

## Worked page

```html
<h2>Goal</h2>
<p>Catch item charge allocation mismatches while the invoice is still unposted, and record one Allocation Ledger Entry per resolved allocation.</p>
<p>Posting is intercepted at exactly one place — event subscribers on Sales-Post codeunit 80. <strong>Open: none.</strong></p>
<hr>
<h2>Happy path</h2>
<h3>Order Processor</h3>
<p>Release Sales Order. You see the Sales Order page, Sales Order Released; Status → Released. Post Sales Order. You see Posting Progress, Posting Started.</p>
<h3>Posting Engine</h3>
<p>Validate Item Charge Allocation. You see Posting Progress, Item Charge Allocation Validated. Post Sales Invoice. You see the Posted Sales Invoice.</p>
<hr>
<h2>When it stops</h2>
<p><strong>Before Validate.</strong> The Order Processor is still on the Sales Order. No invoice exists.</p>
<p><strong>After mismatch.</strong> Item Charge Allocation Mismatch Found. The Sales Order stays Released. No Posted Sales Invoice exists.</p>
<details>
<summary>Modules and brownfield</summary>
<p><strong>Charge Validation</strong> (new, src/ChargeValidation/) · pattern: Document Totals. Owns the allocation-balance decision from read rows — the unit-test surface. Does not write.</p>
<p><strong>Charge Post Subscribers</strong> (new, src/ChargePostSubscribers/) · none. Owns subscribers on Sales-Post codeunit 80 and every write. Does not modify Sales-Post.</p>
<p><strong>Read.</strong> Sales Header, Sales Line, Item Charge Assignment (Sales).</p>
<p><strong>Insert.</strong> Allocation Ledger Entry.</p>
<p><strong>Reshape.</strong> Pageextensions on Sales Order and Posted Sales Invoice.</p>
</details>
```
