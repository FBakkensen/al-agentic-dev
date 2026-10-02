---
description: Fires al-improve-codebase-architecture when its entry skill is typed, in a seeded AL Consumer repository.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

/mattpocock-skills:improve-codebase-architecture
