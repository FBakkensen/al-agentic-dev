# The journey on the Design story

Azure DevOps HTML only. Same item, two depths: overview stays visible; Journey slots sit in a `<details>` fold-out. Never a comment fallback. AzDO owns the font and dark theme makes heading+list+table look identical, so break sameness by changing each section's shape. A section that is not a comparison does not use a table. No images, no mermaid, no markdown file, no canvas copy, no five-column Role / Action / Business Event / View / Status matrix. Names are the citation. Rewrite the whole Description each time; mid-interview ugliness is allowed, a second copy is not. Separate major sections with `<hr>`.

Page order this skill owns: **Goal**, **Happy path**, **When it stops** (overview), then the **Journey slots** fold-out. Modules and brownfield arrive later.

1. `<h2>Goal</h2>` — two short paragraphs max. What the journey enables or catches, then how many Roles cooperate. Put the open gap in one bold line. No table. Title the work item `Design: <Feature journey>` for what the user does, not for the module.
2. `<h2>Happy path</h2>` — one `<h3>` per Role. Several steps for the same Role sit in one paragraph under that heading so the name is not repeated. Each step is Does, then You see (View plus Business Event), Status only when it flips. Prefer the Role name in the heading over a Unicode marker.
3. `<h2>When it stops</h2>` — two paragraphs with bold lead-ins, Before X vs After X. Not blockquotes (AzDO quotes have no visual bar) and not a table.
4. `<details><summary>Journey slots</summary>` — one short paragraph per step naming Role, Action, Business Event, View, and Status only when it flips. Not a five-column table.

---

Worked page (the Description body):

```html
<h2>Goal</h2>
<p>Catch item charge allocation mismatches at posting time, before an invoice exists. Two Roles cooperate across one five-step chain.</p>
<p><strong>Open: whether a mismatch keeps the Sales Order Released or sends it back to Open.</strong></p>
<hr>
<h2>Happy path</h2>
<h3>Order Processor</h3>
<p>Release Sales Order. You see the Sales Order page, Sales Order Released; Status → Released. Post Sales Order. You see Posting Progress, Posting Started.</p>
<h3>Posting Engine</h3>
<p>Validate Item Charge Allocation. You see Posting Progress, Item Charge Allocation Validated. Post Sales Invoice. You see the Posted Sales Invoice, Sales Invoice Posted. Record Allocation Audit Trail. You see Allocation Ledger Entries, drill-down from the Posted Sales Invoice.</p>
<hr>
<h2>When it stops</h2>
<p><strong>Before Validate.</strong> The Order Processor is still on the Sales Order. No invoice exists.</p>
<p><strong>After mismatch.</strong> Item Charge Allocation Mismatch Found. The Order Processor is back on the Sales Order with the allocation breakdown inline. The Sales Order stays Released. No Posted Sales Invoice exists.</p>
<details>
<summary>Journey slots</summary>
<p>Order Processor — Release Sales Order — Sales Order Released — Sales Order page — Status → Released.</p>
<p>Order Processor — Post Sales Order — Posting Started — Posting Progress.</p>
<p>Posting Engine — Validate Item Charge Allocation — Item Charge Allocation Validated — Posting Progress.</p>
<p>Posting Engine — Post Sales Invoice — Sales Invoice Posted — Posted Sales Invoice.</p>
<p>Posting Engine — Record Allocation Audit Trail — Allocation Ledger Entry Recorded — Allocation Ledger Entries, drill-down from the Posted Sales Invoice.</p>
</details>
```
