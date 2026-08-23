---
name: al-arc42
description: Use when settled Business Central architecture content needs the official arc42 v9.0-EN Building Block Level 1, Runtime View, or post-implementation Level 2 format and a local HTML review.
---

# al-arc42 - format the architecture

In: settled architecture content from /al-event-model, /al-design, /al-implement, or /al-refactor. The caller owns meaning. This skill applies the official structure in [ARC42.md](ARC42.md), creates the review surface, and returns publishable artifacts.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Usually ask none. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Apply the requested views

- **Building Block Level 1:** Whitebox Overall System, overview diagram, Motivation, Contained Building Blocks, Important Interfaces, and black boxes.
- **Runtime View:** one named architecturally relevant scenario, its interaction diagram or steps, and notable interaction details.
- **Building Block Level 2:** one selected Level 1 module as a white box, using the same white-box structure and black boxes for proven internals.

Create only the views named by the caller. Level 1 records intended module contracts. Level 2 records stable implementation structure and may be omitted for a simple module.

An implementation change map is a change overlay on the Building Block View, not a fourth arc42 view. Use Level 2 when one Level 1 module changed. When several Level 1 modules changed, add a Level 1 impact overview and the Level 2 white boxes needed to explain their internal object relations. Add a Runtime View only for important order, transaction, or error behavior.

Build the overlay from the landed diff and traced code connections. Include every changed production AL object, only the immediate unchanged collaborators needed for context, and changed tests in a separate Proof group. Mark nodes `Added`, `Changed`, `Existing`, or `Removed`. Label edges with the exact procedure, event, interface implementation, or Read/Insert/Modify relation. Use a current-state diagram without change markers when publishing stable Level 2 to the Feature.

Every BC object, table, field, procedure, event, enum value, and dialog text shown comes from a lookup in this session. Preserve the caller's domain terms, module names, and interface names exactly.

## Write the local review

Regenerate `.output/arc42/<feature-id>/architecture.html` from the settled content. Include the Feature title, executable-item ID when an implementation overlay is present, the exact arc42 headings, a change legend, explanatory text, and inline SVG diagrams. The HTML is a disposable review surface; the Azure DevOps Feature and executable-item receipt remain the records.

Open the HTML in the GitHub Copilot app browser canvas when available. In the CLI, open it with the system browser or print its absolute path. The user reviews the actual page before publication.

## Return publishable artifacts

Save each diagram as SVG and an Azure DevOps-safe PNG. Use an installed `msedge`, `chrome`, or `chromium` with `--headless --screenshot` when the browser canvas cannot capture it. Return the local HTML path, SVG and PNG paths, alt text, the executable-item comment fragment for a change overlay, and the Feature Description fragment for stable architecture.

## Close

The pass ends when the local HTML and Feature fragment contain the same view, every source node appears in the PNG, and the caller has the paths needed for attachment. Commit no `.output/` artifact.
