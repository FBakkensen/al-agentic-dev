# BCApps navigation — paths, branches, search rules

## Branch model

- `main` — the next, unreleased BC version.
- `releases/NN.x` — shipped version NN (e.g. `releases/26.x`). Point branches `releases/NN.M` also exist.
- Areas consolidated into BCApps at different times. System Application, Business Foundation, and Tools go back furthest. First-party `src/Apps/` exists on matching release branches from `releases/27.x`. The BaseApp `src/Layers/` landed on `main` first and is `main`-only so far.

A 404 on a release branch means the path moved or the area predates the consolidation there.

## Layout (`main`)

```
src/
├── Layers/W1/                    # Worldwide Base Application — start here
│   ├── BaseApp/                  # Flat domain folders: Sales/, Purchases/, Inventory/, Finance/,
│   │                             #   Bank/, Manufacturing/, Warehouse/, Service/, CRM/, Assembly/,
│   │                             #   Foundation/, Integration/, System/, …
│   │                             #   Cross-domain *.al objects sit loose at BaseApp root
│   ├── Tests/                    # BaseApp tests (ERM/, Sales/, …) + ApplicationTestLibrary/
│   └── Application/              # Application-layer glue app
├── Layers/<CC>/                  # DE, US, GB, … — localization layers, same shape as W1
├── System Application/           # App/ (platform modules: Email/, Cryptography, …), Test/, Test Library/
├── Business Foundation/          # App/ (No. Series, …), Test/, Test Library/
├── Apps/W1/                      # ~100 first-party apps: APIV2/, ExternalEvents/, Shopify/, …
├── Apps/<CC>/                    # Country-specific first-party apps
└── Tools/                        # Test Framework/, Performance Toolkit/, AI Test Toolkit/
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

## Narrow every search

Every `gh search code` query carries an inline `path:` qualifier — localization layers (`src/Layers/DE`, `src/Apps/IN`, …) mirror the W1 shape and drown W1 results in country noise. The qualifier is a **full-path prefix from repo root, unquoted** (`path:src/Layers/W1`). Quoting the value breaks the match. Spaces in folder names are fine unquoted.

## Index caveats

Search indexes `main` only. Files above GitHub's search-index size cap never appear in results — `SalesPost.Codeunit.al`, ~780 KB, is invisible to search. A subscriber's `[EventSubscriber(...)]` attribute names the publishing codeunit and event verbatim.

## Reading the source

- An event publisher is an `[IntegrationEvent(...)]` attribute followed by an empty procedure carrying the full signature — the signature, not the name, carries the contract. Partner-facing events are `[ExternalBusinessEvent(...)]` declarations under `src/Apps/W1/ExternalEvents/`.
- A System Application module exposes a public facade codeunit delegating to an internal implementation codeunit — the facade is the quotable contract.
- Standard field numbers are stable across releases: in `field(1; "No."; Code[20])`, the number is the referenceable part.
