# Namespace map contract

`apply-namespace-map.ps1` applies a reviewed map of an app's objects to namespaces in one deterministic pass. It reads and writes text only and never changes behavior: no access modifier, no formatting, no procedure body.

```
pwsh <path to this skill>/scripts/apply-namespace-map.ps1 -MapPath <map.json> -RootNamespace <root> [-AppDir <app folder>]
```

Run it from the repo root, after `provision.ps1` has downloaded the app's dependency symbols: the `using` lines come from them. `-RootNamespace` is a parameter because the pass runs before `moduleGate.rootNamespace` exists. `-AppDir` defaults to `appDir` in `al-build.json`; the `testApps` and `containerTestApps` folders inside it are left alone when `al-build.json` exists. Exit `0` is applied; exit `1` prints every problem and has written nothing. After a failure partway through a write, restore the tree with git before running again.

## The map

A JSON array with one entry per object of the app, `{ "type", "id", "name", "namespace" }`:

```json
[
  { "type": "codeunit", "id": 50100, "name": "Post Sales", "namespace": "Contoso.Sales" },
  { "type": "table", "id": 50102, "name": "Sales Log", "namespace": "Contoso.Sales.Logging" },
  { "type": "interface", "id": 0, "name": "Posting Rule", "namespace": "Contoso.Sales.Rules" }
]
```

- `type` is the AL object keyword, lower case: `table`, `tableextension`, `page`, `pageextension`, `pagecustomization`, `codeunit`, `report`, `reportextension`, `xmlport`, `query`, `enum`, `enumextension`, `controladdin`, `profile`, `interface`, `permissionset`, `permissionsetextension`, `entitlement`.
- `id` is the object ID, a positive number. `pagecustomization`, `controladdin`, `profile`, `interface`, and `entitlement` have none; their `id` is `0`.
- `name` is the object name as declared, without quotes. Matching ignores case.
- `namespace` is a dotted AL identifier: segments of letters, digits, and underscores, each starting with a letter or underscore. It is the root namespace or starts with the root namespace and a dot.
- An object is matched by `type`, `id`, and `name` together. Every object the app declares has exactly one entry, every entry names an object the app declares, and no entry appears twice.
- All objects of one file get the same namespace.

## What a file becomes

- `namespace <ns>;` goes above the file's first object and above that object's leading attributes and `///` documentation lines, below any other header comments, followed by a blank line.
- `using <ns>;` lines follow, one per other namespace whose objects the file names in code, sorted, each once, then a blank line.
- The file moves to the folder its namespace names below the source root (`src` when the app has one, otherwise the app folder); a file at the root namespace sits in the source root itself. This is the layout rule 1 of the module gate checks. Folders the moves empty are removed.
- The file takes the CodeCop file name `<ObjectName>.<Type>.al`, from the object name's letters and digits only: `Table`, `TableExt`, `Page`, `PageExt`, `PageCust`, `Codeunit`, `Xmlport`, `Report`, `ReportExt`, `Query`, `Enum`, `EnumExt`, `ControlAddin`, `Profile`, `Interface`, `PermissionSet`, `PermissionSetExt`. `entitlement` is not in Microsoft's type map, and a file with several objects or a name with no letter or digit has no single name to build; those keep their file name.
- Every other byte stays: UTF-8, a BOM, and the file's line endings.

## Where the using lines come from

A name counts as a reference when it appears as an identifier or quoted identifier outside comments, string literals, preprocessor lines, member accesses after a dot (`Rec."Name"`), the file's own object declarations, and the type words that introduce a name (`Record`, `Database::`). Its namespaces come from the map for the app's own objects and from every `.app` in the app's symbol cache for dependencies: the Base App, the System App, and each vendor package. A dependency object with no namespace needs no `using`.

- A reference whose context fixes the object type (`Record X`, `Codeunit X`, `Database::X`, `Codeunit::X`) resolves among objects of that type. Two namespaces for it fail the pass, naming the file, the reference, and the candidates; the file's own namespace is the closest scope and wins when it is one of them.
- Any other reference adds every namespace its name can mean across object types. An unused `using` is the hidden diagnostic AL0792 and cannot turn the gate red; a duplicate `using` is the warning AL0790, so none is written twice.
- Extension objects and `pagecustomization` are never named, so they contribute no `using`.

## What fails before anything is written

- A breach of the map rules above, a map file that is missing, not JSON, or not an array, or a root namespace that is not a dotted AL identifier.
- An app object the map leaves out, and a map entry whose object the app does not have.
- Two files sent to one path, including two names that reduce to the same letters and digits in one namespace, and a path held by a file outside the app's `.al` files.
- A file that is not UTF-8, declares no object, or already has a `namespace` or `using` line. Restore the tree, then run the pass again.
- A typed reference that resolves to two namespaces.
- No `.app` in the symbol cache, or one that is not a symbol package: run `provision.ps1`.

A test app is a separate app with its own map and its own symbol cache. A reference by object number or through reflection is not seen.
