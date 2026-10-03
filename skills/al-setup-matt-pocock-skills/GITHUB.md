## Work item structure

Where the conventions above differ, this structure governs. The `## Agent skills` block's issue tracker line names the repository that takes new Original work items, and that line is the one to read. Pass it to every `gh` call as `--repo <owner>/<repo>`.

### Tools

Every read and write goes through `gh`, version 2.99.0 or later (`gh --version`), signed in with `gh auth login` (`gh auth status`). When `gh` is missing, older, or signed out, show the exact change and stop; write no substitute record anywhere else.

### Reading an item

An existing issue is read by its number: `gh issue view <n> --repo <owner>/<repo> --json number,title,body,updatedAt,issueType,labels,parent,subIssues,blockedBy,comments`.

### Updating an item

An update starts from the body the read just returned, replaces only its own section, and writes the whole body back, so every other section in that body stays. It carries the `updatedAt` that read returned. Read it again before the write; when it changed, read the body again and re-apply the edit, because GitHub has no revision test.

### Triage

Triage roles are labels: each role string in `docs/agents/triage-labels.md` is a label name. Add or remove the one role alone, with `gh issue edit <n> --add-label <role>` or `--remove-label <role>`; the team's other labels stay. A role the repository has no label for is created first with `gh label create <role>`; `gh issue edit` refuses an unknown label.

## When a skill says "publish to the issue tracker"

Write the spec into the Original work item, as "write the spec" gives.

## When a skill says "fetch the relevant ticket"

Read the issue by number as Reading an item gives. Its output carries the parent, the sub-issues, and the blockers.

## When a skill says "create the Original work item"

`gh issue create --type <new Original work item type> --title <title> --body-file <file>`, or `--type <defect type>` when the request reports a defect. A repository with no issue types takes no `--type`.

## When a skill says "write the spec"

Put the spec in the field `<spec field for each type>` names for the item's type, with `gh issue edit <n> --body-file <file>`, as Updating an item gives; the acceptance criteria and every other section of that body stay.

## When a skill says "write the acceptance criteria"

Put the Gherkin `Behavior` and the `Test specification` in `<acceptance criteria location>`, with `gh issue edit <n> --body-file <file>`, as Updating an item gives; the spec and every other section there stay.

## When a skill says "create a slice"

`gh issue create --type <slice type> --parent <original> --title <title> --body-file <file>`, which makes the issue a sub-issue of the Original work item; a repository with no issue types takes no `--type`. An existing issue takes a parent with `gh issue edit <n> --parent <original>`.

## When a skill says "link a blocker"

On the blocked item, `gh issue edit <blocked> --add-blocked-by <blocker>`.

## When a skill says "comment"

`gh issue comment <n> --body-file <file>`.

## When a skill says "attach a file"

`gh` attaches PNG, JPEG, GIF, WebP, SVG, MP4, MOV, and WebM only. Write the body with the reference where the image belongs:

```markdown
![<alt>](./<file>)
```

Then pass the body and the files in one call, `gh issue edit` for a body or `gh issue comment` for a comment:

```bash
gh issue edit <n> --body-file <body> --attach ./<file>#<alt>
gh issue comment <n> --body-file <body> --attach ./<file>#<alt>
```

Attached is verified when a fresh read of the body or comment shows an uploaded-asset URL where each `./<file>` reference was.

The BPMN source, which `--attach` refuses, goes in one comment on the Original work item that opens with `BPMN source`, then a `<details>` block holding an `xml` fence. A refresh edits that comment by its id, the number after `#issuecomment-` in its URL, with `gh api --method PATCH repos/<owner>/<repo>/issues/comments/<id> -F body=@<file>`; it never posts a second one.

A refreshed image is attached again: put its `./<file>` reference back where its old uploaded-asset URL was, and attach it in the same call.

## When a skill says "name the work item in a pull request"

A GitHub pull request says `Fixes #<executable item>` in its body, or `Fixes <owner>/<repo>#<n>` when the item sits in another repository, so its merge closes the item. An Azure Repos pull request carries the issue's URL.
