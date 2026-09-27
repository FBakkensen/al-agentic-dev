# Where inline diagrams render in Claude Code

Research for [#30](https://github.com/FBakkensen/al-agentic-dev/issues/30). Sources were read on 2026-09-27.

Each claim carries a label:

- **Documented**: a primary source states it. The URL follows the claim.
- **Observed**: seen in a live Claude desktop app Code-tab session on 2026-09-27 (desktop app `CLAUDE_CODE_DESKTOP_APP_VERSION=2.9939.2`, `CLAUDE_CODE_ENTRYPOINT=claude-desktop`).
- **Inferred**: reasoning from the two above. No source states it.
- **Undocumented**: no primary source covers it.

## Short answer

- Only the Claude desktop app offers an inline diagram beside the chat, through the host-provided `visualize` MCP server (`show_widget`, `read_me`). No Claude Code doc mentions that server. The only evidence that it exists in the Code tab is observation.
- A plugin can't bundle it or depend on it.
- The portable way to show a visual is an Artifact: an HTML page on claude.ai. The CLI and the desktop app publish them. When an Artifact can't be published, Claude falls back to a local HTML file.
- Mermaid rendering is undocumented on every surface.
- A skill can name `show_widget` directly, since the tool is simply missing on other surfaces. No documented signal identifies the surface a session runs on, except `CLAUDE_CODE_REMOTE` for cloud sessions.

## 1. Which surfaces offer `visualize` / `show_widget`, and which offer Artifacts

### Inline custom visuals (`visualize`)

- **Observed**: this Code-tab session exposes `mcp__visualize__read_me` and `mcp__visualize__show_widget`. A second, deferred copy is also listed under a UUID-named server (`mcp__6f616b42-…__read_me` / `__show_widget`). The tools reach child agents too: this report was written by a subagent (`CLAUDE_CODE_CHILD_SESSION=1`), and it still saw the tools.
- **Documented**, for claude.ai chat and Cowork only: custom visuals are "available to all Claude users on web and desktop, in both chat and Cowork". The same source says they don't render on the iOS or Android apps. Source: https://support.claude.com/en/articles/13979539-custom-visuals-in-chat-and-cowork. It says "Custom visuals are in beta and available on web and desktop only". Source: https://support.claude.com/en/articles/13641943-visual-and-interactive-content. The release notes date the launch to 2026-03-12. Source: https://support.claude.com/en/articles/12138966-release-notes. None of these three pages mentions Claude Code or the Code tab.
- **Undocumented**, for the desktop app's Code tab: the desktop docs page (https://code.claude.com/docs/en/desktop) never mentions `visualize`, `show_widget`, custom visuals or inline widgets. The CHANGELOG (https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) doesn't mention them either.
- **Undocumented / inferred absent**, for the terminal CLI, VS Code, JetBrains and cloud sessions at claude.ai/code: no Claude Code page describes an inline-visual tool on any of them. The CLI renders markdown in a terminal, so it has nowhere to draw an HTML widget. This is inferred.
- **Documented, related**: Claude Code skips MCP Apps UI resources. The MCP page says "MCP Apps UI resources are entries with a `ui://` URI … pages for a host application to render". Claude Code leaves them out of resource lists. Source: https://code.claude.com/docs/en/mcp. The CHANGELOG records the same change. **Inferred**: Claude Code does not act as an MCP Apps renderer. Any inline rendering comes from the desktop host, not from Claude Code.

### Artifacts (the `Artifact` tool, pages published to claude.ai)

- **Documented**: the Artifacts page lists this surface requirement: "Claude Code CLI, or the Claude desktop app version 1.13576.0 or later". Claude Tag sessions can publish as well. Artifacts are "Off by default in Agent SDK, GitHub Action, and MCP-server contexts". Source: https://code.claude.com/docs/en/artifacts#availability.
- **Documented**: the other requirements:
  - a Pro, Max, Team or Enterprise plan; on Enterprise, an Owner enables them
  - a claude.ai login, which rules out API keys, gateway tokens and cloud-provider credentials
  - the Anthropic API as the provider, which rules out Bedrock, Vertex and Foundry
  - no CMEK, HIPAA or ZDR on the organization

  Source: same page. The per-plan table is at https://code.claude.com/docs/en/feature-availability.
- **Observed**: the `Artifact` tool is present in this desktop Code-tab session, including in the subagent.
- **Undocumented**, for VS Code: the VS Code page never mentions artifacts. The extension hosts Claude Code through the SDK `canUseTool` path, the same way the desktop app does. Source: `CLAUDE_CODE_DISABLE_PERMISSION_PROMPT_NOTIFY_HOOKS` in https://code.claude.com/docs/en/env-vars. The Artifacts page, though, says artifacts are off by default in Agent SDK contexts. The two sources point in opposite directions, so no conclusion is drawn.
- **Inferred yes**, for JetBrains: the plugin "runs the CLI in your IDE's terminal". Source: https://code.claude.com/docs/en/platforms. The CLI is a documented artifact surface.
- **Undocumented**, for cloud sessions (claude.ai/code): neither the cloud page (https://code.claude.com/docs/en/claude-code-on-the-web) nor the availability row mentions artifacts. The CHANGELOG records one related fix: the Artifact tool now appears in Remote Control sessions opened from Claude Desktop, claude.ai or mobile.

| Surface | Inline `show_widget` | Artifact tool |
|---|---|---|
| Desktop app, Code tab | Observed. Undocumented | Documented (≥ 1.13576.0). Observed |
| Terminal CLI | Undocumented. Inferred absent | Documented |
| VS Code extension | Undocumented. Inferred absent | Undocumented |
| JetBrains plugin | Undocumented. Inferred absent | Inferred yes: runs the CLI |
| claude.ai/code (cloud) | Undocumented. Inferred absent | Undocumented |
| claude.ai chat / Cowork (not Claude Code) | Documented: web and desktop | n/a |

## 2. Can a plugin bundle or depend on it?

- **Documented**: a plugin can ship its own MCP servers through `.mcp.json`. Source: https://code.claude.com/docs/en/plugins/components. Plugin dependencies name other plugins, not host servers. Source: https://code.claude.com/docs/en/plugins/dependencies.
- **Documented, analogue**: in local and SSH sessions, the desktop app hands its own servers to Claude Code in-process. The MCP docs say "the desktop app registers the connectors as in-process `type: "sdk"` servers, and no MCP setting or `managed-mcp.json` reaches them". Source: https://code.claude.com/docs/en/mcp#how-connectors-reach-claude-code.
- **Observed and inferred**: `visualize` is host-provided. No doc names it, no `.mcp.json` in this repo or the user's configuration declares it, and it looks like the in-process delivery described above.
- **Inferred**: a plugin that shipped a look-alike server couldn't get the host to draw its output. Claude Code has no documented channel for an MCP tool result to render as HTML inline, and it deliberately ignores MCP Apps `ui://` resources (section 1). So a plugin can neither bundle nor depend on `visualize`. It can only use the server where the host supplies it.

## 3. Fallback where it is absent

- **Artifacts**. **Documented**: an Artifact is "a live, interactive web page that Claude Code publishes from your session to a private URL on claude.ai". Source: https://code.claude.com/docs/en/artifacts. It opens in the browser rather than inline, and it needs the plan, login and provider conditions in section 1.
- **Local HTML file**. **Documented** as Claude Code's own fallback: "When one is not met, Claude writes a local HTML file or says it cannot publish instead". Source: https://code.claude.com/docs/en/artifacts#availability. **Documented**: in the desktop app, "The Browser pane can also open static HTML files … Click an HTML, PDF, image, or video path in the chat to open it there". Source: https://code.claude.com/docs/en/desktop. On the other surfaces the user opens the file in a browser; that part is inferred.
- **Mermaid in markdown**. **Undocumented** on every surface: the word appears in no Claude Code docs page read for this report, and nowhere in the CHANGELOG, as of 2026-09-27. The CHANGELOG does document that the CLI renders markdown with syntax-highlighted code blocks and bordered tables. Nothing says it turns a `mermaid` fence into a diagram. Whether the desktop Code tab renders Mermaid was not tested. It is a cheap live check if it matters.
- **Mechanics, documented**: the CHANGELOG notes that auto mode treats "a link that packs content into a public diagram renderer's URL as an upload to that site". It is no longer auto-approved. So a URL-encoded Mermaid or PlantUML link is a gated fallback, not a free one.

## 4. Can a skill tell whether the tool is present without conditional phrasing?

- **Inferred, and the simplest route**: name the tool, for example "draw the decision as a diagram with `show_widget`". The model sees its tool list. Where `show_widget` is missing it can't call the tool and answers in prose, so the skill needs no "if your environment supports…" clause. The fallback could also be stated flatly as its own rule, for example "publish an Artifact when a diagram outlives the turn". That keeps both lines free of conditions.
- **Documented**: the SessionStart hook input carries `source`, `model`, `agent_type` and `session_title`, and no surface field. Source: https://code.claude.com/docs/en/hooks#sessionstart-input. `CLAUDE_CODE_REMOTE=true` is documented for cloud sessions. Source: https://code.claude.com/docs/en/env-vars. A hook's `additionalContext` reaches Claude as a system reminder and should be phrased as factual statements. Source: https://code.claude.com/docs/en/hooks.
- **Observed, undocumented**: in the desktop app, hook and Bash subprocesses see `CLAUDE_CODE_ENTRYPOINT=claude-desktop` and `CLAUDE_CODE_DESKTOP_APP_VERSION`. Neither appears on the env-vars page, so a hook keyed on them relies on an undocumented variable that could change.
- **Inferred**: a SessionStart hook can inject a factual line per surface, for example "This session runs in the Claude desktop app; `show_widget` draws inline diagrams". Only the cloud branch rests on a documented signal, though. Naming the tool gives the same result without any detection, so the hook is worth adding only if live sessions show the model missing the tool.

## Sources

- https://code.claude.com/docs/en/artifacts
- https://code.claude.com/docs/en/desktop
- https://code.claude.com/docs/en/platforms
- https://code.claude.com/docs/en/feature-availability
- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/env-vars
- https://code.claude.com/docs/en/plugins/components
- https://code.claude.com/docs/en/plugins/dependencies
- https://code.claude.com/docs/en/vs-code
- https://code.claude.com/docs/en/jetbrains
- https://code.claude.com/docs/en/claude-code-on-the-web
- https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
- https://support.claude.com/en/articles/13979539-custom-visuals-in-chat-and-cowork
- https://support.claude.com/en/articles/13641943-visual-and-interactive-content
- https://support.claude.com/en/articles/12138966-release-notes
