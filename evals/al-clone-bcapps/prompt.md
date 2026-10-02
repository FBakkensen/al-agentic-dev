---
description: Fires al-clone-bcapps. Ported from routing scenario S4.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

Clone Microsoft's Base App source locally so I can read how posting routines are implemented.
