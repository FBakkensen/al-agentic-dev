---
description: Fires al-build. Ported from routing scenario S1.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
model: sonnet
runs: 5
---

I changed a codeunit and its tests. Run the full gate before we move on.
