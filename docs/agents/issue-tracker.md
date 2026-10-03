# Issue tracker: GitHub

Issues and specs for this repo live on `https://github.com/fbakkensen/al-agentic-dev`. Use the `gh` CLI for all operations.

This tracker covers changes to al-agentic-dev itself. Consumer repositories track work in their own Tracker, as their setup records it.

## Host

- `gh issue` and `gh pr` infer `github.com` from `git remote -v` inside the clone; outside it, pass `-R github.com/fbakkensen/al-agentic-dev`.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`. `--add-label` fails for a label the repo lacks; create it first with `gh label create "..."`.
- **Close**: `gh issue close <number> --comment "..."`

### Relationships and media

`gh` 2.99.0 or later sets these natively; no `gh api` call and no database id are needed.

- **Sub-issue**: `gh issue create --parent <n>` creates one. `gh issue edit <child> --parent <n>` or `gh issue edit <n> --add-sub-issue <child>[,<child>]` links an existing one; `--remove-parent` and `--remove-sub-issue` undo it.
- **Blocking**: `gh issue create --blocked-by <n>[,<n>]` (and `--blocking`) sets edges at creation. `gh issue edit <n> --add-blocked-by <blocker>` / `--remove-blocked-by <blocker>` (and `--add-blocking` / `--remove-blocking`) change them later. An edge that already exists fails with "Target issue has already been taken".
- **Read relationships**: `gh issue view <n> --json parent,subIssues,blockedBy,blocking`. `--json` and `--comments` don't combine; ask for `comments` in the `--json` list instead.
- **Images and video**: `--attach '<file>#<alt text>'` on `gh issue create|edit|comment` and `gh pr create|edit|comment` uploads PNG, JPEG, GIF, WebP, SVG, MP4, MOV, or WebM. A body reference `![<alt>](./<file>)` is rewritten to the uploaded asset, and an unreferenced file is appended. Other file types can't be attached. On a private repo the asset loads only for signed-in members.
- **Issue types**: this repo belongs to a personal account, so it has none and `--type` fails here. `--type` works in an organization repository that defines types.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create an issue on the host above.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The map is one issue labelled `wayfinder:map`; its tickets are native sub-issues. Sub-issues and issue dependencies are both enabled on this host.

- **Child ticket**: `gh issue create --parent <map> --label wayfinder:<type> --title "..." --body-file <file>`, adding `--blocked-by <n>[,<n>]` when it has blockers. The labels `wayfinder:map`, `wayfinder:grilling`, `wayfinder:task`, `wayfinder:research`, and `wayfinder:prototype` exist.
- **Blocking**: on an existing ticket, `gh issue edit <child> --add-blocked-by <blocker>`. `gh issue view <child> --json blockedBy` lists its blockers with their state.
- **Frontier query**: one GraphQL call returns the children in map order along with claims and blockers:

  ```
  gh api graphql -f query='query { repository(owner:"fbakkensen", name:"al-agentic-dev") { issue(number:<map>) { subIssues(first:50) { nodes { number title state url assignees(first:5){nodes{login}} labels(first:10){nodes{name}} blockedBy(first:20){nodes{number state}} } } } } }'
  ```

  Keep the children that are open, have no assignee, and have no open `blockedBy` node. The first one in order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` is the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append the gist and link to the map's Decisions so far.
