# Debug app: API queries over an app's tables

A throwaway extension that publishes read-only API queries for the tables an investigation needs. Queries, not pages: no `ODataKeyFields` ceremony, no editable surface, and a join is one `dataitem` nested in another. It is built and published with the inline `al` steps below, never through /al-build.

## Layout

The debug app is always its own app: its own app id, its own object id range, a folder under `.output/` outside the product apps, never committed, and nothing in the product references it.

```
<repo>/.output/debug-app/
  app.json
  src/<Table>Debug.Query.al          # one per table, plus joined ones per question
```

`app.json`: `"name": "<app name> Debug"`, its own `id` and `publisher`, `"idRanges": [{ "from": <free from>, "to": <free to> }]` (a range no installed app's objects use; the publish fails on an object id conflict), a dependency on the product app and on the vendor app whose tables are read, and the same `application`, `platform`, and `runtime` as the environment. `"target": "Cloud"`.

## A query

```al
namespace <Namespace>.Debug;

using <Namespace>;

query <id> "<Prefix> Debug <Parents>"
{
    QueryType = API;
    APIPublisher = '<apiPublisher>';
    APIGroup = 'debug';
    APIVersion = 'v1.0';
    EntityName = '<parent>';
    EntitySetName = '<parents>';
    DataAccessIntent = ReadOnly;

    elements
    {
        dataitem(Parent; "<Parent Table>")
        {
            column(<keyColumn>; "<Key Field>") { }
            column(<statusColumn>; "<Status Field>") { }
            dataitem(Child; "<Child Table>")
            {
                DataItemLink = "<Child Link Field>" = Parent."<Key Field>";
                SqlJoinType = LeftOuterJoin;
                column(child<Field>; "<Child Field>") { }
            }
        }
    }
}
```

Column names are the JSON property names: camelCase, unique within the query. `EntitySetName` must be unique across the tenant's APIs. A DateTime column comes back in UTC (`Z`); a table that stores wall-clock values shows them as such.

## Build and publish

Three inline `al` CLI steps, run in the debug-app folder under `.output/`, typed directly.

1. `al downloadsymbols --project .` plus the target flags below.
2. `al compile -project:. -packagecachepath:.alpackages -out:debug.app`
3. `al publishapp debug.app` plus the target flags below.

| Target | Flags on `downloadsymbols` and `publishapp` |
|---|---|
| SaaS sandbox | `--tenant <tenant> --environmenttype Sandbox --environmentname <environment> --authentication AAD` |
| Agent container | `--environmenttype OnPrem --server http://<agent-container> --serverinstance <serverInstance> --tenant <tenant> --authentication UserPassword` |

On the container, `al` reads the credentials from `BC_SERVER_USERNAME` and `BC_SERVER_PASSWORD`. Run the three steps in one block that sets them from `al-build.json` and removes them after; they are never an argument and never echoed:

```powershell
$cfg    = Get-Content (Join-Path (git rev-parse --show-toplevel) 'al-build.json') -Raw | ConvertFrom-Json
$flags  = '--environmenttype', 'OnPrem', '--server', 'http://<agent-container>', '--serverinstance', $cfg.serverInstance, '--tenant', $cfg.tenant, '--authentication', 'UserPassword'
$env:BC_SERVER_USERNAME = $cfg.container.username; $env:BC_SERVER_PASSWORD = $cfg.container.password
try {
    al downloadsymbols --project . @flags
    al compile -project:. -packagecachepath:.alpackages -out:debug.app
    al publishapp debug.app @flags
} finally { Remove-Item Env:BC_SERVER_USERNAME, Env:BC_SERVER_PASSWORD }
```

Then read `<base>/api/<apiPublisher>/debug/v1.0/$metadata` and `<base>/api/<apiPublisher>/debug/v1.0/companies(<id>)/<parents>?$filter=<expr>` through `Get-Bc` ([`ENDPOINTS.md`](ENDPOINTS.md)).

## Permissions and visibility

The querying user needs read permission on the tables: the product's permission set (or SUPER on a dev sandbox or the container) covers it. A table declared `Access = Internal` cannot be used at compile time from a module that the owning app's `internalsVisibleTo` does not name, and the debug app is such a module: that table is out of reach, and the answer says so.

## Tear down

The `al` CLI has no uninstall or unpublish command, and the Administration Center API uninstalls an app but cannot unpublish it. The automation API's `extensions` entity does both on both targets, with the credentials the skill already reads with: no Web Client, no second Entra app registration. A debug app left behind blocks the product's next publish.

1. **Find it.** `GET $automation/extensions`. Done when exactly one row matches the debug app's own `id` and `publisher`; its `packageId` (not the app id) is the key, and `isInstalled` and `publishedAs` show its state.
2. **Uninstall.** `POST $automation/extensions($packageId)/Microsoft.NAV.uninstall`. Never `Microsoft.NAV.uninstallAndDeleteExtensionData`: deleting data also deletes dependents' data, and a wrong `packageId` would hit the product app.
3. **Unpublish.** `POST $automation/extensions($packageId)/Microsoft.NAV.unpublish`, which works only on an uninstalled app and needs Business Central 25.4 or later.
4. **Check.** `GET $automation/extensions` again. Done when no row carries the debug app's `id`.

```powershell
$automation = "$base/api/microsoft/automation/v2.0/companies($companyId)"
$mine = @((Get-Bc $target "$automation/extensions").value | Where-Object { $_.id -eq '<debug app id>' -and $_.publisher.Trim() -eq '<debug publisher>' })
if ($mine.Count -ne 1) { throw "expected one debug app, found $($mine.Count)" }
$packageId = $mine[0].packageId
$mine[0] | Select-Object packageId, isInstalled, @{ n = 'publishedAs'; e = { $_.publishedAs.Trim() } }
foreach ($action in 'uninstall', 'unpublish') {
    Invoke-RestMethod -Method Post -Uri (Add-Tenant $target "$automation/extensions($packageId)/Microsoft.NAV.$action") -Headers $target.Headers -TimeoutSec 120 | Out-Null
}
(Get-Bc $target "$automation/extensions").value | Where-Object { $_.id -eq '<debug app id>' }   # no output: the app is gone
```

If the environment rejects either action for the debug app (an app published with `al publishapp` may be Dev scope, and the docs do not say whether the actions accept that scope), the user opens the environment's Extension Management page in the Web Client, runs Uninstall, then Unpublish on the debug app, and says when done; then repeat step 4. On a SaaS sandbox the user signs in to the Web Client.
