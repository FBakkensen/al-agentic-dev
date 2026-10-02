---
name: al-walkthrough
description: Use when an implemented Original work item or child PBI has Gherkin scenarios that need walking in the Business Central Web Client of the branch's agent container.
---

# al-walkthrough - walk the slice

In: an implemented executable Original work item, or a child PBI and its Original; the environment is the branch's agent container. This pass observes Gherkin behavior; AAA unit and integration cases remain build evidence.
The lead changes no AL code and creates no report file; the screenshots under `.output/` are evidence, not a report.

## Before the walk

**Driver.** The lead takes the first available of the built-in browser (`mcp__Claude_Browser__*`, or `mcp__remote-devices__Claude_Browser__*` in a cloud session linked to the computer), Claude in Chrome (`mcp__claude-in-chrome__*`), then Playwright CLI.
- A browser driver is available when its tools are present: loaded, or deferred and loaded with one `ToolSearch` call on its prefix. Playwright CLI is available when `playwright-cli` is on the PATH.
- When the only tool present for a browser is its `enable__mcp__remote-devices__Claude_Browser` or `enable__mcp__claude-in-chrome` tool, the lead calls it first; the driver's tools appear once it has run.
- With none available, the lead stops before the republish and tells the user which install is missing (`npm install -g @playwright/cli@latest` for Playwright CLI); the lead walks by no other means.
- Done when the lead has named one driver, or has stopped.

**Confirm.** The lead reads the `Behavior` Gherkin in the executable work item's Acceptance Criteria and the Original's BPMN outcomes.
The lead then asks the user with `AskUserQuestion` to confirm the scenario order, company, required records, and expected visible results.
Done when the user has confirmed; the client opens only after.

## Walk

▶ haiku · /al-build clean republish into the branch's agent container → deployed commit, app version, Web Client URL, username

- The republish is the walk's only delegated step; the lead drives the client in-line.
- The lead states the commit and app version before the first scenario.
- The Web Client URL and username come from the same result; `<agent-container>` is the URL's host label before `.test`.
- Done when the lead holds all four; a failed republish ends the walk with its output named.

Before the first browser call, the lead invokes /al-webclient.
The lead opens the Web Client URL on its `.test` host in the chosen driver and signs in automatically as /al-webclient directs: the republish's username, the `al-build.json` container password read at sign-in and never repeated in chat, no password typed by the user.
- Built-in browser: the user may be asked to approve the `.test` host, and a denied navigation comes back as `navOk: false`. The lead waits for the answer and moves to the next available driver when the site is refused; with none left, the lead stops and tells the user.
- Playwright CLI: the lead opens it with `playwright-cli -s=<agent-container> open <url> --headed`, so parallel branches don't share a browser.
- Done when /al-webclient's frame check passes on the signed-in client.

Before a step relies on a page, action, field, enum value, dialog, or resulting record, the lead confirms it through the current client or /al-lookup in this session, never from recall. The lead reports:
- each step as `▶ <business action>`, `📍 Observed: <exact visible result>`, and `✅ Expected: <matching Gherkin result>`, one per line;
- each mismatch as `⛔ <scenario and step>`, `📍 Observed: <exact visible result>`, `⚡ Expected: <Gherkin result>`, and `🔧 Reproduce: <shortest path back to the mismatch>`, one per line.

At a mismatch the lead takes its screenshot before the next action, as Evidence describes, then still walks every scenario whose state the failure does not invalidate. Done when every confirmed scenario has a result or is named as invalidated by an earlier mismatch.

## Evidence

For each ⛔ step the lead takes one screenshot and saves it as `.output/walkthrough/<work item id>/<scenario number>-<step number>.png`; passing steps stay text.
- Playwright CLI: the lead runs `playwright-cli -s=<agent-container> screenshot --filename=<path>`.
- Claude in Chrome: the lead calls `mcp__claude-in-chrome__computer` with `action` = `screenshot` and `save_to_disk`, then copies the file at the path in the tool result to `<path>`.
- Built-in browser: the lead calls `mcp__Claude_Browser__computer` (`mcp__remote-devices__Claude_Browser__computer` in a cloud session) with the `screenshot` action and saves the file to `<path>` where the tool can write one.
- When a driver returns only the image and no file, the lead says so in the comment and attaches nothing for that step.

The lead attaches the screenshots to the executable work item by calling /al-azure-devops-attachments in-line; the republish stays the only delegated `▶` line.
The lead then posts one comment on the executable work item with `mcp__plugin_al-agentic-dev_ado__wit_work_item_comment_write`, action `add`: the commit and app version, each scenario's result, and the attachment URL beside each ⛔ step.
With no ⛔ step nothing is attached, and the comment says every step passed.
Done when every screenshot is a verified attachment and the comment is posted.

## Close

Done when the lead's reply names, outcome first, the scenarios passed, each mismatch with its screenshot link, the resulting record identifiers, and a hand-reproduction recipe; at a stop, it names what blocked and what the user does next.
The lead hands that back to the work that invoked the skill; invoked directly, it is the whole run.
