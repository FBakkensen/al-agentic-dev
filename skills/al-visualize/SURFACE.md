# SURFACE.md — the decision-surface page contract

Every surface is one self-contained, read-only HTML file: no input capture — no form
controls, no comment boxes, no submit action — and no external assets. Answers happen
in chat. Two moods share one skeleton: a **decision surface** carries open cards; a
**close or ruling surface** carries none — its rail leads with the settled outcome.

## Read in layers

The page discloses top-down, one layer per glance; the reader stops when satisfied.
Each zone opens with a header — a numbered pill, an uppercase name, and a payoff
phrase telling the reader what the zone gives them:

1. **Verdict** — `<h1>`, one thesis line naming what is open (or that nothing is),
   and 3–5 stat tiles: mono numerals, semantic color, uppercase micro-label. The
   page answers "what do you need from me?" here, within two seconds.
2. **The picture** — the centerpiece diagram (below).
3. **One-liners** — one row per change or argument step: glyph · name · one-line
   gist · ID. Prose detail lives behind a `<details>` expander on the row, never
   inline.
4. **Your call** — the open decision cards, in the rail. On a settled surface this
   zone is the ruling card instead.
5. **Proof / evidence** — gate numbers, audit tables, groundings; skimmable,
   collapsible where large.
6. **Already settled** — LOCKED context as quiet collapsed rows.

**One loud thing (hard):** exactly one element class is visually loudest — the open
decision cards (blue ring), or on a settled surface the ruling card (green). All
else stays quiet; a squint shows only what needs the reader.

## Layout

Two-pane grid on wide viewports (page up to ~1560px): content left, rail
(~400px, `position: sticky`) right holding zones 4–6. Below ~1100px, stack.

## Visual identity

```css
:root {
  --bg:#0b0d12; --surface:#12151c; --surface2:#181c25; --line:#252b36; --line-soft:#1d222b;
  --ink:#e9edf3; --muted:#9aa4b2; --faint:#606a77;
  /* GitHub-Primer-dark semantic hues; every hue rides with a glyph */
  --green:#3fb950; --green-em:#2ea043;  /* added / gate green / ruled */
  --amber:#d29922;                      /* modified / duplicated */
  --red:#f85149; --red-soft:#ffb3ae;    /* fix / dissolves / misplaced */
  --blue:#58a6ff;                       /* open decision — the one loud accent */
  --mono:"Cascadia Code", ui-monospace, SFMono-Regular, Consolas, monospace;
}
body { background:var(--bg); color:var(--ink);
  font:15px/1.55 "Segoe UI Variable Text","Segoe UI",-apple-system,system-ui,sans-serif; }
```

Mono is reserved for identifiers, numerals, and IDs; running text stays sans. Tinted
node backgrounds stay near the surface tone (e.g. `#0f1f17` for green, `#201113` for
red) — washed-out pastels and full-strength fills are both defects.

## Diagrams are HTML (hard)

The picture is built from HTML boxes laid out with CSS grid — stage containers
(dashed border, uppercase micro-label) holding node cards (glyph column + title +
one-line gist), with flow carried by glyph cells (`→`, `↓`) between grid tracks.
Text in an HTML box wraps; it can never clip or overlap. SVG appears only for
connector lines that grid adjacency cannot express — never for text layout. A claim
an arrow would carry may instead sit on the node as a labeled chip
(`belongs in stage 1 — beside B8/B9/B10`).

**Colorblind rule (hard): color never carries a meaning alone.** Every semantic
distinction also rides a glyph (`+ ~ = − ⚠ ✓`), a border style, or a label, so the
page reads correctly in grayscale. Legends show color and glyph together.

## Cards and IDs

1. **Stable IDs.** Every addressable element — node, row, card, decision — carries
   `data-id` (`D1`, `N-DFS`, `L2`), shown subtly on the element; chat answers point
   at these.
2. **Open decisions.** 2–4 lettered options; exactly one carries `RECOMMENDED`; each
   option names its worst property on a second line; the card ends with the literal
   reply shape: `Reply in chat: D1: A (or B, or ask).`
3. **Locked context.** Collapsed rows under a muted `LOCKED` tag. A decision settled
   in chat becomes a locked or ruled card naming the pick; the page is updated and
   reloaded so every remaining question is answered with current truth in view.
4. **Navigation only.** Clicking a diagram node may scroll to and flash its row;
   no interaction stores or transmits anything.

## Density

A surface is a working document: realistic names, exact signatures where a decision
turns on one, honest trade-off wording. Every item earns one line in its zone;
everything longer collapses. The verdict strip carries the whole story for the
reader who reads nothing else.
