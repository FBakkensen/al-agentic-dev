# SURFACE.md — the steering-surface artifact contract

Every surface is one self-contained markdown artifact on the GitHub Copilot app's
side-panel editor canvas: read-only — no input capture — and every picture embedded
as a data URI, so the artifact travels as one file. Answers happen in chat.

## The reader scrolls into depth

A steering surface is four layers on one scrolling document, in fixed order, each one
section. The reader stops when satisfied — layer 1 says so explicitly.

1. **The glance** — a task line (ID · name · state) with one chip naming what is
   needed from the reader (`[YOUR REVIEW]`, `[RECEIPT]`); one headline sentence naming
   the product change; labeled fact rows as a table (Today / After, or the 3–5 rows
   the moment needs); an exit line telling the reader they may stop here.
2. **The product** — what the user of the app will experience: the screen, the
   gesture, the refusals. Dialog and error texts verbatim in blockquotes naming who
   reads them. Reasoning sits behind drills, never inline.
3. **Your call** — a table with one row per call: stable ID, title, reversibility
   chip (`[CHEAP TO UNDO]` / `[MODERATE]` / `[HARD TO UNDO]`); under it a one-line
   gist per call, reasoning behind a drill. The layer ends with the literal reply
   shape (`D1: reopen`) and that silence approves.
4. **The work** — marked agent territory: a table of pieces and proof in plain terms;
   a final line saying nothing deeper exists.

A **receipt** is layer 1 plus the work table: verdict line, the honest product delta
("nothing changes for the user" when true), fact rows, work collapsed. When the
landed change carries a mechanism that earns a picture, the receipt grows one
mechanism section — one screen is the floor, not a cap.

## Furniture

Markdown carries the hierarchy: sentence-case headings that read as questions or
statements — no uppercase eyebrows; tables for fact rows and call rows; blockquotes
only for verbatim dialog and error texts; inline code for identifiers and chips. A
**chip** is a small uppercase bracketed label in inline code — `[HARD TO UNDO]`,
`[RECOMMENDED]`, `[SETTLED]` — and is the only place color-like emphasis lives. A
**drill** is a `<details>` block whose summary reads as a link (`Why this shape →`) —
sideways depth, never a box in a box.

## Language

One sentence per fact, in the product's words — the page, the field, the error, the
number. An identifier never stands alone: every `T-NNN`, `D1`, object or case name
carries its plain-language meaning at point of use; the artifact assumes the reader
remembers nothing from chat. Every addressable call shows its stable ID in its row;
chat answers point at these. An open call carries 2–4 lettered options, exactly one
`[RECOMMENDED]`, each option naming its worst property on a second line. Run
narration is a defect.

## Pictures

Prose by default. A picture earns its slot only for a relational fact — three or more
things whose arrangement carries the meaning — that prose would force the reader to
assemble in their head. Every picture is an SVG you draw and embed as a base64 data
URI in a markdown image, in the product's vocabulary: record cards with status chips,
checkbox trees, document flows in document terms (Order → Shipment → Invoice),
position-in-the-flow markers. Two mechanism pictures carry a landed change, labeled
in those same product words: a **sequence** — one lifeline per participant, messages
downward, replies dashed — when the change moves who decides or when; a **data
flow** — stores, processes, arrows, and the transaction boundary drawn — when the
change moves what is written where. When both moved, both appear, the louder one
first. C4, ERD, and all other UML notation stay foreign to this reader and never
appear.

The SVG palette is a light document: ink `#172b4d`, muted `#44546f`, faint `#626f86`,
hairlines `#dcdfe4`; tinted fills reserved for chips — green `#dcfff1` on `#216e4e`,
amber `#fff7d6` on `#7f5f01`, red `#ffeceb` on `#ae2e24`, blue `#e9f2ff` on
`#0055cc`. Color never carries a meaning alone — a glyph, border style, or label
rides with it, so the picture reads in grayscale.
