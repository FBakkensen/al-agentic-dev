# Endpoints and recipes

All PowerShell. Every data request is a GET through `Get-Bc`; the only other requests are the debug app's own uninstall and unpublish ([`DEBUG-APP.md`](DEBUG-APP.md)). Set up the target once; each recipe below says which target it serves and uses its `$h`, `$base`, and `$tenant`.

## Target setup

**SaaS sandbox** — an `az` token, with the tenant and environment the user gave:

```powershell
$tok    = az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv
$h      = @{ Authorization = "Bearer $tok" }
$base   = "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<environment>"
$tenant = $null
```

**Agent container** — basic auth from `al-build.json` in the repo root, read here and never shown. `<agent-container>` is the container name /al-build derives from the branch:

```powershell
$cfg    = Get-Content al-build.json -Raw | ConvertFrom-Json
$pair   = "$($cfg.container.username):$($cfg.container.password)"
$h      = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair)) }
$base   = "http://<agent-container>:7048/$($cfg.serverInstance)"
$tenant = $cfg.tenant
```

**Both targets** — the data request function. The container needs `tenant=` on every request; the SaaS URL carries the tenant in its path:

```powershell
function Add-Tenant([string]$Url) {
    if ($tenant -and $Url -notmatch '[?&]tenant=') { $Url += ($Url.Contains('?') ? '&' : '?') + "tenant=$tenant" }
    $Url
}
function Get-Bc([string]$Url) { Invoke-RestMethod (Add-Tenant $Url) -Headers $h -TimeoutSec 120 }
```

The first authenticated request to a freshly started container took about 40 seconds on Business Central 29.0. Give it the long timeout and never cancel and resend.

## Companies (both targets)

```powershell
(Get-Bc "$base/api/v2.0/companies").value | Select-Object name, id
```

## Metadata of any API group (both targets)

```powershell
$grp = "$base/api/v2.0"        # or api/microsoft/automation/v2.0, api/<publisher>/<group>/<version>
(Get-Bc "$grp/`$metadata").edmx.DataServices.Schema.EntityContainer.EntitySet | Select-Object -ExpandProperty Name
```

Fields of one set: the set's `EntityType` attribute names the type (`Namespace.typeName`); the type lives under the `Schema` with that namespace and lists its `Property` elements.

```powershell
$md       = Get-Bc "$grp/`$metadata"
$set      = ($md.edmx.DataServices.Schema.EntityContainer.EntitySet | Where-Object Name -eq '<entitySet>').EntityType
$typeName = $set.Split('.')[-1]
($md.edmx.DataServices.Schema.EntityType | Where-Object Name -eq $typeName).Property | Select-Object Name, Type
```

## Company-bound query with paging (both targets)

```powershell
$url  = "$grp/companies($companyId)/<entitySet>?`$filter=<expr>&`$top=200"
$rows = @()
do { $r = Get-Bc $url; $rows += $r.value; $url = $r.'@odata.nextLink' } while ($url)
$rows | Select-Object <fields> | Format-Table -AutoSize
```

Filters: `code eq '<code>'`, `version eq 3`, `status ne '<status>'`, `startswith(name,'<prefix>')`, `postingDate ge 2026-09-01`. Combine with `and` / `or`. A text field holding JSON decodes in place: `$_.<field> | ConvertFrom-Json`, printed field by field.

## Automation API — extensions (both targets)

Group `api/microsoft/automation/v2.0`. `GET $grp/companies($companyId)/extensions` lists every installed and published app: `packageId` (the key the actions take), `id` (the app id), `displayName`, `publisher`, `versionMajor` … `versionRevision`, `isInstalled`, `publishedAs`. On Business Central 29.0 an app published with `al publishapp` read `publishedAs` ` Dev`, with a leading space.

Actions on `extensions($packageId)`, POST with no body, answer 204:

- `Microsoft.NAV.install` and `Microsoft.NAV.uninstall`.
- `Microsoft.NAV.unpublish`, on an uninstalled app, on Business Central 25.4 or later. It is the teardown's last step ([`DEBUG-APP.md`](DEBUG-APP.md)); the extension reference page omits it, the automation APIs introduction documents it.

## Developer endpoint — symbols of an installed app (both targets)

For an app whose source is not at hand (a Microsoft test library outside BCApps, a partner app). Base: the SaaS base above; the container's dev endpoint is `http://<agent-container>:7049/<serverInstance>`. This endpoint takes `tenant=` on both targets: `default` on a SaaS sandbox, `$tenant` on the container.

```powershell
$dev = "<SaaS base, or the container's dev endpoint>"
$dt  = if ($tenant) { $tenant } else { 'default' }
Invoke-WebRequest "$dev/dev/packages?publisher=<publisher>&appName=$([uri]::EscapeDataString('<app name>'))&versionText=<version>&tenant=$dt" -Headers $h -OutFile pkg.app
$b = [IO.File]::ReadAllBytes('pkg.app'); [IO.File]::WriteAllBytes('pkg.zip', $b[40..($b.Length-1)]); Expand-Archive pkg.zip pkg -Force
```

`SymbolReference.json` lists objects and procedure signatures; `DocComments.xml` the XML docs. The 40-byte NAVX header must be dropped before unzipping. `DELETE` on `/dev/apps` is not supported.

## Standard API (both targets)

`api/v2.0` — `employees`, `customers`, `salesOrders`, … Company-bound like everything else. Custom fields are absent unless an app extends the API page.
