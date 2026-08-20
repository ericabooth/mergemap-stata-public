# Embedding mergemap output in a webdoc2 report

Verified recipe. Everything below was built and measured, not reasoned about.

- Build: `cd tests/webdoc && /usr/local/bin/stata-mp -b do test_mergemap_in_webdoc2.do`
- Environment: StataNow 19.5, webdoc 1.2.8 (Ben Jann), webdoc2 1.1.3, Chrome 151,
  1280x900 viewport, 960 px content column.

| file | what it is |
|---|---|
| `test_mergemap_in_webdoc2.do` | driver: slices the fragments, builds both pages, asserts |
| `page_mergemap.do` | the webdoc2 page source, driven by `webdoc do` |
| `page_collision.do` | deliberate-failure page, mergemap HTML injected verbatim |
| `mergemap_report.html` | the report: 21,965 px tall, 3 images, 5 iframes, 5 inline SVGs, 2 `<pre>` blocks, 10 `<details>` |
| `collision_demo.html` | what happens with no prefixing and no scoping |
| `frag_*.html` | generated fragments the two pages `webdoc append` |
| `header.html` | copy of the webdoc2 theme header (`net install` does not place it) |
| `filecheck.html` | probes what changes when the report is opened at `file://` |
| `shotharness.html` | frames the report at a fixed 1280x900 and isolates one section, so headless Chrome can screenshot it without distorting `vh` heights |
| `shots/` | 19 screenshots |

Files under `proto/`, `src/` and the webdoc2 repo were read only. Nothing outside
`tests/webdoc/` was written.

---

## 1. Recommended default

**Today, with the prototype output as it stands: iframe with a CSS-class height.**
The self-contained HTML needs no changes, its stylesheet cannot touch the report,
and the diagram reflows to the frame width. The one thing you must not do is pass
the height through `wdiframe`'s `height()` option and hope for `vh`.

```stata
webdoc put <style>.mm-frame { height: 78vh !important; width: 100%; }</style>
wdiframe diagrams/mergemap_run.html, class(mm-frame)
```

**Once mergemap gains an `embed` option: inline SVG in a bounded box.** It is
sharper, its text is selectable and findable, it prints with the page, and it
needs no height guess at all. The only reason it is not the recommendation today
is that the prototype's HTML is not safe to inline as-is (section 5).

Ranking on the four things that actually go wrong:

| method | height guess needed | CSS isolation | text quality | works at `file://` |
|---|---|---|---|---|
| inline SVG (scoped) | no | needs prefixing + scoping | vector, selectable | yes |
| iframe | yes | total | vector, selectable | yes |
| PNG via `wdimg` | no | total | raster | yes |
| `<pre>` SMCL | no | total | text | yes |

Put the `<pre>` receipt under whichever diagram you choose. It costs nothing,
survives copy-paste into email, and is the only tier that still says something
useful if the SVG fails to load.

---

## 2. What `wdimg` and `wdiframe` actually do

Both **link**, neither **copies**. `src` is resolved by the browser relative to
the HTML file, so a relative path only survives if the report and the asset move
together.

### `wdimg`

```
wdimg PATH [, src() width() alt() caption()]
```

Without `caption()` it emits, verbatim:

```html
<img src="PATH" style="max-width:100%; height:auto; border-radius:6px;">
```

With `caption()` it emits a figure **and drops the inline style**:

```html
<figure>
<img src="PATH">
<figcaption>TEXT</figcaption>
</figure>
```

The captioned form is only responsive because `header.html` carries
`figure img { max-width:100%; height:auto; }`. A custom `headerfile()` without
that rule will let a 1600 px PNG overflow the column.

`width()` writes the HTML `width` attribute, not CSS. There is no `height()`.

### `wdiframe`

```
wdiframe SRC [, src() width() height() class() border]
```

Emits:

```html
<iframe src="SRC" width="100%" height="800px" frameborder="0" [class="..."]
        style="border:none; border-radius:8px; box-shadow:0 2px 10px rgba(0,0,0,0.06);
               margin:1rem 0;"></iframe>
```

Defaults are `width=100%`, `height=800px`, no visible border. `border` swaps in
`border:1px solid #dee2e6`.

