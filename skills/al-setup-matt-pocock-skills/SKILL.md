---
name: al-setup-matt-pocock-skills
description: Use whenever /mattpocock-skills:setup-matt-pocock-skills runs, to add the AL workflow's work-item structure to the tracker doc it writes, or when a repository's docs/agents/issue-tracker.md lacks that structure.
---

# al-setup-matt-pocock-skills - the work-item structure in the tracker doc

In: `/mattpocock-skills:setup-matt-pocock-skills` running in a Consumer repository. The entry skill owns exploration, the section order, the draft the user reviews, and every write, including the tracker doc it writes from the user's description of where work is tracked. This addition adds the structure the AL workflow needs after that description. It offers no tracker of its own and chooses no target.

## Section A: the tracker

The user takes the entry's own option for their tracker, or **Other** with a description in their own words. The entry records it in `docs/agents/issue-tracker.md` as it does for any tracker.

When the description names no project for new Original work items, ask one question: which project takes them. Offer no default.

## What the entry writes

- `docs/agents/issue-tracker.md` is the user's description, then the text of [WORK-ITEM-STRUCTURE.md](WORK-ITEM-STRUCTURE.md) unchanged, in the same draft the user reviews. A doc that already holds that heading takes the current text in its place.
- The `## Agent skills` block's issue tracker line is the entry's own, and it names the project that takes new Original work items. Every skill reads the backlog project from that line.
- Section B runs as the entry has it; the structure text says how a triage role is applied.

The setup is done when the draft the entry shows for review holds the structure text after the user's description and the issue tracker line names the project that takes new Original work items.
