# Repository Structure

`microsoft/BCApps` is Microsoft's official repository for Business Central application development — BaseApp, System Application, Business Foundation, first-party apps, and the developer test tooling, consolidated into one repo. Navigate by domain path, not by guessing filenames — when unsure of a folder's contents, `gh repo read-dir "<path>" --repo microsoft/BCApps` lists it without cloning.

## Branch model

- **`main`** — the next, unreleased BC version. The only branch `gh search code` indexes.
- **`releases/NN.x`** — shipped version NN (e.g. `releases/26.x`); point branches `releases/NN.M` also exist. Quote from the branch matching the consumer's `app.json` major.
- Not every area exists on every branch: BCApps consolidated over time. System Application, Business Foundation, and Tools go back furthest; first-party `src/Apps/` from `releases/27.x`; the BaseApp `src/Layers/` landed on `main` first. A 404 on a release branch means the area predates the consolidation there — `read-dir --ref` to check, then quote `main` and name the ref.

## Layout (main)

```
src/
├── Layers/                           # Base Application, per country/region
│   ├── W1/                           # Worldwide base — start here
│   │   ├── BaseApp/                  # Core BC application source, flat domain folders
│   │   │   ├── Sales/                # Orders, invoices, quotes, returns (Posting/, Document/, History/, Pricing/, …)
│   │   │   ├── Purchases/            # Purchase orders, invoices, vendors
│   │   │   ├── Inventory/            # Items, locations, tracking, adjustments
│   │   │   ├── Finance/              # G/L, journals, VAT, currencies
│   │   │   ├── Bank/                 # Bank accounts, reconciliation
│   │   │   ├── Manufacturing/        # Production orders, BOMs, routing
│   │   │   ├── Warehouse/            # Picks, puts, bin contents
│   │   │   ├── Service/              # Service management
│   │   │   ├── CRM/                  # Contacts, opportunities, campaigns
│   │   │   ├── Assembly/             # Assembly orders
│   │   │   ├── FixedAssets/  HumanResources/  Projects/  CashFlow/  CostAccounting/
│   │   │   ├── Foundation/           # No. series hooks, company info, navigation
│   │   │   ├── Integration/          # External integrations (CRM/Dataverse, …)
│   │   │   ├── System/  Utilities/  RoleCenters/  Permissions/
│   │   │   └── *.al                  # Cross-domain objects sit loose at BaseApp root
│   │   ├── Tests/                    # BaseApp tests (ERM/, Bank/, Job/, Marketing/, Sales/, …)
│   │   │   └── ApplicationTestLibrary/  # Library - * helper codeunits
│   │   └── Application/              # Application-layer glue app
│   └── <CC>/                         # DE, US, GB, … — localization layers, same shape
│
├── System Application/
│   ├── App/                          # Platform modules: Email/, Azure AD */, Cryptography, Retention Policy, Telemetry, …
│   ├── Test/                         # Module tests
│   └── Test Library/                 # System app test helpers
│
├── Business Foundation/              # Foundational business logic (No. Series, …)
│   ├── App/  Test/  Test Library/
│
├── Apps/                             # First-party apps
│   ├── W1/
│   │   ├── APIV1/ & APIV2/           # REST API implementations ({app,test}/src/)
│   │   ├── ExternalEvents/           # Business events for external subscribers
│   │   ├── Shopify/  EDocument/  Subscription Billing/  Sustainability/
│   │   ├── Email - * Connector/  External File Storage - */
│   │   └── … (~100 apps; read-dir when unsure of the name)
│   └── <CC>/                         # Country-specific first-party apps
│
├── Tools/
│   ├── Test Framework/               # Test runner, assert, Any, TestPage infrastructure
│   ├── Performance Toolkit/
│   └── AI Test Toolkit/
│
├── GDL/  DemoTool/  DisabledTests/  rulesets/
```

## Lookup table

| Looking for | Path |
|---|---|
| **Events in a domain** | `src/Layers/W1/BaseApp/<Domain>/`, plus `src/Apps/W1/ExternalEvents/` for partner-facing events |
| **Table definitions** | `src/Layers/W1/BaseApp/<Domain>/*.Table.al` |
| **Posting routines** | `src/Layers/W1/BaseApp/<Domain>/Posting/` (e.g. `Sales/Posting/SalesPost.Codeunit.al`) |
| **Standard tests** | `src/Layers/W1/Tests/<Domain>/` |
| **Test libraries** | `src/Layers/W1/Tests/ApplicationTestLibrary/`, `src/Tools/Test Framework/` |
| **API implementations** | `src/Apps/W1/APIV2/app/src/` |
| **System utilities** | `src/System Application/App/<Module>/` |
| **No. Series & foundation logic** | `src/Business Foundation/App/` |
| **First-party app source** | `src/Apps/W1/<AppName>/app/` |

_Avoid_: searching without a `path:` qualifier — localization layers (`src/Layers/DE`, `src/Apps/IN`, …) mirror the W1 shape and drown results in country noise. Narrow to `path:src/Layers/W1` (or the specific app) first — the qualifier is a full-path prefix from repo root, unquoted.
