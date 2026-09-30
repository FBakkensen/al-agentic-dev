---
description: Fires al-review. Ported from routing scenario S18.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
---

Review my diff against its Gherkin, AAA proof, and module contracts.
