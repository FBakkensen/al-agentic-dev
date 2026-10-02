---
name: al-environment-data
description: "Reads Business Central data through an environment's API with GET requests only, and through a throwaway read-only debug app when no API exposes the table. Use when the data behind a failing test, run, or bug sits on a SaaS sandbox the user names, or when it sits in the branch's agent container."
---

# al-environment-data

Business Central calls both a SaaS sandbox and a container instance an environment. Either is a database with an OData face: the API read is deterministic and scriptable, the Web Client costs a sign-in and a walk. Reach for the API first, the client only for what the API cannot show.

Recipes per target live in [`ENDPOINTS.md`](ENDPOINTS.md); the debug app and its teardown in [`DEBUG-APP.md`](DEBUG-APP.md).

## The two targets

| | SaaS sandbox | Agent container |
|---|---|---|
| Credential | `az` token for `https://api.businesscentral.dynamics.com` | basic auth, `container.username` and `container.password` from `al-build.json` |
| Base URL | `https://api.businesscentral.dynamics.com/v2.0/<tenant>/<environment>` | `http://<agent-container>:7048/BC` with `?tenant=<tenant>` on every API request (a SaaS URL carries the tenant in its path) |
| Asked | `AskUserQuestion` for the tenant and environment, each investigation, written to no config or instruction file | nothing: `<agent-container>` is the name /al-build derives from the branch, and the tenant (`default`) comes from `al-build.json` |

## Steps

1. **Credential.** Build the request header for the target ([`ENDPOINTS.md`](ENDPOINTS.md)). Done when `GET <base>/api/v2.0/companies` answers 200 (SaaS: after `az account show` names the tenant the user gave).
2. **Company.** The companies answer gives each company id; the `?company=` name in Web Client URLs is a different thing. Done when the company holding the data is resolved to its id.
3. **Resolve the entity from `$metadata`.** Every API group publishes it: standard v2.0, automation, and any app's own group. Done when the entity set and the fields to read both come from the metadata document.
4. **Query with GET.** `$filter`, `$select`, `$top`, `$orderby`; follow `@odata.nextLink` until absent. Done when the rows answer the question; a 404 on the entity sends you back to step 3.
5. **Table without an API.** When the app owning the table publishes no API for it, build a debug app of read-only API queries and read through it ([`DEBUG-APP.md`](DEBUG-APP.md)). Done when the route's `$metadata` lists the sets and they return rows.
6. **Decode payloads in place.** A text field holding JSON goes through `ConvertFrom-Json` and prints field by field; a field holding HTML is read as HTML.
7. **Tear down.** A debug app leaves with the investigation, also one abandoned midway. Done when the automation API's `extensions` list no longer holds it.

## Boundaries

- Data requests are `GET`. The only mutations are publishing and removing this skill's own debug app, on a SaaS sandbox or the agent container, never on a customer tenant. Every change to business data goes through the product or its UI.
- Credentials sit in the request header and nowhere else: not printed, logged, saved, or passed as a command-line value.
- The debug app is not the product: own app id, own object id range, a folder under `.output/`, never committed, nothing in the product references it.
- Every table, field, and object a debug query names or shows is confirmed through `$metadata`, the `/dev/packages` symbols, or /al-lookup in this session, never recalled; the query and every line shown use Business Central vocabulary.

## Close

State what was read (entity, filter, row count) and what it showed, or the entity that does not exist and the debug query that would expose it. After a debug app, state that the `extensions` list no longer holds it.
