---
description: Fires al-pr-shepherd. Ported from routing scenario S26.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
---

My PR is ready — watch CI and the Copilot review, fix the findings, keep it synced with main until it can merge.
