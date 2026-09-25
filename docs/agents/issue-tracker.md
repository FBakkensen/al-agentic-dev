# Issue tracker: GitHub Enterprise

Issues and specs for this repo live on `https://9altitudes.ghe.com/gtm-general/al-agentic-dev`. Use the `gh` CLI for all operations.

This tracker covers changes to al-agentic-dev itself. Consumer projects track work in Azure DevOps under their own conventions.

## Host

- `gh issue` and `gh pr` infer `9altitudes.ghe.com` from `git remote -v` inside the clone; outside it, pass `-R 9altitudes.ghe.com/gtm-general/al-agentic-dev`.
- `gh api` takes `--hostname 9altitudes.ghe.com` on every call.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

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

- **Database id**: `gh api --hostname 9altitudes.ghe.com repos/gtm-general/al-agentic-dev/issues/<n> --jq .id`. This is not the `#number` and not the `node_id`.
- **Child ticket**: create the issue, then run `gh api --hostname 9altitudes.ghe.com --method POST repos/gtm-general/al-agentic-dev/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>`. Label it `wayfinder:<type>`. `wayfinder:map`, `wayfinder:grilling`, and `wayfinder:task` exist; create `wayfinder:research` or `wayfinder:prototype` with `gh label create` the first time one is needed.
- **Blocking**: `gh api --hostname 9altitudes.ghe.com --method POST repos/gtm-general/al-agentic-dev/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`. `issue_dependencies_summary.blocked_by` counts open blockers only.
- **Frontier query**: one GraphQL call returns the children in map order along with claims and blockers:

  ```
  gh api graphql --hostname 9altitudes.ghe.com -f query='query { repository(owner:"gtm-general", name:"al-agentic-dev") { issue(number:<map>) { subIssues(first:50) { nodes { number title state url assignees(first:5){nodes{login}} labels(first:10){nodes{name}} blockedBy(first:20){nodes{number state}} } } } } }'
  ```

  Keep the children that are open, have no assignee, and have no open `blockedBy` node. The first one in order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` is the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append the gist and link to the map's Decisions so far.