The critical detail: **`height()` lands in the HTML `height` attribute, not in
CSS.** Chrome tolerates `height="800px"` and renders 800 px, but the attribute is
a presentational hint, so:

- `height(78vh)` is invalid as an attribute and is dropped. The frame falls back
  to the CSS default of 150 px.
- any CSS rule that sets `height` beats the attribute, which is why `class()` is
  the way to get `vh`.

Measured, 1280x900 viewport:

| call | rendered frame height | inner document height | clipped |
|---|---|---|---|
| `wdiframe FILE` (default) | 800 px | 2476 px | yes, inner scrollbar |
| `wdiframe FILE, height(2600px)` | 2600 px | 2600 px | no |
| `wdiframe FILE, class(mm-frame-vh)` + `height:78vh` | 702 px | 2476 px | yes, inner scrollbar |
| `wdiframe FILE, class(mm-frame-auto)` + `height:auto` | **150 px** | 2476 px | yes, badly |

---

## 3. The four embeds, copy-pasteable

All four assume the page-level CSS from section 4 has been appended once.

### (a) PNG via `wdimg`

```stata
wputh2 Build map
wdimg diagrams/mergemap_run.png, alt(mergemap run diagram) ///
      caption(Join and transform map for the 2019-2022 build.)
```

Bound it if the PNG is tall. `tw_vert_run.png` is 1600x5745 and renders 928x3332
in a 960 px column, which is close to four screens for one figure:

```stata
webdoc put <div class="mm-scroll">
wdimg diagrams/mergemap_run.png, alt(mergemap run diagram)
webdoc put </div>
```

### (b) iframe via `wdiframe`

```stata
webdoc put <style>.mm-frame { height: 78vh !important; width: 100%; }</style>
wdiframe diagrams/mergemap_run.html, class(mm-frame)
```

A `<style>` block written straight from a do-file parses fine; the braces do not
open a Stata block because the line does not end in `{`. Verified on the page.

### (c) Inline SVG in the page DOM

Read the fragment out of mergemap's HTML and append it verbatim. `webdoc append`
takes the filename **without** `using`, and writes the file byte for byte, so
nothing in the SVG passes through Stata's macro expander.

```stata
* one-time prep, outside the webdoc2 page (see test_mergemap_in_webdoc2.do
* for the Mata that slices <style> and <svg> out and rewrites them)
webdoc append "frag_mm_css.html"          // scoped, prefixed stylesheet, once
webdoc put <div class="mm-embed">
webdoc append "frag_mm_svg.html"          // <svg viewBox=...> ... </svg>
webdoc put </div>
```

Three rewrites are mandatory before the fragment is safe. They are exactly what
mergemap should be doing itself (section 5):

1. every CSS class renamed `mm-*`, in the stylesheet and in the SVG;
2. every rule scoped under `.mm-embed`, and the `body` rules dropped;
3. every `id` prefixed, and every `url(#...)` reference with it.

### (d) SMCL text as a `<pre>` block

Escape `&`, `<`, `>` and wrap. The diagram is 155 lines, longest line 79
characters, which is about 600 px at 12.5 px monospace, so it fits any report
column without wrapping.

```stata
webdoc append "frag_pre_smcl.html"       // <pre class="mm-pre">...</pre>
webdoc append "frag_pre_receipt.html"
```

The escaping in `test_mergemap_in_webdoc2.do` is three `subinstr()` calls in
Mata. Do the `&` first.

---

## 4. Page-level CSS this all depends on

