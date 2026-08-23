---
name: al-arc42
description: Use when settled Business Central architecture content needs the official arc42 v9.0-EN Building Block Level 1, Runtime View, or post-implementation Level 2 format and a local HTML review.
---

# al-arc42 - format the architecture

In: settled architecture content from /al-event-model, /al-design, /al-implement, or /al-refactor. The caller owns meaning. This skill applies the official structure in [ARC42.md](ARC42.md), creates the review surface, and returns publishable artifacts.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Usually ask none. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Apply one view

- **Building Block Level 1:** Whitebox Overall System, overview diagram, Motivation, Contained Building Blocks, Important Interfaces, and black boxes.
- **Runtime View:** one named architecturally relevant scenario, its interaction diagram or steps, and notable interaction details.
- **Building Block Level 2:** one selected Level 1 module as a white box, using the same white-box structure and black boxes for proven internals.

Use only the requested view. Level 1 records intended module contracts. Level 2 records stable implementation structure and may be omitted for a simple module.

Every BC object, table, field, procedure, event, enum value, and dialog text shown comes from a lookup in this session. Preserve the caller's domain terms, module names, and interface names exactly.

## Write the local review

Regenerate `.output/arc42/<feature-id>/architecture.html` from the settled content. Include the Feature title, the exact arc42 headings, explanatory text, and inline SVG diagrams. The HTML is a disposable review surface; the Azure DevOps Feature remains the design record.

Open the HTML in the GitHub Copilot app browser canvas when available. In the CLI, open it with the system browser or print its absolute path. The user reviews the actual page before publication.

## Return publishable artifacts

Save each diagram as SVG and an Azure DevOps-safe PNG. Use an installed `msedge`, `chrome`, or `chromium` with `--headless --screenshot` when the browser canvas cannot capture it. Return the local HTML path, SVG and PNG paths, alt text, and the Feature Description fragment that follows [ARC42.md](ARC42.md).

## Close

The pass ends when the local HTML and Feature fragment contain the same view, every source node appears in the PNG, and the caller has the paths needed for attachment. Commit no `.output/` artifact.
