## Work item structure

For an Original work item and its child work items, this structure governs where the conventions above differ: no skill closes or reopens one, and every `gh` call passes `--repo` from the tracker line.

The `## Agent skills` block's issue tracker line names the repository that takes new Original work items, and that line is the one to read. Pass it to every `gh` call as `--repo <owner>/<repo>`.

### Tools

Every read and write goes through `gh`, version 2.99.0 or later (`gh --version`), signed in with `gh auth login` (`gh auth status`). When `gh` is missing, older, or signed out, show the exact change and stop; write no substitute record anywhere else.

### Work items

- **Read**: an existing issue is read by its number: `gh issue view <n> --repo <owner>/<repo> --json number,title,body,updatedAt,issueType,labels,parent,subIssues,blockedBy,comments`.
- **The Original work item** is the issue the request arrives on. `Original` names its role in this workflow; its parent and sub-issues stay as they are.
- **A new Original work item** is created only when the request arrives on none. It is an issue of type Feature, or Bug when the request reports a defect, created in the tracker line's repository: `gh issue create --type Feature --title <title> --body-file <file>`.
- **Slices**: one slice creates no child, and the Original work item is executable. Several slices each get one sub-issue of type Task directly under the Original work item: `gh issue create --type Task --parent <original> --title <title> --body-file <file>`.
- **Never**: create a grandchild sub-issue below the Original work item; re-parent, transfer, close, or reopen an item; set a Project field, milestone, or assignee.
- **Comment**: `gh issue comment <n> --body-file <file>`.

### Fields

- One body holds everything. The spec goes first, under the entry's headings, and `## Acceptance Criteria` ends the body with the Gherkin `Behavior` before the `Test specification`. A Bug's spec lives in its body too.
- An update to a body read earlier starts with the `updatedAt` that read returned. Read it again before the write; when it changed, read the body again and re-apply the edit, because GitHub has no revision test.

### Links

Parent and blocking edges are native, never text lines in a body.

- **Parent**: `--parent <original>` at creation, or `gh issue edit <n> --parent <original>` on an existing issue that has no parent.
- **Blocking**: on the blocked item, `gh issue edit <blocked> --add-blocked-by <blocker>`.

### Triage

Triage roles are labels: each role string in `docs/agents/triage-labels.md` is a label name. Add or remove the one role alone, with `gh issue edit <n> --add-label <role>` or `--remove-label <role>`; the team's other labels stay. A role the repository has no label for is created first with `gh label create <role>`; `gh issue edit` refuses an unknown label. A role never closes or reopens an item.

### Attach files

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

### How a pull request names a work item

A GitHub pull request says `Fixes #<executable item>` in its body, or `Fixes <owner>/<repo>#<n>` when the item sits in another repository, so its merge closes the item. An Azure Repos pull request carries the issue's URL.

### When a skill says "publish to the issue tracker"

Write into the Original work item's body as Fields places it. Create an issue only as Work items allows.

### When a skill says "fetch the relevant ticket"

Read the issue by number with `gh issue view` as Work items gives. Its output carries the parent, the sub-issues, and the blockers.
