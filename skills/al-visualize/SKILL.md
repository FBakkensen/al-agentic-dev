---
name: al-visualize
description: Use when settled BPMN, arc42 Runtime View, Building Block View, or BC-anatomy delta content needs an editable diagram and Azure DevOps-safe PNG.
---

# al-visualize - render the settled view

In: settled semantic content from /al-event-model, /al-design, /al-implement, /al-refactor, or /al-next. The calling skill owns meaning; this skill owns layout and portable renderings.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Usually ask none. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Choose the notation

- **Business process:** BPMN 2.0 source and PNG.
- **Runtime View:** sequence-style SVG source and PNG.
- **Building Block View:** arc42 box-and-connection SVG source and PNG.
- **BC-anatomy delta:** changed objects, schema, events, permissions, translations, tests, and external edges as SVG source and PNG.

Keep one notation per diagram. Use stable IDs and labels so source diffs remain readable.

## Ground the content

Every BC object, table, field, procedure, event, enum value, and dialog text shown comes from a lookup in this session. Preserve domain terms and module names exactly as the owning artifact states them.

## Render

When canvas tools are available, use `list_canvas_capabilities`, `open_canvas`, and `invoke_canvas_action`. On either the GitHub Copilot app or bare CLI without them, write the SVG directly and invoke an installed `msedge`, `chrome`, or `chromium` with `--headless --screenshot` to produce the PNG; for BPMN, keep the `.bpmn` source beside the equivalent SVG rendering. If neither canvas nor a named browser executable exists, return that exact blocker and do not claim a publishable diagram.

Lay out the main flow left to right, keep crossings rare, show module interfaces at boundaries, and make gateway labels and end outcomes readable at Azure DevOps Description width.

Write artifacts under `.output/diagrams/<slug>/`. Keep editable source beside a PNG snapshot. These are ignored build artifacts and are never committed.

## Check the handoff

The source reopens without missing nodes. The PNG contains every source node, readable labels, and no clipped edges. Return both absolute paths plus alt text to the calling skill; that skill attaches them and embeds the PNG.

## Close

On success, finish with the rendered view, source path, PNG path, and the one architectural fact the picture makes visible. In the GitHub Copilot app, open or focus the canvas; in the CLI, print the verified artifact paths. On the named renderer blocker, finish with that blocker and the editable source path only.
