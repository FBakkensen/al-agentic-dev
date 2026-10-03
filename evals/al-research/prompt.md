---
description: Fires al-research beside its entry skill, in a seeded AL Consumer repository.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

/mattpocock-skills:research when does the Base App fill Location Code on a new sales order, and does ShopFloor's subscriber on Sales Header insert run before or after it
