# al-agentic-dev

A Claude Code plugin of Agent Skills for AL and Business Central development, maintained for Naveksa and forked from an original built for 9Altitudes.

## Language

**Plugin repository**:
This repository: the plugin's source, hosted and distributed on github.com.
_Avoid_: the repo, the plugin repo, upstream

**Consumer repository**:
A Naveksa AL repository in Azure Repos that the shipped skills work inside.
_Avoid_: project repo, customer repo, target repo

**Base plugin**:
A third-party plugin this plugin extends and requires — mattpocock-skills (engineering discipline), bcquality (Microsoft's AL quality knowledge), and SShadowS's AL language server; its skills are called by name, never copied.
_Avoid_: upstream, parent, donor (a donor is only the source of a copy)

**9Altitudes predecessor**:
The 9Altitudes copy this fork diverged from; a reference only, never a source of incoming changes.
_Avoid_: upstream, parent, original (taken by Original User Story)

**Release**:
A version of a Naveksa app published to AppSource; the latest one is the baseline that breaking changes are measured against. A build delivered outside AppSource is not a Release.
_Avoid_: release branch, promoted version, latest build
