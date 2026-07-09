# Search Patterns

Heuristics over `microsoft/BCApps`, run through the `gh` CLI. Each pattern names *what* to search for, *where*, and *what to expect on a hit*. The mechanism is the same three commands throughout:

```bash
gh search code "<query>" --repo microsoft/BCApps                 # find the declaration line (add path: to narrow) — indexes main only
gh repo read-file "<path>" --repo microsoft/BCApps --ref <branch> # quote it verbatim — no clone
gh repo read-dir "<path>"  --repo microsoft/BCApps --ref <branch> # list a folder when you don't know the filename
```

`gh search code` returns `repo:path: matching line` — that path feeds straight into `read-file`. Search finds the path on `main`; `read-file --ref releases/NN.x` quotes the consumer's version **where the area exists on that branch** — BaseApp (`src/Layers/`) is on `main` only so far, so BaseApp quotes come from `main` with the ref named; System Application, Business Foundation, and (from 27.x) first-party apps version-match (see `repo-structure.md` for the branch model). Narrow with an inline `path:` qualifier — a **full-path prefix from repo root, unquoted** (`path:src/Layers/W1`; quoting the value breaks the match, spaces in folder names are fine unquoted); never search without one — localization layers (`src/Layers/DE`, `src/Apps/IN`, …) drown W1 results.

Two index caveats: search covers `main` only, and files above GitHub's search-index size cap never appear in results (`SalesPost.Codeunit.al`, ~780 KB, is invisible to search) — find those by searching for a subscriber or neighbouring object, or go straight to the known path (`repo-structure.md` lookup table, `read-dir`). Big files are whole-file reads — pipe through `grep -n` to find the line, then `sed -n 'A,Bp'` for the surrounding block.

## Objects

- **Codeunit** — `gh search code 'codeunit "Sales-Post" path:src/Layers/W1/BaseApp/Sales' --repo microsoft/BCApps`. Expect: declaration with ID, procedures, event publishers.
- **Table** — `gh search code 'table 18 Customer path:src/Layers/W1' --repo microsoft/BCApps`. Expect: declaration, field list, triggers.
- **Page** — `gh search code 'page <id> "<name>" path:src/Layers/W1' --repo microsoft/BCApps`, narrowed by domain. Expect: declaration, layout, actions.

## Events

- **Named publisher** — `gh search code 'OnBeforePostSalesDoc path:src/Layers/W1/BaseApp' --repo microsoft/BCApps`, then `read-file` the hit. Expect: `[IntegrationEvent(...)]` attribute followed by the empty publisher procedure with its full signature. The publisher's own file may be above the index cap — a subscriber hit still names the publishing codeunit and event verbatim in its `[EventSubscriber(...)]` attribute.
- **Discover events near an object** — `read-file` the codeunit, `grep -n 'IntegrationEvent'` for the attribute lines paired with publisher declarations. Read the signature, not the name.
- **External / business events** — `gh search code 'ExternalBusinessEvent path:src/Apps/W1/ExternalEvents' --repo microsoft/BCApps`. Expect: `[ExternalBusinessEvent(...)]` declarations.

## Tables and fields

- **Field declaration** — `read-file` the table, `grep -n 'field('` + field name. Expect: type, length, and any `OnValidate` / `OnLookup` / `OnAfterValidate` triggers.
- **Standard ID** — fields with documented IDs (`field(1; "No."; Code[20])`) signal a stable contract you can reference.

## Tests and libraries

- **Library** — `gh search code '"Library - Sales" path:src/Layers/W1/Tests' --repo microsoft/BCApps`. Expect: helper procedures (`CreateSalesOrder`, `CreateSalesHeader`, `CreateSalesLine`).
- **Standard test** — `gh search code '<helper> path:src/Layers/W1/Tests/ERM' --repo microsoft/BCApps` (e.g. `CreateSalesOrder`). Expect: arrange/act/assert flows you can mirror.
- **Test framework** — `gh search code '<name> path:src/Tools/Test Framework' --repo microsoft/BCApps` for Assert, Any, TestPage infrastructure.

## API implementations

- **API page** — `gh search code '<entity> path:src/Apps/W1/APIV2' --repo microsoft/BCApps`. Expect: API page declaration with `EntityName`, `EntitySetName`, exposed fields.

## System and foundation

- **System Application module** — `gh search code '<name> path:src/System Application/App' --repo microsoft/BCApps`. Expect: the module's facade codeunit and its implementation split.
- **No. Series / foundation logic** — `gh search code '<name> path:src/Business Foundation/App' --repo microsoft/BCApps`.

## Workflow

Start from a known object or event name. Narrow by `path:`. Confirm the declaration with `read-file` on the consumer's release branch before deciding where to hook or what to mirror — and name the ref the quote came from.

_Avoid_: matching on a name alone, or `read-file`-ing a huge posting codeunit whole when a `grep -n` + `sed -n` window is what you need. Read the declaration. Quote the signature.
