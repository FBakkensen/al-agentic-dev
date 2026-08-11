# SURFACE.md — the steering-surface page contract

Every surface is one self-contained, read-only HTML file: no input capture — no form
controls, no submit action — and no external assets. Answers happen in chat.

## The reader scrolls into depth

A steering surface is four layers on one scroll page. Each layer fills most of a
viewport (`min-height: 92vh`), so one glance holds one layer; a cue line at its foot
names what the next layer offers and anchors to it. The reader stops when satisfied —
layer 1 says so explicitly.

1. **The glance** — a task line (ID · name · state) with one lozenge naming what is
   needed from the reader (`Your review`, `Receipt`); one headline sentence naming the
   product change; labeled fact rows (Today / After, or the 3–5 rows the moment
   needs); an exit line telling the reader they may stop here.
2. **The product** — what the user of the app will experience: the screen, the
   gesture, the refusals. Dialog and error texts verbatim in quoted blocks naming who
   reads them. Reasoning sits behind drill links, never inline.
3. **Your call** — one flat row per call: title, reversibility lozenge (cheap /
   moderate / hard to undo), stable ID; a one-line gist; reasoning behind a drill. The
   layer ends with the literal reply shape (`D1: reopen`) and that silence approves.
4. **The work** — marked agent territory: a table of pieces and proof in plain terms;
   locked context behind one expander; a final line saying nothing deeper exists.

A **receipt** is layer 1 plus the work expander: verdict line, the honest product
delta ("nothing changes for the user" when true), fact rows, work collapsed. When
the landed change carries a mechanism that earns a picture, the receipt grows one
second screen for it, reached by a cue line — one screen is the floor, not a cap.

## Visual identity — a light document

```css
:root {
  --bg:#fff; --panel:#f7f8f9; --line:#dcdfe4; --line-soft:#ebecf0;
  --ink:#172b4d; --muted:#44546f; --faint:#626f86;
  --blue:#0c66e4; --blue-bg:#e9f2ff; --blue-ink:#0055cc;
  --green-bg:#dcfff1; --green-ink:#216e4e;
  --amber-bg:#fff7d6; --amber-ink:#7f5f01;
  --red-bg:#ffeceb;  --red-ink:#ae2e24;
}
body { background:var(--bg); color:var(--ink);
  font:16px/1.6 -apple-system,"Segoe UI Variable Text","Segoe UI",system-ui,sans-serif; }
```

One sans family; hierarchy rides weight and size. Mono only for identifiers, trees,
and IDs — never as a costume for "technical". Color lives in lozenges — small
uppercase tinted chips — and nowhere else; the tinted panels above are the only
fills, reserved for trees, quoted dialog texts, and pictures. Everything else is flat
rows over hairline dividers. Headings are sentence-case questions or statements — no
uppercase eyebrows above them. Text measure stays at or under 72ch.

## Scroll machinery

Progressive disclosure is pure scroll — no click on the main path. Guard in
`@supports`: content rises into view via `animation-timeline: view()` (~16px
translate, ease-out); a 3px top gauge fills via `animation-timeline: scroll()`; cue
lines (`▼ Scroll for …`) carry anchor links as the fallback. Drills are native
`<details>` styled as links (`Why this shape →`) — sideways depth, never a box in a
box.

## Pictures

Prose by default. A picture earns its slot only for a relational fact — three or more
things whose arrangement carries the meaning — that prose would force the reader to
assemble in their head. Every picture is drawn in the product's vocabulary: record
cards with status lozenges, checkbox trees, document flows in document terms
(Order → Shipment → Invoice), position-in-the-flow markers. Two mechanism pictures
carry a landed change, labeled in those same product words: a **sequence** — one
lifeline per participant, messages downward, replies dashed — when the change moves
who decides or when; a **data flow** — stores, processes, arrows, and the
transaction boundary drawn — when the change moves what is written where. When both
moved, both appear, the louder one first. C4, ERD, and all other UML notation stay
foreign to this reader and never appear. Boxes are HTML/CSS; SVG only for connector
lines. Color never carries a meaning alone — a glyph, border style, or label rides
with it, so the page reads in grayscale.

## Language

One sentence per fact, in the product's words — the page, the field, the error, the
number. An identifier never stands alone: every `T-NNN`, `D1`, object or case name
carries its plain-language meaning at point of use; the page assumes the reader
remembers nothing from chat. Run narration is a defect. Every addressable call
carries a `data-id` shown subtly on the element; chat answers point at these. An open
call carries 2–4 lettered options, exactly one `RECOMMENDED`, each option naming its
worst property on a second line.
