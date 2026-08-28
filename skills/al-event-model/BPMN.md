# BPMN rendering

The `.bpmn` file is the only editable process source. SVG, PNG, and review HTML are generated from it; never draw a second SVG by hand.

## Renderer

The package-local renderer pins:

- `bpmn-to-image` 0.10.0
- `bpmn-js` 18.25.1
- `puppeteer` 24.34.0

`bpmn-js` imports and lays out the BPMN 2.0 XML. `bpmn-to-image` uses Puppeteer to export SVG and PNG. Keep the default footer and bpmn.io project logo; never pass `--no-footer`.

## Prepare once

Resolve the `bpmn-renderer` folder beside this file. In one PowerShell call, run:

`$env:PUPPETEER_SKIP_DOWNLOAD = 'true'; npm ci --prefix <bpmn-renderer-folder>`

Resolve the machine's existing Edge, Chrome, or Chromium executable. If Node.js, npm, or a browser is unavailable, return that exact blocker.

## Render

1. Write `.output/bpmn/<original-work-item-id>/process.bpmn`.
2. Change the working directory to that output folder so generated paths stay local to the review artifact.
3. In one PowerShell call, set the browser path and run:

   `$env:PUPPETEER_EXECUTABLE_PATH = '<browser-executable>'; npm exec --prefix <bpmn-renderer-folder> -- bpmn-to-image --scale=2 --min-dimensions=1600x900 "process.bpmn;process.svg,process.png"`

4. Treat a non-zero exit as a rendering failure. Keep `process.bpmn` as the source and both generated files as derived artifacts.

## Local review HTML

Write `.output/bpmn/<original-work-item-id>/process.html` as a self-contained page with:

1. Original User Story title
2. Trigger
3. Success guarantee
4. Minimal guarantee
5. the generated SVG embedded inline

Use no CDN, iframe, or remote asset. Open the local HTML in the GitHub Copilot app browser canvas when available; otherwise open it in the system browser or print its absolute path.

## Completion

The BPMN source imports without error. The SVG and PNG contain every lane, activity, gateway label, record, and named end event. Nothing is clipped at 1600 by 900 pixels. The user reviews the local HTML before the source and PNG are attached to Azure DevOps.
