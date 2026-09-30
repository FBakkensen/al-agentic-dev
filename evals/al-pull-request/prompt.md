---
description: Fires al-pull-request. Ported from routing scenario S40.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
---

Push this branch and open a ready pull request with the Azure DevOps links and available proof.
