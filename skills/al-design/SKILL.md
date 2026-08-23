---
name: al-design
description: Use when an Azure DevOps Feature needs its BC shape, deep-module boundaries, or arc42 Building Block Level 1 defined or revised.
---

# al-design - shape the modules

In: the Feature with its original request and process model. This conversation owns architecture and data shape before code: canonical BC shape, Level 1 modules, their responsibilities, and their caller-visible interfaces. Implementation details remain open. If Azure DevOps work-item tools are unavailable, show the exact Description update and attachment set, then stop without creating a substitute record.

Ask one substantive question per message. Show the competing module boundaries and their consequences when the choice is real. Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool.

## Speak in BC shapes

Start with the canonical shape: master data with entries, a document flavor, a journal plus posting extension, setup, dimensions, or another verified Base App precedent. Maintain `docs/patterns.md` only when this repo gains its first example of a reusable BC shape.

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

Ask /al-arc42 to apply the official template and create the local architecture review HTML, editable SVG, and Azure DevOps-safe PNG. The user reviews the HTML before publication. Embed the PNG and black box text in the Feature Description; attach the SVG. Detect attachment upload separately from work-item editing; when upload is unavailable, show both artifact paths and exact manual attach steps, then resume after the user supplies the attachment URLs. Level 1 records intended boundaries. Level 2 waits for implementation evidence.

## Close

The pass ends when every important behavior has one module owner, each caller-visible interface is named, and the Feature contains the accepted Level 1 view. Commit any `docs/patterns.md` change with a plain descriptive message at every exit. No `docs/design.md` copy is created.
