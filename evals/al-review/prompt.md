---
description: Fires al-review beside its entry skill for a slice with an Azure DevOps work item, in a seeded AL Consumer repository.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

/mattpocock-skills:code-review since main, for PBI 4711