```css
/* webdoc emits a bare <body> with no container, so wdwidth has nothing to act
   on and the report runs edge to edge. Wrap the body yourself. */
.mm-page    { max-width: 960px; margin: 0 auto; padding: 0 1rem 4rem 1rem; }

/* bounded viewport for a diagram taller than the screen */
.mm-scroll  { max-height: 70vh; overflow: auto; border: 1px solid #dee2e6;
              border-radius: 6px; padding: .5rem; background: #fff; margin: 1rem 0; }

/* horizontal diagrams: never stretch, scroll sideways instead */
.mm-xscroll { overflow-x: auto; overflow-y: hidden; border: 1px solid #dee2e6;
              border-radius: 6px; padding: .5rem; margin: 1rem 0; }
.mm-xscroll svg { max-width: none !important; width: auto; height: auto; }

/* iframe height that CSS can set; height() cannot take vh */
.mm-frame   { height: 78vh !important; width: 100%; }

.mm-pre     { font-family: 'SF Mono', Menlo, Consolas, monospace; font-size: 12.5px;
              line-height: 1.35; background: #F5F7FA; border: 1px solid #DEE2E6;
              border-left: 4px solid #1B2D55; border-radius: 0 6px 6px 0;
              padding: .9rem 1.2rem; overflow-x: auto; }
```

In the page do-file:

```stata
wdinit mergemap_report, replace
wdnavbar ...
wdnavbarclose
webdoc append "frag_page_css.html"
webdoc put <div class="mm-page">
* ... body ...
webdoc put </div>
webdoc close
```

---

## 5. Required mergemap-side changes

1. **Prefix every CSS class with `mm-`.** The prototype ships `.bh .bl .bn .bf
   .cc .cl .cn .cf .dof .hc .hn .hb .hf .bx .bu .bt .bstk .bw .sp .spd .hl`, plus
   `.svgwrap`. Walking all 2,654 readable rules on the built report (Bootstrap
   5.3.2 contributes 1,297, the webdoc2 theme 52) found **no** rule matching any
   of them, nor `.box`, `.node`, `.flag`, `.sub`, `.legend` or `.foot`. So the
   class names are not a live collision today. Prefix them anyway: two-letter
   names are a collision waiting on the next Bootstrap release or the next thing
   the author pastes into the page, and unprefixed names make the stylesheet
   impossible to scope by inspection. The damage measured in item 3 comes from
   element selectors and ids, not from class names.

2. **Add an `embed` option that emits a fragment, not a document.** It should
   write, in order: one `<style>` block whose every rule is scoped under a
   wrapper class, then `<div class="mm-embed">`, then the `<svg>`, then `</div>`.
   No `<!DOCTYPE>`, no `<html>`, no `<head>`, no `<body>`.

3. **Never emit `body`, `h1`, `h2`, `details`, `summary`, `pre` or bare `svg`
   selectors in embed mode.** This is the damage they do, measured on
   `collision_demo.html`: the host report's `<body>` picked up
   `max-width: 920px; margin: 24px` and jumped left in a 1265 px viewport; `h1`
   went from 29.6 px to 19 px and `h2` from 21.6 px to 15 px; the body font
   changed from Inter to `-apple-system`. mergemap's rules win because the block
   is injected into `<body>`, after the head, at equal specificity.

4. **Make ids unique per diagram.** Every mergemap HTML file uses the same two
   marker ids, `ag` and `aa`. Two diagrams on one page therefore produce
   duplicate ids, and `getElementById('ag')` resolves to the first one. Proved on
   `collision_demo.html`: recolouring the first diagram's `#ag` marker path to
   red turned the *second* diagram's arrowheads red too, and the second SVG's
   `marker-end="url(#ag)"` resolved to an element inside the first SVG. A
   per-render counter or a short hash (`mm1-ag`, `mm2-ag`) fixes it.

5. **Drop `width`/`height` from the `<svg>` root in embed mode, keep `viewBox`.**
   The prototype emits `viewBox="0 0 880 2367" width="880" height="2367"`. With
   the attributes removed the diagram scales to the column and holds its aspect
   ratio: 928x2496 at a 960 px column, 743x1999 at a 775 px column, effective
   text 13.7 px and 11 px respectively.

6. **Emit presentation attributes as well as classes, or accept that the
   fragment is useless without its stylesheet.** No `rect` in the prototype
   carries a `fill` or `style` attribute. With the stylesheet removed, every box
   computes to `fill: rgb(0,0,0); stroke: none` and text falls back to the host's
   font size. A bare `<svg>` fragment is a page of black rectangles.

