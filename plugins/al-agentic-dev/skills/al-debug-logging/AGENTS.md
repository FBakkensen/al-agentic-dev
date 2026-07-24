# al-debug-logging

*Dev-time only — this file never ships. The shipped surface is `SKILL.md` and `references/`. See the root `AGENTS.md`, "Shipped vs dev-time files".*

## Layout

```
skills/al-debug-logging/
├── SKILL.md
└── references/
    ├── telemetry-workflow.md
    └── bc-event-subscriber-pattern.md
```

## Editing rules

- The same-publisher requirement is never hedged with "usually" or "often" in any shipped file of this skill.
- Every probe example keeps the `DEBUG-` prefix. Cleanup is one `rg "DEBUG-" -g "*.al"`; an example that drops the prefix escapes it.
- A capture-path or harness change updates `SKILL.md`'s Inspect step and `references/telemetry-workflow.md` in lockstep.
