---
name: al-environment-data
description: "Use when the data behind a failing test or run has to be read, GET only, from the API of a SaaS sandbox the user names or of the branch's agent container."
---

# al-environment-data

An environment's API reads its data deterministically. The two targets, their credentials and base URLs, and every recipe are in [`ENDPOINTS.md`](ENDPOINTS.md); the debug app for a table with no API is in [`DEBUG-APP.md`](DEBUG-APP.md).

## Steps

1. **Target.** SaaS sandbox: ask with `AskUserQuestion` for the tenant and environment, in every investigation, and write them to no config or instruction file. Agent container: ask nothing; `<agent-container>` is the branch name with `/` and `\` replaced by `-`, as /al-build derives it. Done when `docker ps` shows that container, or the user, told that none exists, runs /al-build to provision one.
2. **Credential.** Build the target's request header ([`ENDPOINTS.md`](ENDPOINTS.md), Target setup). When the `az` token request fails on authentication, stop and give the user `az login --tenant <tenant>` to run themselves, then resume. Done when `GET <base>/api/v2.0/companies` answers 200.
3. **Company.** Resolve the company that holds the data to its id; the `?company=` name in Web Client URLs is a different thing. Done when the id is in hand.
4. **Entity from `$metadata`.** Every API group publishes it: standard v2.0, automation, and any app's own group. Done when the entity set and the fields to read both come from the metadata document.
5. **Query with GET.** `$filter`, `$select`, `$top`, `$orderby`, paging, and JSON-in-text payloads decoded in place: [`ENDPOINTS.md`](ENDPOINTS.md). Done when the rows the question names are shown, or the count is zero; a 404 on the entity sends you back to step 4.
6. **Table without an API.** When the app owning the table publishes no API for it, name the table and its fields from the app's symbols (the `/dev/packages` download in [`ENDPOINTS.md`](ENDPOINTS.md)) or /al-lookup, then build the debug app and read through it ([`DEBUG-APP.md`](DEBUG-APP.md)). Done when the route's `$metadata` lists the set and it returns rows.
7. **Tear down.** The debug app leaves with the investigation, also one abandoned midway ([`DEBUG-APP.md`](DEBUG-APP.md), Tear down).

## Boundaries

- Data requests are `GET`. The only mutations are publishing and removing this skill's own debug app, on a SaaS sandbox or the agent container, never on a customer tenant; every change to business data goes through the product or its UI.
- Credentials sit in the request header and nowhere else: not printed, logged, saved, or passed as a command-line value.
- Every table, field, and object a debug query names or shows is confirmed through the symbols or /al-lookup in this session, never recalled; the query and every line shown use Business Central vocabulary.

## Close

Done when the answer names the entity, filter, row count, and what the rows showed (or the entity that does not exist and the debug query that would expose it), and any debug app is gone. Hand that read and the debug app's teardown verdict back to the work that invoked the skill; invoked directly, they are the whole run.
