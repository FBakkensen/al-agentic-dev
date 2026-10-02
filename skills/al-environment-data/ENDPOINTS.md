# Endpoints and recipes

All PowerShell, run from the repo root. Set up the target once; each recipe below names the target it serves and takes `$target`.

## Target setup

**SaaS sandbox** — an `az` token, with the tenant and environment the user gave. The tenant is in the base URL:

```powershell
$tok    = az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv
$target = @{
    Base    = "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<environment>"
    Headers = @{ Authorization = "Bearer $tok" }
    Tenant  = $null
}
```

**Agent container** — basic auth from `al-build.json` in the repo root. `<agent-container>` is the container name /al-build derives from the branch. Every API request carries `tenant=` (`default` in `al-build.json`):

```powershell
$cfg    = Get-Content (Join-Path (git rev-parse --show-toplevel) 'al-build.json') -Raw | ConvertFrom-Json
$pair   = "$($cfg.container.username):$($cfg.container.password)"
$target = @{
    Base    = "http://<agent-container>:7048/$($cfg.serverInstance)"
    Headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair)) }
    Tenant  = $cfg.tenant
}
```

**Both targets** — the data request function:

```powershell
function Add-Tenant([hashtable]$Target, [string]$Url) {
    if ($Target.Tenant -and $Url -notmatch '[?&]tenant=') { $Url += ($Url.Contains('?') ? '&' : '?') + "tenant=$($Target.Tenant)" }
    $Url
}
function Get-Bc([hashtable]$Target, [string]$Url) { Invoke-RestMethod (Add-Tenant $Target $Url) -Headers $Target.Headers -TimeoutSec 120 }
$base = $target.Base
```

The first authenticated request to a freshly started container took about 40 seconds on Business Central 29.0. Give it the long timeout and never cancel and resend.

## Companies (both targets)

```powershell
(Get-Bc $target "$base/api/v2.0/companies").value | Select-Object name, id
```

## Metadata of any API group (both targets)

```powershell
$group = "$base/api/v2.0"        # or api/microsoft/automation/v2.0, api/<apiPublisher>/<group>/<version>
(Get-Bc $target "$group/`$metadata").edmx.DataServices.Schema.EntityContainer.EntitySet | Select-Object -ExpandProperty Name
```

Fields of one set: the set's `EntityType` attribute names the type (`Namespace.typeName`); the type lives under the `Schema` with that namespace and lists its `Property` elements.

```powershell
$metadata   = Get-Bc $target "$group/`$metadata"
$entityType = ($metadata.edmx.DataServices.Schema.EntityContainer.EntitySet | Where-Object Name -eq '<entitySet>').EntityType
$typeName   = $entityType.Split('.')[-1]
($metadata.edmx.DataServices.Schema.EntityType | Where-Object Name -eq $typeName).Property | Select-Object Name, Type
```

## Company-bound query with paging (both targets)

```powershell
$url  = "$group/companies($companyId)/<entitySet>?`$filter=<expr>&`$top=200"
$rows = @()
do { $r = Get-Bc $target $url; $rows += $r.value; $url = $r.'@odata.nextLink' } while ($url)
$rows | Select-Object <fields> | Format-Table -AutoSize
```

A text field holding JSON is decoded in place and printed field by field: `$_.<field> | ConvertFrom-Json`. A field holding HTML is read as HTML.

## Automation API — extensions (both targets)

Group `api/microsoft/automation/v2.0`. `GET $group/companies($companyId)/extensions` lists every installed and published app: `packageId` (the key the actions take), `id` (the app id), `displayName`, `publisher`, `versionMajor` … `versionRevision`, `isInstalled`, `publishedAs`. On Business Central 29.0 an app published with `al publishapp` read `publishedAs` ` Dev`, with a leading space.

The actions are POSTs on `extensions($packageId)` with no body, answered 204: `Microsoft.NAV.uninstall` and `Microsoft.NAV.unpublish`, the debug app's teardown ([`DEBUG-APP.md`](DEBUG-APP.md)). The extension reference page omits unpublish; the automation APIs introduction documents it.

## Developer endpoint — symbols of an installed app (both targets)

Names the tables and fields of an app whose source is not at hand (a Microsoft test library outside BCApps, a partner app). Base: the SaaS base above; the container's dev endpoint is `http://<agent-container>:7049/<serverInstance>`. This endpoint takes `tenant=` on both targets: `default` on a SaaS sandbox, `$target.Tenant` on the container. The files go under `.output/`.

```powershell
$dev  = "<SaaS base, or the container's dev endpoint>"
$dt   = if ($target.Tenant) { $target.Tenant } else { 'default' }
$out  = '.output/symbols'
New-Item -ItemType Directory -Force $out | Out-Null
Invoke-WebRequest "$dev/dev/packages?publisher=<publisher>&appName=$([uri]::EscapeDataString('<app name>'))&versionText=<version>&tenant=$dt" -Headers $target.Headers -OutFile "$out/pkg.app"
$bytes = [IO.File]::ReadAllBytes("$out/pkg.app"); [IO.File]::WriteAllBytes("$out/pkg.zip", $bytes[40..($bytes.Length-1)]); Expand-Archive "$out/pkg.zip" "$out/pkg" -Force
```

`SymbolReference.json` lists objects and procedure signatures; `DocComments.xml` the XML docs. The 40-byte NAVX header must be dropped before unzipping. `DELETE` on `/dev/apps` is not supported.

## Standard API (both targets)

`api/v2.0` — the standard entity sets, each `<entitySet>` resolved from its `$metadata`. Company-bound like everything else. Custom fields are absent unless an app extends the API page.
