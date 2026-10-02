# al-agentic-dev

A Claude Code plugin of Agent Skills for AL and Business Central development, owned by Flemming Bakkensen, serving Naveksa's AL work, and forked from an original built for 9Altitudes.

## Language

**Plugin repository**:
This repository: the plugin's source, hosted and distributed on github.com.
_Avoid_: the repo, the plugin repo, upstream

**Consumer repository**:
A Naveksa AL repository that the shipped skills work inside, with its own Code host and its own Tracker.
_Avoid_: project repo, customer repo, target repo

**Code host**:
Where a Consumer repository's code and pull requests live — Azure Repos, or GitHub under the `naveksadk` organization; its remote says which.
_Avoid_: platform, provider, the host

**Tracker**:
Where a Consumer repository's work items live — Azure DevOps Boards or GitHub Issues — as its setup records it; chosen independently of its Code host, in any combination.
_Avoid_: board, backlog, ALM

**Base plugin**:
A third-party plugin this plugin extends and requires — mattpocock-skills (engineering discipline), bcquality (Microsoft's AL quality knowledge), and SShadowS's AL language server; its skills are called by name or extended by an AL addition, never copied.
_Avoid_: upstream, parent, donor (a donor is only the source of a copy)

**Entry skill**:
A mattpocock-skills skill (or a Claude Code built-in such as `/simplify`) that the user types to start a step of the flow; it runs the step and owns its process.
_Avoid_: wrapper, host skill, parent skill

**AL addition**:
A skill of ours, usually named `al-<entry skill>`, that loads alongside its entry skill in an AL repository and adds only the AL specifics to that step; how the Tracker is worked comes from the Consumer repository's setup, never from the addition.
_Avoid_: overlay, extension, wrapper, AL version of

**Original work item**:
The work item a request arrives on — a Feature, Bug, or Product Backlog Item (PBI) in Azure DevOps, an issue on GitHub — carrying it through design and implementation; when the request splits, each slice is one direct child work item.
_Avoid_: Original User Story, root item, parent (its own structural parent is untouched)

**9Altitudes predecessor**:
The 9Altitudes copy this fork diverged from; a reference only, never a source of incoming changes.
_Avoid_: upstream, parent, original (taken by Original work item)

**Release**:
A version of a Naveksa app published to AppSource; the latest one is the baseline that breaking changes are measured against. A build delivered outside AppSource is not a Release.
_Avoid_: release branch, promoted version, latest build
