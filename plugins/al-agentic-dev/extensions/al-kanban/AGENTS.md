# al-kanban — dev-time context

This extension is a **proof of concept** in a very agile stage.

*Dev-time only — this file never ships as runtime context. The runtime surface is `extension.mjs`, `lib.mjs`, and `board.html`; usage lives in `README.md`, the live gate in `SMOKE-TEST.md`.*

- **No backwards compatibility, ever.** Never preserve old behaviour, old data shapes, old action names, or migration paths for their own sake. Rename, reshape, and delete freely when a change improves the design.
- No deprecation cycles, no compatibility shims, no "keep the old field just in case".
- Prefer the simplest change that moves the PoC forward over any change that hedges for hypothetical future consumers.
- Pure logic stays in `lib.mjs` (SDK-free) so `node --test lib.test.mjs` keeps running without the extension host; CI runs it. Keep new logic there, not in `extension.mjs`.
