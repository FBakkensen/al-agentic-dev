# Driving the BC Web Client — what the client does, and the move that works

Facts about the BC Web Client an annotated walk runs into, regardless of the browser tooling behind it. Each names the wall and the move.

## The client lives inside an iframe

With `runinframe=1` the whole client renders inside an iframe; the outer page is only shell. Anything that reads or clicks the page at the top level sees no BC controls — every read and every click targets the iframe's own document.

## Navigation drops the session

A full page navigation returns the client to sign-in and loses the walk's state. Drive inside the client — search, role-center links, in-page actions, drilldowns. Re-entering by URL is a restart, not a step.

## Grid values go through the field lookup

Typing a value into a grid cell leaves the record dirty and unvalidated, and the client raises *"There are unsaved changes on the page."* Set the value by opening the field's lookup and picking the row. A dirty record from a typing mistake is discarded, never saved around.

## Only the selected row is editable

A grid renders `input` elements on the selected row only; every other row is static cells. Select a row with a plain click on one of its cells — synthesised pointer sequences are unreliable — and confirm the selection landed by re-reading the row's `aria-selected` before acting on it.

## FactBox panes render lazily

A FactBox can be present but empty until it is toggled open; its tiles do not exist in the page before that. Toggle the pane open first, then read.

## Replay batches want a genuinely fresh container

Re-running a recording batch against a container left populated by a killed run produces false reds from stateful collisions — No. Series clashes, leftover documents. Judge a background run's liveness by its log file's write time, not by whether the process exists.
