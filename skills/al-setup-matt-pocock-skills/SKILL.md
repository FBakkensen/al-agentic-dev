---
name: al-setup-matt-pocock-skills
description: Use whenever /mattpocock-skills:setup-matt-pocock-skills runs, or when a repository's engineering skills should track work as Azure DevOps work items instead of GitHub or GitLab issues.
---

# al-setup-matt-pocock-skills - Azure DevOps as the issue tracker

In: `/mattpocock-skills:setup-matt-pocock-skills` running in a Consumer repository. The entry skill owns exploration, the section order, the draft the user reviews, and every write. This addition adds one option to its Section A and the text that option writes.

## Section A: the Azure DevOps option

Offer **Azure DevOps** beside the entry's own options: work items in org `naveksaas`, read and written through the bundled `ado` MCP server.

Recommend it when `git remote -v` points at Azure Repos, `dev.azure.com/naveksaas` or `naveksaas.visualstudio.com`. Otherwise the entry's own recommendation stands, and Azure DevOps is one more option.

When the user picks it, ask one question before Section B: which project takes new Original work items. Recommend `NAVEKSA NEXT`, ShopFloor's backlog. Confirm the answer is a project in the org with `mcp__plugin_al-agentic-dev_ado__core_list_projects`.

## What the entry writes

- `docs/agents/issue-tracker.md` holds the text of [ISSUE-TRACKER.md](ISSUE-TRACKER.md), unchanged. It names no project; the issue tracker line below is the project's one home.
- The `## Agent skills` block's issue tracker line names the backlog project:

  ```markdown
  Azure DevOps work items in org `naveksaas`; new Original work items go into the `<backlog project>` project. See `docs/agents/issue-tracker.md`.
  ```

- Section B runs as the entry has it. Its role strings are applied as Azure DevOps tags, so the triage labels line reads "the five default roles, applied as Azure DevOps tags" when the defaults stay.

The setup is done when the entry's own close runs with `docs/agents/issue-tracker.md` holding the Azure DevOps text and the issue tracker line naming a project that `core_list_projects` returned.
