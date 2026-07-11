# al-kanban smoke test — live gate

Run this in a **GitHub Copilot desktop-app session** (not a terminal `copilot` run — the terminal CLI loads the extension but has no canvas render surface) on a real AL project that uses the al-agentic-dev task pipeline (any repo with `specs/<NNN>-<slug>/tasks/`), with the al-agentic-dev plugin installed at a version that ships this extension.

## 1. Open the board

- Ask the agent: *"show the task board"* (or have it call `open_canvas` with canvas id `al-kanban`).
- **Pass:** a side panel opens showing the project's real tasks from `specs/<NNN>-<slug>/tasks/`, technical strip on top, verify strip below, chips for provision/breaking-change tasks. The header shows the resolved folder path.
- If the project has no `specs/*/tasks/`: the panel shows the empty state naming the searched paths — that is a pass for discovery, pick a feature branch with tasks and reopen.

## 2. Live move

- Run a real pipeline step that flips a task's frontmatter (e.g. `/al-refine` on a `ready` technical task), or hand-edit a task's `status:`/`phase:` and save.
- **Pass:** the card moves to its new column within ~1 second, no manual refresh.

## 3. Advance + pending badge

- Click a card that shows an **Advance** button (e.g. a `ready` technical task) and press it.
- **Pass:** the prompt `Run the /al-refine skill on task T-NNN` lands in the chat as a user message; the card shows a *pending* badge.
- Let the skill run to completion.
- **Pass:** when the skill stamps the file, the badge clears and the card moves.
- Negative check: press Advance on another card and do **not** run the skill — after 5 minutes the badge turns *stale* (grey, dashed); clicking it dismisses it.

## 4. Drawer

- Click a blocked card (red edge).
- **Pass:** the drawer shows the `blocked-on:` text verbatim, plus goal, depends_on, and any deviations.

## 5. Teardown

- Close the canvas panel.
- **Pass:** no orphan node listener remains — `netstat -ano | findstr <port>` (Windows) or `lsof -i :<port>` (macOS/Linux), with the port from the panel URL, shows nothing; a subsequent reopen gets a fresh port and works.
