---
name: al-setup-matt-pocock-skills
description: Use whenever /mattpocock-skills:setup-matt-pocock-skills runs, to add the AL workflow's work-item structure to the tracker doc it writes, or when a repository's docs/agents/issue-tracker.md lacks that structure.
---

# al-setup-matt-pocock-skills - the AL verbs in the Tracker doc

In: `/mattpocock-skills:setup-matt-pocock-skills` running in a Consumer repository. The entry skill owns exploration, the section order, the draft the user reviews, and every write, including the Tracker doc it writes from the user's description of where work is tracked. Skills name verbs and the Tracker doc answers them, each in a `When a skill says "…"` section. This addition names the AL verbs the draft answers, adds the reads those answers need, and names where new Original work items go.

## Section A: the tracker

The user takes the entry's own option for their tracker, or **Other** with a description in their own words. The entry records it in `docs/agents/issue-tracker.md` as it does for any tracker.

Where new Original work items go is the one thing to settle. For GitHub it is the repository of the `origin` remote when `origin` is on github.com; otherwise ask one question: which repository takes them. For Azure DevOps, when the description names no project, ask one question: which project takes them. For any other Tracker, when the description names no place for them, ask one question: where new Original work items go. Offer no default.

## The verbs

The Tracker doc answers these as `## When a skill says "…"` sections, after a `## Work item structure` section of tool mechanics:

- "publish to the issue tracker": write the spec into the Original work item.
- "fetch the relevant ticket": read the item with its parent, children, and blockers.
- "create the Original work item", "write the spec", "write the acceptance criteria", "create a slice", "link a blocker", "comment", "attach a file", and "name the work item in a pull request".

## What the entry explores

Beyond the entry's own reads, read what the verbs need from the Tracker itself:

- The work item types a new Original work item, a defect, and a slice can be.
- The field that holds the spec on each type, and where the acceptance criteria go.

Azure DevOps: the backlog levels (`wit_backlog`, action `list`), each candidate type's fields (`wit_work_item`, action `get_type`), and one or two recent items read by id. GitHub: the owner's issue types (`gh api orgs/<owner>/issue-types`, where a 404 means none) and one or two recent issues read by number. Any other Tracker: what the user's description names, and the values that the seed templates' placeholders name, proposed from the description and those reads.

## What the entry writes

The AL sections of the Tracker doc follow the Tracker the user picked, in the same draft the user reviews. A re-run replaces `## Work item structure` and every AL verb section with the current ones.

- GitHub: the entry's own GitHub template, then the text of [GITHUB.md](GITHUB.md). The template's `## When a skill says "publish to the issue tracker"` and `## When a skill says "fetch the relevant ticket"` sections drop, because GITHUB.md carries each; every other template section stays.
- Azure DevOps: the user's description, then the text of [AZURE-DEVOPS.md](AZURE-DEVOPS.md).
- Any other Tracker: the user's description, then a `## Work item structure` section and the verb sections, each answered from the description and the reads, and the user confirms or corrects every answer in the draft.
- A seed template carries the placeholders `<new Original work item type>`, `<defect type>`, `<slice type>`, `<spec field for each type>`, and `<acceptance criteria location>`. The draft fills each with the value the reads proposed, and the user confirms or corrects it there. A GitHub repository whose owner defines no issue types has no `--type` in its sections.
- The `## Agent skills` block's issue tracker line is the entry's own, and it names the repository or project from Section A. Every skill reads it from that line.
- Section B runs as the entry has it; the Tracker doc says how a triage role is applied.

The setup is done when the draft the entry shows for review holds the AL sections of the Tracker doc for the picked Tracker with every verb section answered, from a seed template with its placeholders filled or from the description; each verb heading appears once, and the issue tracker line carries Section A's answer.
