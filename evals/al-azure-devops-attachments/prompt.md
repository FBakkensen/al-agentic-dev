---
description: Fires al-azure-devops-attachments. Ported from routing scenario S38.
tags: [trigger]
plugins: ["../..", "../../.base-plugins/mattpocock-skills", "../../.base-plugins/bcquality", "../../.base-plugins/al-language-server-go-windows"]
allowed_tools: [Read, Glob, Grep, Skill]
---

Attach these local PNG and SVG files to Azure DevOps User Story 32717. Use the CLI if the MCP cannot upload them.
