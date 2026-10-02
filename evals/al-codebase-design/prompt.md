---
description: Fires al-codebase-design beside its entry skill, in a seeded AL Consumer repository.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

/mattpocock-skills:codebase-design how should I structure the ShopFloor setup so the rest of the app can read it?
