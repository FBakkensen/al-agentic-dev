---
name: al-webclient
description: "Use before the first browser call of any task that touches the Business Central Web Client in the built-in browser, Claude in Chrome, or Playwright CLI, on a SaaS sandbox or on the branch's agent container."
---

# al-webclient

The Web Client is a single-page app inside an iframe. Every recipe is page JavaScript from [`SNIPPETS.md`](SNIPPETS.md), cited below by its headings and run through the driver's evaluate tool: `javascript_tool` in the built-in browser (`mcp__Claude_Browser__javascript_tool`, with `action` = `javascript_exec`, `text`, and `tabId`) and in Claude in Chrome (`mcp__claude-in-chrome__javascript_tool`), `playwright-cli -s=<agent-container> eval` or `run-code` in Playwright.

## Rules

1. **Reuse the open page.** The agent drives the tab the user already has on a Business Central page, in place. With none open, it opens the target once: the container URL below, or the SaaS environment's tenant-qualified URL, which the user supplies. A SaaS sign-in, account-picker, or MFA page, a blank frame, and a container sign-in that survives its one attempt are each a stop for the user, never a retry.
2. **Agent container** (the container /al-build names after the branch). Its Web Client is the `.test` URL /al-build prints, else `http://<agent-container>.test/<serverInstance>/?tenant=<tenant>` from `al-build.json`. The agent signs in itself with the sign-in snippet, filling `container.username` and `container.password` from `al-build.json`; the password sits in the form field and nowhere else, never printed or repeated in chat. `page=` and `company=` URLs are allowed. Done when Where am I returns `ready:true`.
3. **SaaS sandbox.** The user signs in, with MFA. Once a Business Central page is open, every URL move costs the user a fresh sign-in and MFA and is forbidden, with no exception for "same origin" or "just to test whether it prompts": a navigation with a URL, `page=`, `company=`, `bookmark=`, or any `location` change on the top window or the iframe. The agent moves with Tell Me (Alt+Q), page actions, links, list rows, and My Settings → Company. A reload uses the driver's own reload action with no URL (`playwright-cli reload`); Claude in Chrome's navigate tool has none, so there, and in any driver without one, a reload is a stop for the user. The client signs back in silently while the session cookie lives, and a reload collapses the stack to the page in the URL. A page the client's controls cannot reach is a stop: say so.
4. **One iframe, one live page.** `document.querySelector('iframe').contentDocument` is the client; the outer document is a shell (app launcher, search, settings, help), so a driver's own page-read and click tools may see only that shell. The second iframe (Office TokenFactory) is cross-origin and unreadable, as expected. The client stacks pages: Tell Me, drill-downs, and lookups open on top of the current page, which stays in the DOM (`.spa-view.spa-not-top-most`, `inert`) until its Back arrow closes it. The live page is `.spa-view:not(.spa-not-top-most)`; scope every query to it, because the whole frame mixes in stale pages and a match inside an inert page cannot be clicked.
5. **Act, return, then read.** A script that outlasts the driver's evaluation limit returns a timeout, and the action it issued still happened: the outcome is unknown, never failed. Issue the action in one call, read the state in the next, and poll for a concrete condition (a heading, a row, a dialog), not a fixed sleep.
6. **Datasets come from an API.** A virtualised grid renders only its visible rows, so a scrape is never the complete list; read the data with /al-environment-data, and use the UI to act and to verify.

## Steps for one action

1. **Confirm the frame.** The agent runs Where am I. Done when it returns `ready:true` and the top page's caption is the page expected; on a wrong top page, the agent closes it with its Back arrow or opens the right page.
2. **Check for a blocker.** Run Dialogs. A dialog this action triggers (a lookup list, My Settings, a confirmation) is worked inside; an error, a personalization message, or an unsaved-changes prompt blocks and is resolved first. Discard only changes the agent made by mistake; ask the user about any other unsaved change. A browser-native prompt (beforeunload) is invisible to the frame query, so the driver or the user handles it. Done when a fresh Dialogs run shows no unexpected dialog.
3. **Locate by what the user sees.** Match buttons, links, and menu items by trimmed `innerText`, `aria-label`, or `title`, visible and enabled. Labels are localised, so read them off the page first; generated class names (`root-221`) change per render. A visible but disabled menu item means the action does not apply to the current record: state, not a target. Done when exactly one visible, enabled element matches; zero or several means re-read the page, never guess.
4. **Name the expected result, then fire.** Decide what the frame must show next (a heading, a closed dialog, a new row). `.click()` works for page actions; a Tell Me result opens with keyboard Enter on its focused row, because synthesised mouse events raise a personalization error and navigate nowhere. `'clicked'` proves the call, not the effect.
5. **Verify by re-reading.** Done when the result named in step 4 is visible (the heading, the row's `aria-selected="true"`, the dialog gone). The value shown after Business Central validated it is the truth, not the input written. A result missing on the first read is pending: poll read-only for a few seconds. An attempt failed after an explicit error, or when the window expires with no change; an unknown outcome is never replayed.

Two identical failures switch technique or stop: the agent says what failed and what the frame shows, then asks the user.

## Grids and fields

- Only the selected row renders `input` elements; other rows are static cells. Select with a plain click on a cell and confirm `aria-selected` before touching inputs (Rows).
- A lookup-backed field takes its value from its lookup dropdown, a stack view and never a dialog, by clicking the row whose key matches exactly (Lookup field). Typing into the cell sets only the text: Business Central validates on leave, an unknown value raises an error dialog, and the record stays dirty and unvalidated. The agent discards a dirty record from its own typing mistake through that dialog and redoes it through the lookup, never saving around it. A dialog query that finds nothing after a lookup click has not looked: What did that click open? reads whatever appeared.
- Setting `.value` changes pixels, not state: inputs are React-controlled, so assign through the native `HTMLInputElement` value setter and raise `input`, as the snippets do.
- Lists are virtualised: reach a record out of view through the page's search box, never by scrolling or scraping.
- FactBox tiles do not exist in the DOM until the FactBox is toggled open: the agent toggles it, waits, then reads.

## Close

Done when the reply names the page the frame shows now and what changed, in the user's words for the controls: a page reached or an action confirmed by re-read, or at a stop, what blocked and what the user does next. Hand that back to the work that invoked the skill; invoked directly, it is the whole run.
