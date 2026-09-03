---
name: al-design
description: Use when an Azure DevOps Original User Story needs its BC shape, deep-module boundaries, or arc42 Building Block Level 1 defined or revised.
---

# al-design - shape the modules

In: the Original User Story with its original request and process model. This conversation owns architecture and data shape before code: canonical BC shape, Level 1 modules, their responsibilities, and their caller-visible interfaces. Implementation details remain open. If Azure DevOps work-item tools are unavailable, show the exact Description update and attachment set, then stop without creating a substitute record.

Ask one substantive question per message. Show the competing module boundaries and their consequences when the choice is real. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Speak in BC shapes

Start with the canonical shape: master data with entries, a document flavor, a journal plus posting extension, setup, dimensions, or another verified Base App precedent. Maintain `docs/patterns.md` only when this repo gains its first example of a reusable BC shape.

▶ execution · task · canonical-shape survey: how the Base App models the concept — tables, seams, events — read in .bcapps/release → precedent table with file:line

Every Base App seam, table, field, object, procedure, event, or enum value named comes from a lookup in this session. Reach for the platform before designing custom structure.

## Deep modules

A module earns its place by hiding substantial behavior behind a small interface. Apply the deletion test: complexity that disappears was pass-through; complexity that spreads across callers needs one owner. A seam needs real variation; one implementation alone does not justify an AL interface.

## Building Block View

Use the arc42 Building Block View, Level 1:

- overview diagram
- Motivation
- Contained Building Blocks
- Important Interfaces
- one black box description per important module: Purpose/Responsibility, Interface(s), and only relevant optional fields

▶ mechanical · task · /al-arc42 the Building Block Level 1 view from the settled black boxes → HTML path, SVG and PNG paths, alt text, publishable fragments

Open the HTML in the browser canvas; the user reviews it before publication.

▶ mechanical · task · /al-azure-devops-attachments the PNG and SVG to the Original User Story → verified attachment URLs

Embed the verified PNG URL, explanatory text, and black boxes under `Building Block View` in the Original User Story Description. Missing MCP attachment support is not a blocker; authentication trouble stays with that skill until the Azure CLI token works. Level 1 records intended boundaries. Level 2 waits for implementation evidence.

## Close

The pass ends when every important behavior has one module owner, each caller-visible interface is named, and the Original User Story contains the accepted Level 1 view. At every exit:

▶ mechanical · task · /al-commit the complete worktree — any `docs/patterns.md` change and the rest — work items <ids> → commit hashes and subjects, remaining worktree

No `docs/design.md` copy is created.
