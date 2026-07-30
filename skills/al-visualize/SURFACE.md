# SURFACE.md — the decision-surface page contract

Every surface is one self-contained, read-only HTML file: it captures no input — no form
controls, no comment boxes, no submit action. Answers happen in chat. The only permissible
external asset is a pinned diagram-library import (for example
`https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs`); hand-drawn inline SVG
is equally welcome and often better — prefer it for swimlanes, journeys, heatmaps, and
anything whose nodes need individual identity for navigation.

## Page anatomy

`<h1>` title, a one-line thesis in muted color, and one hint line telling the reader how
this works: read here, answer in chat, each card named by its ID. Then the two-pane split.

**Layout rule (hard): the diagram never leaves the screen while deciding.** On wide
viewports (the page may use the full width, up to ~1720px): the centerpiece diagram in a
left pane with `position: sticky; top: 0` (its own scroll when taller than the viewport),
and a right rail (~380–460px) that scrolls the locked cards and open decisions. Card-only
sections that belong to the diagram — a transition table, a risk list — may sit under it
in the left pane. Below ~1000px viewport width, fall back to a stacked layout.

## Visual identity

```css
:root {
  --bg:#f7f7f5; --card:#ffffff; --ink:#1a1a1a; --muted:#6b6b6b;
  /* Okabe-Ito derived, colorblind-safe */
  --accent:#0072b2; --accent-soft:#e5f1f8;   /* blue: new / added / primary */
  --warn:#e69f00;  --warn-soft:#fdf3e0;      /* orange: modified / attention */
  --danger:#d55e00; --danger-soft:#fbe9e0;   /* vermillion: blocker / removed */
  --ok:#009e73;    --ok-soft:#e2f5ef;        /* bluish green: accepted / ok */
  --line:#e2e2de; --locked:#64748b; --radius:10px;
}
body { font-family:"Segoe UI",system-ui,sans-serif; background:var(--bg);
       color:var(--ink); line-height:1.5; }
```

Cards: `background:var(--card); border:1px solid var(--line); border-radius:var(--radius);`.

**Colorblind rule (hard): color never carries a meaning alone.** Every semantic
distinction — added/modified/unchanged, blocker/should-fix/follow-up, command/event/
read-model, friction — is also encoded as a glyph (`+` / `~` / `=` / `⚠`), a shape, a
border style (solid/dashed/dotted), or a label, so the page reads correctly in grayscale.
Legends show the color and the redundant cue together.

## Cards and IDs

1. **Stable IDs.** Every addressable element — diagram node, card, decision, claim —
   carries `data-id="…"`: short, stable, human-readable (`D2`, `N-DISPOSITION`, `R1`),
   shown subtly on the element. These are what the chat interview and the user's answers
   point at.
2. **Locked cards.** Already-agreed context under a `LOCKED` badge (`var(--locked)`).
   A decision settled in chat becomes a locked card naming the chosen option.
3. **Open decisions.** Cards listing 2–4 lettered options, exactly one carrying a
   `RECOMMENDED` mark — displayed for reading; the pick is given in chat.
4. **Navigation only.** Clicking a diagram node scrolls to and flashes its rail card and
   vice versa where a linkage exists; hover tooltips may name the files behind a node.
   No interaction stores or transmits anything.

## Density

A surface is a working document, not a poster: realistic names, exact signatures where a
decision turns on one, honest trade-off wording including each option's worst property.
The page must answer "what do you need from me?" within two seconds of opening — the
open decisions are visually loudest, locked context and evidence quieter.