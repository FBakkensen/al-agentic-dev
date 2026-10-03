---
description: Fires al-pr-shepherd on a pull request in a seeded AL Consumer repository whose origin is on github.com.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

Can you get PR 12 through to merge? I've left a few comments on it, and the branch is probably behind main by now.
