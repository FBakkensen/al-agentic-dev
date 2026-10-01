---
name: al-arc42
description: Use when settled Business Central architecture content needs the official arc42 v9.0-EN Building Block Level 1, Runtime View, or post-implementation Level 2 format and a local HTML review.
---

# al-arc42 - format the architecture

In: settled architecture content from /al-to-spec, /al-next, /al-implement, /al-improve-codebase-architecture, or /al-simplify. The caller owns meaning. This skill applies the official structure in [ARC42.md](ARC42.md), creates the review surface, and returns publishable artifacts.

Usually ask none. Before the first tool call, write one sentence. Update on an important finding or a changed direction; close with the outcome first, standing on its own.

## Apply the requested views

- **Building Block Level 1:** Whitebox Overall System, overview diagram, Motivation, Contained Building Blocks, Important Interfaces, and black boxes.
- **Runtime View:** one named architecturally relevant scenario, its interaction diagram or steps, and notable interaction details.
- **Building Block Level 2:** one selected Level 1 module as a white box, using the same white-box structure and black boxes for proven internals.

The stable current-state Building Block View and any Runtime View sit under `Implementation Decisions` in the Original work item. A change overlay goes to the executable item's comment and receipt, never to the Original work item. Create only the views named by the caller. Level 1 records intended module contracts. Level 2 records stable implementation structure and may be omitted for a simple module.

An implementation change map is a change overlay on the Building Block View, not a fourth arc42 view. Use Level 2 when one Level 1 module changed. When several Level 1 modules changed, add a Level 1 impact overview and the Level 2 white boxes needed to explain their internal object relations. Add a Runtime View only for important order, transaction, or error behavior.

Build the overlay from the landed diff and traced code connections. Include every changed production AL object, only the immediate unchanged collaborators needed for context, and changed tests in a separate Proof group. Mark nodes `Added`, `Changed`, `Existing`, or `Removed`. Label edges with the exact procedure, event, interface implementation, or Read/Insert/Modify relation. Use a current-state diagram without change markers when publishing stable Level 2 to the Original work item.

Every BC object, table, field, procedure, event, enum value, and dialog text shown comes from a lookup in this session. Preserve the caller's domain terms, module names, and interface names exactly.

## Write the local review

Regenerate `.output/arc42/<original-work-item-id>/architecture.html` from the settled content. Include the Original work item title, executable-item ID when an implementation overlay is present, the exact arc42 headings, a change legend, explanatory text, and inline SVG diagrams. The HTML is a disposable review surface; the Azure DevOps Original work item and executable-item receipt remain the records.

Show the HTML through `show_widget`, falling back to an Artifact, then to the local file opened in the system browser or named by its absolute path. The user reviews the actual page before publication.

## Return publishable artifacts

Save each diagram as SVG and an Azure DevOps-safe PNG. Capture the PNG with an installed `msedge`, `chrome`, or `chromium` and `--headless --screenshot`. Return the local HTML path, SVG and PNG paths, alt text, the executable-item comment fragment for a change overlay, and the Original work item fragment for stable architecture, placed under `Implementation Decisions` in Description, or in Repro Steps on a Bug.

## Close

The pass ends when every source node appears in the PNG, the caller has the paths needed for attachment, and the local HTML and the Original work item fragment contain the same view when an Original fragment is requested. An overlay-only call closes on the HTML, the PNG, and the comment fragment. Commit no `.output/` artifact.
