# al-kanban — canvas extension

Live kanban board over the al-agentic-dev task pipeline. Renders the `specs/<NNN>-<slug>/tasks/` folder of the current workspace as two strips — technical tasks (Ready → Refined → Implemented → Refactored → Mutated, swimlanes per slice) and verify tasks (Waiting on gate → Opened by review → Planned → Page-scripted → Verified) — plus provision/breaking-change chips. Column placement derives from `status:` + `phase:` frontmatter.

**Read-only.** The board never writes task files; skills remain the only writers. The **Advance** button on a card sends the next pipeline command (e.g. `Run the /al-refine skill on task T-003`) into the chat session and marks the card with an optimistic *pending* badge — the badge clears when the file's `status:`/`phase:` actually changes, and goes stale (dismissible) after 5 minutes if no change arrives.

## How it loads

The extension ships inside the al-agentic-dev plugin at `extensions/al-kanban/`. Installed-plugin `extensions/<name>/extension.mjs` folders are discovered automatically — no separate install step. Open it with the `open_canvas` tool (canvas id `al-kanban`) or by asking the agent to "show the task board".

Optional open input:

```json
{ "tasksFolder": "specs/014-my-feature/tasks" }
```

Without input the board auto-discovers: the `specs/*/tasks/` whose parent folder name matches the current git branch, else the most recently modified one, else an explicit empty state naming the paths it searched.

## Requirements and limitations

- **Rendering requires the GitHub Copilot desktop app.** The extension model is shared with the terminal Copilot CLI — the extension loads there too — but the CLI has no canvas render surface, so terminal-only users will not see the board even with the plugin installed.
- **Dark theme only** (GitHub Primer dark palette). The canvas host exposes no theme signal (`CanvasHostContext` in `canvas.d.ts` carries none), and the webview's `prefers-color-scheme` reflects the OS setting rather than the app's theme — so a light variant could not follow the app anyway.
- Freshness comes from `fs.watch` on the tasks folder + SSE push; card moves land within ~1 second of a file save.
- No build step, no npm dependencies: `extension.mjs` (Node built-ins + `@github/copilot-sdk`) and one static `board.html`.
- A task file whose frontmatter fails to parse renders as a visible "unparseable" card; it never crashes the board.

## Development

Fixture with full column coverage and expected counts: `tests/fixtures/al-kanban/` in the marketplace repo. Live-gate script: `SMOKE-TEST.md`.
