---
name: al-webclient
description: "Use before the first browser call of any task that touches the Business Central Web Client in the built-in browser, Claude in Chrome, or Playwright CLI, on a SaaS sandbox or on the branch's agent container."
---

# al-webclient

The Web Client is a single-page app inside an iframe. Every recipe is page JavaScript from [`SNIPPETS.md`](SNIPPETS.md), cited below by its headings and run through the driver's evaluate tool:
- Built-in browser: `mcp__Claude_Browser__javascript_tool`, with `action` = `javascript_exec`, `text`, and `tabId`.
- Claude in Chrome: `mcp__claude-in-chrome__javascript_tool`. Playwright: `playwright-cli -s=<agent-container> eval` or `run-code`.

## Rules

1. **Reuse the open page.** The agent drives the tab the user already has on a Business Central page, in place.
   - On a SaaS sandbox with no Business Central page open, the agent stops and asks the user to open the sandbox and sign in, then continues.
   - A SaaS sign-in or MFA page and a blank frame are each a stop for the user; the agent never retries a SaaS sign-in.
2. **Agent container** (the container /al-build names after the branch). The agent opens its `.test` Web Client URL once: the one /al-build prints, else `http://<agent-container>.test/<serverInstance>/?tenant=<tenant>` from `al-build.json`.
   - The agent signs in itself with the sign-in snippet, with the container credentials from `al-build.json`.
   - The password appears only in that one sign-in call, read from `al-build.json` at that moment; never in prose, never in a later call, never saved.
   - With `playwright-cli`, the agent builds that call's text in the shell from the config, so it never types the value. A script argument is a command-line value for that one process, and page JavaScript has no route to an environment variable.
   - `page=` and `company=` URLs are allowed. Done when Where am I returns `ready:true` and the expected page caption.
3. **SaaS sandbox.** The user signs in, with MFA. The agent opens no URL: every URL move costs the user a fresh sign-in and MFA.
   - Forbidden, with no exception for "same origin" or "just to test whether it prompts": a navigation with a URL, `page=`, `company=`, `bookmark=`, any `location` change on the top window or the iframe.
   - The agent moves with Tell Me (Alt+Q), page actions, links, list rows, and My Settings → Company; a page those cannot reach is a stop, and the agent says so.
   - A reload uses the driver's own reload action, with no URL, where it has one (`playwright-cli reload`). In every other driver, Claude in Chrome and the built-in browser included, a reload is a stop for the user.
   - A reload collapses the stack to the page in the URL; the client signs back in silently while the session cookie lives.
4. **One iframe, one live page.** `document.querySelector('iframe').contentDocument` is the client.
   - The outer document is a shell (app launcher, search, settings, help), so a driver's own page-read and click tools may see only that shell. The second iframe is cross-origin and unreadable, as expected.
   - The client stacks pages: Tell Me, drill-downs, and lookups open on top of the current page, which stays in the DOM (`.spa-view.spa-not-top-most`, `inert`) until its Back arrow closes it.
   - The live page is `.spa-view:not(.spa-not-top-most)`. The agent scopes every query to it, because the whole frame mixes in stale pages and a match inside an inert page cannot be clicked.
5. **Act, return, then read.** A script that outlasts the driver's evaluation limit returns a timeout, and its action still happened: that outcome is unknown, never failed, never replayed. The agent issues the action in one call, reads in the next, and polls for a condition, not a fixed sleep.
6. **Datasets come from an API.** A virtualised grid renders only its visible rows, so a scrape is never the complete list: the agent reads data with /al-environment-data and uses the UI to act and to verify.

## Steps for one action

1. **Confirm the frame.** The agent runs Where am I. Done when it returns `ready:true` and the top page's caption is the page expected; on a wrong top page, the agent closes it with its Back arrow or opens the right page.
2. **Check for a blocker.** The agent runs Dialogs; done when a fresh run shows no unexpected dialog.
   - A dialog this action triggers (My Settings, a confirmation) is worked inside. An error, a personalization message, or an unsaved-changes prompt blocks, and the agent resolves it first.
   - The agent discards only changes it made by mistake and asks the user about any other unsaved change.
   - A browser-native prompt (beforeunload) is invisible to the frame query: the agent handles it with the driver's dialog handling where the driver has it, and otherwise asks the user.
3. **Locate by what the user sees.** The agent matches buttons, links, and menu items by trimmed `innerText`, `aria-label`, or `title`, visible and enabled.
   - Labels are localised, so the agent reads them off the page first; generated class names (`root-221`) change per render. A visible but disabled menu item means the action does not apply to the current record: state, not a target.
   - A record shown as a tile keeps its actions in the tile's own menu (Rows).
   - Done when exactly one visible, enabled element matches; zero or several means the agent re-reads the page and never guesses.
4. **Name the expected result, then fire.** The agent decides what the frame must show next (a heading, a closed dialog, a new row), then fires.
   - `.click()` works for page actions. A Tell Me result opens with keyboard Enter (Open a page with Tell Me), because synthesised mouse events raise a personalization error and navigate nowhere.
   - `'clicked'` proves the call, not the effect. Done when the expected result is written down and the call has returned.
5. **Verify by re-reading.** Done when the result named in step 4 is visible (the heading, the selected row, the dialog gone); the value shown after Business Central validated it is the truth, not the input written.
   - A result missing on the first read is pending: the agent re-reads read-only until it shows. An explicit error is a failure; a re-read that still shows no change is unknown as in rule 5, so the agent reads again before anything else.
6. **After two identical failures,** the agent switches technique or stops, says what failed and what the frame shows, and asks the user. Done when the user has been told both.

## Grids and fields

- Only the selected row renders `input` elements, so the agent selects the row first (Rows). A lookup-backed field takes its value from its lookup dropdown, a stack view and never a dialog (Lookup field).
- Typing sets only the text: Business Central validates on leave, an unknown value raises an error dialog, and the record stays dirty. The agent discards a dirty record from its own typing mistake through the unsaved-changes dialog's Discard, redoes it through the lookup, and never saves around it.
- A caret, menu, or toggle opens a stack view or menu, not a dialog, so a dialog query after the agent's click has not looked: the agent reads a lookup with Lookup field call 2, and anything else with What did that click open?.
- Setting `.value` changes pixels, not state: inputs are React-controlled, so the agent assigns through the native `HTMLInputElement` value setter and raises `input`, as the snippets do.
- The agent reaches a record out of view through the page's search box (Rows), never by scrolling.
- FactBox tiles do not exist in the DOM until the FactBox is toggled open: the agent toggles it, waits, then reads.

## Close

Done when the reply names the page the frame shows now and what changed, in the user's words for the controls: a page reached or an action confirmed by re-read, or at a stop, what blocked and what the user does next.
Hand that back to the work that invoked the skill; invoked directly, it is the whole run.
