---
name: al-setup-matt-pocock-skills
description: Use whenever /mattpocock-skills:setup-matt-pocock-skills runs, to add the AL workflow's work-item structure to the tracker doc it writes, or when a repository's docs/agents/issue-tracker.md lacks that structure.
---

# al-setup-matt-pocock-skills - the work-item structure in the tracker doc

In: `/mattpocock-skills:setup-matt-pocock-skills` running in a Consumer repository. The entry skill owns exploration, the section order, the draft the user reviews, and every write, including the tracker doc it writes from the user's description of where work is tracked. This addition adds the structure the AL workflow needs after that description. It offers no tracker of its own and chooses no target.

## Section A: the tracker

The user takes the entry's own option for their tracker, or **Other** with a description in their own words. The entry records it in `docs/agents/issue-tracker.md` as it does for any tracker.

The tracker line names where new Original work items go. For GitHub it is the repository of the `origin` remote when `origin` is on github.com; otherwise ask one question: which repository takes them. For Azure DevOps, when the description names no project, ask one question: which project takes them. Offer no default.

## What the entry writes

The structure text follows the Tracker the user picked, in the same draft the user reviews. A doc that already holds a `## Work item structure` heading takes the current text in its place.

- GitHub: the entry's own GitHub template, then the text of [GITHUB.md](GITHUB.md) unchanged. The template's `## When a skill says "publish to the issue tracker"` and `## When a skill says "fetch the relevant ticket"` sections drop, because GITHUB.md carries each; every other template section stays.
- Azure DevOps: the user's description, then the text of [AZURE-DEVOPS.md](AZURE-DEVOPS.md) unchanged.
- Any other Tracker: the user's description alone, and say the AL workflow serves GitHub and Azure DevOps Trackers.
- The `## Agent skills` block's issue tracker line is the entry's own, and it names the repository or project that takes new Original work items. Every skill reads it from that line.
- Section B runs as the entry has it; the structure text says how a triage role is applied.

The setup is done when the draft the entry shows for review holds the structure text for the picked Tracker, each "publish" and "fetch" heading appears once, and the issue tracker line names where new Original work items go.