7. **Give the horizontal layout a different embed default.** `html_horiz_run`
   is 6802x439. Stretched to a 960 px column it renders 928x60 with effective
   text of 1.4 to 1.8 px, which is unreadable. At native size inside
   `overflow-x: auto` it stays at 13 px and only the box scrolls. Horizontal
   diagrams should keep their `width` attribute and ship a sideways scroller,
   which also means mergemap's own `svg { max-width: 100%; }` has to be overridden
   inside that box or it cancels the scroller.

8. **Add a `height()` option to the HTML writer, or document the class trick.**
   Not to `wdiframe` (that is Eric's package), but mergemap's help should say
   plainly: to bound a mergemap iframe, use `class()` plus a CSS rule, because
   `height()` writes an HTML attribute that cannot take `vh` and there is no
   pure-CSS auto-height for an iframe.

9. **Keep the SMCL/text tier byte-clean for `<pre>`.** It already is: pure ASCII
   box drawing (`+ - | < > v`), longest line 79 characters, no tabs. Do not switch
   to Unicode box-drawing characters without checking the monospace stack, and
   keep the width at or under 80 so it fits a report column.

10. **Keep `<details>` as-is.** Native `<details>`/`<summary>` render correctly
    inside a Bootstrap 5 webdoc2 page: disclosure triangle, click to open, no
    JavaScript, no restyling from Bootstrap beyond `summary { display: list-item }`.
    Nine of them on one page behaved. They only need the scoped mergemap rules to
    get the grey summary bar and border; without them they still work, just plain.

---

## 6. Gotchas found

**`webdoc append` takes no `using`.** `webdoc append "file.html"` works;
`webdoc append using "file.html"` fails with `invalid '"file.html'` r(198). The
program prepends `using` itself. This is the clean way to inject raw HTML,
because the file is copied byte for byte and nothing runs through Stata's macro
expander. That matters here: mergemap's SVG contains `` &#96;y' ``, and a stray
apostrophe in a `webdoc put` line is a macro-expansion hazard.

**`webdoc do` invents its own document.** It scans the do-file text for a literal
`webdoc init`; `wdinit` is invisible to that scan, so webdoc prepends
`webdoc init "<dofile basename>"` and creates a stray `<basename>.html`. wdinit
1.1.3 closes and erases the stray when it takes over; repeated runs in the same
directory left no `page_mergemap.html` or `page_collision.html` behind and never
hit r(602). Erasing `page_*.html` before the run anyway costs nothing.

**webdoc2 pages have no content container.** `webdoc` emits a bare `<body>`.
`header.html` styles `.container` and `wdwidth` sets `--wd-page-width`, but
nothing emits a `.container`, so on a page with no navbar `wdwidth` does nothing
and text runs edge to edge. Wrap the body in your own `<div>` with an explicit
`max-width`.

**`header.html` is not installed by `net install`.** `findfile header.html`
returned r(601) with webdoc2 installed. Copy `header.html` next to the page (`.`
is on the default adopath) or use `net get webdoc2`.

**Mata `fopen(fn, "w")` refuses to overwrite** and aborts with r(602)
`file already exists`. Call `_unlink(fn)` first. Mata has no `fileread()`
either; use `cat()` and join with `char(10)`.

**A bare `{ ... }` block at Mata top level cannot declare variables** (r(3000),
`'string' found where almost anything else expected`). Wrap the code in a
`void` function and call it.

**`strtrim()` does not trim newlines.** Scoping CSS by splitting on `}` leaves a
leading newline on each selector, so a `sel == "body"` test silently fails and
the `body` rules survive into the scoped stylesheet. Replace `char(10)`,
`char(13)` and `char(9)` with blanks first.

**`svg { max-width: 100% }` cancels a sideways scroller.** mergemap ships that
rule. Inside `overflow-x: auto` it clamps the SVG back to the box width and there
is nothing left to scroll. Override with `.mm-xscroll svg { max-width: none }`.

**No JavaScript auto-height for an `file://` iframe.** At `file://` the frame's
`contentDocument` is `null` (Chrome treats each local file as an opaque origin),
so the usual measure-and-resize trick is impossible in the case that matters
most: a report someone opened by double-clicking it. Verified with
`filecheck.html`. Over `http://` the same access works.

**Stata SVGs do carry a `viewBox`.** The assumption that they do not is wrong for
Stata 19.5. `tw_vert_run.svg` starts
`<svg version="1.1" width="5.570in" height="20.000in" viewBox="0 0 4010 14400">`.
The problem is the **inch** units on `width`/`height`, not a missing `viewBox`.
Drop those two attributes and it scales correctly: 895x3214 in a 960 px column,
aspect ratio preserved to three decimals, effective text 18.8 px. Also strip the
`<?xml ... ?>` prolog before inlining; HTML parses it as a bogus comment.

---

## 7. What was measured

1280x900 viewport, 960 px column, unless noted.

| section | embed | rendered | verdict |
|---|---|---|---|
| A1 | PNG, unbounded | 928x3332 | correct but four screens tall |
| A2 | PNG in `.mm-scroll` | box 630 px, content 3230 px | recommended for tall PNGs |
| A3 | PNG with caption | 928x585 | figure styling from `header.html` applies |
| B1 | iframe, default | 800 px frame, 2476 px content | clipped, inner scrollbar |
| B2 | iframe, `height(2600px)` | 2600 px | fits, but height is hard-coded |
| B3 | iframe, `class()` + 78vh | 702 px | recommended |
| B4 | iframe, `height:auto` | 150 px | does not work, ever |
| C1 | inline SVG, viewBox only | 928x2496, text 13.7 px | recommended |
| C2 | inline SVG, native, boxed | 880x2367 in a 630 px box | good when native size matters |
| C3 | Stata twoway SVG inline | 895x3214, text 18.8 px | works once inch units are dropped |
| C4 | horizontal, stretched | 928x60, text 1.8 px | unreadable |
| C5 | horizontal, `.mm-xscroll` | 6802x439, box scrolls | recommended for horizontal |
| D1 | ASCII diagram `<pre>` | 923 px wide, no x-scroll | fits |
| D2 | receipt `<pre>` | 923 px wide, no x-scroll | fits |
| E | nine `<details>` blocks | open and close | no Bootstrap conflict |

Whole-page checks, all passing:

- No horizontal page scroll at 1280 px, 805 px or 390 px viewport widths.
- No console errors.
- No duplicate element ids on `mergemap_report.html`.
- Host `<body>` keeps `max-width: none` and `margin: 0`; `h1` stays at 29.6 px.
  The scoped stylesheet has 33 rules and every one starts with `.mm-embed`.
- At a 775 px column the inline SVG still renders at 743x1999 with 11 px
  effective text, and the `<pre>` blocks still fit without wrapping.
- At 390 px the TOC and the column fit; only the `<pre>` blocks gain an internal
  horizontal scrollbar, which is correct behaviour.

---

## 8. Not verified

- **Safari and Firefox.** Everything above is Chrome 151. The `height` attribute
  vs CSS-class precedence and the `file://` opaque-origin behaviour are both
  spec-backed, but the exact `height="800px"` leniency is not.
- **Printing and PDF export.** No print stylesheet was exercised. Iframes and
  `max-height` scroll boxes both behave badly in print, and that is a real risk
  for a report meant to be handed round as a PDF.
- **`mergemap run` inside `webdoc do`.** Not attempted. `DECISIONS.md` item 7
  already says not to nest them because of the log-file conflict. This test only
  ever read pre-built prototype artifacts.
- **The real `mergemap` command.** No mergemap ado was run. Everything came from
  the checked-in prototype output under `proto/`.
- **`wdimg`/`wdiframe` with paths containing spaces or non-ASCII characters.**
  Only plain relative paths were used.
- **A diagram over about 2500 px.** The tallest tested was 2367 px of SVG and
  5745 px of PNG. The 5000 px case is covered by the same `.mm-scroll` and
  `78vh` strategies, but was not built.
- **More than one inline mergemap diagram on a single page.** The id collision
  was proved on the collision demo; the prefixed version was only ever rendered
  once per page.
- **Custom `headerfile()` themes.** Only the stock `header.html` was used, and
  several recommendations lean on rules that live in it (`figure img`,
  `.container`, `pre.stlog`).
- **`webdoc2 ... , cleanup` and `open`.** The pages were built with plain
  `webdoc do`, not through the `webdoc2` wrapper.
