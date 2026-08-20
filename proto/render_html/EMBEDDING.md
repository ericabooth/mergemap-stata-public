# renderhtml: outputs, options, and the embed contract

`renderhtml.ado` turns a v2 mergemap journal (34 columns, `usingfile` in column 9)
into either a self-contained HTML page or an embeddable fragment. No JavaScript,
no external assets, no absolute paths.

## Regenerating

```
cd proto/render_html
/usr/local/bin/stata-mp -b do demo.do     # every gallery output
/usr/local/bin/stata-mp -b do tests.do    # 19 option and schema checks
grep '^r([0-9]' demo.log tests.log        # must print nothing
```

## Syntax

```
renderhtml using journal.tsv, saving(out.html)
    [layout(vertical|horizontal) accent(hex) details embed idprefix(name)
     noheader noprovenance replace]
```

| option | effect |
|---|---|
| `layout()` | `vertical` (default) or `horizontal` |
| `accent()` | one accent colour, default `#4a6d8c`; used for flags and join arrowheads only |
| `details` | append the per-event ledger (`<details>` blocks) for joins, links and filters |
| `embed` | emit a fragment instead of a document (see below) |
| `idprefix()` | id and CSS-scope namespace; defaults to `mm-` plus a slug of the output filename |
| `noheader` | drop the caption and legend |
| `noprovenance` | drop the provenance footer |

## Outputs in this directory

| file | what it is |
|---|---|
| `html_vert_scan.html` | scan mode, vertical: the default product, no counts anywhere |
| `html_vert_scan_details.html` | the same plus the event ledger |
| `html_vert_run.html` | run mode, vertical |
| `html_vert_run_details.html` | the same plus the event ledger |
| `html_horiz_scan.html` / `html_horiz_run.html` | horizontal, inside a sideways scroller |
| `frag_run_vert.html` | embed fragment, namespace `mm-1` |
| `frag_scan_vert.html` | embed fragment with ledger, namespace `mm-2` |
| `frag_run_horiz.html` | embed fragment, horizontal, namespace `mm-3` |
| `html_embed_fragment.html` | a mock host report carrying all three fragments; the proof page |

## The embed contract (DECISIONS 21, WEBDOC2 section 5)

With `embed` the file is a fragment, in this order:

```html
<!-- provenance comment -->
<style type="text/css"> ...rules, every one scoped under .mm-1... </style>
<div class="mm-embed mm-1">
  <div class="mm-cap">...</div>
  <div class="mm-leg">...</div>
  <div class="mm-wrap"><svg class="mm-svg" viewBox="0 0 880 2667"> ... </svg></div>
  <div class="mm-foot">...</div>
</div>
```

Guarantees, all checked by `tests.do` and by the browser measurements recorded
below:

1. **No document furniture.** No `<!DOCTYPE>`, `<html>`, `<head>`, `<body>`.
2. **No element selectors, anywhere.** Every selector in the fragment's
   stylesheet is a class selector scoped under the per-diagram class, including
   inside `@media print`. This is the rule that keeps the host report's `body`,
   `h1`, `h2`, `pre`, `details` and `summary` intact.
3. **Every class is prefixed `mm-`**, including the per-diagram scope class.
4. **Every id is namespaced per diagram.** The only ids emitted are the two
   arrowhead markers, `<prefix>-ag` and `<prefix>-aa`, and every `url(#...)`
   reference carries the same prefix. Two diagrams on one page no longer share
   an arrowhead.
5. **The `<svg>` carries `viewBox` and no `width`/`height`**, so a vertical
   diagram scales to whatever column it lands in.
6. **Shapes carry presentation attributes as well as classes** (`fill`,
   `stroke`, `stroke-width`, `font-family`, `font-size`, `font-weight`), so a
   fragment whose stylesheet is stripped is still a legible diagram rather than
   a page of black rectangles.
7. **Horizontal keeps its natural width.** The scoped rule sets the SVG's width
   in pixels and `max-width: none`; `.mm-wrap` scrolls sideways. Squeezed into a
   text column the same diagram rendered its labels at under 2px.

### Overflow and print

```css
.<prefix> .mm-wrap { max-height: 32rem; overflow: auto; resize: vertical; ... }
@media print { .<prefix> .mm-wrap { max-height: none; overflow: visible; ... } }
```

### Tooltips

Every node is a `<g class="mm-node">` whose first child is an SVG `<title>`
carrying the full, untruncated detail: keys, in/using/out counts, the `_merge`
category breakdown, coverage percentages, key storage types, duplicate-key
counts, options, lifecycle, severity and every flag. Native browser tooltip, no
JavaScript.

## v2 schema handling

- Column 9 is read by **name** as `usingfile`; a v1 header (column named `using`)
  is refused with a message that says so, not a bare `r(100)`.
- `severity` drives emphasis, but never colour alone: `warn` and `stop` both
  prefix `!!` on the flag text, and the box stroke thickens (1.7 for warn,
  2.2 in the accent for stop).
- `keytypes` renders as `types: county str5 vs str5`; a drift between the two
  sides is marked `!!` and takes the accent.
- `cover_master` / `cover_using` render as
  `cover: master 99.7% matched · using 99.2% used`, and are simply absent in
  scan mode.
- `lifecycle` marks save nodes `[saved, new]` or `[saved, overwrites]`.
- `class=filter` renders as a slim inset node on the spine: the condition on the
  first line, the tidylog row change beneath it in run mode, and
  `row change unknown until run` in scan mode.
- Unknown trailing columns are ignored; a journal that predates the five v2
  additions still renders.

## Measured on the proof page

Chrome, 1280x900 viewport, 958px content column, `html_embed_fragment.html`:

| check | result |
|---|---|
| host `body` | Georgia, 17px, `max-width: none`, `margin: 0px`, background `#fbfbfb` — unchanged |
| host `h1` / `h2` / `p` | 30px / 22px / 17px with 26.35px line height — unchanged |
| element selectors in mergemap rules (walked live via CSSOM) | 0 |
| duplicate element ids on the page | 0 of 6 |
| host rule `#mm-1-ag path { fill: #b00020 }` | recolours diagram 1 only; diagrams 2 and 3 keep `#444` and `#4a6d8c` |
| vertical fragment | scales 1.058x, effective text 11.6px |
| horizontal fragment | box 958px, content 7028px, `overflow-x: auto`, text 12px |
| page horizontal scrollbar | none |
| `@media print` rule present | yes |
