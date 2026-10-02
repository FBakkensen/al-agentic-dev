---
description: Fires al-commit. Ported from routing scenario S39.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

Commit everything in this worktree, including changes from earlier sessions, split into as many valid commits as possible.
