---
description: Fires al-tdd beside its entry skill, in a seeded AL Consumer repository.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

/mattpocock-skills:tdd block releasing a sales order when the customer is over its credit limit
