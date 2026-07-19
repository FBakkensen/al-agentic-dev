# PR Classification Protocol

Classify one PR. Emit exactly one JSON line in that PR's todo description.

Stay inside that PR. Do not inspect other JSONL records or the wider codebase unless Deep Dive requires it.

## Inputs

- PR number.
- Its matching `type == "pr"` record in `.output/releases/release-analysis.jsonl`.

Common fields: `title`, `body` / `description`, `files`, `labels`, `breakingChangeIndicators`, `keyALChanges`, `commits`.

## Steps

1. Locate the matching record.
2. Apply the first matching type rule:

| Order | Type | Rule |
|---|---|---|
| 1 | `breaking` | `breakingChangeIndicators` non-empty, breaking-change label present, or public API surface changed |
| 2 | `exclude` | All changed files in `test/`, `docs/`, `.github/`, or `scripts/`; no runtime or user impact |
| 3 | `feature` | `feat:` prefix and the change introduces new user-facing functionality |
| 4 | `bugfix` | `fix:` prefix and the change resolves a user-facing defect |
| 5 | `technical` | `refactor:`, `chore:`, or `perf:` prefix, or change is internal only |
| 6 | `improvement` | Enhances existing user-facing functionality |

3. Extract these slots:
   - **User-facing** (`feature`, `improvement`, `bugfix`): `area`, `desc`, `details`.
   - **Breaking**: `change`, `migration`.
   - **Technical**: `category`, `summary`.
   - **Exclude**: `reason`.
4. Emit the matching template as one line in the PR todo description.

## Slot rules

- **`area`** — name the page, report, API, codeunit, table, or workflow. _Avoid_: `Configuration`, `the page`. Use: `Item Configurator List page`, `Codeunit 80 Sales-Post`, `Sales Header table`.
- **`desc`** — what the user can now do or no longer hits. One sentence, BC vocabulary. _Avoid_: `Updated logic`. Use: `Bulk-copy configuration from one item to many in one action`.
- **`details`** — concrete UI surface or usage path. Name the field, action, page, or runtime entry point. _Avoid_: empty on a user-facing PR.
- **`category`** — exactly one of `refactor`, `chore`, `perf`.
- **`summary`** — one line, technical audience, what changed (not how).
- **`change`** + **`migration`** — what broke + the exact steps a consumer takes. Migration is imperative, ordered, code-grounded.
- **`reason`** — one of `test`, `docs`, `ci`, `al-go` (or another short tag if the file scope justifies it).

`Updated logic` means the title was classified without `keyALChanges` or `files` → Deep Dive before re-emitting.

## Output templates

User-facing:

```json
{"pr":<NUMBER>,"type":"feature|improvement|bugfix","area":"<page/codeunit/report>","desc":"<user impact>","details":"<field/action/page>"}
```

Breaking:

```json
{"pr":<NUMBER>,"type":"breaking","change":"<what changed>","migration":"<exact steps>"}
```

Technical:

```json
{"pr":<NUMBER>,"type":"technical","category":"refactor|chore|perf","summary":"<one line>"}
```

Excluded:

```json
{"pr":<NUMBER>,"type":"exclude","reason":"test|docs|ci|al-go"}
```

## Per-PR Yes/No

- No: `{"pr":142,"type":"improvement","area":"Configuration","desc":"Updated logic","details":""}`
- Yes: `{"pr":142,"type":"improvement","area":"Item Configurator List page","desc":"Bulk-copy configuration from one item to many in one action","details":"\"Copy Configuration\" action; target items selected via lookup"}`

The Yes line names page, action, and behaviour. The No line names none.

## Deep Dive Protocol

Run for a vague, ambiguous, or quality-gate failure.

1. Re-read `body`/`description`, `keyALChanges`, `files`, and `commits`.
2. Name exact pages, actions, and fields. If `keyALChanges` omits them, inspect file paths and AL headers.
3. Inspect one relevant AL object only if the surface remains unnamed.
4. Reclassify when evidence changes the type: a `chore:` that adds a user action is `feature` or `improvement`.
5. Rewrite `area`, `desc`, and `details`; overwrite the todo description with the sharper JSON line.

One Deep Dive per PR. If its second pass remains vague, add `"deepDive":"insufficient evidence"` to the todo description and leave it for human resolution before rendering.
